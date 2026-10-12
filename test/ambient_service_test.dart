import 'package:aqademiq/core/router/app_router.dart';
import 'package:aqademiq/core/router/pending_launch_route.dart';
import 'package:aqademiq/data/models/focus_session.dart';
import 'package:aqademiq/data/repositories/focus_repository.dart';
import 'package:aqademiq/services/ambient/ambient_bridge.dart';
import 'package:aqademiq/services/ambient/ambient_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records what the native half would have been asked to do.
///
/// The channel is stubbed rather than the bridge replaced, so the argument
/// encoding is exercised too — a surface that receives an unencodable payload
/// fails at run time on a device and nowhere else.
class _RecordingChannel {
  final List<String> calls = [];
  final List<Map<Object?, Object?>?> payloads = [];

  /// Just the live-session traffic.
  ///
  /// `publish` writes the glanceable half (next task, the week) whenever its
  /// own providers resolve, which is asynchronous and unrelated to the session.
  /// Counting it against the session's push budget would make these tests fail
  /// on timing rather than on behaviour.
  ///
  /// `ready` is excluded for the same reason it exists: it is the handshake
  /// that tells the native side it may drain parked presses, sent once at
  /// start-up. It redraws nothing, so it is not a push.
  List<String> get sessionCalls =>
      calls.where((c) => c != 'publish' && c != 'ready').toList();

  void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AmbientBridge.channel, (call) async {
      calls.add(call.method);
      payloads.add((call.arguments as Map?)?.cast<Object?, Object?>());
      return null;
    });
  }

  void remove() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AmbientBridge.channel, null);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late _RecordingChannel channel;

  setUp(() {
    channel = _RecordingChannel()..install();
    // Read the provider rather than building the service by hand, so the test
    // exercises the same wiring the app root uses.
    container = ProviderContainer()..read(ambientServiceProvider);
  });

  tearDown(() {
    container.dispose();
    channel.remove();
  });

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  /// A call arriving from the native side — a widget tap or a lock-screen
  /// press — exactly as the platform delivers it.
  Future<void> fromNative(String method, Object? arguments) async {
    const codec = StandardMethodCodec();
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      AmbientBridge.channel.name,
      codec.encodeMethodCall(MethodCall(method, arguments)),
      (_) {},
    );
    await settle();
  }

  test('says nothing at all while no session is running', () async {
    await settle();
    expect(channel.sessionCalls, isEmpty);
  });

  // The cold-launch race. A widget tap arrives before the splash has routed,
  // and the splash's own `go` 1.6s later would land on top of a direct
  // navigation — which is how a Start 5 from the home screen started a session
  // behind a screen the student could not see. Still on the splash, the
  // destination is parked for the splash to honour instead.
  test('a widget route that arrives during the splash is parked, not lost',
      () async {
    await settle();
    await fromNative('route', 'focus');
    expect(container.read(pendingLaunchRouteProvider), Routes.timer);
  });

  // Once, not once per setter. It used to fire from inside each of the two
  // handler setters, so it went out twice — and the first went out with only
  // the action handler installed, which would drop a parked widget route.
  test('announces readiness exactly once, after both handlers are wired',
      () async {
    await settle();
    expect(channel.calls.where((c) => c == 'ready'), hasLength(1));
  });

  test('raises the surfaces once when a session starts', () async {
    final controller = container.read(focusControllerProvider.notifier)
      ..configure(durationMin: 25);
    await controller.start();
    await settle();

    expect(channel.sessionCalls, ['startSession']);
    // By method, not by position: other traffic (the start-up handshake, a
    // publish) can land first, and `.first` silently reads the wrong payload.
    final payload = channel.payloads[channel.calls.indexOf('startSession')]!;
    expect(payload['endsAt'], isA<String>());
    expect(payload['frozen'], isFalse);
    expect(payload['meltStage'], 0);
  });

  test('a freeze is worth a push, and says so', () async {
    final controller = container.read(focusControllerProvider.notifier)
      ..configure(durationMin: 25);
    await controller.start();
    await settle();
    channel.calls.clear();
    channel.payloads.clear();

    controller.pause();
    await settle();

    expect(channel.sessionCalls, ['updateSession']);
    expect(channel.payloads.last!['frozen'], isTrue);
  });

  test('stands down when the session ends — the Island is not ours to hold',
      () async {
    final controller = container.read(focusControllerProvider.notifier)
      ..configure(durationMin: 25);
    await controller.start();
    await settle();
    channel.calls.clear();

    await controller.complete();
    await settle();

    expect(channel.sessionCalls, contains('endSession'));
  });

  test('a second passing is not worth a push', () async {
    final controller = container.read(focusControllerProvider.notifier)
      ..configure(durationMin: 25);
    await controller.start();
    await settle();
    channel.calls.clear();

    // Exactly what the in-app timer does every second: same stage, same task,
    // one more second spent. None of these may reach a surface.
    for (var i = 1; i <= 30; i++) {
      container.read(focusControllerProvider.notifier).state =
          container.read(focusControllerProvider).copyWith(elapsedSec: i);
    }
    await settle();

    expect(channel.sessionCalls, isEmpty);
  });

  test('crossing a melt stage is', () async {
    final controller = container.read(focusControllerProvider.notifier)
      ..configure(durationMin: 25);
    await controller.start();
    await settle();
    channel.calls.clear();

    // 25 min = 1500s, so stage 1 begins at 300s.
    container.read(focusControllerProvider.notifier).state =
        container.read(focusControllerProvider).copyWith(elapsedSec: 301);
    await settle();

    expect(channel.sessionCalls, ['updateSession']);
    expect(channel.payloads.last!['meltStage'], 1);
  });

  test('a whole session spends about five pushes, not fifteen hundred',
      () async {
    final controller = container.read(focusControllerProvider.notifier)
      ..configure(durationMin: 25);
    await controller.start();
    await settle();

    // Every second of a 25-minute session.
    for (var i = 1; i <= 1500; i++) {
      container.read(focusControllerProvider.notifier).state =
          container.read(focusControllerProvider).copyWith(elapsedSec: i);
    }
    await settle();

    // One start plus one per stage boundary crossed. The clock itself is drawn
    // by the OS and costs nothing, which is the entire point.
    //
    // Only the session calls are counted: `publish` writes the glanceable data
    // (next task, the week) on its own schedule and is not part of this budget.
    expect(channel.sessionCalls.length, lessThanOrEqualTo(kMeltStages + 1));
    expect(channel.sessionCalls, contains('startSession'));
  });
}
