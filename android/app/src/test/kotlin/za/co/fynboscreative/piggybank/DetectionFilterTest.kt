package za.co.fynboscreative.piggybank

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import za.co.fynboscreative.piggybank.DetectionFilter.AMOUNT_SHAPE
import za.co.fynboscreative.piggybank.DetectionFilter.VERDICT_CAPTURE
import za.co.fynboscreative.piggybank.DetectionFilter.VERDICT_MESSAGING_NO_SENDERS
import za.co.fynboscreative.piggybank.DetectionFilter.VERDICT_NO_AMOUNT_SHAPE
import za.co.fynboscreative.piggybank.DetectionFilter.VERDICT_SENDER_NOT_ALLOWED
import za.co.fynboscreative.piggybank.DetectionFilter.drops
import za.co.fynboscreative.piggybank.DetectionFilter.verdict

class DetectionFilterTest {
    private val sms = "com.google.android.apps.messaging"
    private val bankApp = "za.co.fnb.connect.itest"
    private val spend = "Purchase R1 250.00 at Checkers"

    @Test
    fun messagingAppWithNoSendersDrops() {
        assertEquals(VERDICT_MESSAGING_NO_SENDERS, verdict(sms, "Mom", spend, emptySet()))
        assertEquals(VERDICT_MESSAGING_NO_SENDERS, verdict("com.whatsapp", null, spend, emptySet()))
    }

    @Test
    fun senderNotOnAllowlistDrops() {
        assertEquals(VERDICT_SENDER_NOT_ALLOWED, verdict(sms, "Mom", spend, setOf("FNB")))
        assertEquals(VERDICT_SENDER_NOT_ALLOWED, verdict(sms, null, spend, setOf("FNB")))
        assertEquals(VERDICT_SENDER_NOT_ALLOWED, verdict(bankApp, "Promo", spend, setOf("FNB")))
    }

    @Test
    fun allowedSenderWithAmountCaptures() {
        assertEquals(VERDICT_CAPTURE, verdict(sms, "FNB", spend, setOf("FNB")))
    }

    @Test
    fun tickedNameInSmsBodyCapturesFromAnyNumber() {
        // Investec sends from a different long number every time (2026-10-27).
        val investec = "A payment/transfer from Investec account ending in 0000 for R100.00 was made"
        assertEquals(VERDICT_CAPTURE, verdict(sms, "+27000000000001", investec, setOf("Investec")))
        assertEquals(VERDICT_CAPTURE, verdict(sms, null, investec, setOf("investec")))
    }

    @Test
    fun bodyMatchNeedsTheWholeWordAndOnlyAppliesToMessagingApps() {
        assertEquals(VERDICT_SENDER_NOT_ALLOWED, verdict(sms, "Mom", "R50 for the FNBX shirt", setOf("FNB")))
        assertEquals(VERDICT_SENDER_NOT_ALLOWED, verdict(bankApp, "Promo", "FNB says R50 off", setOf("FNB")))
    }

    @Test
    fun tickedNameInChatAppBodyIsStillDropped() {
        // F2: a person's WhatsApp/Telegram message naming the bank must not be uploaded.
        for (chat in listOf("com.whatsapp", "com.whatsapp.w4b", "org.telegram.messenger", "org.thoughtcrime.securesms", "com.facebook.orca")) {
            assertEquals(VERDICT_SENDER_NOT_ALLOWED, verdict(chat, "Mom", "paid you R50 from FNB", setOf("FNB")))
        }
    }

    @Test
    fun bankAppWithNoSenderAllowlistIsNotFiltered() {
        assertEquals(VERDICT_CAPTURE, verdict(bankApp, null, spend, emptySet()))
    }

    @Test
    fun noAmountShapeIsReportedButKept() {
        val v = verdict(sms, "FNB", "Your OTP is 123456", setOf("FNB"))
        assertEquals(VERDICT_NO_AMOUNT_SHAPE, v)
        assertFalse(drops(v))
    }

    @Test
    fun onlySenderVerdictsDrop() {
        assertTrue(drops(VERDICT_MESSAGING_NO_SENDERS))
        assertTrue(drops(VERDICT_SENDER_NOT_ALLOWED))
        assertFalse(drops(VERDICT_CAPTURE))
    }

    @Test
    fun amountShape() {
        listOf("R50", "R 1 250.00", "ZAR1,000.5", "paid R12.99.").forEach {
            assertTrue(it, AMOUNT_SHAPE.containsMatchIn(it))
        }
        listOf("Your OTP is 123456", "FOR5", "R", "Rands only").forEach {
            assertFalse(it, AMOUNT_SHAPE.containsMatchIn(it))
        }
    }
}
