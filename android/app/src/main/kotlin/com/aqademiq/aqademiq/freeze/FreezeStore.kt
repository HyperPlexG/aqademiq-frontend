package com.aqademiq.aqademiq.freeze

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONArray
import org.json.JSONException
import org.json.JSONObject

/**
 * App freeze's native side on disk: SharedPreferences `aqademiq_freeze`.
 *
 * Four things, all device-local (APP_FREEZE.md: "We never see your picks"):
 *
 *  * **the policy** Dart last applied, as the JSON string it sent — the
 *    monitor and the boot receiver read it with the app closed;
 *  * **the event queue** (§1.2), which the shield writes and `takeEvents`
 *    drains, so a Thaw pressed with the engine gone is still delivered;
 *  * **shield counts** per package for the current thaw day (4 AM), which
 *    pick the shield's copy (§4);
 *  * **the last check-in** per Distracting package, so Ada asks at most once
 *    in 30 minutes.
 *
 * The parsed policy is cached against the string it came from: the monitor
 * asks for it every second, and re-parsing an unchanged policy that often
 * would be work for nothing.
 */
object FreezeStore {
    const val EVENT_THAW_REQUEST = "thaw_request"

    private const val PREFS = "aqademiq_freeze"
    private const val KEY_POLICY = "policy"
    private const val KEY_EVENTS = "events"
    private const val KEY_SHIELDS = "shields"
    private const val KEY_CHECKINS = "checkins"

    /** A queue nobody drains must not grow without end. */
    private const val MAX_EVENTS = 50
    private const val CHECKIN_KEEP_MS = 24 * 60 * 60_000L

    private val lock = Any()
    private var cachedRaw: String? = null
    private var cachedPolicy: FreezePolicy? = null

    private fun prefs(context: Context): SharedPreferences =
        context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    // ---- the policy --------------------------------------------------------

    /**
     * Keep [raw] as the policy. Committed, not applied: the boot receiver may
     * be the next thing to read it, after a process that never got to write.
     */
    fun savePolicy(context: Context, raw: String): FreezePolicy? {
        val parsed = FreezePolicy.parse(raw)
        synchronized(lock) {
            prefs(context).edit().putString(KEY_POLICY, raw).commit()
            cachedRaw = raw
            cachedPolicy = parsed
        }
        return parsed
    }

    /** The policy last applied, or null when there is none (or it is unreadable). */
    fun policy(context: Context): FreezePolicy? {
        val raw = prefs(context).getString(KEY_POLICY, null) ?: return null
        return synchronized(lock) {
            if (raw != cachedRaw) {
                cachedPolicy = FreezePolicy.parse(raw)
                cachedRaw = raw
            }
            cachedPolicy
        }
    }

    // ---- events (§1.2) -----------------------------------------------------

    /** Queue an event for Dart and tell a live engine there is one waiting. */
    fun queueEvent(context: Context, type: String, target: String?, label: String?, at: Long) {
        synchronized(lock) {
            val store = prefs(context)
            val events = readArray(store.getString(KEY_EVENTS, null))
            val event = JSONObject()
            event.put("type", type)
            event.put("at", at)
            if (target != null) event.put("target", target)
            if (label != null) event.put("label", label)
            events.put(event)
            val kept = if (events.length() <= MAX_EVENTS) {
                events
            } else {
                JSONArray().also { out ->
                    for (i in events.length() - MAX_EVENTS until events.length()) out.put(events.opt(i))
                }
            }
            store.edit().putString(KEY_EVENTS, kept.toString()).commit()
        }
        AppFreezePlugin.notifyEventsWaiting()
    }

    /** Every queued event, oldest first, as channel maps. Reading clears them. */
    fun takeEvents(context: Context): List<Map<String, Any>> {
        val raw = synchronized(lock) {
            val store = prefs(context)
            val value = store.getString(KEY_EVENTS, null)
            if (value != null) store.edit().remove(KEY_EVENTS).commit()
            value
        } ?: return emptyList()
        val out = ArrayList<Map<String, Any>>()
        for (e in readArray(raw).objects()) {
            val type = e.opt("type") as? String ?: continue
            val event = HashMap<String, Any>()
            event["type"] = type
            event["at"] = e.longOrNull("at") ?: System.currentTimeMillis()
            (e.opt("target") as? String)?.let { event["target"] = it }
            (e.opt("label") as? String)?.let { event["label"] = it }
            out.add(event)
        }
        return out
    }

    // ---- shield counts (§4) ------------------------------------------------

    /**
     * One more shield over [pkg] today; returns today's count including this
     * one. Counts reset when the thaw day turns over at 4 AM.
     */
    fun bumpShieldCount(context: Context, pkg: String, t: Long): Int = synchronized(lock) {
        val store = prefs(context)
        val day = FreezeRules.thawDayStart(t)
        val json = readObject(store.getString(KEY_SHIELDS, null))
        val counts = if (json.longOrNull("day") == day) {
            json.optJSONObject("counts") ?: JSONObject()
        } else {
            JSONObject()
        }
        val n = (counts.intOrNull(pkg) ?: 0) + 1
        counts.put(pkg, n)
        val next = JSONObject()
        next.put("day", day)
        next.put("counts", counts)
        store.edit().putString(KEY_SHIELDS, next.toString()).apply()
        n
    }

    // ---- check-ins ---------------------------------------------------------

    /** When Ada last checked in about [pkg], or 0 for never. */
    fun lastCheckIn(context: Context, pkg: String): Long =
        readObject(prefs(context).getString(KEY_CHECKINS, null)).longOrNull(pkg) ?: 0L

    fun markCheckIn(context: Context, pkg: String, t: Long) {
        synchronized(lock) {
            val store = prefs(context)
            val old = readObject(store.getString(KEY_CHECKINS, null))
            // Rebuilt rather than edited, dropping anything a day old: the
            // 30-minute rule never needs it, and the object stays small.
            val next = JSONObject()
            for (key in old.keys()) {
                val at = old.longOrNull(key) ?: continue
                if ((t - at) in 0L until CHECKIN_KEEP_MS) next.put(key, at)
            }
            next.put(pkg, t)
            store.edit().putString(KEY_CHECKINS, next.toString()).apply()
        }
    }

    // ---- JSON --------------------------------------------------------------

    private fun readArray(raw: String?): JSONArray {
        if (raw.isNullOrEmpty()) return JSONArray()
        return try {
            JSONArray(raw)
        } catch (e: JSONException) {
            JSONArray()
        }
    }

    private fun readObject(raw: String?): JSONObject {
        if (raw.isNullOrEmpty()) return JSONObject()
        return try {
            JSONObject(raw)
        } catch (e: JSONException) {
            JSONObject()
        }
    }
}
