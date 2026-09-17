package com.aqademiq.aqademiq

import android.content.Intent
import android.net.Uri
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
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
}
