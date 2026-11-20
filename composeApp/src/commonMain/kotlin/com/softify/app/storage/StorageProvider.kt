package com.softify.app.storage

import java.io.InputStream
import java.io.OutputStream

enum class StorageHealth {
    HEALTHY,
    PERMISSION_REVOKED,
    FOLDER_DELETED,
    STORAGE_FULL,
}

interface StorageProvider {
    fun getAvailableSpaceBytes(): Long
    fun getUsedSpaceBytes(): Long
    fun getStorageLocationName(): String
    fun exists(filename: String): Boolean
    fun getFileSize(filename: String): Long
    fun openOutputStream(filename: String, append: Boolean = false): OutputStream
    fun openInputStream(filename: String): InputStream
    fun rename(fromFilename: String, toFilename: String): Boolean
    fun delete(filename: String): Boolean
    fun listFiles(): List<String>
    fun getFileUri(filename: String): String
    fun validateStorage(): StorageHealth
}
