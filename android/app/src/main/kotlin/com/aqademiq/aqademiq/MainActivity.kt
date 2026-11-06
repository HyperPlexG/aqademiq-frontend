package com.aqademiq.aqademiq

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import com.aqademiq.aqademiq.freeze.AppFreezePlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    /**
     * Screenshots, for the weekly report's "Screenshotting?" banner
     * (lib/features/report/report_screenshots.dart). Android 14 tells a
     * visible activity that the screen was captured, and nothing about what
     * was in it; older Android has no such callback, so there it never fires.
     */
    private var screenshotChannel: MethodChannel? = null

    /** An `Activity.ScreenCaptureCallback` on API 34+, held to unregister. */
    private var screenCapture: Any? = null

    /**
     * Attach the ambient channel as soon as there is an engine to talk to.
     *
     * This is also where a Freeze pressed while the app was not running gets
     * replayed: the press is parked in shared preferences by [AmbientBridge]
     * and drained here, so it changes the session rather than evaporating.
     */
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        AmbientBridge.attach(
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AmbientBridge.CHANNEL),
            applicationContext,
        )
        // A widget tapped while the app was closed brought us here, so the link
        // is already on the launch intent and would otherwise be missed.
        AmbientBridge.routeFrom(intent)

        // The 23 haptic patterns. Flutter's own HapticFeedback takes no
        // parameters, so intensity, duration and multi-beat timing all arrive
        // through here (lib/services/haptics/haptic_driver.dart).
        HapticsBridge.attach(
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, HapticsBridge.CHANNEL),
            applicationContext,
        )

        // Settings → Calendar import: reads the phone's calendars (read-only).
        // A plugin rather than an attached object because the permission
        // prompt needs the activity's result callback.
        flutterEngine.plugins.add(DeviceImportPlugin())

        // App freeze (APP_FREEZE.md): the grants, the app list for the picker,
        // and the policy the monitor enforces with the app closed. A plugin for
        // the same reason as above — Settings opens from the activity — and so
        // the shield can tell a live engine that a Thaw is waiting.
        flutterEngine.plugins.add(AppFreezePlugin())

        // One call, `screenshotTaken`, sent from the capture callback below.
        screenshotChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "aqademiq/screenshot")

        // A permission the student refused can only be re-enabled from the app's
        // page in system Settings. iOS reaches it through a URL; Android has none,
        // so Dart asks for it here (lib/services/app_settings.dart).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "aqademiq/app_settings")
            .setMethodCallHandler { call, result ->
                if (call.method == "open") {
                    startActivity(
                        Intent(
                            Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                            Uri.fromParts("package", packageName, null),
                        ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                    )
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }

    /**
     * The capture callback is only delivered while the activity is visible,
     * so it is held from start to stop. Needs the normal (install-time)
     * DETECT_SCREEN_CAPTURE permission; without it registering throws, which
     * is caught rather than taking the activity down over a banner.
     */
    override fun onStart() {
        super.onStart()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE && screenCapture == null) {
            val callback = Activity.ScreenCaptureCallback {
                screenshotChannel?.invokeMethod("screenshotTaken", null)
            }
            try {
                registerScreenCaptureCallback(mainExecutor, callback)
                screenCapture = callback
            } catch (e: SecurityException) {
                screenCapture = null
            }
        }
    }

    override fun onStop() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            (screenCapture as? Activity.ScreenCaptureCallback)?.let { unregisterScreenCaptureCallback(it) }
            screenCapture = null
        }
        super.onStop()
    }

    /** A widget tapped while the app was already open (singleTop). */
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        AmbientBridge.routeFrom(intent)
    }

    override fun onDestroy() {
        // Swiped away, backed out of, or reclaimed: the engine (and the session
        // it holds) goes with this activity, so the card and the stored session
        // go too. Not for a configuration change, where the activity is only
        // being recreated.
        AmbientBridge.detach(applicationContext, standDown = !isChangingConfigurations)
        HapticsBridge.detach()
        screenshotChannel = null
        super.onDestroy()
    }
}
