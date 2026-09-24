package za.co.fynboscreative.piggybank

import android.app.Notification
import android.content.Context
import android.content.SharedPreferences
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

/**
 * Notification/email detection feature (plan §3, Phase D — notifications
 * only; Gmail is server-side, Phase C).
 *
 * The allowlist filter runs HERE, in the native callback, before anything
 * reaches Dart or crosses the platform channel — a notification from a
 * package not on the synced allowlist is dropped in this function and
 * never queued, logged, or otherwise retained. This is the concrete
 * mechanism behind the plan's "nothing outside that allowlist is ever
 * read, parsed, or sent anywhere."
 *
 * The allowlist and the capture queue both live in one SharedPreferences
 * file (not a database — a capped list of small text blobs doesn't
 * warrant one), shared with MainActivity's platform-channel handler, which
 * is the only other reader/writer of these keys.
 *
 * The finer filter (sprint plan §3 Phase 3) — per-sender allowlist and a
 * currency-amount shape check — runs in SHADOW MODE: its verdict is
 * computed and attached to the queued item, but nothing is dropped on its
 * account. A filter tuned against imagined bank formats is tuned against
 * nothing, so it reports what it would have done for a while first, and
 * `GET /detection/filter-report` says whether it was ever right. The
 * package allowlist above is unaffected and still drops hard.
 */
class DetectionNotificationListenerService : NotificationListenerService() {

    private fun prefs(): SharedPreferences = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        val packageName = sbn.packageName
        val allowlist = prefs().getStringSet(KEY_ALLOWLIST, emptySet()) ?: emptySet()
        if (packageName !in allowlist) return

        val extras = sbn.notification.extras
        val bigText = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString()
        val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString()
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()
        val body = (bigText ?: text)?.trim()
        if (body.isNullOrEmpty()) return

        // For an SMS app the notification title is the sender: a bank's
        // short-name, or a person. Kept as its own field as well as inside
        // rawText, because the per-sender allowlist has to match on it.
        val sender = title?.trim()?.takeIf { it.isNotEmpty() }
        val rawText = if (sender == null) body else "$sender: $body"

        if (sender != null) rememberSeenSender(packageName, sender)
        enqueue(packageName, rawText, sbn.postTime, sender, verdict(packageName, sender, body))
    }

    /**
     * What the finer filter WOULD do with this notification. Nothing acts
     * on it yet — see the class comment.
     *
     * An empty sender allowlist for a package means "not configured", not
     * "allow nothing": the user has to have listed at least one sender
     * before absence from the list means anything.
     */
    private fun verdict(packageName: String, sender: String?, body: String): String {
        val allowedSenders = senderAllowlist()[packageName].orEmpty()
        if (allowedSenders.isNotEmpty() && (sender == null || sender !in allowedSenders)) {
            return VERDICT_SENDER_NOT_ALLOWED
        }
        if (!AMOUNT_SHAPE.containsMatchIn(body)) return VERDICT_NO_AMOUNT_SHAPE
        return VERDICT_CAPTURE
    }

    private fun senderAllowlist(): Map<String, Set<String>> =
        readPackageToNames(KEY_SENDER_ALLOWLIST)

    /**
     * Records that this sender exists, so the settings screen can offer the
     * senders actually seen on this phone instead of asking the user to
     * type a bank's SMS short-name from memory.
     */
    private fun rememberSeenSender(packageName: String, sender: String) {
        val seen = readPackageToNames(KEY_SEEN_SENDERS)
        val forPackage = seen[packageName].orEmpty()
        if (sender in forPackage) return
        if (forPackage.size >= MAX_SEEN_SENDERS_PER_PACKAGE) return

        val updated = JSONObject(prefs().getString(KEY_SEEN_SENDERS, "{}"))
        updated.put(packageName, JSONArray((forPackage + sender).toList()))
        prefs().edit().putString(KEY_SEEN_SENDERS, updated.toString()).apply()
    }

    private fun readPackageToNames(key: String): Map<String, Set<String>> {
        val root = JSONObject(prefs().getString(key, "{}"))
        return root.keys().asSequence().associateWith { packageName ->
            val names = root.optJSONArray(packageName) ?: JSONArray()
            (0 until names.length()).mapNotNull { names.optString(it).takeIf(String::isNotEmpty) }.toSet()
        }
    }

    private fun enqueue(
        packageName: String,
        rawText: String,
        postTimeMillis: Long,
        sender: String?,
        filterVerdict: String,
    ) {
        val sharedPrefs = prefs()
        val queue = JSONArray(sharedPrefs.getString(KEY_QUEUE, "[]"))
        val item = JSONObject().apply {
            put("source_ref", packageName)
            put("raw_text", rawText.take(MAX_RAW_TEXT_CHARS))
            put("captured_at", isoTimestamp(postTimeMillis))
            if (sender != null) put("sender", sender.take(MAX_SENDER_CHARS))
            put("filter_verdict", filterVerdict)
        }
        queue.put(item)

        // Capped queue (plan §3): once full, drop the oldest rather than
        // growing unbounded if the device is offline or the app just
        // isn't opened for a while.
        val trimmed = if (queue.length() > MAX_QUEUE_SIZE) {
            JSONArray().apply {
                for (i in (queue.length() - MAX_QUEUE_SIZE) until queue.length()) {
                    put(queue.get(i))
                }
            }
        } else {
            queue
        }
        sharedPrefs.edit().putString(KEY_QUEUE, trimmed.toString()).apply()
    }

    private fun isoTimestamp(millis: Long): String {
        val formatter = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US)
        formatter.timeZone = TimeZone.getTimeZone("UTC")
        return formatter.format(Date(millis))
    }

    companion object {
        const val PREFS_NAME = "detection_notification_queue"
        const val KEY_ALLOWLIST = "allowlist_packages"
        const val KEY_QUEUE = "queued_items"
        const val KEY_SENDER_ALLOWLIST = "allowlist_senders"
        const val KEY_SEEN_SENDERS = "seen_senders"
        const val MAX_QUEUE_SIZE = 200
        const val MAX_RAW_TEXT_CHARS = 4000
        const val MAX_SENDER_CHARS = 255
        const val MAX_SEEN_SENDERS_PER_PACKAGE = 50

        // Must match FilterVerdict in backend detection/schemas.py — there
        // is no codegen between the two sides.
        const val VERDICT_CAPTURE = "capture"
        const val VERDICT_NO_AMOUNT_SHAPE = "no_amount_shape"
        const val VERDICT_SENDER_NOT_ALLOWED = "sender_not_allowed"

        /**
         * A deliberately permissive first cut at "this text mentions money":
         * R or ZAR immediately before a number. Untuned, because there is no
         * corpus of real bank SMSes to tune it against yet (plan §4) — and
         * while it only reports, permissive is the right bias, since a shape
         * this misses is a transaction the filter would have silently
         * thrown away.
         */
        val AMOUNT_SHAPE = Regex("""(?<![A-Za-z])(?:ZAR|R)\s?\d[\d ,]*(?:\.\d{1,2})?""")
    }
}
