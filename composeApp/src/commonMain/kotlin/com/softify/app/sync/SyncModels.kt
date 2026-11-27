package com.softify.app.sync

enum class SyncEntityType {
    FAVORITE,
    PLAYLIST,
    HISTORY,
    SETTING;

    fun toWireType(): String = when (this) {
        FAVORITE -> "track_like"
        PLAYLIST -> "playlist"
        HISTORY -> "history_aggregate"
        SETTING -> "setting"
    }

    companion object {
        fun fromWireType(wire: String): SyncEntityType = when (wire.lowercase()) {
            "track_like", "favorite" -> FAVORITE
            "playlist" -> PLAYLIST
            "history_aggregate", "history" -> HISTORY
            "setting" -> SETTING
            else -> SETTING
        }
    }
}

/**
 * Represents a single sync outbox mutation record.
 */
data class SyncChange(
    val entityType: SyncEntityType,
    val entityId: String,
    val hlc: HlcTimestamp,
    val isDeleted: Boolean = false,
    val payload: String = "",
    val version: Int = 1
)

data class SyncResult(
    val serverHlc: HlcTimestamp,
    val appliedChanges: List<SyncChange>,
    val budgetTier: String = "TIER_0_NORMAL",
    val isSuccess: Boolean = true,
    val cursor: Long = 0L
)

/**
 * Resolves conflict between local and remote change records using Last-Write-Wins (LWW)
 * powered by Hybrid Logical Clocks.
 */
object LwwResolver {
    fun resolve(local: SyncChange, remote: SyncChange): SyncChange {
        return if (remote.hlc > local.hlc) {
            remote
        } else {
            local
        }
    }
}
