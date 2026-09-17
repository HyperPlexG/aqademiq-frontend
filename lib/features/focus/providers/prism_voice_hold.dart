import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/voice_input_service.dart';
import 'prism_audio_provider.dart';

/// Quiets the Prism soundscape while voice input has the microphone.
///
/// Wired in from `main.dart` as the app's [voiceAudioHoldProvider], because the
/// voice service lives below the features and must not import Prism itself.
class PrismVoiceHold implements VoiceAudioHold {
  PrismVoiceHold(this._ref);

  final Ref _ref;

  PrismAudioController get _prism =>
      _ref.read(prismAudioControllerProvider.notifier);

  @override
  Future<void> hold() => _prism.holdForVoice();

  @override
  Future<void> release() => _prism.releaseAfterVoice();
}
