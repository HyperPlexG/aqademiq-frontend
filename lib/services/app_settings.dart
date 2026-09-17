import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

const _channel = MethodChannel('aqademiq/app_settings');

/// Opens Aqademiq's own page in the system Settings app.
///
/// Needed wherever a permission was refused: neither OS will show the prompt a
/// second time, so Settings is the only way back. iOS exposes that page as a
/// URL; Android has no equivalent, so `MainActivity` opens it on request.
///
/// Best-effort — the message that offers this already says where to go.
Future<void> openAppSettings() async {
  try {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await launchUrl(Uri.parse('app-settings:'));
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      await _channel.invokeMethod<void>('open');
    }
  } on Object catch (e) {
    debugPrint('[settings] could not open app settings: $e');
  }
}
