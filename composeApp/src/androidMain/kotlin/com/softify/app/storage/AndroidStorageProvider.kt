package com.softify.app.storage

import android.content.Context
import android.net.Uri
import android.os.Environment
import android.os.StatFs
import androidx.documentfile.provider.DocumentFile
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.InputStream
import java.io.OutputStream

class AndroidStorageProvider(
    private val context: Context,
    private val treeUriProvider: () -> String?
) : StorageProvider {

    private fun getTreeUri(): Uri? {
        val uriStr = treeUriProvider()
        return if (!uriStr.isNullOrBlank()) {
            runCatching { Uri.parse(uriStr) }.getOrNull()
        } else {
            null
        }
    }

    private fun getDefaultDirectory(): File {
        val base = context.getExternalFilesDir(Environment.DIRECTORY_MUSIC) ?: context.filesDir
        val dir = File(base, "SoftifyDownloads")
        if (!dir.exists()) {
            dir.mkdirs()
        }
        return dir
    }

    override fun getAvailableSpaceBytes(): Long {
        val treeUri = getTreeUri()
        return if (treeUri != null) {
            runCatching {
                val stat = StatFs(context.filesDir.absolutePath)
                stat.availableBytes
            }.getOrDefault(0L)
        } else {
            val dir = getDefaultDirectory()
            runCatching {
                val stat = StatFs(dir.absolutePath)
                stat.availableBytes
            }.getOrDefault(dir.usableSpace)
        }
    }

    override fun getUsedSpaceBytes(): Long {
        val treeUri = getTreeUri()
        return if (treeUri != null) {
            val doc = DocumentFile.fromTreeUri(context, treeUri)
            doc?.listFiles()?.sumOf { it.length() } ?: 0L
        } else {
            getDefaultDirectory().listFiles()?.sumOf { it.length() } ?: 0L
        }
    }

    override fun getStorageLocationName(): String {
        val treeUri = getTreeUri()
        return if (treeUri != null) {
            val doc = DocumentFile.fromTreeUri(context, treeUri)
            doc?.name ?: treeUri.lastPathSegment ?: "Custom Folder"
        } else {
            "Default App Storage"
        }
    }

    override fun exists(filename: String): Boolean {
        val treeUri = getTreeUri()
        return if (treeUri != null) {
            val doc = DocumentFile.fromTreeUri(context, treeUri)
            doc?.findFile(filename)?.exists() == true
        } else {
            File(getDefaultDirectory(), filename).exists()
        }
    }

    override fun getFileSize(filename: String): Long {
        val treeUri = getTreeUri()
        return if (treeUri != null) {
            val doc = DocumentFile.fromTreeUri(context, treeUri)
            doc?.findFile(filename)?.length() ?: 0L
        } else {
            val f = File(getDefaultDirectory(), filename)
            if (f.exists()) f.length() else 0L
        }
    }

    override fun openOutputStream(filename: String, append: Boolean): OutputStream {
        val treeUri = getTreeUri()
        if (treeUri != null) {
            val doc = DocumentFile.fromTreeUri(context, treeUri)
                ?: throw IllegalStateException("Cannot open DocumentFile from URI: $treeUri")
            val target = doc.findFile(filename) ?: doc.createFile("application/octet-stream", filename)
                ?: throw IllegalStateException("Failed to create file $filename in $treeUri")
            val mode = if (append) "wa" else "wt"
            return context.contentResolver.openOutputStream(target.uri, mode)
                ?: throw IllegalStateException("Cannot open output stream for ${target.uri}")
        } else {
            val file = File(getDefaultDirectory(), filename)
            file.parentFile?.mkdirs()
            return FileOutputStream(file, append)
        }
    }

    override fun openInputStream(filename: String): InputStream {
        val treeUri = getTreeUri()
        if (treeUri != null) {
            val doc = DocumentFile.fromTreeUri(context, treeUri)
                ?: throw IllegalStateException("Cannot open DocumentFile from URI: $treeUri")
            val target = doc.findFile(filename)
                ?: throw IllegalStateException("File not found: $filename in $treeUri")
            return context.contentResolver.openInputStream(target.uri)
                ?: throw IllegalStateException("Cannot open input stream for ${target.uri}")
        } else {
            return FileInputStream(File(getDefaultDirectory(), filename))
        }
    }

    override fun rename(fromFilename: String, toFilename: String): Boolean {
        val treeUri = getTreeUri()
        if (treeUri != null) {
            val doc = DocumentFile.fromTreeUri(context, treeUri) ?: return false
            val src = doc.findFile(fromFilename) ?: return false
            val existingDst = doc.findFile(toFilename)
            existingDst?.delete()
            return src.renameTo(toFilename)
        } else {
            val src = File(getDefaultDirectory(), fromFilename)
            val dst = File(getDefaultDirectory(), toFilename)
            if (dst.exists()) dst.delete()
            return src.renameTo(dst)
        }
    }

    override fun delete(filename: String): Boolean {
        val treeUri = getTreeUri()
        return if (treeUri != null) {
            val doc = DocumentFile.fromTreeUri(context, treeUri) ?: return false
            doc.findFile(filename)?.delete() ?: false
        } else {
            File(getDefaultDirectory(), filename).delete()
        }
    }

    override fun listFiles(): List<String> {
        val treeUri = getTreeUri()
        return if (treeUri != null) {
            val doc = DocumentFile.fromTreeUri(context, treeUri) ?: return emptyList()
            doc.listFiles().mapNotNull { it.name }
        } else {
            getDefaultDirectory().listFiles()?.map { it.name } ?: emptyList()
        }
    }

    override fun getFileUri(filename: String): String {
        val treeUri = getTreeUri()
        return if (treeUri != null) {
            val doc = DocumentFile.fromTreeUri(context, treeUri)
            val f = doc?.findFile(filename)
            f?.uri?.toString() ?: ""
        } else {
            File(getDefaultDirectory(), filename).toURI().toString()
        }
    }

    override fun validateStorage(): StorageHealth {
        val treeUri = getTreeUri()
        if (treeUri != null) {
            val hasPerm = context.contentResolver.persistedUriPermissions.any {
                it.uri == treeUri && it.isWritePermission
            }
            if (!hasPerm) {
                return StorageHealth.PERMISSION_REVOKED
            }
            val doc = DocumentFile.fromTreeUri(context, treeUri)
            if (doc == null || !doc.exists() || !doc.isDirectory) {
                return StorageHealth.FOLDER_DELETED
            }
        } else {
            val dir = getDefaultDirectory()
            if (!dir.exists() && !dir.mkdirs()) {
                return StorageHealth.FOLDER_DELETED
            }
            if (!dir.canWrite()) {
                return StorageHealth.PERMISSION_REVOKED
            }
        }

        if (getAvailableSpaceBytes() < 50L * 1024L * 1024L) {
            return StorageHealth.STORAGE_FULL
        }

        return StorageHealth.HEALTHY
    }
}
