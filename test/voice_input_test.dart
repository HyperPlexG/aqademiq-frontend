// Voice input: speech becomes text in a field, and nothing more.
//
// The requirement is small and strict — the student speaks, reads what was
// heard, and taps send themselves. So the tests that matter are about what the
// mic must NOT do: send, keep writing after a message has gone, talk over
// another screen's dictation, or leave the focus soundscape silenced.

import 'dart:async';

import 'package:aqademiq/core/theme/app_colors.dart';
import 'package:aqademiq/core/theme/app_theme.dart';
import 'package:aqademiq/data/repositories/ada_repository.dart';
import 'package:aqademiq/features/ada/presentation/ada_screen.dart';
import 'package:aqademiq/services/voice_input_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// Ada's chat, reduced to a record of what was actually sent.
class _RecordingChat extends AdaChatController {
  final sent = <String>[];

  @override
  AdaChatState build() => const AdaChatState();

  @override
  Future<void> send(String text) async => sent.add(text);
}

/// A recognizer the test drives by hand, quirks included.
class _FakeEngine implements SpeechEngine {
  bool initialises = true;
  bool permitted = true;
  bool listenThrows = false;

  /// The platform declines to start and says nothing at all — no status, no
  /// error. Android does this whenever it still thinks it is listening.
  bool refuseToStart = false;

  /// When false the test decides when the platform confirms, via
  /// [becomesReady].
  bool autoReady = true;

  int initCalls = 0;
  int listenCalls = 0;
  int stopCalls = 0;
  int cancelCalls = 0;

  @override
  Duration get warmUp => Duration.zero;

  @override
  Duration get startTimeout => const Duration(milliseconds: 50);

  void Function(String status)? _onStatus;
  void Function(String message)? _onError;
  void Function(String words)? _onWords;

  @override
  Future<bool> initialize({
    required void Function(String status) onStatus,
    required void Function(String message) onError,
  }) async {
    initCalls++;
    _onStatus = onStatus;
    _onError = onError;
    return initialises;
  }

  @override
  Future<bool> hasPermission() async => permitted;

  @override
  Future<void> listen(void Function(String words) onWords) async {
    listenCalls++;
    if (listenThrows) throw StateError('recognizer busy');
    if (refuseToStart) return;
    _onWords = onWords;
    if (autoReady) becomesReady();
  }

  /// The platform confirms it is capturing.
  void becomesReady() => _onStatus?.call('listening');

  @override
  Future<void> stop() async => stopCalls++;

  @override
  Future<void> cancel() async => cancelCalls++;

  /// The recognizer reports the whole utterance so far.
  void hears(String words) => _onWords?.call(words);

  /// The recognizer closes the mic and delivers its last results.
  void finishes() {
    _onStatus?.call('notListening');
    _onStatus?.call('done');
  }

  void fails([String message = 'error_no_match']) => _onError?.call(message);
}

class _FakeHold implements VoiceAudioHold {
  int holds = 0;
  int releases = 0;

  @override
  Future<void> hold() async => holds++;

  @override
  Future<void> release() async => releases++;
}

({ProviderContainer container, _FakeEngine engine, _FakeHold hold}) _setUp() {
  final engine = _FakeEngine();
  final hold = _FakeHold();
  final container = ProviderContainer(
    overrides: [
      speechEngineProvider.overrideWithValue(engine),
      voiceAudioHoldProvider.overrideWithValue(hold),
    ],
  );
  addTearDown(container.dispose);
  return (container: container, engine: engine, hold: hold);
}

/// Pumps the real Ada screen with a hand-driven recognizer and a chat that only
/// records sends.
Future<({_FakeEngine engine, _RecordingChat chat})> _pumpAda(
  WidgetTester tester, {
  bool initialises = true,
  bool permitted = true,
  bool autoReady = true,
}) async {
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final engine = _FakeEngine()
    ..initialises = initialises
    ..permitted = permitted
    ..autoReady = autoReady;
  final container = ProviderContainer(
    overrides: [
      speechEngineProvider.overrideWithValue(engine),
      adaChatProvider.overrideWith(_RecordingChat.new),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: buildAppTheme(
          brightness: Brightness.light,
          accent: AppAccent.violet,
        ),
        // In the app Ada sits inside the tab shell's Scaffold; the TextField
        // needs its Material and the snackbars need somewhere to appear.
        home: const Scaffold(body: AdaScreen()),
      ),
    ),
  );
  await tester.pump();
  return (
    engine: engine,
    chat: container.read(adaChatProvider.notifier) as _RecordingChat,
  );
}

String _adaInput(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField)).controller!.text;

/// Starting is no longer instant — it waits for the platform to confirm, and
/// then for the microphone to warm up — so the clock has to move a little.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 20));
  await tester.pump();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('talking to Ada', () {
    testWidgets(
      'spoken words fill the input, and nothing is sent until send is tapped',
      (
        tester,
      ) async {
        final t = await _pumpAda(tester);

        await tester.tap(find.text('Speak'));
        await _settle(tester);
        expect(find.text('Listening'), findsOneWidget);

        t.engine.hears('plan my week around the chemistry exam');
        await _settle(tester);

        expect(_adaInput(tester), 'plan my week around the chemistry exam');
        expect(
          t.chat.sent,
          isEmpty,
          reason: 'dictation must never send on its own',
        );

        await tester.tap(find.text('↑'));
        await _settle(tester);

        expect(t.chat.sent, ['plan my week around the chemistry exam']);
        expect(_adaInput(tester), isEmpty);
      },
    );

    testWidgets('a result arriving after send does not refill the box', (
      tester,
    ) async {
      // What the student would see without the cancel-before-clear ordering:
      // the message they just sent, back in the input.
      final t = await _pumpAda(tester);
      await tester.tap(find.text('Speak'));
      await _settle(tester);
      t.engine.hears('remind me to revise');
      await _settle(tester);

      await tester.tap(find.text('↑'));
      await _settle(tester);
      t.engine.hears('remind me to revise.');
      await _settle(tester);

      expect(_adaInput(tester), isEmpty);
      expect(
        find.text('Speak'),
        findsOneWidget,
        reason: 'the mic should have closed',
      );
    });

    testWidgets('tapping again stops listening and keeps the words', (
      tester,
    ) async {
      final t = await _pumpAda(tester);
      await tester.tap(find.text('Speak'));
      await _settle(tester);
      t.engine.hears('what is due tomorrow');
      await _settle(tester);

      await tester.tap(find.text('Listening'));
      await _settle(tester);
      t.engine.finishes();
      await _settle(tester);

      expect(t.engine.stopCalls, 1);
      expect(find.text('Speak'), findsOneWidget);
      expect(_adaInput(tester), 'what is due tomorrow');
      expect(t.chat.sent, isEmpty);
    });

    testWidgets(
      'leaving the screen mid-dictation closes the mic without an error',
      (tester) async {
        // Found while testing the send path: ending the session from dispose()
        // changed provider state while the screen was still subscribed to it,
        // and Flutter asserted on rebuilding a torn-down widget. In the app the
        // easy way to hit it is swiping Quick Add away while talking.
        final t = await _pumpAda(tester);
        await tester.tap(find.text('Speak'));
        await _settle(tester);
        t.engine.hears('half a thought');
        await _settle(tester);

        await tester.pumpWidget(const SizedBox());
        await _settle(tester);
        t.engine.hears('half a thought that kept going');
        await _settle(tester);

        expect(tester.takeException(), isNull);
        expect(
          t.engine.cancelCalls,
          1,
          reason: 'the mic must not stay open behind a closed screen',
        );
      },
    );

    testWidgets('the pill says Starting until the mic is really open', (
      tester,
    ) async {
      // The skipped-words bug: Android reports "listening" before the
      // microphone opens, so a pill reading Listening invited the student to
      // talk into a mic that was not capturing yet.
      final t = await _pumpAda(tester, autoReady: false);

      await tester.tap(find.text('Speak'));
      await _settle(tester);
      expect(find.text('Starting'), findsOneWidget);
      expect(find.text('Listening'), findsNothing);

      t.engine.becomesReady();
      await _settle(tester);

      expect(find.text('Listening'), findsOneWidget);
    });

    testWidgets('a refused microphone explains itself and offers Settings', (
      tester,
    ) async {
      await _pumpAda(tester, initialises: false, permitted: false);

      await tester.tap(find.text('Speak'));
      await _settle(tester);

      expect(find.textContaining('Turn it on in Settings'), findsOneWidget);
      expect(find.widgetWithText(SnackBarAction, 'Settings'), findsOneWidget);
      // Still offered, so the student can try again after fixing it.
      expect(find.text('Speak'), findsOneWidget);
    });

    testWidgets(
      'a phone with no recognizer loses the control rather than failing on every tap',
      (
        tester,
      ) async {
        await _pumpAda(tester, initialises: false);

        await tester.tap(find.text('Speak'));
        await _settle(tester);

        expect(find.text('Speak'), findsNothing);
        expect(
          find.textContaining("isn't available on this phone"),
          findsOneWidget,
        );
      },
    );
  });

  group('what the field reads while dictating', () {
    test('an empty field takes the spoken words', () {
      expect(
        composeDictation('', 'remind me about physics'),
        'remind me about physics',
      );
    });

    test('spoken words are added after what was typed, not in place of it', () {
      // Half a question typed, the rest said out loud — both halves survive.
      expect(
        composeDictation('Plan my week', 'around the chemistry exam'),
        'Plan my week around the chemistry exam',
      );
    });

    test('no doubled space when the typed text already ends in one', () {
      expect(
        composeDictation('Plan my week ', 'please'),
        'Plan my week please',
      );
      expect(composeDictation('Line one\n', 'line two'), 'Line one\nline two');
    });

    test('silence leaves the typed text exactly as it was', () {
      expect(composeDictation('Plan my week', ''), 'Plan my week');
      expect(composeDictation('Plan my week', '   '), 'Plan my week');
    });

    test(
      'a field holding only whitespace is replaced rather than prefixed',
      () {
        expect(composeDictation('   ', 'hello'), 'hello');
      },
    );

    test('padding the recognizer adds is trimmed', () {
      expect(composeDictation('', '  hello Ada  '), 'hello Ada');
    });
  });

  group('binding dictation to a field', () {
    test('successive results replace each other rather than piling up', () {
      // Recognizers resend the whole utterance each time. Appending each one
      // would read "I I need I need to".
      final field = TextEditingController(text: 'Hey');
      addTearDown(field.dispose);
      Dictation(field)
        ..begin()
        ..show('I')
        ..show('I need')
        ..show('I need to revise');

      expect(field.text, 'Hey I need to revise');
    });

    test('the cursor sits at the end, ready to keep typing', () {
      final field = TextEditingController();
      addTearDown(field.dispose);
      Dictation(field)
        ..begin()
        ..show('hello');

      expect(field.selection, const TextSelection.collapsed(offset: 5));
    });
  });

  group('the microphone', () {
    final owner = Object();

    test(
      'starting opens it for the screen that asked, and quiets Prism',
      () async {
        final t = _setUp();
        final voice = t.container.read(voiceInputProvider.notifier);

        final problem = await voice.start(owner: owner, onWords: (_) {});

        expect(problem, isNull);
        expect(
          t.container.read(voiceInputProvider).isListeningFor(owner),
          isTrue,
        );
        expect(
          t.hold.holds,
          1,
          reason: 'the soundscape would be picked up by the mic',
        );
      },
    );

    test('words arrive as the whole utterance so far', () async {
      final t = _setUp();
      final heard = <String>[];
      await t.container
          .read(voiceInputProvider.notifier)
          .start(owner: owner, onWords: heard.add);

      t.engine
        ..hears('plan')
        ..hears('plan my week');

      expect(heard, ['plan', 'plan my week']);
    });

    test('stopping keeps the final result that arrives afterwards', () async {
      final t = _setUp();
      final heard = <String>[];
      final voice = t.container.read(voiceInputProvider.notifier);
      await voice.start(owner: owner, onWords: heard.add);

      await voice.stop(owner: owner);
      t.engine
        ..hears('plan my week.')
        ..finishes();

      expect(t.engine.stopCalls, 1);
      expect(heard.last, 'plan my week.');
      expect(t.container.read(voiceInputProvider).listening, isFalse);
    });

    test(
      'once cancelled, nothing more lands — not even a late final result',
      () async {
        // The send race. Send cancels dictation and clears the field in the same
        // frame; if a final result could still arrive, the message the student
        // just sent would reappear in the box.
        final t = _setUp();
        final heard = <String>[];
        final voice = t.container.read(voiceInputProvider.notifier);
        await voice.start(owner: owner, onWords: heard.add);
        t.engine.hears('plan my');

        final cancelling = voice.cancel(owner: owner);
        t.engine.hears('plan my week'); // arrives after the cancel began
        await cancelling;
        t.engine.hears('plan my week.');

        expect(heard, ['plan my']);
        expect(t.container.read(voiceInputProvider).listening, isFalse);
      },
    );

    test('Prism comes back exactly once when the student stops', () async {
      final t = _setUp();
      final voice = t.container.read(voiceInputProvider.notifier);
      await voice.start(owner: owner, onWords: (_) {});

      await voice.stop(owner: owner);
      t.engine.finishes(); // notListening, then done

      expect(t.hold.releases, 1);
    });

    test('an error it cannot recover from ends recording', () async {
      final t = _setUp();
      await t.container
          .read(voiceInputProvider.notifier)
          .start(owner: owner, onWords: (_) {});

      t.engine.fails('error_audio');
      await Future<void>.delayed(voiceRestartGap * 2);

      expect(t.container.read(voiceInputProvider).phase, VoicePhase.idle);
      expect(t.hold.releases, 1);
    });

    test(
      'a recognizer that throws does not leave the mic marked open',
      () async {
        final t = _setUp();
        t.engine.listenThrows = true;

        await t.container
            .read(voiceInputProvider.notifier)
            .start(owner: owner, onWords: (_) {});

        expect(t.container.read(voiceInputProvider).listening, isFalse);
        expect(
          t.hold.releases,
          t.hold.holds,
          reason: 'Prism must not stay silenced',
        );
      },
    );
  });

  group('recording until the student stops', () {
    final owner = Object();

    test('the recognizer stopping on its own does not end recording', () async {
      // Android ends a session about a second after you stop speaking, no
      // matter what timeouts it is given. The session is replaced rather than
      // being treated as the student having finished.
      final t = _setUp();
      await t.container
          .read(voiceInputProvider.notifier)
          .start(owner: owner, onWords: (_) {});

      t.engine.finishes();
      await Future<void>.delayed(voiceRestartGap * 3);

      expect(t.engine.listenCalls, 2);
      expect(
        t.container.read(voiceInputProvider).isListeningFor(owner),
        isTrue,
      );
      expect(
        t.hold.releases,
        0,
        reason: 'Prism stays down for the whole dictation',
      );
    });

    test('words from every session are kept, not just the last', () async {
      // Each session reports only its own utterance. Without stitching, the
      // first half of a long thought disappears when the recognizer cycles.
      final t = _setUp();
      final heard = <String>[];
      await t.container
          .read(voiceInputProvider.notifier)
          .start(owner: owner, onWords: heard.add);

      t.engine.hears('remind me to revise');
      t.engine.finishes();
      await Future<void>.delayed(voiceRestartGap * 3);
      t.engine.hears('chemistry tonight');

      expect(heard.last, 'remind me to revise chemistry tonight');
    });

    test('silence restarts the session instead of ending it', () async {
      final t = _setUp();
      await t.container
          .read(voiceInputProvider.notifier)
          .start(owner: owner, onWords: (_) {});

      t.engine.fails(); // error_no_match: the student simply paused
      await Future<void>.delayed(voiceRestartGap * 3);

      expect(t.engine.listenCalls, 2);
      expect(
        t.container.read(voiceInputProvider).isListeningFor(owner),
        isTrue,
      );
    });

    test(
      'stopping really does stop — no session is started after it',
      () async {
        final t = _setUp();
        final voice = t.container.read(voiceInputProvider.notifier);
        await voice.start(owner: owner, onWords: (_) {});

        await voice.stop(owner: owner);
        t.engine.finishes();
        await Future<void>.delayed(voiceRestartGap * 3);

        expect(t.engine.listenCalls, 1);
        expect(t.container.read(voiceInputProvider).phase, VoicePhase.idle);
      },
    );

    test(
      'a recognizer that keeps refusing gives up instead of looping',
      () async {
        final t = _setUp();
        await t.container
            .read(voiceInputProvider.notifier)
            .start(owner: owner, onWords: (_) {});

        t.engine.refuseToStart = true;
        t.engine.finishes();
        await Future<void>.delayed(const Duration(seconds: 1));

        expect(t.container.read(voiceInputProvider).phase, VoicePhase.idle);
        expect(t.engine.listenCalls, lessThan(6), reason: 'must not spin');
        expect(t.hold.releases, 1, reason: 'Prism must not stay silenced');
      },
    );
  });

  group('a start the platform quietly refuses', () {
    final owner = Object();

    test('is retried once, and reported when it still will not start', () async {
      // The mic button that "sometimes does nothing": listen() reports nothing
      // when the platform declines, so the old code showed Listening over a
      // microphone that was never opened.
      final t = _setUp();
      t.engine.refuseToStart = true;

      final problem = await t.container
          .read(voiceInputProvider.notifier)
          .start(owner: owner, onWords: (_) {});

      expect(problem, VoiceUnavailable.couldNotStart);
      expect(t.engine.listenCalls, 2, reason: 'one retry after clearing it');
      expect(t.container.read(voiceInputProvider).phase, VoicePhase.idle);
      expect(t.hold.releases, t.hold.holds, reason: 'Prism must come back');
    });

    test('recovers silently when the retry works', () async {
      final t = _setUp();
      t.engine.refuseToStart = true;
      final voice = t.container.read(voiceInputProvider.notifier);

      // Clears while the first attempt is timing out, as a closing session does.
      Timer(
        const Duration(milliseconds: 20),
        () => t.engine.refuseToStart = false,
      );
      final problem = await voice.start(owner: owner, onWords: (_) {});

      expect(problem, isNull);
      expect(
        t.container.read(voiceInputProvider).isListeningFor(owner),
        isTrue,
      );
    });

    test('is not announced as listening until the platform confirms', () async {
      // Android claims to be listening the moment it asks the recognizer to
      // start. Announcing that invites the student to talk into a mic that is
      // not open yet, which is where the first words went.
      final t = _setUp();
      t.engine.autoReady = false;
      final voice = t.container.read(voiceInputProvider.notifier);

      final starting = voice.start(owner: owner, onWords: (_) {});
      await Future<void>.delayed(Duration.zero);
      expect(t.container.read(voiceInputProvider).phase, VoicePhase.starting);
      expect(t.container.read(voiceInputProvider).listening, isFalse);

      t.engine.becomesReady();
      await starting;

      expect(t.container.read(voiceInputProvider).listening, isTrue);
    });

    test('stopping while it is still starting gives up cleanly', () async {
      final t = _setUp();
      t.engine.autoReady = false;
      final voice = t.container.read(voiceInputProvider.notifier);
      unawaited(voice.start(owner: owner, onWords: (_) {}));
      await Future<void>.delayed(Duration.zero);

      await voice.stop(owner: owner);

      expect(t.container.read(voiceInputProvider).phase, VoicePhase.idle);
      expect(t.engine.cancelCalls, greaterThanOrEqualTo(1));
      expect(t.hold.releases, t.hold.holds);
    });
  });

  group('when voice cannot start', () {
    final owner = Object();

    test(
      'a refused permission is reported as denied, and nothing is silenced',
      () async {
        final t = _setUp();
        t.engine
          ..initialises = false
          ..permitted = false;

        final problem = await t.container
            .read(voiceInputProvider.notifier)
            .start(owner: owner, onWords: (_) {});

        expect(problem, VoiceUnavailable.denied);
        expect(t.container.read(voiceInputProvider).listening, isFalse);
        expect(t.hold.holds, 0);
      },
    );

    test('a phone with no recognizer is reported as unsupported', () async {
      // Permission granted, yet initialisation failed: there is nothing to
      // talk to. The control hides on this answer, so it must not be confused
      // with a refusal the student could fix in Settings.
      final t = _setUp();
      t.engine.initialises = false;

      final problem = await t.container
          .read(voiceInputProvider.notifier)
          .start(owner: owner, onWords: (_) {});

      expect(problem, VoiceUnavailable.unsupported);
      expect(
        t.container.read(voiceInputProvider).unavailable,
        VoiceUnavailable.unsupported,
      );
    });

    test('granting access in Settings works on the very next tap', () async {
      final t = _setUp();
      final voice = t.container.read(voiceInputProvider.notifier);
      t.engine
        ..initialises = false
        ..permitted = false;
      expect(
        await voice.start(owner: owner, onWords: (_) {}),
        VoiceUnavailable.denied,
      );

      // The student flips the switch in Settings and comes back.
      t.engine
        ..initialises = true
        ..permitted = true;
      final problem = await voice.start(owner: owner, onWords: (_) {});

      expect(problem, isNull);
      expect(
        t.engine.initCalls,
        2,
        reason: 'a failed start must not be remembered',
      );
      expect(t.container.read(voiceInputProvider).unavailable, isNull);
    });
  });

  group('two screens, one microphone', () {
    test('a second screen taking the mic silences the first', () async {
      final t = _setUp();
      final voice = t.container.read(voiceInputProvider.notifier);
      final ada = Object();
      final quickAdd = Object();
      final adaHeard = <String>[];
      final quickAddHeard = <String>[];

      await voice.start(owner: ada, onWords: adaHeard.add);
      t.engine.hears('for Ada');
      await voice.start(owner: quickAdd, onWords: quickAddHeard.add);
      t.engine.hears('buy milk');

      expect(adaHeard, ['for Ada']);
      expect(quickAddHeard, ['buy milk']);
      expect(
        t.container.read(voiceInputProvider).isListeningFor(quickAdd),
        isTrue,
      );
      expect(t.container.read(voiceInputProvider).isListeningFor(ada), isFalse);
    });

    test(
      "one screen closing cannot cut off another screen's dictation",
      () async {
        // The Ada screen being disposed while the Quick Add sheet is dictating
        // must not end the sheet's session.
        final t = _setUp();
        final voice = t.container.read(voiceInputProvider.notifier);
        final ada = Object();
        final quickAdd = Object();
        final heard = <String>[];

        await voice.start(owner: quickAdd, onWords: heard.add);
        await voice.cancel(owner: ada);
        await voice.stop(owner: ada);
        t.engine.hears('buy milk');

        expect(heard, ['buy milk']);
        expect(t.engine.cancelCalls, 0);
        expect(t.engine.stopCalls, 0);
        expect(
          t.container.read(voiceInputProvider).isListeningFor(quickAdd),
          isTrue,
        );
      },
    );
  });
}
