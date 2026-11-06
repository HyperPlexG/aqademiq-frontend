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
        // Deliberately NOT draining here.
        //
        // Attaching means this side is ready, not that Dart is. The engine sets
        // the channel up before the Dart entrypoint has installed its handler,
        // so draining now removes the parked press and invokes it into nothing.
        // Dart calls "ready" once it is actually listening; that is where the
        // drain happens.
    }

    /**
     * The engine is going away with the activity.
     *
     * The session lives in Dart and is not kept anywhere else, so once the
     * engine is gone nothing will ever end it: swiping the app away used to
     * leave the card counting down for ever and parked every later press for
     * an app that would never ask for it. [standDown] (everything but a
     * configuration change) takes the card and the stored session with it.
     */
    fun detach(context: Context, standDown: Boolean) {
        channel?.setMethodCallHandler(null)
        channel = null
        if (standDown && state(context).has("session")) endSession(context)
    }

    private fun handle(context: Context, call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startSession", "updateSession" -> {
                val args = call.arguments as? Map<*, *>
                if (args == null) {
                    result.error("bad_args", "session payload missing", null)
                    return
                }
                val action = if (call.method == "startSession") {
                    AmbientSessionService.ACTION_START
                } else {
                    AmbientSessionService.ACTION_UPDATE
                }
                sendToService(context, action, args)
                storeSession(context, args)
                result.success(null)
            }

            "endSession" -> {
                endSession(context)
                result.success(null)
            }

            "publish" -> {
                val args = call.arguments as? Map<*, *>
                if (args != null) publish(context, args)
                result.success(null)
            }

            // Dart has a handler now, so a press parked by a widget, a tile or
            // a notification action finally has somewhere to land.
            "ready" -> {
                drainPendingAction(context)
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

        if (action == AmbientSessionService.ACTION_START) {
            // Only the start promotes the service. It comes from a session
            // begun in the app, so the app is in front, where Android allows it.
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        } else {
            // An update only redraws the card of a service already in the
            // foreground, mostly with the screen off (a melt stage). Another
            // startForegroundService for it can be refused from the
            // background on Android 12+; a plain start of a service that is
            // running in the foreground is allowed.
            try {
                context.startService(intent)
            } catch (e: IllegalStateException) {
                // No service to redraw and no right to start one: the card is
                // already gone, which is the state the next start rebuilds.
            }
        }
    }

    /**
     * Stand the session down: forget it first, so the widgets stop saying "In
     * session" even if the service cannot be reached, then take the card away.
     */
    private fun endSession(context: Context) {
        storeSession(context, null)
        val stop = Intent(context, AmbientSessionService::class.java)
            .setAction(AmbientSessionService.ACTION_STOP)
        try {
            context.startService(stop)
        } catch (e: IllegalStateException) {
            // Refused from the background (nothing in the foreground to make
            // the start legal). Stopping needs no permission.
            context.stopService(stop)
        }
    }

    /** Store the glanceable payload where a widget can read it unaided. */
    private fun publish(context: Context, args: Map<*, *>) {
        save(context, toJson(args))
    }

    /**
     * Keep the running session in the same object the widgets read, so the
     * Focus widget says "In session" instead of offering a second one. The
     * glance is published on its own clock (a task ticked, a check-in logged),
     * so the session cannot wait for it — the same split iOS makes.
     */
    private fun storeSession(context: Context, args: Map<*, *>?) {
        val json = state(context)
        if (args == null) json.remove("session") else json.put("session", toJson(args))
        save(context, json)
    }

    /** The published state: what every widget draws from. Empty if none yet. */
    fun state(context: Context): JSONObject {
        val raw = prefs(context).getString(KEY_STATE, null) ?: return JSONObject()
        return try {
            JSONObject(raw)
        } catch (e: org.json.JSONException) {
            JSONObject()
        }
    }

    private fun save(context: Context, json: JSONObject) {
        // commit, not apply: the widgets are redrawn from this straight away,
        // and must not read the version before it.
        prefs(context).edit().putString(KEY_STATE, json.toString()).commit()
        AmbientWidgets.refresh(context)
    }

    private fun toJson(args: Map<*, *>): JSONObject {
        val json = JSONObject()
        args.forEach { (key, value) ->
            if (key is String) json.put(key, JSONObject.wrap(value))
        }
        return json
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
            // a press on a dead process would do nothing at all. Below Android
            // 12 only: from 12 an activity started by a service a notification
            // action started (a trampoline) is blocked, and the call is dropped.
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
                context.packageManager.getLaunchIntentForPackage(context.packageName)
                    ?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    ?.let(context::startActivity)
            }
        }
    }

    /**
     * A tapped widget, handed to Dart as intent rather than as a route.
     *
     * `aqademiq://focus/start5` becomes `focus/start5`; the app decides where
     * that lands, so renaming a route cannot break a widget already sitting on
     * someone's home screen.
     */
    fun routeFrom(intent: Intent?) {
        val uri = intent?.data ?: return
        if (uri.scheme != "aqademiq") return
        val route = ((uri.host ?: "") + (uri.path ?: "")).trim('/')
        if (route.isEmpty()) return
        channel?.let { live ->
            Handler(Looper.getMainLooper()).post { live.invokeMethod("route", route) }
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

    /**
     * ISO-8601 UTC, as written by [AmbientSession.toMap] on the Dart side.
     * Internal so the Focus widget can trim the session cube to the time left.
     *
     * java.time on every API level (core library desugaring backports it to
     * 24 and 25). Dart writes microseconds — six fractional digits — and the
     * old SimpleDateFormat fallback read `SSS` against them as milliseconds,
     * putting the end minutes out on those versions.
     */
    internal fun parseInstant(iso: String?): Long {
        if (iso.isNullOrBlank()) return 0L
        return try {
            java.time.Instant.parse(iso).toEpochMilli()
        } catch (e: java.time.format.DateTimeParseException) {
            0L
        }
    }
}
