package za.co.fynboscreative.piggybank

import org.junit.Assert.assertEquals
import org.junit.Test
import za.co.fynboscreative.piggybank.DetectionNotificationListenerService.Companion.ackRemoveCount

class QueueAckTest {
    @Test
    fun noTrimRemovesAllAcked() = assertEquals(20, ackRemoveCount(20, 0))

    @Test
    fun trimDuringUploadSparesNewerItems() = assertEquals(17, ackRemoveCount(20, 3))

    @Test
    fun trimLargerThanAckRemovesNothing() = assertEquals(0, ackRemoveCount(20, 25))

    @Test
    fun negativeInputsAreSafe() {
        assertEquals(0, ackRemoveCount(-1, 0))
        assertEquals(5, ackRemoveCount(5, -2))
    }
}
