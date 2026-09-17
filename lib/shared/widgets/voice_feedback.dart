import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../services/app_settings.dart';
import '../../services/voice_input_service.dart';

/// Tells the student why the mic didn't open, and how to fix it if they can.
void showVoiceUnavailable(BuildContext context, VoiceUnavailable problem) {
  final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
  switch (problem) {
    case VoiceUnavailable.denied:
      // iOS gates dictation behind two switches, Android behind one — name the
      // ones they will actually find on the Settings page.
      final what = defaultTargetPlatform == TargetPlatform.iOS
          ? 'microphone and speech recognition access'
          : 'microphone access';
      messenger.showSnackBar(
        SnackBar(
          content: Text('Voice input needs $what. Turn it on in Settings.'),
          action: SnackBarAction(
            label: 'Settings',
            onPressed: () => unawaited(openAppSettings()),
          ),
        ),
      );
    case VoiceUnavailable.unsupported:
      messenger.showSnackBar(
        const SnackBar(
          content: Text("Voice input isn't available on this phone."),
        ),
      );
  }
}
