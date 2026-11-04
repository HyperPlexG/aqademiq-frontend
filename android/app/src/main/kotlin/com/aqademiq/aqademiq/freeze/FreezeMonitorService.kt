package com.aqademiq.aqademiq.freeze

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import com.aqademiq.aqademiq.MainActivity
import com.aqademiq.aqademiq.R

/**
 * App freeze's watcher (APP_FREEZE.md §6): a `specialUse` foreground service
 * that runs while the policy can freeze anything.
 *
 * While the screen is on it reads the foreground app from UsageStatsManager
 * about once a second and puts [ShieldActivity] over a frozen one; it checks
 * in, once in 30 minutes, when a Distracting app is opened. With the screen
 * off it does nothing at all — no poll, no alarm, no wake lock — because no
 * app can be opened then, and the first thing the screen coming on does is
 * look again.
 *
 * Its own service, not [com.aqademiq.aqademiq.AmbientSessionService]: that
 * one is the focus session's `mediaPlayback` card and lives only as long as a
 * session, while a frost runs on its schedule with no session at all. So the
 * shade can hold both during a Freeze-now session; they are two things.
 *
 * All work happens on one background thread ([worker]); the main thread only
 * takes start commands and calls startForeground, which must be prompt.
 */
class FreezeMonitorService : Service() {

    companion object {
        private const val TAG = "FreezeMonitor"

        const val ACTION_REFRESH = "com.aqademiq.freeze.REFRESH"
        const val ACTION_STOP = "com.aqademiq.freeze.STOP"

        private const val CHANNEL_ID = "aqademiq_app_freeze"
        private const val CHECKIN_CHANNEL_ID = "aqademiq_freeze_checkin"

        /**
         * Below the reminder scheduler's ids (1–3 for check-ins, 1000+ for
         * tasks), so a reminder can never replace this notification.
         */
        private const val NOTIFICATION_ID = 0x46
        private const val CHECKIN_ID = 0x47

        private const val POLL_MS = 1_000L
        private const val NOTICE_MS = 30_000L
        private const val CHECKIN_GAP_MS = 30 * 60_000L
        private const val CHECKIN_TIMEOUT_MS = 10 * 60_000L

        /** If the shield did not take the screen, try again after this. */
        private const val RESHIELD_MS = 3_000L

        /**
         * How far back a read may look: on the first one, for the app that is
         * already open (a restart under an app in use for a while), and after
         * a long screen-off.
         */
        private const val FIRST_LOOK_MS = 60 * 60_000L
        private const val OVERLAP_MS = 2_000L

        private const val IDLE_TITLE = "App freeze is on"
        private const val IDLE_TEXT = "Frosts run on their schedule."

        @Volatile
        var running = false
            private set

        /**
         * Start or stop the monitor to match the stored policy: it runs while
         * the policy can freeze anything and Usage access is granted (without
         * it there is nothing to watch with). [refresh] re-reads the policy
         * in a monitor that is already running.
         */
        fun sync(context: Context, refresh: Boolean) {
            val policy = FreezeStore.policy(context)
            val wanted = policy != null &&
                FreezeRules.needsMonitor(policy, System.currentTimeMillis()) &&
                FreezeAccess.usageAccess(context)
            when {
                !wanted -> stop(context)
                refresh || !running -> start(context)
            }
        }

        private fun start(context: Context) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
            val intent = Intent(context, FreezeMonitorService::class.java).setAction(ACTION_REFRESH)
            try {
                context.startForegroundService(intent)
            } catch (e: IllegalStateException) {
                // Android 12+ refuses a foreground-service start from the
                // background. The next applyPolicy / status / boot tries again.
                Log.w(TAG, "monitor start refused", e)
            } catch (e: SecurityException) {
                Log.w(TAG, "monitor start refused", e)
            }
        }

        /**
         * A stop is a start command, not stopService: a service told to stop
         * before it has called startForeground crashes the app, and a command
         * queues behind the start that is still on its way.
         */
        private fun stop(context: Context) {
            if (!running) return
            val intent = Intent(context, FreezeMonitorService::class.java).setAction(ACTION_STOP)
            try {
                context.startService(intent)
            } catch (e: IllegalStateException) {
                context.stopService(Intent(context, FreezeMonitorService::class.java))
            } catch (e: SecurityException) {
                Log.w(TAG, "monitor stop refused", e)
            }
        }
    }

    private val main = Handler(Looper.getMainLooper())
    private var thread: HandlerThread? = null
    private var worker: Handler? = null
    private var screenReceiver: BroadcastReceiver? = null

    @Volatile private var stopping = false

    /** The newest start command delivered; a stop names it (see [finish]). */
    @Volatile private var lastStartId = 0

    @Volatile private var shownTitle: String? = null

    @Volatile private var shownText: String? = null

    // Worker-thread state.
    private var interactive = true
    private var foreground: String? = null
    private var foregroundSince = 0L
    private var lastQueryEnd = 0L
    private var previous: String? = null
    private var shieldedPkg: String? = null
    private var shieldedSince = -1L
    private var shieldedStage = 1
    private var lastShieldAt = 0L
    private var lastNoticeAt = 0L
    private val labels = HashMap<String, String>()

    private val tick = object : Runnable {
        override fun run() {
            if (stopping || !interactive) return
            poll()
            if (!stopping && interactive) worker?.postDelayed(this, POLL_MS)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        running = true
        ensureChannels()
        val t = HandlerThread("freeze-monitor").also { it.start() }
        thread = t
        worker = Handler(t.looper)
        val power = getSystemService(Context.POWER_SERVICE) as? PowerManager
        interactive = power?.isInteractive ?: true
        registerScreenReceiver()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        lastStartId = startId
        if (intent?.action == ACTION_STOP) {
            finish(startId)
            return START_NOT_STICKY
        }
        // Foreground first, whatever happens next: a startForegroundService
        // that is not answered with startForeground crashes the app.
        val now = System.currentTimeMillis()
        val policy = FreezeStore.policy(this)
        if (!goForeground(policy, now)) {
            finish(startId)
            return START_NOT_STICKY
        }
        if (!wanted()) {
            finish(startId)
            return START_NOT_STICKY
        }
        stopping = false
        worker?.post {
            lastNoticeAt = 0L
            if (interactive) restartPolling()
        }
        // Sticky: a frost is a promise that outlives the process. A restart
        // arrives with a null intent and lands here as a refresh.
        return START_STICKY
    }

    override fun onDestroy() {
        running = false
        stopping = true
        screenReceiver?.let {
            try {
                unregisterReceiver(it)
            } catch (e: IllegalArgumentException) {
                // Never registered, or already gone.
            }
        }
        screenReceiver = null
        worker?.removeCallbacksAndMessages(null)
        thread?.quitSafely()
        thread = null
        worker = null
        super.onDestroy()
    }

    /**
     * Stop, unless a newer start is already on its way: stopSelf(startId)
     * is ignored when [startId] is not the latest, and that start then lands
     * in [onStartCommand] as usual. A plain stopSelf() here would drop it,
     * and a dropped startForegroundService crashes the app.
     */
    private fun finish(startId: Int) {
        stopping = true
        worker?.removeCallbacksAndMessages(null)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        shownTitle = null
        shownText = null
        stopSelf(startId)
    }

    // ---- the screen ----------------------------------------------------------

    /**
     * Screen off stops the poll; screen on starts it and redraws the
     * notification. Both are sent by the system itself, so a not-exported
     * receiver gets them (unlike ACTION_USER_PRESENT, which SystemUI sends).
     */
    private fun registerScreenReceiver() {
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                when (intent.action) {
                    Intent.ACTION_SCREEN_OFF -> worker?.post {
                        interactive = false
                        worker?.removeCallbacks(tick)
                    }
                    Intent.ACTION_SCREEN_ON -> worker?.post {
                        interactive = true
                        lastNoticeAt = 0L
                        restartPolling()
                    }
                }
            }
        }
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_ON)
            addAction(Intent.ACTION_SCREEN_OFF)
        }
        ContextCompat.registerReceiver(this, receiver, filter, ContextCompat.RECEIVER_NOT_EXPORTED)
        screenReceiver = receiver
    }

    private fun restartPolling() {
        val w = worker ?: return
        w.removeCallbacks(tick)
        w.post(tick)
    }

    // ---- the poll (worker thread) --------------------------------------------

    private fun poll() {
        val now = System.currentTimeMillis()
        val policy = FreezeStore.policy(this)
        if (policy == null) {
            stopFromWorker()
            return
        }
        if (now - lastNoticeAt >= NOTICE_MS || now < lastNoticeAt) {
            lastNoticeAt = now
            // The 30-second beat is also where the monitor notices it is no
            // longer needed: Freeze now ended, the last frost was deleted,
            // Usage access was taken away.
            if (!FreezeRules.needsMonitor(policy, now) || !FreezeAccess.usageAccess(this)) {
                stopFromWorker()
                return
            }
            refreshNotice(policy, now)
        }
        readForeground(now)
        val pkg = foreground ?: return
        if (FreezeRules.Floor.contains(this, pkg)) {
            previous = pkg
            return
        }
        if (FreezeRules.isFrozen(policy, pkg, now)) {
            // A new open (or the freeze starting under an open app) is one
            // more shield today. The same open still on top after a few
            // seconds means the shield did not get there: show it again,
            // without counting it twice.
            val fresh = pkg != shieldedPkg || foregroundSince != shieldedSince
            if (fresh) {
                val count = FreezeStore.bumpShieldCount(this, pkg, now)
                shieldedPkg = pkg
                shieldedSince = foregroundSince
                shieldedStage = count.coerceIn(1, 3)
                showShield(policy, pkg, shieldedStage, now)
                lastShieldAt = now
            } else if (now - lastShieldAt >= RESHIELD_MS || now < lastShieldAt) {
                showShield(policy, pkg, shieldedStage, now)
                lastShieldAt = now
            }
        } else if (pkg != previous && policy.groups.distracting.contains(pkg)) {
            checkIn(pkg, now)
        }
        previous = pkg
    }

    /**
     * The worker decided the monitor is not needed. Decided again on the
     * main thread, where start commands land: an applyPolicy that arrived in
     * between may have made it needed after all.
     */
    private fun stopFromWorker() {
        stopping = true
        main.post {
            if (wanted()) {
                stopping = false
                worker?.post { if (interactive) restartPolling() }
            } else {
                finish(lastStartId)
            }
        }
    }

    private fun wanted(): Boolean {
        val policy = FreezeStore.policy(this) ?: return false
        return FreezeRules.needsMonitor(policy, System.currentTimeMillis()) && FreezeAccess.usageAccess(this)
    }

    /**
     * The newest ACTIVITY_RESUMED since the last read. Each read overlaps the
     * last by a moment, so an event landing between two reads is never lost;
     * reading it twice changes nothing.
     */
    private fun readForeground(now: Long) {
        val usage = usageStats() ?: return
        val earliest = now - FIRST_LOOK_MS
        val begin = if (lastQueryEnd == 0L || lastQueryEnd > now) {
            earliest
        } else {
            maxOf(earliest, lastQueryEnd - OVERLAP_MS)
        }
        val events = try {
            usage.queryEvents(begin, now)
        } catch (e: RuntimeException) {
            null
        } ?: return
        lastQueryEnd = now
        val resumed = resumedType()
        val event = UsageEvents.Event()
        var pkg: String? = null
        var at = 0L
        while (events.hasNextEvent()) {
            if (!events.getNextEvent(event)) break
            if (event.eventType == resumed) {
                pkg = event.packageName
                at = event.timeStamp
            }
        }
        if (pkg != null) {
            foreground = pkg
            foregroundSince = at
        }
    }

    private fun usageStats(): UsageStatsManager? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1) {
            getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager
        } else {
            null
        }

    /** ACTIVITY_RESUMED (Q+) and MOVE_TO_FOREGROUND (before) are the same event, 1. */
    @Suppress("DEPRECATION")
    private fun resumedType(): Int =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            UsageEvents.Event.ACTIVITY_RESUMED
        } else {
            UsageEvents.Event.MOVE_TO_FOREGROUND
        }

    // ---- the shield ----------------------------------------------------------

    /** Copy per APP_FREEZE.md §4, worked out here so the shield only draws. */
    private fun showShield(policy: FreezePolicy, pkg: String, stage: Int, now: Long) {
        val never = policy.groups.neverOpen.contains(pkg)
        val over = FreezeRules.covering(policy, pkg, now)
        val deep = !never && over.any { it.deep }
        val until = FreezeRules.nextUnfreeze(over)
        val line = when {
            never -> "This one stays frozen."
            until == null -> "Until you stop"
            stage == 1 -> "Yours again at ${FreezeRules.bareClock(until)}"
            else -> FreezeRules.bareClock(until)
        }
        val deepNote = if (deep) {
            val deepEnd = FreezeRules.deepUntil(over)
            if (deepEnd == null) "Deep freeze until you stop" else "Deep freeze until ${FreezeRules.clock(deepEnd)}"
        } else {
            null
        }
        val intent = Intent(this, ShieldActivity::class.java)
            .addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_NO_ANIMATION,
            )
            .putExtra(ShieldActivity.EXTRA_PACKAGE, pkg)
            .putExtra(ShieldActivity.EXTRA_LABEL, label(pkg))
            .putExtra(ShieldActivity.EXTRA_STAGE, stage)
            .putExtra(ShieldActivity.EXTRA_LINE, line)
            .putExtra(ShieldActivity.EXTRA_BREATH, FreezeRules.breathFor(policy, now))
            .putExtra(ShieldActivity.EXTRA_DEEP, deep)
            .putExtra(ShieldActivity.EXTRA_DEEP_NOTE, deepNote)
            .putExtra(ShieldActivity.EXTRA_NEVER, never)
        try {
            // Allowed from the background because the student granted Display
            // over other apps — that grant is the exemption.
            startActivity(intent)
        } catch (e: RuntimeException) {
            Log.w(TAG, "shield refused", e)
        }
    }

    @Suppress("DEPRECATION")
    private fun label(pkg: String): String = labels.getOrPut(pkg) {
        try {
            val pm = packageManager
            pm.getApplicationLabel(pm.getApplicationInfo(pkg, 0)).toString()
        } catch (e: PackageManager.NameNotFoundException) {
            pkg
        }
    }

    // ---- Ada's check-in ------------------------------------------------------

    /** "Quick check-in" — at most once in 30 minutes per app. Never a count, never guilt. */
    private fun checkIn(pkg: String, now: Long) {
        val last = FreezeStore.lastCheckIn(this, pkg)
        if (last in (now - CHECKIN_GAP_MS + 1)..now) return
        FreezeStore.markCheckIn(this, pkg, now)
        if (!NotificationManagerCompat.from(this).areNotificationsEnabled()) return
        val notification = NotificationCompat.Builder(this, CHECKIN_CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_ada_0)
            .setContentTitle("Ada")
            .setContentText("Quick check-in — is this what you meant to open?")
            .setColor(ContextCompat.getColor(this, R.color.notification_color))
            .setContentIntent(openFreeze())
            .setAutoCancel(true)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            // A check-in about an app opened an hour ago means nothing.
            .setTimeoutAfter(CHECKIN_TIMEOUT_MS)
            .build()
        post(CHECKIN_ID, notification)
    }

    // ---- the ongoing notification --------------------------------------------

    private fun refreshNotice(policy: FreezePolicy, now: Long) {
        val (title, text) = noticeText(policy, now)
        if (title == shownTitle && text == shownText) return
        shownTitle = title
        shownText = text
        post(NOTIFICATION_ID, buildNotice(title, text))
    }

    /**
     * §6: "9 apps on ice" / "Back at 3:42. Phone and Messages stay open."
     * while something is frozen, the idle pair otherwise. The count is the
     * apps the running freezes name that are frozen right now (so a thawed
     * app is not on ice); a Keep only freeze names what stays open instead.
     */
    private fun noticeText(policy: FreezePolicy, now: Long): Pair<String, String> {
        val running = FreezeRules.active(policy, now)
        if (running.isEmpty()) return IDLE_TITLE to IDLE_TEXT
        val thawedAll = running.none { it.deep } &&
            policy.grants.any { it.target == FreezeRules.ALL_APPS && now < it.until }
        if (thawedAll) return IDLE_TITLE to IDLE_TEXT
        val keep = running.filter { it.apps.keepOnly }
        val title = if (keep.isNotEmpty()) {
            var kept: Set<String>? = null
            for (a in keep) kept = kept?.intersect(a.apps.packages) ?: a.apps.packages
            val n = kept?.size ?: 0
            if (n == 0) "Everything on ice" else "Everything but ${apps(n)} on ice"
        } else {
            val floor = FreezeRules.Floor.packages(this)
            val named = HashSet<String>()
            for (a in running) named.addAll(a.apps.packages)
            val n = named.count { it !in floor && FreezeRules.isFrozen(policy, it, now, running) }
            if (n == 0) return IDLE_TITLE to IDLE_TEXT
            "${apps(n)} on ice"
        }
        val back = FreezeRules.nextUnfreeze(running)
        val first = if (back == null) "Until you stop." else "Back at ${FreezeRules.bareClock(back)}."
        return title to "$first Phone and Messages stay open."
    }

    private fun apps(n: Int): String = if (n == 1) "1 app" else "$n apps"

    /** Called on the main thread; startForeground must answer every start. */
    private fun goForeground(policy: FreezePolicy?, now: Long): Boolean {
        val (title, text) = if (policy != null) noticeText(policy, now) else (IDLE_TITLE to IDLE_TEXT)
        val notification = buildNotice(title, text)
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
            shownTitle = title
            shownText = text
            true
        } catch (e: RuntimeException) {
            // ForegroundServiceStartNotAllowedException (a sticky restart in
            // the background on Android 12+) and friends.
            Log.w(TAG, "could not go foreground", e)
            false
        }
    }

    private fun buildNotice(title: String, text: String): Notification =
        NotificationCompat.Builder(this, CHANNEL_ID)
            // Ada's frost silhouette: a status bar masks icons to one colour,
            // so frozen has to survive as outline alone (CLAUDE.md).
            .setSmallIcon(R.drawable.ic_stat_frost_0)
            .setContentTitle(title)
            .setContentText(text)
            .setContentIntent(openFreeze())
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .setShowWhen(false)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setColor(ContextCompat.getColor(this, R.color.notification_color))
            .build()

    /** Both notifications open App freeze — as intent, not a route (`aqademiq://freeze`). */
    private fun openFreeze(): PendingIntent =
        PendingIntent.getActivity(
            this,
            NOTIFICATION_ID,
            Intent(Intent.ACTION_VIEW, Uri.parse("aqademiq://freeze"), this, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

    private fun post(id: Int, notification: Notification) {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return
        try {
            manager.notify(id, notification)
        } catch (e: SecurityException) {
            // Notifications not allowed (Android 13+): the monitor still works.
        }
    }

    private fun ensureChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return
        if (manager.getNotificationChannel(CHANNEL_ID) == null) {
            manager.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "App freeze", NotificationManager.IMPORTANCE_LOW).apply {
                    description = "Shows while App freeze is keeping frozen apps closed."
                    setShowBadge(false)
                    enableVibration(false)
                    setSound(null, null)
                },
            )
        }
        if (manager.getNotificationChannel(CHECKIN_CHANNEL_ID) == null) {
            // High so it shows as a banner over the app just opened — a
            // check-in nobody sees is not one — but silent: a nudge, not an
            // alarm.
            manager.createNotificationChannel(
                NotificationChannel(CHECKIN_CHANNEL_ID, "Ada's check-ins", NotificationManager.IMPORTANCE_HIGH).apply {
                    description = "A quiet question when you open an app you marked Distracting."
                    setShowBadge(false)
                    enableVibration(false)
                    setSound(null, null)
                },
            )
        }
    }
}
