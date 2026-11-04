package com.aqademiq.aqademiq.freeze

import android.app.Activity
import android.app.AppOpsManager
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.os.Process
import android.provider.Settings
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.text.Collator
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * The Android half of `aqademiq/app_freeze` (APP_FREEZE.md §1), for
 * `lib/features/freeze/data/app_freeze_channel.dart`.
 *
 * Android has no Screen Time API, so App freeze is built from two grants the
 * student gives in Settings — Usage access (which app is open) and Display
 * over other apps (the shield on top) — and [FreezeMonitorService], which
 * watches with them. There is no prompt to show, so `requestAuthorization`
 * answers with what is true and `openSettings` takes the student to the
 * right page. No accessibility service: "We never read your screen."
 *
 * Package names stay on the phone. `installedApps` and `appIcon` exist so the
 * picker can be drawn in Flutter; nothing they return is sent anywhere.
 *
 * A plugin, registered from MainActivity like [com.aqademiq.aqademiq.DeviceImportPlugin],
 * because the Settings pages open best from the activity (Back returns to
 * the app) and because the shield needs a live channel to say an event is
 * waiting.
 */
class AppFreezePlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware {

    companion object {
        const val CHANNEL = "aqademiq/app_freeze"

        /** The plugin on the live engine, if there is one. */
        @Volatile private var attached: AppFreezePlugin? = null

        /**
         * An event was queued (the shield's Thaw). If Dart is listening, tell
         * it now; otherwise it reads the queue the next time it asks.
         */
        fun notifyEventsWaiting() {
            val plugin = attached ?: return
            plugin.main.post { plugin.channel?.invokeMethod("eventsWaiting", null) }
        }
    }

    private var channel: MethodChannel? = null
    private var context: Context? = null
    private var activity: Activity? = null
    private var io: ExecutorService? = null
    private val main = Handler(Looper.getMainLooper())

    // ---- lifecycle ---------------------------------------------------------

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        io = Executors.newSingleThreadExecutor()
        channel = MethodChannel(binding.binaryMessenger, CHANNEL).also { it.setMethodCallHandler(this) }
        attached = this
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        if (attached === this) attached = null
        channel?.setMethodCallHandler(null)
        channel = null
        context = null
        io?.shutdown()
        io = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    // ---- calls -------------------------------------------------------------

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val ctx = context
        if (ctx == null) {
            result.error("detached", "The plugin is not attached to an engine", null)
            return
        }
        when (call.method) {
            "status" -> {
                result.success(FreezeAccess.status(ctx))
                // Self-healing: a grant given in Settings since the last
                // applyPolicy starts the monitor the moment the app looks.
                FreezeMonitorService.sync(ctx, refresh = false)
            }
            "requestAuthorization" -> result.success(FreezeAccess.authorized(ctx))
            "openSettings" -> {
                openSettings(ctx, call.argument<String>("target"))
                result.success(null)
            }
            // iOS only: Android's picker is drawn in Flutter from installedApps.
            "pickApps" -> result.success(null)
            "deleteSelection" -> result.success(null)
            "installedApps" -> background(result) { installedApps(ctx) }
            "appIcon" -> {
                val pkg = call.argument<String>("package")
                val size = (call.argument<Any>("size") as? Number)?.toInt() ?: 96
                if (pkg.isNullOrEmpty()) result.success(null) else background(result) { appIcon(ctx, pkg, size) }
            }
            "floorApps" -> background(result) { floorApps(ctx) }
            "applyPolicy" -> {
                val raw = call.argument<String>("policy")
                if (raw == null) {
                    result.error("bad_args", "policy missing", null)
                    return
                }
                FreezeStore.savePolicy(ctx, raw)
                FreezeMonitorService.sync(ctx, refresh = true)
                result.success(null)
            }
            "takeEvents" -> result.success(FreezeStore.takeEvents(ctx))
            else -> result.notImplemented()
        }
    }

    /** Runs a PackageManager read off the main thread; replies on it. */
    private fun background(result: MethodChannel.Result, work: () -> Any?) {
        val executor = io
        if (executor == null) {
            result.error("detached", "The plugin is not attached to an engine", null)
            return
        }
        try {
            executor.execute {
                try {
                    val value = work()
                    main.post { result.success(value) }
                } catch (e: Exception) {
                    main.post { result.error("read_failed", e.message, null) }
                }
            }
        } catch (e: java.util.concurrent.RejectedExecutionException) {
            result.error("detached", "The plugin is shutting down", null)
        }
    }

    // ---- settings ----------------------------------------------------------

    /**
     * The Settings page for one grant. Each target tries the most specific
     * page first and falls back, because OEM Settings apps differ in which of
     * these they answer; the app's own page is the last resort for all.
     */
    private fun openSettings(ctx: Context, target: String?) {
        val ours = Uri.fromParts("package", ctx.packageName, null)
        val attempts = ArrayList<Intent>()
        when (target) {
            "usage" -> {
                // Android 10+ Settings accepts the package and opens our row.
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    attempts.add(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS, ours))
                }
                attempts.add(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
            }
            "overlay" -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                attempts.add(Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, ours))
                attempts.add(Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION))
            }
            // The list page, which needs no permission. Deliberately not
            // ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS: that one needs a
            // permission Play only allows for a few kinds of app.
            "battery" -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                attempts.add(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
            }
        }
        attempts.add(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, ours))
        for (intent in attempts) {
            if (launch(ctx, intent)) return
        }
    }

    private fun launch(ctx: Context, intent: Intent): Boolean {
        val act = activity
        return try {
            if (act != null) {
                act.startActivity(intent)
            } else {
                ctx.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            }
            true
        } catch (e: ActivityNotFoundException) {
            false
        } catch (e: SecurityException) {
            false
        }
    }

    // ---- apps --------------------------------------------------------------

    /** Every launchable app but Aqademiq, as `{package, label}`, by label. */
    private fun installedApps(ctx: Context): List<Map<String, String>> {
        val pm = ctx.packageManager
        val labels = HashMap<String, String>()
        val launcher = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        for (ri in FreezeRules.Floor.query(pm, launcher)) {
            val info = ri.activityInfo ?: continue
            val pkg = info.packageName ?: continue
            if (pkg == ctx.packageName || labels.containsKey(pkg)) continue
            // The app's name rather than the activity's: an app with two
            // launcher entries is still one thing to freeze.
            val label = info.applicationInfo?.loadLabel(pm)?.toString()?.takeIf { it.isNotBlank() }
                ?: ri.loadLabel(pm)?.toString()?.takeIf { it.isNotBlank() }
                ?: pkg
            labels[pkg] = label
        }
        val collator = Collator.getInstance()
        val byLabel = Comparator<Pair<String, String>> { a, b -> collator.compare(a.second, b.second) }
        return labels.entries
            .map { it.key to it.value }
            .sortedWith(byLabel)
            .map { mapOf("package" to it.first, "label" to it.second) }
    }

    /** The app's launcher icon as a [size] px square PNG, or null if it has none. */
    private fun appIcon(ctx: Context, pkg: String, size: Int): ByteArray? {
        val pm = ctx.packageManager
        val drawable = try {
            pm.getLaunchIntentForPackage(pkg)?.let { pm.getActivityIcon(it) } ?: pm.getApplicationIcon(pkg)
        } catch (e: PackageManager.NameNotFoundException) {
            return null
        }
        val px = size.coerceIn(16, 512)
        val bitmap = Bitmap.createBitmap(px, px, Bitmap.Config.ARGB_8888)
        drawable.setBounds(0, 0, px, px)
        drawable.draw(Canvas(bitmap))
        val out = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
        bitmap.recycle()
        return out.toByteArray()
    }

    /**
     * The phone's own Phone, Messages, Maps and Wallet — what Dart offers as
     * Always open. Keys are left out when the phone has no such app.
     */
    private fun floorApps(ctx: Context): Map<String, String> {
        val out = LinkedHashMap<String, String>()
        FreezeRules.Floor.dialer(ctx)?.let { out["phone"] = it }
        FreezeRules.Floor.sms(ctx)?.let { out["messages"] = it }
        maps(ctx)?.let { out["maps"] = it }
        wallet(ctx)?.let { out["wallet"] = it }
        return out
    }

    /** Whatever opens a geo: link — the default, or Google Maps, or the first that can. */
    private fun maps(ctx: Context): String? {
        val pm = ctx.packageManager
        val geo = Intent(Intent.ACTION_VIEW, Uri.parse("geo:0,0"))
        FreezeRules.Floor.resolve(pm, geo)?.let { return it }
        val all = FreezeRules.Floor.query(pm, geo)
            .mapNotNull { it.activityInfo?.packageName }
            .filter { it != "android" }
        return all.firstOrNull { it == "com.google.android.apps.maps" } ?: all.firstOrNull()
    }

    /** Google Wallet, else Samsung Wallet, if installed (both are in <queries>). */
    private fun wallet(ctx: Context): String? {
        val pm = ctx.packageManager
        return listOf("com.google.android.apps.walletnfcrel", "com.samsung.android.spay")
            .firstOrNull { pm.getLaunchIntentForPackage(it) != null }
    }
}

/**
 * What the phone lets App freeze do (APP_FREEZE.md §1.1). Shared by the
 * plugin and the monitor, which stops itself if Usage access is taken away.
 */
internal object FreezeAccess {
    fun status(ctx: Context): Map<String, Boolean> {
        val usage = usageAccess(ctx)
        val overlay = overlay(ctx)
        return mapOf(
            "supported" to (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O),
            "authorized" to (usage && overlay),
            "usage_access" to usage,
            "overlay" to overlay,
            "battery_restricted" to batteryRestricted(ctx),
            "notifications" to NotificationManagerCompat.from(ctx).areNotificationsEnabled(),
        )
    }

    fun authorized(ctx: Context): Boolean = usageAccess(ctx) && overlay(ctx)

    /** Usage access is an app-op, not a runtime permission; Settings flips the op. */
    fun usageAccess(ctx: Context): Boolean {
        val ops = ctx.getSystemService(Context.APP_OPS_SERVICE) as? AppOpsManager ?: return false
        val mode = try {
            usageMode(ops, ctx.packageName)
        } catch (e: RuntimeException) {
            return false
        }
        // MODE_DEFAULT defers to the permission itself (some OEMs grant it that way).
        return if (mode == AppOpsManager.MODE_DEFAULT) {
            ctx.checkCallingOrSelfPermission("android.permission.PACKAGE_USAGE_STATS") ==
                PackageManager.PERMISSION_GRANTED
        } else {
            mode == AppOpsManager.MODE_ALLOWED
        }
    }

    @Suppress("DEPRECATION")
    private fun usageMode(ops: AppOpsManager, pkg: String): Int =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            ops.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), pkg)
        } else {
            ops.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), pkg)
        }

    fun overlay(ctx: Context): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.M || Settings.canDrawOverlays(ctx)

    fun batteryRestricted(ctx: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return false
        val power = ctx.getSystemService(Context.POWER_SERVICE) as? PowerManager ?: return false
        return !power.isIgnoringBatteryOptimizations(ctx.packageName)
    }
}
