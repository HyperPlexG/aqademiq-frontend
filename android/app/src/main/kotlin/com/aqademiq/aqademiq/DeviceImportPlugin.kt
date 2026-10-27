package com.aqademiq.aqademiq

import android.Manifest
import android.app.Activity
import android.content.ContentUris
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.CalendarContract
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * Reads the phone's calendars for Settings → Calendar import
 * (lib/services/device_import/device_import_service.dart).
 *
 * Every calendar the phone syncs is in CalendarContract — Google, Samsung,
 * Exchange / Outlook — and `Instances` returns repeating events already
 * expanded, one row per occurrence, which is what a timetable needs.
 *
 * Read-only: the manifest asks for READ_CALENDAR and never WRITE_CALENDAR, so
 * an import cannot change the student's own calendar.
 *
 * Reminders are not here on purpose. Android has no reminders store other apps
 * can read — Samsung Reminder, Google Keep and Todoist each keep their own —
 * so Reminder import on Android is "Paste a list", handled entirely in Dart.
 *
 * A plugin (rather than an object attached from MainActivity like the other
 * bridges) because the permission prompt needs the activity and its result
 * callback, which ActivityAware provides.
 */
class DeviceImportPlugin :
    FlutterPlugin,
    MethodChannel.MethodCallHandler,
    ActivityAware,
    PluginRegistry.RequestPermissionsResultListener {

    companion object {
        const val CHANNEL = "aqademiq/device_import"
        private const val REQUEST_CODE = 4127
    }

    private var channel: MethodChannel? = null
    private var context: Context? = null
    private var activity: Activity? = null
    private var activityBinding: ActivityPluginBinding? = null
    private var pendingAccess: MethodChannel.Result? = null
    private var io: ExecutorService? = null
    private val main = Handler(Looper.getMainLooper())

    // ---- lifecycle ---------------------------------------------------------

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        io = Executors.newSingleThreadExecutor()
        channel = MethodChannel(binding.binaryMessenger, CHANNEL).also { it.setMethodCallHandler(this) }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        context = null
        io?.shutdown()
        io = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) = attach(binding)

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) = attach(binding)

    override fun onDetachedFromActivityForConfigChanges() = detach()

    override fun onDetachedFromActivity() {
        // The activity is gone for good (not a rotation), so the prompt's
        // result will never arrive here. Answer with what is true now rather
        // than leave Dart waiting on it for ever.
        pendingAccess?.success(canRead())
        pendingAccess = null
        detach()
    }

    private fun attach(binding: ActivityPluginBinding) {
        activityBinding = binding
        activity = binding.activity
        binding.addRequestPermissionsResultListener(this)
    }

    private fun detach() {
        activityBinding?.removeRequestPermissionsResultListener(this)
        activityBinding = null
        activity = null
    }

    // ---- calls -------------------------------------------------------------

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val reminders = call.argument<String>("kind") == "reminders"
        when (call.method) {
            "requestAccess" -> if (reminders) result.success(false) else requestAccess(result)
            "calendars" -> if (reminders) result.success(emptyList<Any>()) else read(result) { calendars() }
            "events" -> {
                val ids = call.argument<List<String>>("calendarIds") ?: emptyList()
                val from = call.argument<Number>("from")?.toLong() ?: 0L
                val to = call.argument<Number>("to")?.toLong() ?: 0L
                read(result) { events(ids, from, to) }
            }
            "reminders" -> result.success(emptyList<Any>())
            else -> result.notImplemented()
        }
    }

    // ---- access ------------------------------------------------------------

    private fun canRead(): Boolean {
        val ctx = context ?: return false
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
            ctx.checkSelfPermission(Manifest.permission.READ_CALENDAR) == PackageManager.PERMISSION_GRANTED
    }

    private fun requestAccess(result: MethodChannel.Result) {
        if (canRead()) {
            result.success(true)
            return
        }
        val act = activity
        if (act == null || Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            result.success(false)
            return
        }
        if (pendingAccess != null) {
            result.error("busy", "A permission prompt is already showing", null)
            return
        }
        pendingAccess = result
        act.requestPermissions(arrayOf(Manifest.permission.READ_CALENDAR), REQUEST_CODE)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ): Boolean {
        if (requestCode != REQUEST_CODE) return false
        val result = pendingAccess ?: return true
        pendingAccess = null
        result.success(grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED)
        return true
    }

    // ---- reads -------------------------------------------------------------

    /** Runs a ContentResolver query off the main thread; replies on it. */
    private fun read(result: MethodChannel.Result, work: () -> Any) {
        if (!canRead()) {
            result.error("denied", "Calendar access was not granted", null)
            return
        }
        val executor = io
        if (executor == null) {
            result.error("detached", "The plugin is not attached to an engine", null)
            return
        }
        executor.execute {
            try {
                val value = work()
                main.post { result.success(value) }
            } catch (e: Exception) {
                main.post { result.error("read_failed", e.message, null) }
            }
        }
    }

    private fun calendars(): List<Map<String, Any?>> {
        val resolver = context?.contentResolver ?: return emptyList()
        val projection = arrayOf(
            CalendarContract.Calendars._ID,
            CalendarContract.Calendars.CALENDAR_DISPLAY_NAME,
            CalendarContract.Calendars.ACCOUNT_NAME,
            CalendarContract.Calendars.CALENDAR_COLOR,
            CalendarContract.Calendars.VISIBLE,
        )
        val out = mutableListOf<Map<String, Any?>>()
        resolver.query(CalendarContract.Calendars.CONTENT_URI, projection, null, null, null)?.use { c ->
            while (c.moveToNext()) {
                // Calendars the student switched off in their calendar app.
                if (!c.isNull(4) && c.getInt(4) == 0) continue
                out.add(
                    mapOf(
                        "id" to c.getLong(0).toString(),
                        "title" to (c.getString(1) ?: ""),
                        "account" to c.getString(2),
                        "color" to (if (c.isNull(3)) null else hex(c.getInt(3))),
                    ),
                )
            }
        }
        return out
    }

    private fun events(ids: List<String>, from: Long, to: Long): List<Map<String, Any?>> {
        val resolver = context?.contentResolver ?: return emptyList()
        val wanted = ids.mapNotNull { it.toLongOrNull() }.distinct()
        if (wanted.isEmpty() || to <= from) return emptyList()

        val uri = CalendarContract.Instances.CONTENT_URI.buildUpon().also {
            ContentUris.appendId(it, from)
            ContentUris.appendId(it, to)
        }.build()
        val projection = arrayOf(
            CalendarContract.Instances.EVENT_ID,
            CalendarContract.Instances.BEGIN,
            CalendarContract.Instances.END,
            CalendarContract.Instances.TITLE,
            CalendarContract.Instances.DESCRIPTION,
            CalendarContract.Instances.EVENT_LOCATION,
            CalendarContract.Instances.ALL_DAY,
            CalendarContract.Instances.CALENDAR_ID,
            CalendarContract.Instances.CALENDAR_DISPLAY_NAME,
            CalendarContract.Instances.STATUS,
            CalendarContract.Instances.UID_2445,
        )
        val selection = "${CalendarContract.Instances.CALENDAR_ID} IN (${wanted.joinToString(",") { "?" }})"
        val args = wanted.map { it.toString() }.toTypedArray()

        // All-day events are stored at UTC midnight, so their day is read in
        // UTC; a timed event's day is the phone's local day.
        val utcDay = SimpleDateFormat("yyyy-MM-dd", Locale.US).apply { timeZone = TimeZone.getTimeZone("UTC") }
        val localDay = SimpleDateFormat("yyyy-MM-dd", Locale.US)

        val out = mutableListOf<Map<String, Any?>>()
        resolver.query(uri, projection, selection, args, "${CalendarContract.Instances.BEGIN} ASC")?.use { c ->
            while (c.moveToNext()) {
                if (!c.isNull(9) && c.getInt(9) == CalendarContract.Events.STATUS_CANCELED) continue
                val begin = c.getLong(1)
                val allDay = !c.isNull(6) && c.getInt(6) != 0
                // The event's iCalendar UID where the account provides one
                // (Google, Exchange): it survives a new phone or re-adding the
                // account. EVENT_ID is only this phone's row number, so it is
                // the fallback for local calendars that have no UID.
                val uid = if (c.isNull(10)) null else c.getString(10)
                out.add(
                    mapOf(
                        "id" to (if (uid.isNullOrBlank()) c.getLong(0).toString() else uid),
                        "title" to (c.getString(3) ?: ""),
                        "notes" to c.getString(4),
                        "location" to c.getString(5),
                        "start" to begin,
                        "end" to (if (c.isNull(2)) null else c.getLong(2)),
                        "allDay" to allDay,
                        "startDay" to (if (allDay) utcDay else localDay).format(Date(begin)),
                        "calendarId" to c.getLong(7).toString(),
                        "calendarTitle" to (c.getString(8) ?: ""),
                    ),
                )
            }
        }
        return out
    }

    private fun hex(color: Int): String = String.format(Locale.US, "#%06X", 0xFFFFFF and color)
}
