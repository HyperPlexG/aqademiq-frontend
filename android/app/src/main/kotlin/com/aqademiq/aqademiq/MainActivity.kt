package com.aqademiq.aqademiq

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
    }

    override fun onDestroy() {
        AmbientBridge.detach()
        super.onDestroy()
    }
}
