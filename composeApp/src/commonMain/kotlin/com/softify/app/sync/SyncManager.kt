package com.softify.app.sync

import com.softify.app.util.PlaybackLogger
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.util.UUID

/**
 * Manages offline-first SQLite outbox synchronization with Last-Write-Wins (LWW)
 * conflict resolution and tombstones for deletions.
 */
class SyncManager(
    val deviceId: String = UUID.randomUUID().toString(),
    val clock: HlcClock = HlcClock(nodeId = deviceId.take(8))
) {
    val recoveryCode: String = generateRecoveryCode(deviceId)

    private val _outbox = mutableListOf<SyncChange>()
    private val _stateMap = mutableMapOf<String, SyncChange>() // Key: entityType:entityId

    private val _pendingCount = MutableStateFlow(0)
    val pendingCount: StateFlow<Int> = _pendingCount.asStateFlow()

    private val _lastSyncTimestamp = MutableStateFlow<Long?>(null)
    val lastSyncTimestamp: StateFlow<Long?> = _lastSyncTimestamp.asStateFlow()

    private val _budgetTier = MutableStateFlow("TIER_1_NORMAL")
    val budgetTier: StateFlow<String> = _budgetTier.asStateFlow()

    private val _isLocalOnly = MutableStateFlow(false)
    val isLocalOnly: StateFlow<Boolean> = _isLocalOnly.asStateFlow()

    fun setLocalOnly(localOnly: Boolean) {
        _isLocalOnly.value = localOnly
        PlaybackLogger.log("SoftifySync", "Local only mode set to: $localOnly")
    }

    @Synchronized
    fun recordChange(
        entityType: SyncEntityType,
        entityId: String,
        payload: String = "",
        isDeleted: Boolean = false
    ): SyncChange {
        val timestamp = clock.now()
        val change = SyncChange(
            entityType = entityType,
            entityId = entityId,
            hlc = timestamp,
            isDeleted = isDeleted,
            payload = payload
        )

        val key = "${entityType.name}:$entityId"
        _stateMap[key] = change
        _outbox.add(change)
        _pendingCount.value = _outbox.size

        PlaybackLogger.log("SoftifySync", "Outbox change enqueued: $key ($timestamp, isDeleted=$isDeleted)")
        return change
    }

    @Synchronized
    fun getPendingChanges(): List<SyncChange> {
        return _outbox.toList()
    }

    @Synchronized
    fun applyRemoteChanges(remoteChanges: List<SyncChange>, serverHlc: HlcTimestamp) {
        clock.update(serverHlc)

        for (remote in remoteChanges) {
            val key = "${remote.entityType.name}:${remote.entityId}"
            val local = _stateMap[key]
            if (local == null) {
                _stateMap[key] = remote
            } else {
                _stateMap[key] = LwwResolver.resolve(local, remote)
            }
        }

        // Outbox items applied or superseded can be cleared
        _outbox.clear()
        _pendingCount.value = 0
        _lastSyncTimestamp.value = System.currentTimeMillis()
        PlaybackLogger.log("SoftifySync", "Applied ${remoteChanges.size} remote changes successfully.")
    }

    @Synchronized
    fun updateTier(tier: String) {
        _budgetTier.value = tier
    }

    @Synchronized
    fun exportUserDataJson(): String {
        val sb = StringBuilder()
        sb.append("{\n")
        sb.append("  \"deviceId\": \"$deviceId\",\n")
        sb.append("  \"recoveryCode\": \"$recoveryCode\",\n")
        sb.append("  \"exportedAt\": ${System.currentTimeMillis()},\n")
        sb.append("  \"entities\": [\n")
        val items = _stateMap.values.filter { !it.isDeleted }
        items.forEachIndexed { index, change ->
            sb.append("    {\"type\": \"${change.entityType}\", \"id\": \"${change.entityId}\", \"hlc\": \"${change.hlc}\", \"payload\": \"${change.payload.replace("\"", "\\\"")}\"}")
            if (index < items.size - 1) sb.append(",")
            sb.append("\n")
        }
        sb.append("  ]\n")
        sb.append("}")
        return sb.toString()
    }

    @Synchronized
    fun clearAllData() {
        _outbox.clear()
        _stateMap.clear()
        _pendingCount.value = 0
        _lastSyncTimestamp.value = null
        PlaybackLogger.log("SoftifySync", "All user data cleared locally (GDPR delete).")
    }

    @Synchronized
    fun getStateSnapshot(): Map<String, SyncChange> = _stateMap.toMap()
}
