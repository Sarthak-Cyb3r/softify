package com.softify.app.playback

data class ChunkPlan(
    val shouldOpen: Boolean,
    val requestPosition: Long,
    val requestLength: Long
)

/**
 * Pure range-planning helper for bounded HTTP chunk requests (e.g. googlevideo.com).
 * Uses absolute stream positions so seeks never double the byte offset.
 */
object BoundedRangeHelper {
    const val LENGTH_UNSET: Long = -1L
    const val DEFAULT_CHUNK_SIZE: Long = 1_048_576L // 1 MiB

    private val CONTENT_RANGE_TOTAL_REGEX =
        Regex("""bytes\s+(?:\d+-\d+|\*)/(\d+)""", RegexOption.IGNORE_CASE)

    fun parseTotalLengthFromContentRange(headerValue: String?): Long? {
        if (headerValue.isNullOrBlank()) return null
        val match = CONTENT_RANGE_TOTAL_REGEX.find(headerValue.trim()) ?: return null
        return match.groupValues[1].toLongOrNull()
    }

    fun computeChunkPlan(
        position: Long,
        requestedLength: Long,
        knownTotalLength: Long,
        chunkSize: Long = DEFAULT_CHUNK_SIZE
    ): ChunkPlan {
        if (position < 0L || chunkSize <= 0L) {
            return ChunkPlan(shouldOpen = false, requestPosition = 0L, requestLength = 0L)
        }
        if (requestedLength == 0L) {
            return ChunkPlan(shouldOpen = false, requestPosition = position, requestLength = 0L)
        }
        if (knownTotalLength > 0L && position >= knownTotalLength) {
            return ChunkPlan(shouldOpen = false, requestPosition = position, requestLength = 0L)
        }

        var requestLen = chunkSize
        if (requestedLength != LENGTH_UNSET && requestedLength > 0L) {
            requestLen = minOf(requestLen, requestedLength)
        }
        if (knownTotalLength > 0L) {
            val remainingToEof = (knownTotalLength - position).coerceAtLeast(0L)
            if (remainingToEof == 0L) {
                return ChunkPlan(shouldOpen = false, requestPosition = position, requestLength = 0L)
            }
            requestLen = minOf(requestLen, remainingToEof)
        }

        return ChunkPlan(
            shouldOpen = true,
            requestPosition = position,
            requestLength = requestLen
        )
    }

    fun computeOpenReturnLength(
        position: Long,
        requestedLength: Long,
        knownTotalLength: Long
    ): Long {
        if (knownTotalLength > 0L) {
            val remainingToEof = (knownTotalLength - position).coerceAtLeast(0L)
            return if (requestedLength != LENGTH_UNSET && requestedLength >= 0L) {
                minOf(requestedLength, remainingToEof)
            } else {
                remainingToEof
            }
        }
        return requestedLength
    }
}
