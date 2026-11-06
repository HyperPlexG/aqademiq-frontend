package com.aqademiq.aqademiq.freeze

import java.util.Calendar
import java.util.GregorianCalendar
import org.json.JSONArray
import org.json.JSONException
import org.json.JSONObject

/**
 * The policy Dart hands over in `applyPolicy` (APP_FREEZE.md §3), parsed once
 * into plain objects so the monitor is not re-reading JSON every second.
 *
 * Tolerant on purpose, like `FreezeData.fromJson` on the Dart side: a missing
 * key takes the same default Dart would give it, an unknown key is ignored,
 * and a frost without an id or a name is dropped rather than failing the
 * whole policy. A policy that does not parse at all is `null`, which freezes
 * nothing — the safe failure, since nothing freezes that the student did not
 * ask for.
 *
 * Only what Android uses is kept. `ios_selection` / `ios_count`, `set_up`,
 * `recent_apps` and `generated_at` belong to the other platform or to the
 * screens.
 */
class FreezePolicy(
    val frosts: List<Frost>,
    val groups: Groups,
    val thaw: Thaw,
    val now: Now?,
    val grants: List<Grant>,
    val standdown: Standdown?,
    /** Thaws already taken today, as Dart counted them at [thawsCountedAt]. */
    val thawsToday: Int,
    val thawsCountedAt: Long?,
    val focusLabel: String?,
) {

    /** A set of apps by package name. Keep only covers every app it does not list. */
    class AppSet(val packages: Set<String>, val keepOnly: Boolean) {
        fun contains(app: String): Boolean = app in packages

        /** "Freeze these" with nothing picked (or only iOS picks): covers no app here. */
        val coversNothing: Boolean
            get() = !keepOnly && packages.isEmpty()

        companion object {
            val EMPTY = AppSet(emptySet(), false)

            fun from(json: Any?): AppSet {
                if (json !is JSONObject) return EMPTY
                return AppSet(
                    packages = json.optJSONArray("packages").strings().toSet(),
                    keepOnly = json.opt("mode") == "keepOnly",
                )
            }
        }
    }

    class Frost(
        val id: String,
        val name: String,
        val session: Boolean,
        /** ISO weekdays, 1 = Monday … 7 = Sunday. */
        val days: Set<Int>,
        /** Minutes after local midnight; `end <= start` runs overnight. */
        val start: Int,
        val end: Int,
        /** yyyymmdd, inclusive. */
        val fromDay: Int?,
        val untilDay: Int?,
        /** Null runs until stopped. */
        val sessionMinutes: Int?,
        val sessionStartedAt: Long?,
        val deep: Boolean,
        val apps: AppSet,
        val enabled: Boolean,
        val skipUntil: Long?,
    ) {
        val allDay: Boolean
            get() = start == 0 && end >= 1440

        val overnight: Boolean
            get() = !allDay && end <= start

        companion object {
            fun from(json: JSONObject): Frost? {
                val id = json.opt("id") as? String ?: return null
                val name = json.opt("name") as? String ?: return null
                return Frost(
                    id = id,
                    name = name,
                    session = json.opt("kind") == "session",
                    days = json.optJSONArray("days").ints().filter { it in 1..7 }.toSet(),
                    start = (json.intOrNull("start") ?: 540).coerceIn(0, 1440),
                    end = (json.intOrNull("end") ?: 780).coerceIn(0, 1440),
                    fromDay = dayKeyOf(json.opt("from_day") as? String),
                    untilDay = dayKeyOf(json.opt("until_day") as? String),
                    sessionMinutes = json.intOrNull("session_minutes"),
                    sessionStartedAt = json.longOrNull("session_started_at"),
                    deep = json.opt("deep") == true,
                    apps = AppSet.from(json.opt("apps")),
                    enabled = json.opt("enabled") != false,
                    skipUntil = json.longOrNull("skip_until"),
                )
            }
        }
    }

    /** Freeze now: an ad-hoc freeze that is not a frost. */
    class Now(
        val startedAt: Long,
        /** Null = "Until I stop". */
        val endsAt: Long?,
        val deep: Boolean,
        val apps: AppSet,
    ) {
        companion object {
            fun from(json: Any?): Now? {
                if (json !is JSONObject) return null
                val started = json.longOrNull("started_at") ?: return null
                return Now(
                    startedAt = started,
                    endsAt = json.longOrNull("ends_at"),
                    deep = json.opt("deep") == true,
                    apps = AppSet.from(json.opt("apps")),
                )
            }
        }
    }

    /** A thaw: [target] ("*" or a package) is open until [until]. */
    class Grant(val target: String, val until: Long) {
        companion object {
            fun from(json: JSONObject): Grant? {
                val target = json.opt("target") as? String ?: return null
                val until = json.longOrNull("until") ?: return null
                return Grant(target, until)
            }
        }
    }

    /** Thaw everything: frosts stand down, except the Deep freezes in [holds]. */
    class Standdown(val since: Long, val until: Long?, val holds: Map<String, Long>) {
        companion object {
            fun from(json: Any?): Standdown? {
                if (json !is JSONObject) return null
                val since = json.longOrNull("since") ?: return null
                val holds = HashMap<String, Long>()
                val raw = json.optJSONObject("holds")
                if (raw != null) {
                    for (key in raw.keys()) {
                        raw.longOrNull(key)?.let { holds[key] = it }
                    }
                }
                return Standdown(since, json.longOrNull("until"), holds)
            }
        }
    }

    class Groups(val alwaysOpen: AppSet, val neverOpen: AppSet, val distracting: AppSet) {
        companion object {
            fun from(json: Any?): Groups {
                if (json !is JSONObject) return Groups(AppSet.EMPTY, AppSet.EMPTY, AppSet.EMPTY)
                return Groups(
                    alwaysOpen = AppSet.from(json.opt("always_open")),
                    neverOpen = AppSet.from(json.opt("never_open")),
                    distracting = AppSet.from(json.opt("distracting")),
                )
            }
        }
    }

    class Thaw(val increasing: Boolean) {
        companion object {
            fun from(json: Any?): Thaw =
                Thaw(increasing = json is JSONObject && json.opt("resistance") == "increasing")
        }
    }

    companion object {
        /** Null when [raw] is missing or is not a JSON object. */
        fun parse(raw: String?): FreezePolicy? {
            if (raw.isNullOrBlank()) return null
            val json = try {
                JSONObject(raw)
            } catch (e: JSONException) {
                return null
            }
            return from(json)
        }

        fun from(json: JSONObject): FreezePolicy = FreezePolicy(
            frosts = json.optJSONArray("frosts").objects().mapNotNull { Frost.from(it) },
            groups = Groups.from(json.opt("groups")),
            thaw = Thaw.from(json.opt("thaw")),
            now = Now.from(json.opt("now")),
            grants = json.optJSONArray("grants").objects().mapNotNull { Grant.from(it) },
            standdown = Standdown.from(json.opt("standdown")),
            thawsToday = (json.intOrNull("thaws_today") ?: 0).coerceAtLeast(0),
            thawsCountedAt = json.longOrNull("thaws_counted_at"),
            focusLabel = json.opt("focus_label") as? String,
        )

        private val DAY = Regex("""(\d{4})-(\d{2})-(\d{2})""")

        /**
         * "2026-11-09" → 20261109, so dates compare as plain ints. An
         * out-of-range month or day rolls over the way Dart's
         * `DateTime(y, m, d)` does — "2026-02-30" is 2026-03-02, "2026-13-01"
         * is 2027-01-01 — through a lenient calendar, so both sides agree on
         * which day a hand-edited or odd date means.
         */
        fun dayKeyOf(raw: String?): Int? {
            val match = DAY.matchEntire(raw ?: return null) ?: return null
            val (y, m, d) = match.destructured
            val day = GregorianCalendar(y.toInt(), m.toInt() - 1, d.toInt()).apply { isLenient = true }
            return day.get(Calendar.YEAR) * 10000 + (day.get(Calendar.MONTH) + 1) * 100 + day.get(Calendar.DAY_OF_MONTH)
        }
    }
}

// ---- JSON helpers (shared with FreezeStore) ---------------------------------

/** A number under [key], or null when it is absent, JSON null or not a number. */
internal fun JSONObject.longOrNull(key: String): Long? = (opt(key) as? Number)?.toLong()

internal fun JSONObject.intOrNull(key: String): Int? = (opt(key) as? Number)?.toInt()

internal fun JSONArray?.strings(): List<String> {
    if (this == null) return emptyList()
    val out = ArrayList<String>(length())
    for (i in 0 until length()) {
        val value = opt(i)
        if (value is String) out.add(value)
    }
    return out
}

internal fun JSONArray?.ints(): List<Int> {
    if (this == null) return emptyList()
    val out = ArrayList<Int>(length())
    for (i in 0 until length()) {
        val value = opt(i)
        if (value is Number) out.add(value.toInt())
    }
    return out
}

internal fun JSONArray?.objects(): List<JSONObject> {
    if (this == null) return emptyList()
    val out = ArrayList<JSONObject>(length())
    for (i in 0 until length()) {
        val value = opt(i)
        if (value is JSONObject) out.add(value)
    }
    return out
}
