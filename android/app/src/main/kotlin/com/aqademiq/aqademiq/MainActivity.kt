package com.aqademiq.aqademiq

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

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
    }

    /** A widget tapped while the app was already open (singleTop). */
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        AmbientBridge.routeFrom(intent)
    }

    override fun onDestroy() {
        AmbientBridge.detach()
        super.onDestroy()
    }
}
