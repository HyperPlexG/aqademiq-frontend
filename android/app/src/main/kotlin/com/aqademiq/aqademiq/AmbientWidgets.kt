package com.aqademiq.aqademiq

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.net.Uri
import android.text.SpannableString
import android.text.Spanned
import android.text.style.StyleSpan
import android.view.View
import android.widget.RemoteViews
import org.json.JSONObject
import java.util.Calendar

/**
 * The three home-screen widgets (spec §5), the Android half of the iOS ones in
 * `ios/AmbientWidgets/AmbientWidgets.swift`: Next, This week, Focus.
 *
 * Like the iOS extension, they never think. The app derives everything they
 * show and [AmbientBridge] keeps it as one small JSON object in shared prefs;
 * a widget reads that object and draws it. No network, no models, no work —
 * which is also why they are correct with the app closed.
 *
 * They are redrawn whenever the app publishes or a session starts, changes or
 * ends ([refresh]), and every 30 minutes besides, which is what moves "today"
 * across midnight on This week.
 */
object AmbientWidgets {

    /** Redraw every widget the student has placed, from the latest state. */
    fun refresh(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        val glance = Glance.load(context)
        for (widget in listOf(NextWidget(), WeekWidget(), FocusWidget())) {
            val ids = manager.getAppWidgetIds(ComponentName(context, widget.javaClass))
            if (ids.isNotEmpty()) manager.updateAppWidget(ids, widget.draw(context, glance))
        }
    }

    /**
     * A tap, as intent rather than as a route: `aqademiq://plan` means "show
     * the plan", and the app decides where that is. Renaming a route cannot
     * break a widget already sitting on someone's home screen.
     */
    internal fun open(context: Context, intent: String): PendingIntent =
        PendingIntent.getActivity(
            context,
            intent.hashCode(),
            Intent(Intent.ACTION_VIEW, Uri.parse("aqademiq://$intent"), context, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
}

/** What the widgets show, read once from the state the app published. */
internal class Glance(
    val nextTitle: String?,
    val nextTime: String?,
    val nextSubject: String?,
    val nextTint: Int?,
    /** Seven flags, Monday first: did the student show up that day. */
    val weekDays: List<Boolean>,
    val sessionStage: Int?,
    val sessionFrozen: Boolean,
) {
    companion object {
        fun load(context: Context): Glance {
            val json = AmbientBridge.state(context)
            val days = json.optJSONArray("weekDays")
            val session = json.optJSONObject("session")
            return Glance(
                nextTitle = json.text("nextTaskTitle"),
                nextTime = json.text("nextTaskTime"),
                nextSubject = json.text("nextTaskSubject"),
                nextTint = json.text("nextTaskTint")?.let(::parseHex),
                weekDays = List(7) { index -> days?.optBoolean(index, false) ?: false },
                sessionStage = session?.optInt("meltStage", 0)?.coerceIn(0, 4),
                sessionFrozen = session?.optBoolean("frozen", false) ?: false,
            )
        }

        private fun JSONObject.text(key: String): String? =
            if (isNull(key)) null else optString(key).takeIf { it.isNotBlank() }

        /** `#RRGGBB` as the app writes it. */
        private fun parseHex(raw: String): Int? = try {
            Color.parseColor(if (raw.startsWith("#")) raw else "#$raw")
        } catch (e: IllegalArgumentException) {
            null
        }
    }
}

/** A widget that draws itself from a [Glance]; the system calls in on its schedule. */
abstract class AmbientWidget : AppWidgetProvider() {
    internal abstract fun draw(context: Context, glance: Glance): RemoteViews

    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        manager.updateAppWidget(ids, draw(context, Glance.load(context)))
    }
}

/** One task, not three, not a list. */
class NextWidget : AmbientWidget() {
    override fun draw(context: Context, glance: Glance): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_next)
        val title = glance.nextTitle
        if (title == null) {
            views.setViewVisibility(R.id.next_title, View.GONE)
            views.setViewVisibility(R.id.next_meta, View.GONE)
            views.setViewVisibility(R.id.next_empty, View.VISIBLE)
        } else {
            views.setViewVisibility(R.id.next_empty, View.GONE)
            views.setViewVisibility(R.id.next_title, View.VISIBLE)
            views.setTextViewText(R.id.next_title, title)
            val meta = glance.nextTime ?: glance.nextSubject
            views.setViewVisibility(R.id.next_meta, if (meta == null) View.GONE else View.VISIBLE)
            views.setTextViewText(R.id.next_time, meta ?: "")
            // The subject's own colour; the accent when it has none.
            views.setInt(
                R.id.next_dot,
                "setColorFilter",
                glance.nextTint ?: context.getColor(R.color.widget_accent),
            )
        }
        views.setOnClickPendingIntent(android.R.id.background, AmbientWidgets.open(context, "plan"))
        return views
    }
}

/** Seven marks, and no judgement. */
class WeekWidget : AmbientWidget() {
    override fun draw(context: Context, glance: Glance): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_week)
        // Monday-first index of today, matching AppDate.mondayOf in the app.
        val today = (Calendar.getInstance().get(Calendar.DAY_OF_WEEK) + 5) % 7
        for (index in 0 until 7) {
            val shown = glance.weekDays[index]
            views.setImageViewResource(
                DAYS[index],
                when {
                    shown -> R.drawable.ada_stage_0
                    // Still open, nothing lost: brighter than a day gone by.
                    index == today -> R.drawable.ada_outline_today
                    else -> R.drawable.ada_outline
                },
            )
            // Today's letter is the only accent, and the only bold one.
            val letter = SpannableString(LETTERS[index])
            if (index == today) {
                letter.setSpan(StyleSpan(Typeface.BOLD), 0, letter.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
            }
            views.setTextViewText(LETTER_VIEWS[index], letter)
            views.setTextColor(
                LETTER_VIEWS[index],
                context.getColor(
                    when {
                        index == today -> R.color.widget_accent
                        shown -> R.color.widget_letter_shown
                        else -> R.color.widget_letter_missed
                    },
                ),
            )
        }
        views.setOnClickPendingIntent(android.R.id.background, AmbientWidgets.open(context, "stats"))
        return views
    }

    private companion object {
        val LETTERS = listOf("M", "T", "W", "T", "F", "S", "S")
        val DAYS = intArrayOf(
            R.id.week_day_0, R.id.week_day_1, R.id.week_day_2, R.id.week_day_3,
            R.id.week_day_4, R.id.week_day_5, R.id.week_day_6,
        )
        val LETTER_VIEWS = intArrayOf(
            R.id.week_letter_0, R.id.week_letter_1, R.id.week_letter_2, R.id.week_letter_3,
            R.id.week_letter_4, R.id.week_letter_5, R.id.week_letter_6,
        )
    }
}

/** Start 5: the one operable thing on any widget. */
class FocusWidget : AmbientWidget() {
    override fun draw(context: Context, glance: Glance): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_focus)
        val stage = glance.sessionStage
        views.setImageViewResource(R.id.focus_ada, Ada.drawable(stage ?: 0, glance.sessionFrozen))
        if (stage == null) {
            views.setViewVisibility(R.id.focus_status, View.GONE)
            views.setViewVisibility(R.id.focus_button, View.VISIBLE)
        } else {
            // A session is already running: say so rather than offering to
            // start a second one.
            views.setViewVisibility(R.id.focus_button, View.GONE)
            views.setViewVisibility(R.id.focus_status, View.VISIBLE)
            views.setTextViewText(R.id.focus_status, if (glance.sessionFrozen) "Frozen" else "In session")
            views.setTextColor(
                R.id.focus_status,
                context.getColor(if (glance.sessionFrozen) R.color.widget_frost else R.color.widget_meta),
            )
        }
        // Mid-session the app already refuses to start a second one, so the
        // same tap simply opens the running session — as on iOS.
        val start = AmbientWidgets.open(context, "focus/start5")
        views.setOnClickPendingIntent(android.R.id.background, start)
        views.setOnClickPendingIntent(R.id.focus_button, start)
        return views
    }
}

/** One Ada, generated from the painter's geometry (tool/generate_ada_android.py). */
internal object Ada {
    fun drawable(stage: Int, frozen: Boolean): Int = if (frozen) {
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
}
