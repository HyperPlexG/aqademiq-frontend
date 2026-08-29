package com.aqademiq.aqademiq

import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

/**
 * The Android half of `aqademiq/ambient`.
 *
 * Two jobs, deliberately kept apart:
 *
 *  * **The live session** goes to [AmbientSessionService], which owns the
 *    ongoing notification and lets the system tick its countdown.
 *  * **The glanceable data** (next task, the week, minutes today) is written to
 *    shared preferences, where a home-screen widget can read it without the app
 *    running at all.
 *
 * Presses come back the other way. When the process is alive the channel
 * carries them straight to the session; when it is not, the press is parked in
 * shared preferences and replayed the moment Dart attaches — which is what
 * stops a Freeze pressed on a dead process from being silently dropped.
 */
object AmbientBridge {
    const val CHANNEL = "aqademiq/ambient"

    private const val PREFS = "aqademiq_ambient"
    private const val KEY_STATE = "state"
    private const val KEY_PENDING_ACTION = "pendingAction"

    private var channel: MethodChannel? = null

    fun attach(channel: MethodChannel, context: Context) {
        this.channel = channel
        channel.setMethodCallHandler { call, result -> handle(context, call, result) }
        // A press that arrived while nothing was listening still has to land.
        drainPendingAction(context)
    }

    fun detach() {
        channel?.setMethodCallHandler(null)
        channel = null
    }

    private fun handle(context: Context, call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startSession", "updateSession" -> {
                val args = call.arguments as? Map<*, *>
                if (args == null) {
                    result.error("bad_args", "session payload missing", null)
                    return
                }
                sendToService(context, AmbientSessionService.ACTION_START, args)
                result.success(null)
            }

            "endSession" -> {
                context.startService(
                    Intent(context, AmbientSessionService::class.java)
                        .setAction(AmbientSessionService.ACTION_STOP),
                )
                result.success(null)
            }

            "publish" -> {
                val args = call.arguments as? Map<*, *>
                if (args != null) publish(context, args)
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    private fun sendToService(context: Context, action: String, args: Map<*, *>) {
        val endsAt = parseInstant(args["endsAt"] as? String)
        val remaining = (args["remainingSec"] as? Number)?.toInt() ?: 0
        val frozen = args["frozen"] as? Boolean ?: false

        val intent = Intent(context, AmbientSessionService::class.java)
            .setAction(action)
            .putExtra(AmbientSessionService.EXTRA_ENDS_AT, endsAt)
            .putExtra(AmbientSessionService.EXTRA_FROZEN, frozen)
            .putExtra(AmbientSessionService.EXTRA_REMAINING, remaining)
            .putExtra(
                AmbientSessionService.EXTRA_MELT_STAGE,
                (args["meltStage"] as? Number)?.toInt() ?: 0,
            )
            .putExtra(AmbientSessionService.EXTRA_TASK_TITLE, args["taskTitle"] as? String)
            .putExtra(AmbientSessionService.EXTRA_SUBJECT, args["subjectLabel"] as? String)
            .putExtra(AmbientSessionService.EXTRA_PRISM_MODE, args["prismMode"] as? String)
            .putExtra(
                AmbientSessionService.EXTRA_DURATION_SEC,
                (args["durationSec"] as? Number)?.toInt() ?: 0,
            )

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(intent)
        } else {
            context.startService(intent)
        }
    }

    /** Store the glanceable payload where a widget can read it unaided. */
    private fun publish(context: Context, args: Map<*, *>) {
        val json = JSONObject()
        args.forEach { (key, value) ->
            if (key is String) json.put(key, JSONObject.wrap(value))
        }
        prefs(context).edit().putString(KEY_STATE, json.toString()).apply()
    }

    /**
     * Route a press to Dart, or park it until Dart is there to take it.
     *
     * Called from the notification's action buttons, which can be pressed with
     * the app nowhere in sight — the whole point of freezing from a lock screen
     * is that you do not have to find the app first.
     */
    fun dispatch(context: Context, action: String) {
        val live = channel
        if (live != null) {
            Handler(Looper.getMainLooper()).post { live.invokeMethod("action", action) }
        } else {
            prefs(context).edit().putString(KEY_PENDING_ACTION, action).apply()
            // Bring the app up so the session can actually change; without this
            // a press on a dead process would do nothing at all.
            context.packageManager.getLaunchIntentForPackage(context.packageName)
                ?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                ?.let(context::startActivity)
        }
    }

    private fun drainPendingAction(context: Context) {
        val store = prefs(context)
        val pending = store.getString(KEY_PENDING_ACTION, null) ?: return
        store.edit().remove(KEY_PENDING_ACTION).apply()
        channel?.let { live ->
            Handler(Looper.getMainLooper()).post { live.invokeMethod("action", pending) }
        }
    }

    private fun prefs(context: Context): SharedPreferences =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    /** ISO-8601 UTC, as written by [AmbientSession.toMap] on the Dart side. */
    private fun parseInstant(iso: String?): Long {
        if (iso.isNullOrBlank()) return 0L
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                java.time.Instant.parse(iso).toEpochMilli()
            } else {
                val format = java.text.SimpleDateFormat(
                    "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'",
                    java.util.Locale.US,
                ).apply { timeZone = java.util.TimeZone.getTimeZone("UTC") }
                format.parse(iso)?.time ?: 0L
            }
        } catch (e: Exception) {
            0L
        }
    }
}
