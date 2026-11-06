package com.aqademiq.aqademiq.freeze

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ResolveInfo
import android.net.Uri
import android.os.Build
import android.provider.AlarmClock
import android.provider.Settings
import android.provider.Telephony
import android.telecom.TelecomManager
import java.util.Calendar
import java.util.Locale

/**
 * The App freeze rules (APP_FREEZE.md §2), the Android port of `FreezeEngine`
 * in `lib/features/freeze/domain/freeze_engine.dart`.
 *
 * The Dart file is the specification. A frost has to keep running while
 * Aqademiq is closed, so the monitor evaluates the same rules over the same
 * policy itself — change a rule there and change it here and in
 * `FreezeRules.swift`. Everything is in the phone's local time zone, read
 * through [Calendar] by fields (as Dart's `DateTime(y, m, d, 0, minute)` does),
 * so a DST night lands on the same wall-clock minute on both sides.
 *
 * [Floor] is the one Android-only rule: the apps that are never frozen
 * whatever the policy says.
 */
object FreezeRules {
    /** A thaw day starts at 4 AM — "Resets each morning", not at midnight. */
    const val DAY_START_HOUR = 4
    const val BREATH_SECONDS = 10
    const val BREATH_STEP = 10
    const val MAX_BREATH = 60
    const val NOW_ID = "now"
    const val ALL_APPS = "*"

    /** One window of a frost; [end] null = until stopped. */
    class Window(val start: Long, val end: Long?)

    /** A freeze running now: a frost in its window, or Freeze now. */
    class Active(
        val id: String,
        val name: String,
        val apps: FreezePolicy.AppSet,
        val deep: Boolean,
        val start: Long,
        val end: Long?,
    ) {
        fun covers(app: String): Boolean = if (apps.keepOnly) !apps.contains(app) else apps.contains(app)
    }

    // ---- local time, by fields -------------------------------------------

    private fun calendar(t: Long): Calendar = Calendar.getInstance().apply { timeInMillis = t }

    /** Local midnight of the day containing [t]. */
    private fun dayOf(t: Long): Calendar = calendar(t).apply {
        set(Calendar.HOUR_OF_DAY, 0)
        set(Calendar.MINUTE, 0)
        set(Calendar.SECOND, 0)
        set(Calendar.MILLISECOND, 0)
    }

    /** [minute] after [day]'s midnight, by wall clock; 1440 + n is tomorrow. */
    private fun at(day: Calendar, minute: Int): Long {
        val c = day.clone() as Calendar
        if (minute >= 1440) c.add(Calendar.DAY_OF_MONTH, minute / 1440)
        val m = minute % 1440
        c.set(Calendar.HOUR_OF_DAY, m / 60)
        c.set(Calendar.MINUTE, m % 60)
        c.set(Calendar.SECOND, 0)
        c.set(Calendar.MILLISECOND, 0)
        return c.timeInMillis
    }

    /** ISO weekday: 1 = Monday … 7 = Sunday. */
    private fun weekday(day: Calendar): Int {
        val dow = day.get(Calendar.DAY_OF_WEEK)
        return if (dow == Calendar.SUNDAY) 7 else dow - 1
    }

    private fun dayKey(day: Calendar): Int =
        day.get(Calendar.YEAR) * 10000 + (day.get(Calendar.MONTH) + 1) * 100 + day.get(Calendar.DAY_OF_MONTH)

    private fun inDates(f: FreezePolicy.Frost, day: Calendar): Boolean {
        val key = dayKey(day)
        val from = f.fromDay
        val until = f.untilDay
        if (from != null && key < from) return false
        if (until != null && key > until) return false
        return true
    }

    // ---- the rules -------------------------------------------------------

    /**
     * The window of [f] that contains [t], ignoring whether the frost is on,
     * skipped or standing down.
     */
    fun windowAt(f: FreezePolicy.Frost, t: Long): Window? {
        if (f.session) {
            val started = f.sessionStartedAt ?: return null
            if (t < started) return null
            val minutes = f.sessionMinutes
            val end = if (minutes == null) null else started + minutes * 60_000L
            if (end != null && t >= end) return null
            return Window(started, end)
        }
        val today = dayOf(t)
        val clock = calendar(t)
        val minute = clock.get(Calendar.HOUR_OF_DAY) * 60 + clock.get(Calendar.MINUTE)
        if (!f.overnight) {
            val end = if (f.allDay) 1440 else f.end
            if (weekday(today) in f.days && inDates(f, today) && minute >= f.start && minute < end) {
                return Window(at(today, f.start), at(today, end))
            }
            return null
        }
        // Overnight: tonight's window, or the tail of last night's.
        if (weekday(today) in f.days && inDates(f, today) && minute >= f.start) {
            return Window(at(today, f.start), at(today, 1440 + f.end))
        }
        val yesterday = (today.clone() as Calendar).apply { add(Calendar.DAY_OF_MONTH, -1) }
        if (weekday(yesterday) in f.days && inDates(f, yesterday) && minute < f.end) {
            return Window(at(yesterday, f.start), at(today, f.end))
        }
        return null
    }

    fun standingDown(p: FreezePolicy, t: Long): Boolean {
        val s = p.standdown ?: return false
        val until = s.until
        return t >= s.since && (until == null || t < until)
    }

    /**
     * Everything running at [t]. A frost that is off, skipped for today, or
     * standing down (without a Deep freeze hold) is not running.
     */
    fun active(p: FreezePolicy, t: Long): List<Active> {
        val out = ArrayList<Active>()
        val down = standingDown(p, t)
        for (f in p.frosts) {
            if (!f.enabled) continue
            val skip = f.skipUntil
            if (skip != null && t < skip) continue
            val w = windowAt(f, t) ?: continue
            if (down) {
                val hold = p.standdown?.holds?.get(f.id)
                if (hold == null || t >= hold) continue
            }
            out.add(Active(f.id, f.name, f.apps, f.deep, w.start, w.end))
        }
        val now = p.now
        if (now != null) {
            val ends = now.endsAt
            if (t >= now.startedAt && (ends == null || t < ends)) {
                val held = if (!down) {
                    true
                } else {
                    val hold = p.standdown?.holds?.get(NOW_ID)
                    hold != null && t < hold
                }
                if (held) out.add(Active(NOW_ID, "Freeze now", now.apps, now.deep, now.startedAt, ends))
            }
        }
        return out
    }

    /** A thaw that covers [app] at [t]. */
    fun grantFor(p: FreezePolicy, app: String, t: Long): FreezePolicy.Grant? =
        p.grants.firstOrNull { t < it.until && (it.target == ALL_APPS || it.target == app) }

    /** The running freezes that cover [app]. */
    fun covering(p: FreezePolicy, app: String, t: Long, running: List<Active> = active(p, t)): List<Active> =
        running.filter { it.covers(app) }

    /**
     * The rule for one app (§2): Never open always, Always open never, else a
     * running freeze covers it and no thaw reaches it (thaws never reach a
     * Deep freeze). [app] is a package name. The device floor is not applied
     * here; callers check [Floor] first.
     */
    fun isFrozen(p: FreezePolicy, app: String, t: Long, running: List<Active> = active(p, t)): Boolean {
        if (p.groups.neverOpen.contains(app)) return true
        if (p.groups.alwaysOpen.contains(app)) return false
        val over = covering(p, app, t, running)
        if (over.isEmpty()) return false
        if (over.any { it.deep }) return true
        return grantFor(p, app, t) == null
    }

    /**
     * When [app] really unfreezes, for the shield's line and the notification:
     * the LATEST end among the freezes covering it (§4) — two freezes on one
     * app hold it until the last one ends. Null when any of them has no end
     * ("Until you stop"), or when [over] is empty.
     */
    fun nextUnfreeze(over: List<Active>): Long? =
        if (over.isEmpty() || over.any { it.end == null }) null else over.maxOf { it.end!! }

    /**
     * When thawing opens again under the Deep freezes in [over]: the latest
     * end among them. Null when one of them runs until stopped.
     */
    fun deepUntil(over: List<Active>): Long? {
        val deep = over.filter { it.deep }
        if (deep.isEmpty() || deep.any { it.end == null }) return null
        return deep.mapNotNull { it.end }.maxOrNull()
    }

    /** The start of the thaw day containing [t] (4 AM local). */
    fun thawDayStart(t: Long): Long {
        val four = dayOf(t).apply { set(Calendar.HOUR_OF_DAY, DAY_START_HOUR) }
        if (t < four.timeInMillis) {
            four.add(Calendar.DAY_OF_MONTH, -1)
            four.set(Calendar.HOUR_OF_DAY, DAY_START_HOUR)
        }
        return four.timeInMillis
    }

    /**
     * Thaws taken today. The policy carries Dart's count and when it was
     * taken; a count from an earlier thaw day says nothing about this one.
     */
    fun thawsToday(p: FreezePolicy, t: Long): Int {
        val counted = p.thawsCountedAt ?: return 0
        return if (thawDayStart(counted) == thawDayStart(t)) p.thawsToday else 0
    }

    /** The breath before a thaw: 10 s, or on Increasing 10 more per thaw today, up to 60. */
    fun breathFor(p: FreezePolicy, t: Long): Int {
        if (!p.thaw.increasing) return BREATH_SECONDS
        return (BREATH_SECONDS + BREATH_STEP * thawsToday(p, t)).coerceAtMost(MAX_BREATH)
    }

    /**
     * Whether the policy can freeze anything now or later — the monitor runs
     * while this is true. Never open and Distracting work at any hour; a
     * schedule frost counts until its last day has passed (and the night
     * after it, for an overnight one); a session frost or Freeze now only
     * while it is running, because starting one goes through the app, which
     * applies the policy again.
     */
    fun needsMonitor(p: FreezePolicy, t: Long): Boolean {
        if (p.groups.neverOpen.packages.isNotEmpty()) return true
        if (p.groups.distracting.packages.isNotEmpty()) return true
        val now = p.now
        if (now != null && !now.apps.coversNothing) {
            val ends = now.endsAt
            if (ends == null || t < ends) return true
        }
        val yesterday = dayOf(t).apply { add(Calendar.DAY_OF_MONTH, -1) }
        val yesterdayKey = dayKey(yesterday)
        for (f in p.frosts) {
            if (!f.enabled || f.apps.coversNothing) continue
            if (f.session) {
                val started = f.sessionStartedAt ?: continue
                val minutes = f.sessionMinutes
                if (minutes == null || t < started + minutes * 60_000L) return true
            } else {
                if (f.days.isEmpty()) continue
                val until = f.untilDay
                if (until == null || until >= yesterdayKey) return true
            }
        }
        return false
    }

    // ---- words -----------------------------------------------------------

    /** "3:42" — no AM/PM, as the shield and the notification say it (FreezeText.bareClock). */
    fun bareClock(t: Long): String {
        val c = calendar(t)
        val h = c.get(Calendar.HOUR_OF_DAY)
        val h12 = if (h % 12 == 0) 12 else h % 12
        return String.format(Locale.US, "%d:%02d", h12, c.get(Calendar.MINUTE))
    }

    /** "1:00 PM" (FreezeText.clock). */
    fun clock(t: Long): String {
        val h = calendar(t).get(Calendar.HOUR_OF_DAY)
        return bareClock(t) + (if (h < 12) " AM" else " PM")
    }

    /**
     * The apps Android never freezes, whatever the policy says (§2): Aqademiq
     * itself, every home app, Settings, System UI, the default dialer and SMS
     * app, the phone's emergency and in-call apps, the clock (an alarm rings
     * in it), and the system screens other apps borrow — the share sheet, the
     * file and photo pickers, Google sign-in. Without this a Keep only frost
     * would put the shield over the launcher and the student could not leave
     * it, over the dialer in an emergency, and over the 6:30 alarm.
     *
     * Cached for ten minutes: the default launcher, dialer or SMS app changes
     * rarely, and the monitor asks every second.
     */
    object Floor {
        private const val TTL_MS = 10 * 60_000L

        /** Present on most phones under these names; harmless where absent. */
        private val FIXED = setOf(
            "android",
            "com.android.systemui",
            "com.android.settings",
            "com.android.phone",
            "com.android.server.telecom",
            "com.android.incallui",
            "com.samsung.android.incallui",
            "com.android.emergency",
            "com.samsung.android.emergency",
            "com.google.android.apps.safetyhub",
            "com.android.cellbroadcastreceiver",
            "com.google.android.cellbroadcastreceiver",
            "com.android.permissioncontroller",
            "com.google.android.permissioncontroller",
            "com.android.packageinstaller",
            "com.google.android.packageinstaller",
            // Screens another app opens on top of itself: the share sheet
            // (Android 14+ moved it out of "android"), the document and
            // photo pickers, and Play services — Google sign-in and
            // Credential Manager live there. Freezing these breaks an app
            // the student is allowed to use.
            "com.android.intentresolver",
            "com.google.android.documentsui",
            "com.android.documentsui",
            "com.google.android.providers.media.module",
            "com.android.providers.media.module",
            "com.google.android.gms",
            // The clock: a ringing alarm is its full-screen activity, and a
            // Wind down frost must never cover the morning alarm. Whatever
            // answers SHOW_ALARMS is added in packages() as well.
            "com.google.android.deskclock",
            "com.android.deskclock",
            "com.sec.android.app.clockpackage",
        )

        @Volatile private var cached: Set<String> = emptySet()

        @Volatile private var cachedAt = 0L

        fun contains(context: Context, app: String): Boolean = app in packages(context)

        fun packages(context: Context): Set<String> {
            val t = System.currentTimeMillis()
            val current = cached
            if (current.isNotEmpty() && (t - cachedAt) in 0L until TTL_MS) return current
            val pm = context.packageManager
            val out = HashSet<String>(FIXED)
            out.add(context.packageName)
            // Every home app, not only the default: the student may switch.
            for (ri in query(pm, Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME))) {
                ri.activityInfo?.packageName?.let(out::add)
            }
            resolve(pm, Intent(Settings.ACTION_SETTINGS))?.let(out::add)
            // Every app that answers SHOW_ALARMS, not only the default: an
            // alarm rings in the app that set it, whichever that is.
            for (ri in query(pm, Intent(AlarmClock.ACTION_SHOW_ALARMS))) {
                ri.activityInfo?.packageName?.let(out::add)
            }
            dialer(context)?.let(out::add)
            sms(context)?.let(out::add)
            cached = out
            cachedAt = t
            return out
        }

        /** The default dialer, or whatever answers a tel: link. */
        fun dialer(context: Context): String? {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val telecom = context.getSystemService(Context.TELECOM_SERVICE) as? TelecomManager
                val pkg = try {
                    telecom?.defaultDialerPackage
                } catch (e: RuntimeException) {
                    null
                }
                if (!pkg.isNullOrEmpty()) return pkg
            }
            return resolve(context.packageManager, Intent(Intent.ACTION_DIAL, Uri.parse("tel:")))
        }

        /** The default SMS app, or whatever answers an smsto: link. */
        fun sms(context: Context): String? {
            val pkg = try {
                Telephony.Sms.getDefaultSmsPackage(context)
            } catch (e: RuntimeException) {
                null
            }
            if (!pkg.isNullOrEmpty()) return pkg
            return resolve(context.packageManager, Intent(Intent.ACTION_SENDTO, Uri.parse("smsto:")))
        }

        @Suppress("DEPRECATION")
        internal fun query(pm: PackageManager, intent: Intent): List<ResolveInfo> = try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                pm.queryIntentActivities(intent, PackageManager.ResolveInfoFlags.of(0L))
            } else {
                pm.queryIntentActivities(intent, 0)
            }
        } catch (e: RuntimeException) {
            emptyList()
        }

        /**
         * The package that would open [intent] by default, or null when
         * nothing does or the phone would ask (the chooser lives in "android").
         */
        @Suppress("DEPRECATION")
        internal fun resolve(pm: PackageManager, intent: Intent): String? = try {
            val ri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                pm.resolveActivity(
                    intent,
                    PackageManager.ResolveInfoFlags.of(PackageManager.MATCH_DEFAULT_ONLY.toLong()),
                )
            } else {
                pm.resolveActivity(intent, PackageManager.MATCH_DEFAULT_ONLY)
            }
            ri?.activityInfo?.packageName?.takeIf { it.isNotEmpty() && it != "android" }
        } catch (e: RuntimeException) {
            null
        }
    }
}
