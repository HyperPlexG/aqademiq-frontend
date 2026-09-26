import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
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
///
/// Three things about the platforms shape everything below, all of them found
/// by using the first version on a real phone:
///
/// 1. **The recognizer stops on its own.** Android ends a session roughly a
///    second after you stop speaking — inside the plugin, whatever timeouts we
///    pass — and Apple caps one request at about a minute. "Record until I say
///    stop" therefore means starting a new session each time one ends and
///    stitching the text together, which is what the restart path below does.
/// 2. **A refused start is silent.** `listen()` reports nothing when the
///    platform declines — most often because the previous session has not
///    finished closing. That was the mic button that "sometimes doesn't work":
///    the UI said Listening and no audio was ever captured. So a start is now
///    only believed once the platform says `listening`, and is retried once.
/// 3. **Android says `listening` before the mic is open.** It reports it the
///    moment the recognizer is *asked* to start, not when it is ready, and the
///    warm-up costs the first word or two. The UI waits out
///    [SpeechEngine.warmUp] before inviting anyone to speak.

/// Why voice input could not start.
enum VoiceUnavailable {
  /// The student refused microphone (or, on iOS, speech recognition) access.
  /// The OS will not ask again, so the only way back is Settings.
  denied,

  /// The phone has no recognizer — e.g. an Android build without Google
  /// services. Permanent for this install, so the control is hidden.
  unsupported,

  /// The recognizer would not start this time. Transient — usually the
  /// previous session still closing — so the control stays and a second tap
  /// generally works.
  couldNotStart,
}

/// What the microphone is doing.
enum VoicePhase {
  idle,

  /// Asked to start and not yet capturing: the platform has not confirmed, or
  /// it has and the mic is still warming up. Nothing said now is heard.
  starting,

  /// Actually capturing.
  listening,
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

  /// Asks the platform to start capturing. Returning normally does **not**
  /// mean it started — wait for the `listening` status.
  ///
  /// [onWords] receives the whole utterance of the current session — not a
  /// delta, and not the text of earlier sessions. [onLevel] receives how loud
  /// the microphone is, already scaled to 0–1, for the waveform.
  Future<void> listen(
    void Function(String words) onWords, {
    void Function(double level)? onLevel,
  });

  /// Ends the session; the recognizer may still deliver a final result.
  Future<void> stop();

  /// Ends the session and discards anything not yet delivered.
  Future<void> cancel();

  /// How long after the platform claims to be listening the microphone is
  /// actually capturing.
  Duration get warmUp;

  /// How long to wait for the platform to confirm a start before assuming it
  /// quietly refused.
  Duration get startTimeout;
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
    // Sessions are stitched end to end, so the wait for a final result sits
    // between every pair of them. Shorter than the two-second default, and
    // safe: the partial results already carry the words.
    finalTimeout: const Duration(milliseconds: 800),
    // Speech through a Bluetooth headset on Android needs the runtime
    // BLUETOOTH_CONNECT permission — a second prompt, for a feature most
    // students would use holding the phone. The phone's own mic is enough.
    options: [SpeechToText.androidNoBluetooth],
  );

  @override
  Future<bool> hasPermission() => _stt.hasPermission;

  @override
  Future<void> listen(
    void Function(String words) onWords, {
    void Function(double level)? onLevel,
  }) async {
    await _stt.listen(
      onResult: (r) => onWords(r.recognizedWords),
      onSoundLevelChange: onLevel == null
          ? null
          : (raw) => onLevel(normaliseSoundLevel(raw, defaultTargetPlatform)),
      listenOptions: SpeechListenOptions(
        // Free-form speech, not short commands.
        listenMode: ListenMode.dictation,
        autoPunctuation: true,
        // Errors are handled here, by starting a fresh session, rather than
        // by the plugin tearing the whole thing down — which is the default,
        // so it is left alone.
        // No pauseFor and no listenFor: nothing in this layer may end a
        // session the student did not end. When the platform ends one anyway,
        // the controller starts the next.
        // No localeId: the phone's own language, which is what the student
        // speaks to it in everywhere else.
      ),
    );
  }

  @override
  Future<void> stop() => _stt.stop();

  @override
  Future<void> cancel() => _stt.cancel();

  @override
  // Measured behaviour, not a documented figure: Android reports `listening`
  // when it posts the start, and the microphone opens a few hundred
  // milliseconds later. iOS reports it once its audio engine is running.
  Duration get warmUp => defaultTargetPlatform == TargetPlatform.android
      ? const Duration(milliseconds: 400)
      : Duration.zero;

  @override
  Duration get startTimeout => const Duration(seconds: 2);
}

/// Scales the recognizer's microphone level to 0–1 for drawing.
///
/// The two platforms report different things. Android passes through
/// `SpeechRecognizer`'s `rmsdB`, which sits around −2 in a quiet room and
/// reaches about 10 when someone speaks up. iOS computes dBFS from the raw
/// buffer — 0 is the loudest possible, ordinary speech lands between −45 and
/// −15, and a silent buffer is `log10(0)`, i.e. negative infinity. Both are
/// clamped into a window where speech moves the needle, then eased with a
/// square root so conversational volume reads as visible bars rather than
/// ticks.
double normaliseSoundLevel(double raw, TargetPlatform platform) {
  if (!raw.isFinite) return 0;
  final (floor, ceiling) = platform == TargetPlatform.iOS
      ? (-50.0, -10.0)
      : (-2.0, 10.0);
  final linear = ((raw - floor) / (ceiling - floor)).clamp(0.0, 1.0);
  return math.sqrt(linear);
}

final speechEngineProvider = Provider<SpeechEngine>(
  (ref) => DeviceSpeechEngine(),
);

/// Breathing room between one session ending and the next beginning. Also what
/// gives a busy recognizer a moment to finish closing.
@visibleForTesting
const voiceRestartGap = Duration(milliseconds: 150);

/// Errors worth starting another session for. Everything else ends dictation.
///
/// `error_no_match` and `error_speech_timeout` are simply silence, which is not
/// a reason to stop when the student asked to keep recording. `error_busy` and
/// `error_client` are the recognizer tripping over itself between sessions.
const _recoverableErrors = {
  'error_no_match',
  'error_speech_timeout',
  'error_busy',
  'error_client',
};

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
  const VoiceInputState({
    this.phase = VoicePhase.idle,
    this.owner,
    this.unavailable,
  });

  final VoicePhase phase;

  /// Whoever started the current session, so two screens that both offer voice
  /// can tell whose it is. Identity only; never inspected.
  final Object? owner;

  /// Set once voice is known not to work, so the control can say so or hide.
  final VoiceUnavailable? unavailable;

  /// The microphone is actually capturing.
  bool get listening => phase == VoicePhase.listening;

  bool isListeningFor(Object who) => listening && identical(owner, who);

  /// Starting or listening — i.e. this screen owns the microphone, so its
  /// control should offer to stop rather than to start.
  bool isActiveFor(Object who) =>
      phase != VoicePhase.idle && identical(owner, who);
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

  /// The student wants to be recording. Only [stop], [cancel] and a run of
  /// failures clear it — never the platform ending a session.
  bool _wantListening = false;

  /// Text from sessions that have already ended.
  String _committed = '';

  /// The current session's utterance so far.
  String _current = '';

  Completer<bool>? _startConfirmed;
  Timer? _startTimeout;
  bool _restarting = false;
  int _restartFailures = 0;

  /// Completes when the current dictation has fully ended — every word in.
  Completer<void>? _ended;

  /// How loud the microphone is right now, 0–1, for the recording waveform.
  ///
  /// A notifier rather than part of [state] on purpose: it changes many times a
  /// second, and routing that through the provider would rebuild every screen
  /// watching voice input to move a few bars.
  final level = ValueNotifier<double>(0);

  @override
  VoiceInputState build() {
    ref.onDispose(level.dispose);
    return const VoiceInputState();
  }

  /// Opens the microphone and streams everything heard to [onWords], until
  /// [stop] or [cancel]. Sessions ended by the platform are replaced.
  ///
  /// Returns null when recording began, or why it could not.
  Future<VoiceUnavailable?> start({
    required Object owner,
    required void Function(String words) onWords,
  }) async {
    if (state.phase != VoicePhase.idle) await cancel();

    if (!_ready) {
      // The package only remembers success, so a student who refused and then
      // granted access in Settings gets a working mic on the next tap.
      _ready = await _engine.initialize(onStatus: _onStatus, onError: _onError);
      if (!_ready) {
        final problem = await _engine.hasPermission()
            ? VoiceUnavailable.unsupported
            : VoiceUnavailable.denied;
        state = VoiceInputState(unavailable: problem);
        return problem;
      }
    }

    _onWords = onWords;
    _committed = '';
    _current = '';
    _restartFailures = 0;
    _wantListening = true;
    state = VoiceInputState(phase: VoicePhase.starting, owner: owner);
    _holdAudio();

    if (await _beginListening()) return null;

    // A silent refusal almost always means the previous session is still
    // closing. Clear it out and give it one more go before saying so.
    await _engine.cancel();
    await Future<void>.delayed(voiceRestartGap);
    if (_wantListening && await _beginListening()) return null;

    _wantListening = false;
    _finish();
    return VoiceUnavailable.couldNotStart;
  }

  /// Ends recording and keeps everything heard, including a final result the
  /// recognizer may still be about to deliver.
  Future<void> stop({Object? owner}) async {
    if (!_owns(owner)) return;
    _wantListening = false;
    // Stopping something that never got to listening has nothing to deliver,
    // and `stop()` on an unstarted recognizer reports nothing back — which
    // would strand the control in "starting" for good.
    if (state.phase == VoicePhase.starting) return cancel(owner: owner);
    await _engine.stop();
  }

  /// Ends recording and waits until the last words are in, so whatever the
  /// caller does next — sending, say — sees the finished text rather than the
  /// last partial result. Gives up after [timeout] and cancels, so a
  /// recognizer that never reports back cannot hold a send hostage.
  Future<void> stopAndSettle({
    Object? owner,
    Duration timeout = const Duration(milliseconds: 1500),
  }) async {
    if (!_owns(owner) || state.phase == VoicePhase.idle) return;
    final ended = _ended ??= Completer<void>();
    await stop(owner: owner);
    try {
      await ended.future.timeout(timeout);
    } on TimeoutException {
      await cancel(owner: owner);
    }
  }

  /// Ends recording and delivers nothing more.
  ///
  /// The callback is detached *before* anything is awaited. That ordering is
  /// what lets a caller cancel and then clear its field in the same frame —
  /// sending a message — without a late final result writing the words back.
  Future<void> cancel({Object? owner}) async {
    if (!_owns(owner)) return;
    _onWords = null;
    _wantListening = false;
    if (state.phase == VoicePhase.idle) return;
    _finish();
    await _engine.cancel();
  }

  bool _owns(Object? owner) => owner == null || identical(state.owner, owner);

  /// Asks the platform to listen and waits to be told it really is.
  Future<bool> _beginListening() async {
    final confirmed = Completer<bool>();
    _startConfirmed = confirmed;
    _startTimeout?.cancel();
    _startTimeout = Timer(_engine.startTimeout, () {
      if (!confirmed.isCompleted) confirmed.complete(false);
    });

    try {
      await _engine.listen(_onResult, onLevel: _onLevel);
    } on Object {
      if (!confirmed.isCompleted) confirmed.complete(false);
    }

    final started = await confirmed.future;
    _startTimeout?.cancel();
    _startTimeout = null;
    if (!started) return false;

    // The platform is listening; the microphone is not necessarily open yet.
    await Future<void>.delayed(_engine.warmUp);
    if (!_wantListening) return true;
    state = VoiceInputState(phase: VoicePhase.listening, owner: state.owner);
    return true;
  }

  /// Starts the next session after the platform ended one by itself.
  Future<void> _restart() async {
    if (_restarting || !_wantListening) return;
    _restarting = true;
    try {
      _commitCurrent();
      // Honest about the gap: for these few hundred milliseconds nothing is
      // being heard, and the control says so rather than claiming otherwise.
      state = VoiceInputState(phase: VoicePhase.starting, owner: state.owner);
      await Future<void>.delayed(voiceRestartGap);
      while (_wantListening) {
        if (await _beginListening()) {
          _restartFailures = 0;
          return;
        }
        if (++_restartFailures >= 3) break;
        await _engine.cancel();
        await Future<void>.delayed(voiceRestartGap);
      }
    } finally {
      _restarting = false;
    }
    if (_wantListening) {
      // Out of retries. End quietly — everything heard so far stays in the
      // field, and the control is there to try again.
      _wantListening = false;
      _finish();
    }
  }

  void _onLevel(double value) => level.value = value;

  void _onResult(String words) {
    _current = words;
    _restartFailures = 0;
    _emit();
  }

  /// Everything said this dictation — finished sessions plus the one running —
  /// tidied. Tidying here rather than per session also catches a word repeated
  /// across the seam, which happens when the recognizer restarts mid-sentence.
  String _spokenSoFar() => tidySpeech(
    _committed.isEmpty
        ? _current
        : _current.isEmpty
        ? _committed
        : '$_committed $_current',
  );

  void _emit() => _onWords?.call(_spokenSoFar());

  void _commitCurrent() {
    _committed = _spokenSoFar();
    _current = '';
  }

  void _onStatus(String status) {
    if (status == SpeechToText.listeningStatus) {
      if (_startConfirmed?.isCompleted == false) {
        _startConfirmed!.complete(true);
      }
      return;
    }
    // `notListening` arrives first but the final result has not; `done` means
    // everything from this session is in.
    if (status != SpeechToText.doneStatus) return;
    if (_wantListening) {
      unawaited(_restart());
    } else {
      _finish();
    }
  }

  void _onError(String message) {
    if (_startConfirmed?.isCompleted == false) _startConfirmed!.complete(false);
    if (_wantListening && _recoverableErrors.contains(message)) {
      unawaited(_restart());
      return;
    }
    _wantListening = false;
    _finish();
  }

  void _finish() {
    _onWords = null;
    _wantListening = false;
    _startTimeout?.cancel();
    _startTimeout = null;
    level.value = 0;
    final ended = _ended;
    _ended = null;
    if (ended != null && !ended.isCompleted) ended.complete();
    _releaseAudio();
    if (state.phase != VoicePhase.idle) {
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

/// The noises people make while thinking, which nobody means to type.
///
/// Only true disfluencies — no ordinary word that happens to be short. "Like"
/// and "so" are left alone: a student saying "tasks like this" means it.
const _fillerSounds = {
  'um', 'umm', 'ummm', 'uh', 'uhh', 'uhhh', 'uhm', 'erm', 'er', 'err',
  'ah', 'ahh', 'ahhh', 'hm', 'hmm', 'hmmm', 'mm', 'mmm', 'mhm', 'eh',
};

/// Letters and apostrophes only, for comparing two words while ignoring the
/// punctuation the recognizer attaches to them.
String _bareWord(String token) =>
    token.toLowerCase().replaceAll(RegExp("[^a-z']"), '');

/// Drops the "um"s and the stutters out of dictated speech.
///
/// Two things, both of which a student would delete by hand:
///
/// * filler sounds — "um", "uh", "hmm" and friends;
/// * a word said twice in a row — "I I need" becomes "I need".
///
/// Deliberately literal. It does not reflow sentences, fix grammar or touch
/// anything the student typed themselves; it only removes what was never meant
/// to be there. When a repeat carries punctuation the fuller one is kept, so
/// "week week." keeps the full stop.
String tidySpeech(String spoken) {
  final kept = <String>[];
  for (final token in spoken.trim().split(RegExp(r'\s+'))) {
    if (token.isEmpty) continue;
    final bare = _bareWord(token);
    // Punctuation on its own belongs to the sentence, not to a word.
    if (bare.isEmpty) {
      kept.add(token);
      continue;
    }
    if (_fillerSounds.contains(bare)) continue;
    if (kept.isNotEmpty && _bareWord(kept.last) == bare) {
      if (token.length > kept.last.length) kept[kept.length - 1] = token;
      continue;
    }
    kept.add(token);
  }
  return kept.join(' ');
}

/// What a field reads while dictating: whatever was typed before the mic
/// opened, followed by what has been said since.
///
/// Spoken words are added rather than replacing the field, so a student who
/// typed half a question and finished it out loud keeps both halves. The same
/// join stitches one recognizer session onto the last.
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

  /// Put the field back exactly as it was before the mic opened — the discard
  /// button. Callers cancel the dictation first, so no late word lands after.
  void restore() => field.value = TextEditingValue(
    text: _before,
    selection: TextSelection.collapsed(offset: _before.length),
  );

  /// Show [spoken] after the snapshot, with the cursor at the end.
  void show(String spoken) {
    final text = composeDictation(_before, spoken);
    field.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
