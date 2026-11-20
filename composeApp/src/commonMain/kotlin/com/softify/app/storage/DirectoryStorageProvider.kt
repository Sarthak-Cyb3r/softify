package com.softify.app.storage

import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.InputStream
import java.io.OutputStream

class DirectoryStorageProvider(
    val rootDirectory: File,
    private val locationLabel: String = rootDirectory.absolutePath
) : StorageProvider {

    init {
        if (!rootDirectory.exists()) {
            rootDirectory.mkdirs()
        }
    }

    override fun getAvailableSpaceBytes(): Long {
        return rootDirectory.usableSpace
    }

    override fun getUsedSpaceBytes(): Long {
        return rootDirectory.listFiles()?.sumOf { it.length() } ?: 0L
    }

    override fun getStorageLocationName(): String {
        return locationLabel
    }

    override fun exists(filename: String): Boolean {
        return File(rootDirectory, filename).exists()
    }

    override fun getFileSize(filename: String): Long {
        val f = File(rootDirectory, filename)
        return if (f.exists()) f.length() else 0L
    }

    override fun openOutputStream(filename: String, append: Boolean): OutputStream {
        val file = File(rootDirectory, filename)
        file.parentFile?.mkdirs()
        return FileOutputStream(file, append)
    }

    override fun openInputStream(filename: String): InputStream {
        return FileInputStream(File(rootDirectory, filename))
    }

    override fun rename(fromFilename: String, toFilename: String): Boolean {
        val src = File(rootDirectory, fromFilename)
        val dst = File(rootDirectory, toFilename)
        if (dst.exists()) {
            dst.delete()
        }
        return src.renameTo(dst)
    }

    override fun delete(filename: String): Boolean {
        return File(rootDirectory, filename).delete()
    }

    override fun listFiles(): List<String> {
        return rootDirectory.listFiles()?.map { it.name } ?: emptyList()
    }

    override fun getFileUri(filename: String): String {
        return File(rootDirectory, filename).toURI().toString()
    }

    override fun validateStorage(): StorageHealth {
        if (!rootDirectory.exists()) {
            return StorageHealth.FOLDER_DELETED
        }
        if (!rootDirectory.canWrite()) {
            return StorageHealth.PERMISSION_REVOKED
        }
        if (getAvailableSpaceBytes() < 50L * 1024L * 1024L) {
            return StorageHealth.STORAGE_FULL
        }
        return StorageHealth.HEALTHY
    }
}
