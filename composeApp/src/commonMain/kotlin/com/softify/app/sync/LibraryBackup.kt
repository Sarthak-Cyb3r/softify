package com.softify.app.sync

import com.softify.app.util.JsonCodec
import uniffi.softify_core.Track

data class BackupPlaylist(
    val id: String,
    val name: String,
    val description: String?,
    val tracks: List<Track>
)

data class ValidatedBackup(
    val schemaVersion: Int,
    val deviceId: String,
    val recoveryCode: String?,
    val exportedAtMs: Long,
    val likedTracks: List<Track>,
    val playlists: List<BackupPlaylist>,
    val entities: List<SyncChange>
)

/**
 * Schema-validated JSON export and import helper for user library migration
 * across keystore upgrades or fresh installs. Backwards compatible with M7 entity dumps.
 */
object LibraryBackup {
    const val CURRENT_SCHEMA_VERSION = 2
    const val MAX_BACKUP_BYTES = 5 * 1024 * 1024 // 5 MB safety guard

    private val RECOVERY_CODE_REGEX = Regex("""^SOFT-[2-9A-HJ-NP-Z]{4}-[2-9A-HJ-NP-Z]{4}-[2-9A-HJ-NP-Z]{4}$""")

    fun exportToJson(
        deviceId: String,
        recoveryCode: String,
        likedTracks: List<Track>,
        playlists: List<BackupPlaylist>,
        entities: Collection<SyncChange>,
        exportedAtMs: Long = System.currentTimeMillis()
    ): String {
        val doc = linkedMapOf<String, Any?>(
            "schemaVersion" to CURRENT_SCHEMA_VERSION,
            "deviceId" to deviceId,
            "recoveryCode" to recoveryCode,
            "exportedAt" to exportedAtMs,
            "likedTracks" to likedTracks.map(::trackToMap),
            "playlists" to playlists.map { pl ->
                linkedMapOf<String, Any?>(
                    "id" to pl.id,
                    "name" to pl.name,
                    "description" to pl.description,
                    "tracks" to pl.tracks.map(::trackToMap)
                )
            },
            "entities" to entities.filter { !it.isDeleted }.map { ch ->
                linkedMapOf<String, Any?>(
                    "type" to ch.entityType.name,
                    "id" to ch.entityId,
                    "hlc" to ch.hlc.toString(),
                    "payload" to ch.payload,
                    "version" to ch.version
                )
            }
        )
        return JsonCodec.stringify(doc)
    }

    fun validateAndParse(rawJson: String): Result<ValidatedBackup> {
        return runCatching {
            val trimmed = rawJson.trim()
            require(trimmed.isNotEmpty()) { "Backup JSON is empty" }
            require(trimmed.toByteArray(Charsets.UTF_8).size <= MAX_BACKUP_BYTES) {
                "Backup exceeds maximum supported size (5 MB)"
            }

            val root = try {
                JsonCodec.parseObject(trimmed)
            } catch (e: Exception) {
                throw IllegalArgumentException("Malformed JSON backup: ${e.message}")
            }

            val schemaVersion = (root["schemaVersion"] as? Number)?.toInt() ?: if (root.containsKey("entities")) 1 else -1
            require(schemaVersion in 1..CURRENT_SCHEMA_VERSION) {
                "Unsupported or missing backup schemaVersion: $schemaVersion"
            }

            val exportedAt = (root["exportedAt"] as? Number)?.toLong() ?: -1L
            require(exportedAt > 0L) { "Missing or invalid 'exportedAt' timestamp" }

            val deviceId = root["deviceId"]?.toString()?.takeIf { it.isNotBlank() }
                ?: throw IllegalArgumentException("Missing 'deviceId' in backup")

            val recoveryCode = root["recoveryCode"]?.toString()?.takeIf { it.isNotBlank() }
            if (recoveryCode != null) {
                require(RECOVERY_CODE_REGEX.matches(recoveryCode)) {
                    "Invalid recoveryCode format (expected SOFT-XXXX-XXXX-XXXX)"
                }
            }

            val likedListRaw = root["likedTracks"]
            val likedTracks = if (likedListRaw != null) {
                @Suppress("UNCHECKED_CAST")
                val arr = likedListRaw as? List<Any?>
                    ?: throw IllegalArgumentException("'likedTracks' must be a JSON array")
                arr.mapIndexed { idx, entry -> parseTrack(entry, "likedTracks[$idx]", isLiked = true) }
            } else {
                emptyList()
            }

            val playlistsRaw = root["playlists"]
            val playlists = if (playlistsRaw != null) {
                @Suppress("UNCHECKED_CAST")
                val arr = playlistsRaw as? List<Any?>
                    ?: throw IllegalArgumentException("'playlists' must be a JSON array")
                arr.mapIndexed { idx, entry -> parsePlaylist(entry, "playlists[$idx]") }
            } else {
                emptyList()
            }

            val entitiesRaw = root["entities"]
            val entities = if (entitiesRaw != null) {
                @Suppress("UNCHECKED_CAST")
                val arr = entitiesRaw as? List<Any?>
                    ?: throw IllegalArgumentException("'entities' must be a JSON array")
                arr.mapIndexed { idx, entry -> parseEntity(entry, "entities[$idx]") }
            } else {
                emptyList()
            }

            require(likedListRaw != null || playlistsRaw != null || entitiesRaw != null) {
                "Backup contains no library sections (likedTracks, playlists, or entities)"
            }

            ValidatedBackup(
                schemaVersion = schemaVersion,
                deviceId = deviceId,
                recoveryCode = recoveryCode,
                exportedAtMs = exportedAt,
                likedTracks = likedTracks,
                playlists = playlists,
                entities = entities
            )
        }
    }

    private fun trackToMap(t: Track): Map<String, Any?> = linkedMapOf(
        "id" to t.id,
        "sourceId" to t.sourceId,
        "title" to t.title,
        "artist" to t.artist,
        "album" to t.album,
        "durationMs" to t.durationMs.toLong(),
        "coverUrl" to t.coverUrl,
        "isLiked" to t.isLiked
    )

    private fun parseTrack(raw: Any?, context: String, isLiked: Boolean = false): Track {
        @Suppress("UNCHECKED_CAST")
        val m = raw as? Map<String, Any?>
            ?: throw IllegalArgumentException("$context must be a JSON object")
        val id = m["id"]?.toString()?.takeIf { it.isNotBlank() }
            ?: throw IllegalArgumentException("$context missing non-blank 'id'")
        val sourceId = m["sourceId"]?.toString()?.takeIf { it.isNotBlank() } ?: id
        val title = m["title"]?.toString()?.takeIf { it.isNotBlank() }
            ?: throw IllegalArgumentException("$context missing non-blank 'title'")
        val artist = m["artist"]?.toString()?.takeIf { it.isNotBlank() }
            ?: throw IllegalArgumentException("$context missing non-blank 'artist'")
        val duration = (m["durationMs"] as? Number)?.toLong() ?: 0L
        require(duration >= 0L) { "$context has negative durationMs" }

        return Track(
            id = id,
            sourceId = sourceId,
            title = title,
            artist = artist,
            album = m["album"] as? String,
            durationMs = duration.toULong(),
            coverUrl = m["coverUrl"] as? String,
            matchConfidence = null,
            isLiked = isLiked || ((m["isLiked"] as? Boolean) ?: false),
            isUnavailable = false
        )
    }

    private fun parsePlaylist(raw: Any?, context: String): BackupPlaylist {
        @Suppress("UNCHECKED_CAST")
        val m = raw as? Map<String, Any?>
            ?: throw IllegalArgumentException("$context must be a JSON object")
        val id = m["id"]?.toString()?.takeIf { it.isNotBlank() }
            ?: throw IllegalArgumentException("$context missing non-blank 'id'")
        val name = m["name"]?.toString()?.takeIf { it.isNotBlank() }
            ?: throw IllegalArgumentException("$context missing non-blank 'name'")
        val tracksRaw = m["tracks"] as? List<Any?>
            ?: throw IllegalArgumentException("$context missing 'tracks' array")
        val tracks = tracksRaw.mapIndexed { idx, t -> parseTrack(t, "$context.tracks[$idx]") }
        return BackupPlaylist(
            id = id,
            name = name,
            description = m["description"] as? String,
            tracks = tracks
        )
    }

    private fun parseEntity(raw: Any?, context: String): SyncChange {
        @Suppress("UNCHECKED_CAST")
        val m = raw as? Map<String, Any?>
            ?: throw IllegalArgumentException("$context must be a JSON object")
        val typeStr = m["type"]?.toString()?.takeIf { it.isNotBlank() }
            ?: throw IllegalArgumentException("$context missing 'type'")
        val id = m["id"]?.toString()?.takeIf { it.isNotBlank() }
            ?: throw IllegalArgumentException("$context missing 'id'")
        val hlcStr = m["hlc"]?.toString()?.takeIf { it.isNotBlank() }
            ?: throw IllegalArgumentException("$context missing 'hlc'")
        val hlc = HlcTimestamp.parse(hlcStr)
        val payload = m["payload"]?.toString() ?: ""
        val version = (m["version"] as? Number)?.toInt() ?: 1
        return SyncChange(
            entityType = SyncEntityType.fromWireType(typeStr),
            entityId = id,
            hlc = hlc,
            isDeleted = false,
            payload = payload,
            version = version
        )
    }
}
