package com.aqademiq.aqademiq

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.SystemClock
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat
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
    }

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
        val notification = buildCard(intent)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun stopCard() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf()
    }

    private fun buildCard(intent: Intent): Notification {
        val frozen = intent.getBooleanExtra(EXTRA_FROZEN, false)
        val endsAt = intent.getLongExtra(EXTRA_ENDS_AT, 0L)
        val remainingSec = intent.getIntExtra(EXTRA_REMAINING, 0)
        val durationSec = intent.getIntExtra(EXTRA_DURATION_SEC, 0)
        val taskTitle = intent.getStringExtra(EXTRA_TASK_TITLE)
        val subject = intent.getStringExtra(EXTRA_SUBJECT)
        val prismMode = intent.getStringExtra(EXTRA_PRISM_MODE)

        // "MELTING · DEEP WORK" — the material rule, said in words for the one
        // surface that has room for them. Frost when held, never a pause glyph.
        val state = if (frozen) "Frozen" else "Melting"
        val subtitle = listOfNotNull(
            state,
            subject?.takeIf { it.isNotBlank() },
            prismMode?.takeIf { it.isNotBlank() },
        ).joinToString(" · ")

        val meltStage = intent.getIntExtra(EXTRA_MELT_STAGE, 0).coerceIn(0, 4)
        val title = taskTitle?.takeIf { it.isNotBlank() } ?: "Focus session"

        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_notification)
            .setContentTitle(title)
            .setContentText(subtitle)
            .setContentIntent(openApp())
            // The spec's own card rather than Android's default template:
            // Ada at her melt stage, the task, "MELTING · DEEP WORK", the
            // countdown, and the puddle rail.
            .setStyle(NotificationCompat.DecoratedCustomViewStyle())
            .setCustomContentView(
                buildCard(
                    title = title,
                    subtitle = subtitle,
                    frozen = frozen,
                    endsAt = endsAt,
                    remainingSec = remainingSec,
                    durationSec = durationSec,
                    meltStage = meltStage,
                ),
            )
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

        if (frozen) {
            // A system-rendered countdown cannot be paused. Swapping it for
            // static text is the whole difference between a frozen session that
            // reads as held and one that keeps counting down on a lock screen.
            builder.setUsesChronometer(false)
            builder.setContentText("$subtitle · ${formatRemaining(remainingSec)} left")
        } else {
            // Hand the system the end instant and let it tick. This is the
            // "0 pushes for the clock" line in the spec, made literal.
            builder.setWhen(endsAt)
            builder.setUsesChronometer(true)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                builder.setChronometerCountDown(true)
            }
            builder.setShowWhen(true)
        }

        if (frozen) {
            builder.addAction(0, "Resume", actionIntent(ACTION_RESUME))
        } else {
            builder.addAction(0, "Freeze", actionIntent(ACTION_FREEZE))
        }
        builder.addAction(0, "End", actionIntent(ACTION_END))

        return builder.build()
    }

    /**
     * The card itself.
     *
     * The Chronometer is why this is a custom layout at all: given the end
     * instant and `countDown`, the system ticks it with the app asleep. A
     * TextView here would mean waking up every second to move a clock the OS
     * will move for free.
     */
    private fun buildCard(
        title: String,
        subtitle: String,
        frozen: Boolean,
        endsAt: Long,
        remainingSec: Int,
        durationSec: Int,
        meltStage: Int,
    ): RemoteViews {
        val views = RemoteViews(packageName, R.layout.notification_focus)
        views.setTextViewText(R.id.task, title)
        views.setTextViewText(R.id.subtitle, subtitle.uppercase())
        views.setImageViewResource(R.id.ada, adaDrawable(meltStage, frozen))

        if (frozen) {
            // A system countdown cannot be paused, so a held session shows
            // static text — otherwise the shade keeps counting down a session
            // that is not running, which is worse than showing no card at all.
            views.setViewVisibility(R.id.time, android.view.View.GONE)
            views.setViewVisibility(R.id.time_static, android.view.View.VISIBLE)
            views.setTextViewText(R.id.time_static, formatRemaining(remainingSec))
        } else {
            views.setViewVisibility(R.id.time_static, android.view.View.GONE)
            views.setViewVisibility(R.id.time, android.view.View.VISIBLE)
            // Chronometer counts against elapsed-realtime, not wall clock.
            val base = SystemClock.elapsedRealtime() + (endsAt - System.currentTimeMillis())
            views.setChronometer(R.id.time, base, null, true)
            views.setChronometerCountDown(R.id.time, true)
        }

        if (durationSec > 0) {
            val spent = (durationSec - remainingSec).coerceIn(0, durationSec)
            views.setProgressBar(
                R.id.rail,
                100,
                (spent.toFloat() / durationSec * 100f).roundToInt().coerceIn(0, 100),
                false,
            )
        } else {
            views.setViewVisibility(R.id.rail, android.view.View.GONE)
        }
        return views
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
