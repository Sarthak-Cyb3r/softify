package com.softify.app

import com.softify.app.playback.BoundedRangeHelper
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

class BoundedRangeHelperTest {

    @Test
    fun testSeekToMiddleUsesExactAbsoluteOffsetNotDoubled() {
        val totalBytes = 3_456_789L
        // Seek to ~50% (previously subrange(pos, len) requested 2 * pos -> HTTP 416!)
        val seekPos = 1_750_000L

        val plan = BoundedRangeHelper.computeChunkPlan(
            position = seekPos,
            requestedLength = BoundedRangeHelper.LENGTH_UNSET,
            knownTotalLength = totalBytes
        )

        assertTrue(plan.shouldOpen)
        assertEquals(seekPos, plan.requestPosition, "Chunk request must start at exact seek offset")
        assertEquals(BoundedRangeHelper.DEFAULT_CHUNK_SIZE, plan.requestLength)
        assertTrue(plan.requestPosition + plan.requestLength <= totalBytes)
    }

    @Test
    fun testSeekPastUnknownFirstOpenStillRequestsExactOffset() {
        // Even before knownTotalLength is populated, seeking past 50% must not double offset
        val seekPos = 2_100_000L
        val plan = BoundedRangeHelper.computeChunkPlan(
            position = seekPos,
            requestedLength = BoundedRangeHelper.LENGTH_UNSET,
            knownTotalLength = BoundedRangeHelper.LENGTH_UNSET
        )

        assertTrue(plan.shouldOpen)
        assertEquals(2_100_000L, plan.requestPosition)
        assertEquals(1_048_576L, plan.requestLength)
    }

    @Test
    fun testFinalChunkClampedAndEofPreventedFromSending416() {
        val totalBytes = 3_000_000L

        // Seek near end of track (only 250 KB remaining)
        val nearEndPlan = BoundedRangeHelper.computeChunkPlan(
            position = 2_750_000L,
            requestedLength = BoundedRangeHelper.LENGTH_UNSET,
            knownTotalLength = totalBytes
        )
        assertTrue(nearEndPlan.shouldOpen)
        assertEquals(2_750_000L, nearEndPlan.requestPosition)
        assertEquals(250_000L, nearEndPlan.requestLength)

        // Exact EOF boundary must NOT open another Range request (avoids HTTP 416)
        val eofPlan = BoundedRangeHelper.computeChunkPlan(
            position = totalBytes,
            requestedLength = BoundedRangeHelper.LENGTH_UNSET,
            knownTotalLength = totalBytes
        )
        assertFalse(eofPlan.shouldOpen)
    }

    @Test
    fun testContentRangeParsing206And416() {
        assertEquals(
            3_456_789L,
            BoundedRangeHelper.parseTotalLengthFromContentRange("bytes 0-1048575/3456789")
        )
        assertEquals(
            3_456_789L,
            BoundedRangeHelper.parseTotalLengthFromContentRange("bytes */3456789")
        )
        assertNull(BoundedRangeHelper.parseTotalLengthFromContentRange("bytes 0-100/*"))
        assertNull(BoundedRangeHelper.parseTotalLengthFromContentRange(null))
    }

    @Test
    fun testOpenReturnLengthReportsRemainingStreamSizeWhenKnown() {
        val totalBytes = 3_456_789L
        assertEquals(
            totalBytes,
            BoundedRangeHelper.computeOpenReturnLength(0L, BoundedRangeHelper.LENGTH_UNSET, totalBytes)
        )
        assertEquals(
            1_456_789L,
            BoundedRangeHelper.computeOpenReturnLength(2_000_000L, BoundedRangeHelper.LENGTH_UNSET, totalBytes)
        )
        assertEquals(
            50_000L,
            BoundedRangeHelper.computeOpenReturnLength(2_000_000L, 50_000L, totalBytes)
        )
    }
}
