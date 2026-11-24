package com.softify.app.sync

enum class SyncEntityType {
    FAVORITE,
    PLAYLIST,
    HISTORY,
    SETTING
}

/**
 * Represents a single sync outbox mutation record.
 */
data class SyncChange(
    val entityType: SyncEntityType,
    val entityId: String,
    val hlc: HlcTimestamp,
    val isDeleted: Boolean = false,
    val payload: String = ""
)

data class SyncResult(
    val serverHlc: HlcTimestamp,
    val appliedChanges: List<SyncChange>,
    val budgetTier: String = "TIER_1_NORMAL",
    val isSuccess: Boolean = true
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
