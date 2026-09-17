import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Voice input: speech turned into text that lands in a field for the student
/// to read, correct and send themselves.
///
/// Recognition is the phone's own — Apple's Speech framework on iOS, Google's
/// recognizer on Android — through `speech_to_text`. Nothing is recorded or
/// uploaded by Aqademiq, and the backend is not involved.
///
/// The one rule every caller relies on: **dictation never sends anything.** It
/// only ever writes into a text field.

/// Why voice input could not start.
enum VoiceUnavailable {
  /// The student refused microphone (or, on iOS, speech recognition) access.
  /// The OS will not ask again, so the only way back is Settings.
  denied,

  /// The phone has no recognizer — e.g. an Android build without Google
  /// services. Permanent for this install, so the control is hidden.
  unsupported,
}

/// The platform seam, so the controller can be tested without a microphone.
abstract class SpeechEngine {
  /// Prompts for permission the first time. False means denied or unsupported;
  /// [hasPermission] tells the two apart.
  Future<bool> initialize({
    required void Function(String status) onStatus,
    required void Function(String message) onError,
  });

  /// Whether permission is already granted. Never prompts.
  Future<bool> hasPermission();

  /// [onWords] receives the whole utterance so far — not a delta — every time
  /// it changes.
  Future<void> listen(void Function(String words) onWords);

  /// Ends listening; the recognizer may still deliver a final result.
  Future<void> stop();

  /// Ends listening and discards anything not yet delivered.
  Future<void> cancel();
}

/// The real engine.
class DeviceSpeechEngine implements SpeechEngine {
  final SpeechToText _stt = SpeechToText();

  @override
  Future<bool> initialize({
    required void Function(String status) onStatus,
    required void Function(String message) onError,
  }) => _stt.initialize(
    onStatus: onStatus,
    onError: (e) => onError(e.errorMsg),
    // Speech through a Bluetooth headset on Android needs the runtime
    // BLUETOOTH_CONNECT permission — a second prompt, for a feature most
    // students would use holding the phone. The phone's own mic is enough.
    options: [SpeechToText.androidNoBluetooth],
  );

  @override
  Future<bool> hasPermission() => _stt.hasPermission;

  @override
  Future<void> listen(void Function(String words) onWords) async {
    await _stt.listen(
      onResult: (r) => onWords(r.recognizedWords),
      listenOptions: SpeechListenOptions(
        // Free-form speech, not short commands.
        listenMode: ListenMode.dictation,
        autoPunctuation: true,
        cancelOnError: true,
        // Android ends on silence by itself; iOS does not, so this is the
        // stop for the student who finishes talking and waits.
        pauseFor: const Duration(seconds: 3),
        // Apple's server-side recognition caps one request at about a minute.
        listenFor: const Duration(seconds: 60),
        // No localeId: the phone's own language, which is what the student
        // speaks to it in everywhere else.
      ),
    );
  }

  @override
  Future<void> stop() => _stt.stop();

  @override
  Future<void> cancel() => _stt.cancel();
}

final speechEngineProvider = Provider<SpeechEngine>(
  (ref) => DeviceSpeechEngine(),
);

/// Something that must go quiet while the microphone is open.
///
/// In the app this is the Prism soundscape: left playing, the mic hears the
/// music and the transcript fills with noise. It is injected rather than
/// imported because `services/` sits below the features — `main.dart` wires the
/// Prism implementation in, and tests get the silent default.
abstract class VoiceAudioHold {
  Future<void> hold();
  Future<void> release();
}

class _NoAudioHold implements VoiceAudioHold {
  const _NoAudioHold();
  @override
  Future<void> hold() async {}
  @override
  Future<void> release() async {}
}

final voiceAudioHoldProvider = Provider<VoiceAudioHold>(
  (ref) => const _NoAudioHold(),
);

@immutable
class VoiceInputState {
  const VoiceInputState({this.listening = false, this.owner, this.unavailable});

  /// The microphone is open.
  final bool listening;

  /// Whoever started the current session, so two screens that both offer voice
  /// can tell whose it is. Identity only; never inspected.
  final Object? owner;

  /// Set once voice is known not to work, so the control can say so or hide.
  final VoiceUnavailable? unavailable;

  bool isListeningFor(Object who) => listening && identical(owner, who);
}

final voiceInputProvider =
    NotifierProvider<VoiceInputController, VoiceInputState>(
      VoiceInputController.new,
    );

class VoiceInputController extends Notifier<VoiceInputState> {
  SpeechEngine get _engine => ref.read(speechEngineProvider);

  bool _ready = false;
  bool _holdingAudio = false;
  void Function(String words)? _onWords;

  @override
  VoiceInputState build() => const VoiceInputState();

  /// Opens the microphone and streams what is heard to [onWords].
  ///
  /// Returns null when listening started, or why it could not. A session
  /// already running — from this screen or another — is cancelled first:
  /// there is one microphone.
  Future<VoiceUnavailable?> start({
    required Object owner,
    required void Function(String words) onWords,
  }) async {
    if (state.listening) await cancel();

    if (!_ready) {
      // The package only remembers success, so a student who refused and then
      // granted access in Settings gets a working mic on the next tap.
      _ready = await _engine.initialize(
        onStatus: _onStatus,
        onError: (_) => _finish(),
      );
      if (!_ready) {
        final problem = await _engine.hasPermission()
            ? VoiceUnavailable.unsupported
            : VoiceUnavailable.denied;
        state = VoiceInputState(unavailable: problem);
        return problem;
      }
    }

    _onWords = onWords;
    state = VoiceInputState(listening: true, owner: owner);
    _holdAudio();
    try {
      await _engine.listen((words) => _onWords?.call(words));
    } on Object {
      _finish();
    }
    return null;
  }

  /// Stops listening and keeps what was heard, including a final result the
  /// recognizer may still be about to deliver.
  Future<void> stop({Object? owner}) async {
    if (!_owns(owner)) return;
    await _engine.stop();
  }

  /// Stops listening and delivers nothing more.
  ///
  /// The callback is detached *before* anything is awaited. That ordering is
  /// what lets a caller cancel and then clear its field in the same frame —
  /// sending a message — without a late final result writing the words back.
  Future<void> cancel({Object? owner}) async {
    if (!_owns(owner)) return;
    _onWords = null;
    if (!state.listening) return;
    _finish();
    await _engine.cancel();
  }

  bool _owns(Object? owner) => owner == null || identical(state.owner, owner);

  void _onStatus(String status) {
    // `done` is the last word: every result, final one included, is in.
    // `notListening` arrives before it, and the mic is already closed by then,
    // so the audio can come back without waiting.
    if (status == SpeechToText.doneStatus) {
      _finish();
    } else if (status == SpeechToText.notListeningStatus) {
      _releaseAudio();
      if (state.listening) state = VoiceInputState(owner: state.owner);
    }
  }

  void _finish() {
    _onWords = null;
    _releaseAudio();
    if (state.listening || state.owner != null) {
      state = VoiceInputState(unavailable: state.unavailable);
    }
  }

  void _holdAudio() {
    if (_holdingAudio) return;
    _holdingAudio = true;
    // Not awaited: the soundscape fades out over a few seconds, and making the
    // student wait for the fade before the mic opens would feel broken.
    unawaited(ref.read(voiceAudioHoldProvider).hold());
  }

  void _releaseAudio() {
    if (!_holdingAudio) return;
    _holdingAudio = false;
    unawaited(ref.read(voiceAudioHoldProvider).release());
  }
}

/// Ends [owner]'s dictation from a widget's `dispose()`.
///
/// Deferred on purpose. Ending a session changes [voiceInputProvider], and a
/// screen that watches it is still subscribed while its own `dispose()` runs —
/// so a synchronous cancel asks a widget that is mid-teardown to rebuild, which
/// asserts. Swiping Quick Add away while dictating did exactly that. By the
/// microtask the element has fully unmounted and dropped its subscription.
///
/// Callers guard their word callback on `mounted`, so nothing heard in between
/// can reach the field they are about to dispose.
void endDictationAfterTeardown(VoiceInputController voice, Object owner) {
  scheduleMicrotask(() => unawaited(voice.cancel(owner: owner)));
}

/// What a field reads while dictating: whatever was typed before the mic
/// opened, followed by what has been said since.
///
/// Spoken words are added rather than replacing the field, so a student who
/// typed half a question and finished it out loud keeps both halves.
String composeDictation(String typedBefore, String spoken) {
  final words = spoken.trim();
  if (words.isEmpty) return typedBefore;
  if (typedBefore.trim().isEmpty) return words;
  final joiner = RegExp(r'\s$').hasMatch(typedBefore) ? '' : ' ';
  return '$typedBefore$joiner$words';
}

/// Binds dictation to one text field.
class Dictation {
  Dictation(this.field);

  final TextEditingController field;
  String _before = '';

  /// Snapshot what is already typed. Call before starting to listen.
  void begin() => _before = field.text;

  /// Show [spoken] after the snapshot, with the cursor at the end.
  void show(String spoken) {
    final text = composeDictation(_before, spoken);
    field.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
