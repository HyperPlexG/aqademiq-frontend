package com.aqademiq.aqademiq

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.Bitmap
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import androidx.core.graphics.drawable.toBitmap
import kotlin.math.max
import kotlin.math.roundToInt

/**
 * The focus session, drawn where the student can see it while the app is shut.
 *
 * This is a foreground service for two reasons at once, and it matters that
 * they are the same object: Android will kill the process during a screen-off
 * session and take Prism and the timer with it, and Android also requires a
 * foreground service to own a notification. Running a keepalive service *and*
 * posting a rich session notification would put two entries in the shade for
 * one session, so the keepalive notification simply is the session card.
 *
 * The clock is free. [NotificationCompat.Builder.setUsesChronometer] with
 * `setChronometerCountDown` hands the system an end timestamp and lets it tick
 * the countdown itself — no alarm, no per-second wakeup, nothing pushed from
 * Dart. The app only ever redraws this when Ada's melt stage changes or the
 * session freezes, which is a handful of times across a whole session.
 *
 * It is drawn one of two ways, and the phone decides which — see [Surface].
 */
class AmbientSessionService : Service() {

    companion object {
        const val ACTION_START = "com.aqademiq.ambient.START"
        const val ACTION_UPDATE = "com.aqademiq.ambient.UPDATE"
        const val ACTION_STOP = "com.aqademiq.ambient.STOP"

        /** Presses on the card itself, routed back to the session in Dart. */
        const val ACTION_FREEZE = "com.aqademiq.ambient.FREEZE"
        const val ACTION_RESUME = "com.aqademiq.ambient.RESUME"
        const val ACTION_END = "com.aqademiq.ambient.END"

        const val EXTRA_ENDS_AT = "endsAt"
        const val EXTRA_FROZEN = "frozen"
        const val EXTRA_REMAINING = "remainingSec"
        const val EXTRA_MELT_STAGE = "meltStage"
        const val EXTRA_TASK_TITLE = "taskTitle"
        const val EXTRA_SUBJECT = "subjectLabel"
        const val EXTRA_PRISM_MODE = "prismMode"
        const val EXTRA_DURATION_SEC = "durationSec"

        /**
         * Shared with the locally-scheduled reminders so a session and its
         * reminders sit in one row of the system notification settings rather
         * than looking like two different features.
         */
        private const val CHANNEL_ID = "aqademiq_focus_session"
        private const val NOTIFICATION_ID = 0x4144 // 'AD'

        /**
         * `Notification.FLAG_PROMOTED_ONGOING` (API 36). The system sets it on
         * a notification it has actually promoted; it is spelled out here so
         * the file compiles against an SDK that predates the constant.
         */
        private const val FLAG_PROMOTED_ONGOING = 0x00040000

        /** Long enough for the system to have posted the card and stamped it. */
        private const val PROBE_DELAY_MS = 600L

        private const val TAG = "AmbientSession"
    }

    /**
     * The two drawings of one session (spec §6: "the floor and the ceiling").
     *
     * The spec's card is a custom layout, and Android will not promote a
     * notification that has a custom layout to a status-bar chip. A phone
     * therefore gets one or the other, never both:
     *
     *  * [CARD] — the floor, and what almost every phone shows: the card drawn
     *    to the spec.
     *  * [CHIP] — the ceiling: Android's own template, which is the price of
     *    the status-bar chip, on a phone that really does draw one.
     *
     * "Really does" is the hard part. Android 16 shipped the promotion API a
     * release before it shipped the chip, so asking the SDK level, or even
     * `canPostPromotedNotifications()`, says yes on phones that then show
     * nothing. The only honest test is to post the promotable drawing and look
     * at what the system did with it — see [settleSurface].
     */
    private enum class Surface { CARD, CHIP }

    /** Null until this session has found out which drawing the phone gives it. */
    private var surface: Surface? = null
    private var lastCard: Intent? = null
    private val handler = Handler(Looper.getMainLooper())
    private val probe = Runnable { settleSurface() }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START, ACTION_UPDATE -> showCard(intent)
            ACTION_STOP -> stopCard()
            ACTION_FREEZE -> AmbientBridge.dispatch(this, "freeze")
            ACTION_RESUME -> AmbientBridge.dispatch(this, "resume")
            ACTION_END -> AmbientBridge.dispatch(this, "end")
            else -> stopCard()
        }
        // The session is the user's, not ours to resurrect: if Android kills
        // this, the app rebuilds the card from its own state on next launch.
        return START_NOT_STICKY
    }

    private fun showCard(intent: Intent) {
        ensureChannel()
        lastCard = intent
        if (surface == null && !mayBePromoted()) surface = Surface.CARD
        val notification = buildCard(intent, asChip = surface != Surface.CARD)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
        if (surface == null) {
            handler.removeCallbacks(probe)
            handler.postDelayed(probe, PROBE_DELAY_MS)
        }
    }

    /** Whether it is even worth asking: Android 16+, and the user allows it. */
    private fun mayBePromoted(): Boolean =
        Build.VERSION.SDK_INT >= 36 &&
            NotificationManagerCompat.from(this).canPostPromotedNotifications()

    /**
     * Looks at the card the system actually posted and keeps the chip drawing
     * only if the system promoted it. Otherwise the session falls back to the
     * spec's card, once, and stays there.
     */
    private fun settleSurface() {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val posted = try {
            manager.activeNotifications.firstOrNull { it.id == NOTIFICATION_ID }
        } catch (e: RuntimeException) {
            null
        } ?: return // Not posted yet, or already gone: the next redraw asks again.
        val promoted = (posted.notification.flags and FLAG_PROMOTED_ONGOING) != 0
        surface = if (promoted) Surface.CHIP else Surface.CARD
        Log.i(TAG, "session surface: $surface")
        if (!promoted) lastCard?.let(::showCard)
    }

    private fun stopCard() {
        handler.removeCallbacks(probe)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf()
    }

    override fun onDestroy() {
        handler.removeCallbacks(probe)
        super.onDestroy()
    }

    /** What one drawing of the session needs, read once from the intent. */
    private class Session(
        val title: String,
        val subtitle: String,
        val frozen: Boolean,
        val endsAt: Long,
        val remainingSec: Int,
        val durationSec: Int,
        val meltStage: Int,
    ) {
        /** The puddle rail: how much of the session has been spent, 0–100. */
        val spentPercent: Int?
            get() = if (durationSec <= 0) {
                null
            } else {
                val spent = (durationSec - remainingSec).coerceIn(0, durationSec)
                (spent.toFloat() / durationSec * 100f).roundToInt().coerceIn(0, 100)
            }
    }

    private fun buildCard(intent: Intent, asChip: Boolean): Notification {
        val frozen = intent.getBooleanExtra(EXTRA_FROZEN, false)
        val taskTitle = intent.getStringExtra(EXTRA_TASK_TITLE)
        val subject = intent.getStringExtra(EXTRA_SUBJECT)
        val prismMode = intent.getStringExtra(EXTRA_PRISM_MODE)

        // "Melting · Deep Work" — the material rule, said in words for the one
        // surface that has room for them. Frost when held, never a pause glyph.
        val session = Session(
            title = taskTitle?.takeIf { it.isNotBlank() } ?: "Focus session",
            subtitle = listOfNotNull(
                if (frozen) "Frozen" else "Melting",
                subject?.takeIf { it.isNotBlank() },
                prismMode?.takeIf { it.isNotBlank() },
            ).joinToString(" · "),
            frozen = frozen,
            endsAt = intent.getLongExtra(EXTRA_ENDS_AT, 0L),
            remainingSec = intent.getIntExtra(EXTRA_REMAINING, 0),
            durationSec = intent.getIntExtra(EXTRA_DURATION_SEC, 0),
            meltStage = intent.getIntExtra(EXTRA_MELT_STAGE, 0).coerceIn(0, 4),
        )

        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            // Ada, not the app's logo: a status bar masks every icon to one
            // flat colour, so this is her silhouette at her melt stage, with
            // frost spurs when held (spec §4). It is also the chip's icon.
            .setSmallIcon(adaMask(session.meltStage, session.frozen))
            // Title and text stay set even under the custom card: they are what
            // TalkBack, a watch and the lock screen's redacted view read.
            .setContentTitle(session.title)
            .setContentText(session.subtitle)
            .setContentIntent(openApp())
            // Ongoing, so it cannot be swiped away mid-session by accident.
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            // The promise of a focus session is that nothing interrupts it,
            // including us: this card is ambient and must never make a sound.
            .setSilent(true)
            .setCategory(NotificationCompat.CATEGORY_STOPWATCH)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setColor(0xFF6B5CF0.toInt())
            .setColorized(false)

        if (asChip) dressForChip(builder, session) else dressAsCard(builder, session)
        return builder.build()
    }

    /**
     * The floor: the spec's own card (§6), in the frame Android gives it.
     *
     * The frame is the system's and not negotiable since Android 12: its
     * header row (icon, app name), its background, its inset. Everything
     * inside is ours. The header reads "Aqademiq · Focus", which is as close
     * as that row gets to the spec's "AQADEMIQ · FOCUS".
     */
    private fun dressAsCard(builder: NotificationCompat.Builder, session: Session) {
        builder
            .setStyle(NotificationCompat.DecoratedCustomViewStyle())
            .setCustomContentView(cardViews(R.layout.notification_focus_collapsed, session))
            .setCustomBigContentView(
                cardViews(R.layout.notification_focus, session).apply {
                    session.spentPercent?.let { setProgressBar(R.id.rail, 100, it, false) }
                        ?: setViewVisibility(R.id.rail, android.view.View.GONE)
                    setTextViewText(R.id.action_primary, if (session.frozen) "RESUME" else "FREEZE")
                    setOnClickPendingIntent(
                        R.id.action_primary,
                        actionIntent(if (session.frozen) ACTION_RESUME else ACTION_FREEZE),
                    )
                    setOnClickPendingIntent(R.id.action_end, actionIntent(ACTION_END))
                },
            )
            .setSubText("Focus")
            // The card's countdown is the clock. A second one in the header
            // would be the same number twice, an inch apart.
            .setShowWhen(false)
    }

    /**
     * The row both card layouts share: Ada, the task, the state, the clock.
     *
     * The Chronometer is why this is a custom layout at all: given the end
     * instant and `countDown`, the system ticks it with the app asleep. A
     * TextView here would mean waking up every second to move a clock the OS
     * will move for free.
     */
    private fun cardViews(layout: Int, session: Session): RemoteViews {
        val views = RemoteViews(packageName, layout)
        views.setTextViewText(R.id.task, session.title)
        views.setTextViewText(R.id.subtitle, session.subtitle.uppercase())
        views.setImageViewResource(R.id.ada, adaDrawable(session.meltStage, session.frozen))

        if (session.frozen) {
            // A system countdown cannot be paused, so a held session shows
            // static text — otherwise the shade keeps counting down a session
            // that is not running, which is worse than showing no card at all.
            views.setViewVisibility(R.id.time, android.view.View.GONE)
            views.setViewVisibility(R.id.time_static, android.view.View.VISIBLE)
            views.setTextViewText(R.id.time_static, formatRemaining(session.remainingSec))
        } else {
            views.setViewVisibility(R.id.time_static, android.view.View.GONE)
            views.setViewVisibility(R.id.time, android.view.View.VISIBLE)
            // Chronometer counts against elapsed-realtime, not wall clock.
            val base = SystemClock.elapsedRealtime() + (session.endsAt - System.currentTimeMillis())
            views.setChronometer(R.id.time, base, null, true)
            views.setChronometerCountDown(R.id.time, true)
        }
        return views
    }

    /**
     * The ceiling: Android's own template, for a phone that draws the chip.
     *
     * Android will not promote a notification with a custom layout, so here
     * the card gives up the spec's drawing to earn the status-bar chip — the
     * small icon plus the remaining time, following the student into every
     * other app, which is the nearest thing Android has to the compact Island.
     * The template still carries the same four things: Ada at her melt stage
     * (the large icon), the task, "Melting · Deep Work", and the rail (the
     * progress bar).
     */
    private fun dressForChip(builder: NotificationCompat.Builder, session: Session) {
        builder
            .setLargeIcon(adaBitmap(session.meltStage, session.frozen))
            .setRequestPromotedOngoing(true)

        session.spentPercent?.let { builder.setProgress(100, it, false) }

        if (session.frozen) {
            // A system-rendered countdown cannot be paused. Swapping it for
            // static text is the whole difference between a frozen session that
            // reads as held and one that keeps counting down on a lock screen.
            builder.setUsesChronometer(false)
            builder.setShowWhen(false)
            builder.setContentText(
                "${session.subtitle} · ${formatRemaining(session.remainingSec)} left",
            )
            // The chip says so in a word rather than showing a number that is
            // not moving, which would read as a stuck clock at a glance.
            builder.setShortCriticalText("Frozen")
            builder.addAction(0, "Resume", actionIntent(ACTION_RESUME))
        } else {
            // Hand the system the end instant and let it tick — in the card's
            // header and in the chip. This is the "0 pushes for the clock" line
            // in the spec, made literal. No short critical text here: a fixed
            // string would freeze the chip at whatever was remaining when the
            // card was last posted, minutes out of date.
            builder.setWhen(session.endsAt)
            builder.setUsesChronometer(true)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                builder.setChronometerCountDown(true)
            }
            builder.setShowWhen(true)
            builder.addAction(0, "Freeze", actionIntent(ACTION_FREEZE))
        }
        builder.addAction(0, "End", actionIntent(ACTION_END))
    }

    /** Ada as a bitmap, because a notification's large icon cannot be a vector. */
    private fun adaBitmap(stage: Int, frozen: Boolean): Bitmap? {
        val drawable = ContextCompat.getDrawable(this, adaDrawable(stage, frozen)) ?: return null
        val px = (64 * resources.displayMetrics.density).roundToInt()
        return drawable.toBitmap(px, px)
    }

    /** Her status-bar mask: the same geometry, flattened to one colour. */
    private fun adaMask(stage: Int, frozen: Boolean): Int = if (frozen) {
        when (stage) {
            0 -> R.drawable.ic_stat_frost_0
            1 -> R.drawable.ic_stat_frost_1
            2 -> R.drawable.ic_stat_frost_2
            3 -> R.drawable.ic_stat_frost_3
            else -> R.drawable.ic_stat_frost_4
        }
    } else {
        when (stage) {
            0 -> R.drawable.ic_stat_ada_0
            1 -> R.drawable.ic_stat_ada_1
            2 -> R.drawable.ic_stat_ada_2
            3 -> R.drawable.ic_stat_ada_3
            else -> R.drawable.ic_stat_ada_4
        }
    }

    /** One Ada, generated from the painter's geometry (tool/generate_ada_android.py). */
    private fun adaDrawable(stage: Int, frozen: Boolean): Int = if (frozen) {
        when (stage) {
            0 -> R.drawable.ada_frost_0
            1 -> R.drawable.ada_frost_1
            2 -> R.drawable.ada_frost_2
            3 -> R.drawable.ada_frost_3
            else -> R.drawable.ada_frost_4
        }
    } else {
        when (stage) {
            0 -> R.drawable.ada_stage_0
            1 -> R.drawable.ada_stage_1
            2 -> R.drawable.ada_stage_2
            3 -> R.drawable.ada_stage_3
            else -> R.drawable.ada_stage_4
        }
    }

    private fun formatRemaining(totalSec: Int): String {
        val safe = max(0, totalSec)
        return "%d:%02d".format(safe / 60, safe % 60)
    }

    private fun actionIntent(action: String): PendingIntent {
        val intent = Intent(this, AmbientSessionService::class.java).setAction(action)
        return PendingIntent.getService(
            this,
            action.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun openApp(): PendingIntent {
        val intent = packageManager.getLaunchIntentForPackage(packageName)
            ?.setFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        return PendingIntent.getActivity(
            this,
            0,
            intent ?: Intent(),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Focus sessions",
            // Low: it is a card to glance at, not an alert. Anything higher
            // would let a focus session interrupt the focus session.
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Shows the session running while your screen is off."
            setShowBadge(false)
            enableVibration(false)
            setSound(null, null)
        }
        manager.createNotificationChannel(channel)
    }
}
