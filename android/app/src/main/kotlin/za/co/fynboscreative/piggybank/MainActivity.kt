package za.co.fynboscreative.piggybank

import android.content.Context
import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

/**
 * Hosts the platform channel for the notification/email detection feature
 * (plan §3, Phase D). Kept directly on MainActivity, not a separate plugin
 * class — this project has no other platform channels yet to fit a
 * multi-channel registration pattern into.
 *
 * Method names/args must match `NotificationListenerChannel` (Dart side,
 * `lib/features/detection/native/notification_listener_channel.dart`)
 * exactly — there's no codegen tying the two together.
 */
class MainActivity : FlutterFragmentActivity() {
    private val channelName = "za.co.fynboscreative.piggybank/notification_detection"
    private val ingestBatchLimit = 25 // matches the backend's ingest endpoint's own cap

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "isNotificationListenerEnabled" -> result.success(isNotificationListenerEnabled())
                "openNotificationListenerSettings" -> {
                    startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
                    result.success(null)
                }
                "updateAllowlist" -> {
                    @Suppress("UNCHECKED_CAST")
                    val packages = (call.arguments as? List<String>)?.toSet() ?: emptySet()
                    detectionPrefs().edit()
                        .putStringSet(DetectionNotificationListenerService.KEY_ALLOWLIST, packages)
                        .apply()
                    result.success(null)
                }
                "updateSenderAllowlist" -> {
                    @Suppress("UNCHECKED_CAST")
                    val bySender = (call.arguments as? Map<String, List<String>>).orEmpty()
                    putPackageToNames(DetectionNotificationListenerService.KEY_SENDER_ALLOWLIST, bySender)
                    result.success(null)
                }
                "senderAllowlist" -> result.success(
                    readPackageToNames(DetectionNotificationListenerService.KEY_SENDER_ALLOWLIST)
                )
                "seenSenders" -> result.success(
                    readPackageToNames(DetectionNotificationListenerService.KEY_SEEN_SENDERS)
                )
                "peekQueuedItems" -> result.success(peekQueuedItems())
                "acknowledgeQueuedItems" -> {
                    val count = (call.argument<Int>("count")) ?: 0
                    acknowledgeQueuedItems(count)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun detectionPrefs() =
        getSharedPreferences(DetectionNotificationListenerService.PREFS_NAME, Context.MODE_PRIVATE)

    private fun isNotificationListenerEnabled(): Boolean {
        val enabledListeners = Settings.Secure.getString(contentResolver, "enabled_notification_listeners") ?: ""
        return enabledListeners.contains(packageName)
    }

    /** Never removes an item that may still be uploaded. See
     * NotificationListenerChannel's doc comment for why peek/acknowledge
     * are split — a failed upload must never lose queued items. The one
     * mutation is [pruneQueue], for items that must never be sent at all. */
    private fun peekQueuedItems(): List<Map<String, Any?>> {
        val array = pruneQueue()
        val limit = minOf(array.length(), ingestBatchLimit)
        return (0 until limit).map { i ->
            val obj = array.getJSONObject(i)
            // `sender` and `filter_verdict` are omitted rather than sent as
            // null when absent: items queued before those fields existed are
            // still in the queue, and the ingest endpoint treats a missing
            // field and an explicit null the same way.
            buildMap {
                put("source_ref", obj.getString("source_ref"))
                put("raw_text", obj.getString("raw_text"))
                put("captured_at", obj.getString("captured_at"))
                obj.optString("sender").takeIf { it.isNotEmpty() }?.let { put("sender", it) }
                obj.optString("filter_verdict").takeIf { it.isNotEmpty() }
                    ?.let { put("filter_verdict", it) }
            }
        }
    }

    /**
     * Drops queued items the sender filter now rejects: items queued before
     * the filter dropped hard, or from a sender unticked since. Re-run on
     * every peek so the upload and the later ack see the same queue.
     */
    private fun pruneQueue(): JSONArray {
        val prefs = detectionPrefs()
        // A queue that no longer parses can't be recovered item by item; reset it rather than crash every peek.
        val array = runCatching { JSONArray(prefs.getString(DetectionNotificationListenerService.KEY_QUEUE, "[]")) }
            .getOrElse {
                prefs.edit().putString(DetectionNotificationListenerService.KEY_QUEUE, "[]").apply()
                JSONArray()
            }
        val allowlist = readPackageToNames(DetectionNotificationListenerService.KEY_SENDER_ALLOWLIST)
        val kept = JSONArray()
        for (i in 0 until array.length()) {
            // Malformed items are dropped: the upload below needs all three fields and would throw on them.
            val obj = array.optJSONObject(i) ?: continue
            val pkg = obj.optString("source_ref").takeIf { it.isNotEmpty() } ?: continue
            val rawText = obj.optString("raw_text").takeIf { it.isNotEmpty() } ?: continue
            if (obj.optString("captured_at").isEmpty()) continue
            val sender = obj.optString("sender").takeIf { it.isNotEmpty() }
            val verdict = DetectionFilter.verdict(pkg, sender, rawText, allowlist[pkg].orEmpty().toSet())
            if (!DetectionFilter.drops(verdict)) kept.put(obj)
        }
        if (kept.length() != array.length()) {
            prefs.edit().putString(DetectionNotificationListenerService.KEY_QUEUE, kept.toString()).apply()
        }
        return kept
    }

    private fun readPackageToNames(key: String): Map<String, List<String>> {
        val root = JSONObject(detectionPrefs().getString(key, "{}"))
        return root.keys().asSequence().associateWith { packageName ->
            val names = root.optJSONArray(packageName) ?: JSONArray()
            (0 until names.length()).mapNotNull { names.optString(it).takeIf(String::isNotEmpty) }
        }
    }

    private fun putPackageToNames(key: String, value: Map<String, List<String>>) {
        val root = JSONObject()
        // An empty list is dropped rather than stored: the listener service
        // reads an absent or empty entry as "no sender allowlist configured
        // for this app", which is what clearing the list should mean.
        value.filterValues { it.isNotEmpty() }.forEach { (packageName, names) ->
            root.put(packageName, JSONArray(names))
        }
        detectionPrefs().edit().putString(key, root.toString()).apply()
    }

    /** Removes the first [count] items (oldest first) from the stored
     * queue — call only after the backend has confirmed receipt. */
    private fun acknowledgeQueuedItems(count: Int) {
        val prefs = detectionPrefs()
        val raw = prefs.getString(DetectionNotificationListenerService.KEY_QUEUE, "[]")
        val array = JSONArray(raw)
        val remaining = JSONArray()
        for (i in count until array.length()) {
            remaining.put(array.get(i))
        }
        prefs.edit().putString(DetectionNotificationListenerService.KEY_QUEUE, remaining.toString()).apply()
    }
}
