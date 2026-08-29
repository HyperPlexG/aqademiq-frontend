import 'package:aqademiq/data/models/focus_session.dart';
import 'package:aqademiq/data/repositories/focus_repository.dart';
import 'package:aqademiq/services/ambient/ambient_bridge.dart';
import 'package:aqademiq/services/ambient/ambient_service.dart';
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

  test('says nothing at all while no session is running', () async {
    await settle();
    expect(channel.calls, isEmpty);
  });

  test('raises the surfaces once when a session starts', () async {
    final controller = container.read(focusControllerProvider.notifier)
      ..configure(durationMin: 25);
    await controller.start();
    await settle();

    expect(channel.calls, ['startSession']);
    final payload = channel.payloads.single!;
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

    expect(channel.calls, ['updateSession']);
    expect(channel.payloads.single!['frozen'], isTrue);
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

    expect(channel.calls, contains('endSession'));
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

    expect(channel.calls, isEmpty);
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

    expect(channel.calls, ['updateSession']);
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
    expect(channel.calls.length, lessThanOrEqualTo(kMeltStages + 1));
    expect(channel.calls.first, 'startSession');
  });
}
