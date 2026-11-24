package com.softify.app.sync

import java.security.MessageDigest
import kotlin.math.max

/**
 * Hybrid Logical Clock (HLC) timestamp providing monotonic ordering across distributed nodes.
 * Format: "${millis}-${counter.padStart(4, '0')}-${nodeId}"
 */
data class HlcTimestamp(
    val millis: Long,
    val counter: Int,
    val nodeId: String
) : Comparable<HlcTimestamp> {

    override fun compareTo(other: HlcTimestamp): Int {
        if (this.millis != other.millis) {
            return this.millis.compareTo(other.millis)
        }
        if (this.counter != other.counter) {
            return this.counter.compareTo(other.counter)
        }
        return this.nodeId.compareTo(other.nodeId)
    }

    override fun toString(): String {
        return "$millis-${counter.toString().padStart(4, '0')}-$nodeId"
    }

    companion object {
        fun parse(str: String): HlcTimestamp {
            val parts = str.split("-", limit = 3)
            require(parts.size == 3) { "Invalid HLC string: $str" }
            return HlcTimestamp(
                millis = parts[0].toLong(),
                counter = parts[1].toInt(),
                nodeId = parts[2]
            )
        }
    }
}

/**
 * Thread-safe Hybrid Logical Clock implementation.
 */
class HlcClock(
    val nodeId: String,
    private val physicalClock: () -> Long = { System.currentTimeMillis() }
) {
    private var lastMillis: Long = 0L
    private var counter: Int = 0

    @Synchronized
    fun now(): HlcTimestamp {
        val pt = physicalClock()
        if (pt > lastMillis) {
            lastMillis = pt
            counter = 0
        } else {
            counter++
        }
        return HlcTimestamp(lastMillis, counter, nodeId)
    }

    @Synchronized
    fun update(remote: HlcTimestamp): HlcTimestamp {
        val pt = physicalClock()
        val maxTime = max(max(pt, lastMillis), remote.millis)

        if (maxTime == lastMillis && maxTime == remote.millis) {
            counter = max(counter, remote.counter) + 1
        } else if (maxTime == lastMillis) {
            counter++
        } else if (maxTime == remote.millis) {
            counter = remote.counter + 1
        } else {
            counter = 0
        }
        lastMillis = maxTime
        return HlcTimestamp(lastMillis, counter, nodeId)
    }
}

/**
 * Deterministically generates a 16-character recovery code in SOFT-XXXX-XXXX-XXXX format
 * from a client secret or device ID.
 */
fun generateRecoveryCode(seed: String): String {
    val md = MessageDigest.getInstance("SHA-256")
    val digest = md.digest(seed.toByteArray(Charsets.UTF_8))
    val allowedChars = "23456789ABCDEFGHJKLMNPQRSTUVWXYZ" // Crockford-style base32 (no ambiguous 0/O, 1/I)
    val sb = StringBuilder()
    for (i in 0 until 12) {
        val byteVal = digest[i].toInt() and 0xFF
        sb.append(allowedChars[byteVal % allowedChars.length])
    }
    val codePart = sb.toString()
    return "SOFT-${codePart.substring(0, 4)}-${codePart.substring(4, 8)}-${codePart.substring(8, 12)}"
}
