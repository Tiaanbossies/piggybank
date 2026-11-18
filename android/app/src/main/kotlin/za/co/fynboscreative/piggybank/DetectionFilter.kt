package za.co.fynboscreative.piggybank

/**
 * The finer filter, kept free of Android types so it runs under plain JUnit.
 *
 * Two verdicts drop hard, before anything is queued: a messaging app with no
 * sender allowlist (its notifications are mostly people, not banks), and any
 * sender missing from a configured allowlist. `no_amount_shape` still only
 * reports, until `GET /detection/filter-report` shows it never drops a real
 * transaction.
 */
object DetectionFilter {
    // Must match FilterVerdict in backend detection/schemas.py — there
    // is no codegen between the two sides. The two dropped verdicts never
    // leave the phone, so the backend doesn't need to know them.
    const val VERDICT_CAPTURE = "capture"
    const val VERDICT_NO_AMOUNT_SHAPE = "no_amount_shape"
    const val VERDICT_SENDER_NOT_ALLOWED = "sender_not_allowed"
    const val VERDICT_MESSAGING_NO_SENDERS = "messaging_no_senders"

    // Must match messagingPackages in notification_listener_channel.dart.
    val MESSAGING_PACKAGES = setOf(
        "com.google.android.apps.messaging", // Google Messages
        "com.samsung.android.messaging", // Samsung Messages
        "com.android.mms", // AOSP Messaging
        "com.whatsapp",
        "com.whatsapp.w4b", // WhatsApp Business
        "org.telegram.messenger",
        "org.thoughtcrime.securesms", // Signal
        "com.facebook.orca", // Messenger
    )

    // The SMS apps among MESSAGING_PACKAGES. Only here may a ticked bank name
    // in the text stand in for the sender: in a chat app anyone can type
    // "FNB", so a person's message would be uploaded (F2).
    val SMS_PACKAGES = setOf(
        "com.google.android.apps.messaging",
        "com.samsung.android.messaging",
        "com.android.mms",
    )

    /**
     * A deliberately permissive first cut at "this text mentions money":
     * R or ZAR immediately before a number. Untuned, because there is no
     * corpus of real bank SMSes to tune it against yet (plan §4) — and
     * while it only reports, permissive is the right bias, since a shape
     * this misses is a transaction the filter would have silently
     * thrown away.
     */
    val AMOUNT_SHAPE = Regex("""(?<![A-Za-z])(?:ZAR|R)\s?\d[\d ,]*(?:\.\d{1,2})?""")

    /**
     * Outside messaging apps, an empty sender allowlist means "not
     * configured", not "allow nothing". In a messaging app it means nothing
     * is read until the user ticks a sender.
     */
    fun verdict(packageName: String, sender: String?, body: String, allowedSenders: Set<String>): String {
        if (allowedSenders.isEmpty() && packageName in MESSAGING_PACKAGES) return VERDICT_MESSAGING_NO_SENDERS
        if (allowedSenders.isNotEmpty() && (sender == null || sender !in allowedSenders) &&
            !(packageName in SMS_PACKAGES && namesInBody(body, allowedSenders))
        ) {
            return VERDICT_SENDER_NOT_ALLOWED
        }
        if (!AMOUNT_SHAPE.containsMatchIn(body)) return VERDICT_NO_AMOUNT_SHAPE
        return VERDICT_CAPTURE
    }

    // Some banks (Investec) send SMS from a new number every time, so a
    // ticked name also counts when it appears as a whole word in the text.
    private fun namesInBody(body: String, names: Set<String>): Boolean = names.any {
        Regex("""(?<![A-Za-z0-9])${Regex.escape(it)}(?![A-Za-z0-9])""", RegexOption.IGNORE_CASE).containsMatchIn(body)
    }

    fun drops(verdict: String): Boolean =
        verdict == VERDICT_MESSAGING_NO_SENDERS || verdict == VERDICT_SENDER_NOT_ALLOWED
}
