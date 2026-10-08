@file:Suppress("DEPRECATION")

package com.softify.softify

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageInfo
import android.content.pm.PackageInstaller
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.provider.Settings
import androidx.core.content.ContextCompat
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.security.MessageDigest

class MainActivity : AudioServiceActivity() {
    private val CHANNEL = "com.softify/installer"
    private val ACTION_STATUS = "com.softify.softify.INSTALLER_STATUS"
    private val EXTRA_OPERATION = "com.softify.softify.extra.OPERATION"
    private val OP_INSTALL = "install"
    private val OP_UNINSTALL = "uninstall"
    private val UNINSTALL_TIMEOUT_MS = 120_000L

    // The platform has no STATUS_FAILURE_VERSION_DOWNGRADE: it reports
    // STATUS_FAILURE_INVALID plus the legacy install code in this hidden extra.
    private val EXTRA_LEGACY_STATUS = "android.content.pm.extra.LEGACY_STATUS"
    private val LEGACY_INSTALL_FAILED_VERSION_DOWNGRADE = -25

    private val mainHandler = Handler(Looper.getMainLooper())
    private val pendingOps = HashMap<Int, PendingOp>()
    private val activeSessions = HashMap<Int, PackageInstaller.Session>()
    private val installerReceiver = InstallerResultReceiver()
    private var receiverRegistered = false
    private var lastRequestCode = 0

    private class PendingOp(
        val result: MethodChannel.Result,
        val filePath: String?,
        var timeout: Runnable? = null
    )

    private inner class InstallerResultReceiver : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            handleInstallerStatus(context, intent)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        if (!receiverRegistered) {
            ContextCompat.registerReceiver(
                this,
                installerReceiver,
                IntentFilter(ACTION_STATUS),
                ContextCompat.RECEIVER_NOT_EXPORTED
            )
            receiverRegistered = true
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "installApk" -> installApk(call, result)
                "preflightInstall" -> preflightInstall(call, result)
                "uninstallApk" -> uninstallApk(result)
                "getInstalledInfo" -> getInstalledInfo(result)
                "stageApk" -> stageApk(call, result)
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        if (receiverRegistered) {
            runCatching { unregisterReceiver(installerReceiver) }
            receiverRegistered = false
        }
        mainHandler.removeCallbacksAndMessages(null)
        super.onDestroy()
    }

    private fun installApk(call: MethodCall, result: MethodChannel.Result) {
        val filePath = call.argument<String>("filePath")
        if (filePath == null) {
            result.error("INVALID_ARGUMENT", "filePath is required", null)
            return
        }
        val file = File(filePath)
        if (!file.exists()) {
            result.error("FILE_NOT_FOUND", "APK file not found: $filePath", null)
            return
        }
        if (!canRequestInstalls()) {
            startActivity(
                Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:$packageName"))
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            )
            result.error("BLOCKED", "Requires permission to install unknown apps", null)
            return
        }

        var sessionId = -1
        try {
            val installer = packageManager.packageInstaller
            sessionId = installer.createSession(newSessionParams())
            val session = installer.openSession(sessionId)
            session.openWrite("base.apk", 0, file.length()).use { out ->
                FileInputStream(file).use { input -> input.copyTo(out) }
                session.fsync(out)
            }
            pendingOps[sessionId] = PendingOp(result, filePath)
            activeSessions[sessionId] = session
            session.commit(statusPendingIntent(sessionId, OP_INSTALL).intentSender)
        } catch (e: Exception) {
            failSession(sessionId)
            result.error("INSTALL_ERROR", e.message, null)
        }
    }

    private fun uninstallApk(result: MethodChannel.Result) {
        var sessionId = -1
        try {
            val installer = packageManager.packageInstaller
            sessionId = installer.createSession(newSessionParams())
            val session = installer.openSession(sessionId)
            val timeout = Runnable {
                if (pendingOps.remove(sessionId) != null) {
                    releaseSession(sessionId, false)
                    result.error("FAILURE", "Timed out", null)
                }
            }
            pendingOps[sessionId] = PendingOp(result, null, timeout)
            activeSessions[sessionId] = session
            session.commit(statusPendingIntent(sessionId, OP_UNINSTALL).intentSender)
            mainHandler.postDelayed(timeout, UNINSTALL_TIMEOUT_MS)
        } catch (e: Exception) {
            failSession(sessionId)
            result.error("FAILURE", e.message, null)
        }
    }

    private fun preflightInstall(call: MethodCall, result: MethodChannel.Result) {
        val filePath = call.argument<String>("filePath")
        if (filePath == null) {
            result.error("INVALID_ARGUMENT", "filePath is required", null)
            return
        }
        try {
            val archive = packageManager.getPackageArchiveInfo(filePath, signatureFlags())
                ?: throw IllegalStateException("Unable to parse APK: $filePath")
            val archiveSha = signatureSha256(archive)
                ?: throw IllegalStateException("Unable to read APK signature")
            val apkVersionCode = versionCodeOf(archive)
            var installedVersionCode = 0L
            var signatureMatch = true
            val installed = installedPackageInfo()
            if (installed != null) {
                installedVersionCode = versionCodeOf(installed)
                val installedSha = signatureSha256(installed)
                    ?: throw IllegalStateException("Unable to read installed signature")
                signatureMatch = archiveSha == installedSha
            }
            result.success(
                mapOf<String, Any>(
                    "apkVersionCode" to apkVersionCode,
                    "installedVersionCode" to installedVersionCode,
                    "signatureMatch" to signatureMatch,
                    "canRequestInstalls" to canRequestInstalls()
                )
            )
        } catch (e: Exception) {
            result.error("PREFLIGHT_ERROR", e.message, null)
        }
    }

    private fun getInstalledInfo(result: MethodChannel.Result) {
        val info = installedPackageInfo()
        result.success(
            mapOf<String, Any?>(
                "versionCode" to (info?.let { versionCodeOf(it) } ?: 0L),
                "versionName" to info?.versionName,
                "signatureSha256" to (info?.let { signatureSha256(it) })
            )
        )
    }

    /**
     * Copies the downloaded update into the shared Downloads folder so it survives
     * the uninstall that a signing-key change forces on the user.
     */
    private fun stageApk(call: MethodCall, result: MethodChannel.Result) {
        val filePath = call.argument<String>("filePath")
        if (filePath == null) {
            result.error("INVALID_ARGUMENT", "filePath is required", null)
            return
        }
        val source = File(filePath)
        if (!source.exists()) {
            result.error("FILE_NOT_FOUND", "APK file not found: $filePath", null)
            return
        }
        val fileName = call.argument<String>("fileName") ?: source.name
        try {
            val savedPath = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val values = ContentValues().apply {
                    put(MediaStore.Downloads.DISPLAY_NAME, fileName)
                    put(MediaStore.Downloads.MIME_TYPE, "application/vnd.android.package-archive")
                    put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
                    put(MediaStore.Downloads.IS_PENDING, 1)
                }
                val uri = contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                    ?: throw IllegalStateException("Could not create a Downloads entry")
                contentResolver.openOutputStream(uri)?.use { out ->
                    FileInputStream(source).use { input -> input.copyTo(out) }
                } ?: throw IllegalStateException("Could not write to Downloads")
                values.clear()
                values.put(MediaStore.Downloads.IS_PENDING, 0)
                contentResolver.update(uri, values, null, null)
                "${Environment.DIRECTORY_DOWNLOADS}/$fileName"
            } else {
                val dir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
                if (!dir.exists()) dir.mkdirs()
                val dest = File(dir, fileName)
                FileInputStream(source).use { input ->
                    dest.outputStream().use { output -> input.copyTo(output) }
                }
                dest.absolutePath
            }
            result.success(mapOf("path" to savedPath))
        } catch (e: Exception) {
            result.error("STAGE_ERROR", e.message, null)
        }
    }

    private fun handleInstallerStatus(context: Context, intent: Intent) {
        val status = intent.getIntExtra(PackageInstaller.EXTRA_STATUS, PackageInstaller.STATUS_FAILURE)
        if (status == PackageInstaller.STATUS_PENDING_USER_ACTION) {
            val confirm = intent.getParcelableExtra<Intent>(Intent.EXTRA_INTENT)
            if (confirm != null) {
                context.startActivity(confirm.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            }
            return
        }
        val sessionId = intent.getIntExtra(PackageInstaller.EXTRA_SESSION_ID, -1)
        val op = pendingOps.remove(sessionId) ?: return
        op.timeout?.let { mainHandler.removeCallbacks(it) }
        val success = status == PackageInstaller.STATUS_SUCCESS
        releaseSession(sessionId, success)
        op.filePath?.let { runCatching { File(it).delete() } }
        if (success) {
            op.result.success(mapOf("status" to "SUCCESS"))
            return
        }
        val uninstall = intent.getStringExtra(EXTRA_OPERATION) == OP_UNINSTALL
        val downgrade = intent.getIntExtra(EXTRA_LEGACY_STATUS, 0) == LEGACY_INSTALL_FAILED_VERSION_DOWNGRADE
        val code = when {
            uninstall && status == PackageInstaller.STATUS_FAILURE_ABORTED -> "USER_ABORTED"
            uninstall -> "FAILURE"
            downgrade -> "VERSION_DOWNGRADE"
            else -> statusCode(status)
        }
        val message = if (downgrade) "Version downgrade not allowed" else statusMessage(status)
        op.result.error(code, message, null)
    }

    private fun newSessionParams() =
        PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL)
            .apply { setAppPackageName(packageName) }

    private fun statusPendingIntent(sessionId: Int, operation: String): PendingIntent {
        // A component would make ActivityManagerService skip registered receivers entirely,
        // so the status intent stays implicit and is directed at this package only.
        val intent = Intent(ACTION_STATUS).apply {
            setPackage(packageName)
            putExtra(PackageInstaller.EXTRA_SESSION_ID, sessionId)
            putExtra(EXTRA_OPERATION, operation)
        }
        var flags = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            flags = flags or PendingIntent.FLAG_MUTABLE
        }
        return PendingIntent.getBroadcast(this, ++lastRequestCode, intent, flags)
    }

    private fun failSession(sessionId: Int) {
        if (sessionId < 0) return
        pendingOps.remove(sessionId)
        releaseSession(sessionId, false)
    }

    private fun releaseSession(sessionId: Int, success: Boolean) {
        val session = activeSessions.remove(sessionId)
        try {
            if (session != null) {
                if (success) session.close() else session.abandon()
            } else if (!success) {
                packageManager.packageInstaller.abandonSession(sessionId)
            }
        } catch (e: Exception) {
        }
    }

    private fun statusCode(status: Int) = when (status) {
        PackageInstaller.STATUS_FAILURE_ABORTED -> "USER_ABORTED"
        PackageInstaller.STATUS_FAILURE_BLOCKED -> "BLOCKED"
        PackageInstaller.STATUS_FAILURE_INVALID -> "INVALID"
        PackageInstaller.STATUS_FAILURE_CONFLICT -> "CONFLICT"
        PackageInstaller.STATUS_FAILURE_STORAGE -> "STORAGE"
        else -> "FAILURE"
    }

    private fun statusMessage(status: Int) = when (status) {
        PackageInstaller.STATUS_FAILURE_ABORTED -> "Cancelled by user"
        PackageInstaller.STATUS_FAILURE_BLOCKED -> "Blocked by the system"
        PackageInstaller.STATUS_FAILURE_INVALID -> "Invalid APK"
        PackageInstaller.STATUS_FAILURE_CONFLICT -> "Conflicts with an existing installation"
        PackageInstaller.STATUS_FAILURE_STORAGE -> "Not enough storage"
        else -> "Operation failed"
    }

    private fun canRequestInstalls() =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.O || packageManager.canRequestPackageInstalls()

    private fun signatureFlags() =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            PackageManager.GET_SIGNING_CERTIFICATES
        } else {
            PackageManager.GET_SIGNATURES
        }

    private fun versionCodeOf(info: PackageInfo) =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            info.getLongVersionCode()
        } else {
            info.versionCode.toLong()
        }

    private fun signatureSha256(info: PackageInfo): String? {
        val signatures =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) info.signingInfo?.apkContentsSigners
            else info.signatures
        val signature = signatures?.firstOrNull() ?: return null
        val digest = MessageDigest.getInstance("SHA-256").digest(signature.toByteArray())
        return digest.joinToString("") { "%02X".format(it.toInt() and 0xFF) }
    }

    private fun installedPackageInfo(): PackageInfo? = try {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            packageManager.getPackageInfo(packageName, PackageManager.GET_SIGNING_CERTIFICATES)
        } else {
            packageManager.getPackageInfo(packageName, PackageManager.GET_SIGNATURES)
        }
    } catch (e: Exception) {
        null
    }
}
