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

        val rawText = if (title.isNullOrBlank()) body else "$title: $body"
        enqueue(packageName, rawText, sbn.postTime)
    }

    private fun enqueue(packageName: String, rawText: String, postTimeMillis: Long) {
        val sharedPrefs = prefs()
        val queue = JSONArray(sharedPrefs.getString(KEY_QUEUE, "[]"))
        val item = JSONObject().apply {
            put("source_ref", packageName)
            put("raw_text", rawText.take(MAX_RAW_TEXT_CHARS))
            put("captured_at", isoTimestamp(postTimeMillis))
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
        const val MAX_QUEUE_SIZE = 200
        const val MAX_RAW_TEXT_CHARS = 4000
    }
}
