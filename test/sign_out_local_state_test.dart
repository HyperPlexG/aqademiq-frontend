// Signing out forgets what the phone kept for that account: the focus setup
// and its linked task, App freeze (with the native side handed an empty
// policy, so no app stays frozen with nobody signed in), and what the widgets
// show. A guest — or another account — after that starts clean.

import 'dart:convert';

import 'package:aqademiq/data/auth/account_owner_store.dart';
import 'package:aqademiq/data/auth/auth_repository.dart';
import 'package:aqademiq/data/auth/session_reset.dart';
import 'package:aqademiq/data/models/task.dart';
import 'package:aqademiq/data/repositories/focus_repository.dart';
import 'package:aqademiq/features/focus/providers/linked_task_provider.dart';
import 'package:aqademiq/features/freeze/data/app_freeze_channel.dart';
import 'package:aqademiq/features/freeze/data/freeze_store.dart';
import 'package:aqademiq/features/freeze/domain/freeze_models.dart';
import 'package:aqademiq/features/freeze/providers/freeze_controller.dart';
import 'package:aqademiq/services/ambient/ambient_bridge.dart';
import 'package:aqademiq/services/ambient/ambient_service.dart';
import 'package:aqademiq/services/haptics/haptics_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The previous account's App freeze, as the TestFlight report saw it.
FreezeData _theirs() {
  final now = DateTime.now();
  return FreezeData(
    setUp: true,
    frosts: const [
      Frost(
        id: 'f-lecture',
        name: 'Lecture hours',
        apps: AppSet(
          packages: ['com.instagram.android'],
          iosSelection: 'sel-f-lecture',
          iosCount: 4,
        ),
      ),
      Frost(
        id: 'f-weekend',
        name: 'Weekend',
        days: {6, 7},
        apps: AppSet(packages: ['com.zhiliaoapp.musically']),
      ),
    ],
    groups: const FreezeGroups(
      alwaysOpen: AppSet(
        packages: ['com.android.dialer'],
        iosSelection: 'sel-always',
        iosCount: 1,
      ),
      neverOpen: AppSet(
        packages: ['com.reddit.frontpage'],
        iosSelection: 'sel-never',
        iosCount: 2,
      ),
    ),
    // "The usual · 3 on ice", and a Freeze now running on it.
    recentApps: const AppSet(
      packages: ['a', 'b', 'c'],
      iosSelection: 'sel-usual',
      iosCount: 3,
    ),
    now: FreezeNow(
      startedAt: now,
      endsAt: now.add(const Duration(hours: 1)),
      apps: const AppSet(
        packages: ['a', 'b', 'c'],
        iosSelection: 'sel-usual',
        iosCount: 3,
      ),
    ),
    standdown: Standdown(
      since: now.subtract(const Duration(days: 1)),
      until: now.subtract(const Duration(hours: 1)),
    ),
    thawLog: [ThawRecord(at: now, minutes: 2, target: '*')],
  );
}

final _linked = Task(
  id: 't-zayaa',
  title: 'Go through Zayaa notes',
  tagId: 'tag-1',
  date: DateTime(2026, 11, 10),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> freezeCalls;
  late List<MethodCall> ambientCalls;

  /// Both channels in the order the calls arrived.
  late List<MethodCall> allCalls;

  setUp(() async {
    freezeCalls = [];
    ambientCalls = [];
    allCalls = [];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          ..setMockMethodCallHandler(
            const MethodChannel(AppFreezeChannel.name),
            (call) async {
              freezeCalls.add(call);
              allCalls.add(call);
              return switch (call.method) {
                'takeEvents' => <Object?>[],
                _ => null,
              };
            },
          )
          ..setMockMethodCallHandler(AmbientBridge.channel, (call) async {
            ambientCalls.add(call);
            allCalls.add(call);
            return null;
          });
    addTearDown(() {
      messenger
        ..setMockMethodCallHandler(
          const MethodChannel(AppFreezeChannel.name),
          null,
        )
        ..setMockMethodCallHandler(AmbientBridge.channel, null);
    });
    SharedPreferences.setMockInitialValues({});
    await FreezeStore.instance.init();
    await AccountOwnerStore.instance.init();
    await FreezeStore.instance.write(_theirs());
  });

  ProviderContainer boot() {
    final container = ProviderContainer(
      overrides: [
        hapticsProvider.overrideWithValue(const NoopHapticsService()),
      ],
    );
    addTearDown(container.dispose);
    container
      ..listen(sessionResetProvider, (_, _) {})
      ..listen(authStateProvider, (_, _) {})
      // Watched at the app root, like the reset itself.
      ..listen(ambientServiceProvider, (_, _) {});
    return container;
  }

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 20));

  Map<String, Object?> lastPolicy() {
    final apply = freezeCalls.lastWhere((c) => c.method == 'applyPolicy');
    return jsonDecode((apply.arguments as Map)['policy'] as String)
        as Map<String, Object?>;
  }

  test(
    'sign-out clears the focus link and App freeze, and releases every shield',
    () async {
      final container = boot();
      final auth = container.read(authRepositoryProvider);
      await auth.signInWithEmail(
        email: 'jev@example.com',
        password: 'secret123',
      );
      await settle();

      // Signed in (a different account from the mock's starting guest, so the
      // phone started clean for them): their focus setup and their frosts.
      await FreezeStore.instance.write(_theirs());
      await container.read(freezeControllerProvider.notifier).reapply();
      container.read(linkedTaskProvider.notifier).set(_linked);
      container
          .read(focusControllerProvider.notifier)
          .configure(durationMin: 50, taskId: _linked.id);
      expect(
        container.read(freezeControllerProvider).frosts.map((f) => f.name),
        ['Lecture hours', 'Weekend'],
      );
      freezeCalls.clear();

      allCalls.clear();
      await auth.signOut();
      await settle();

      expect(container.read(linkedTaskProvider), isNull);
      final focus = container.read(focusControllerProvider);
      expect(focus.taskId, isNull);
      expect(focus.durationMin, 25);

      final freeze = container.read(freezeControllerProvider);
      expect(freeze.frosts, isEmpty);
      expect(freeze.now, isNull);
      expect(freeze.standdown, isNull);
      expect(freeze.recentApps.isEmpty, isTrue);
      expect(
        freeze.groups.alwaysOpen.isEmpty && freeze.groups.neverOpen.isEmpty,
        isTrue,
      );
      expect(freeze.thawLog, isEmpty);
      expect(freeze.setUp, isFalse);
      // On disk too: a relaunch does not bring it back.
      expect(FreezeStore.instance.read().frosts, isEmpty);

      // The native side got the empty policy: nothing for it to freeze.
      final policy = lastPolicy();
      expect(policy['frosts'], isEmpty);
      expect(policy.containsKey('now'), isFalse);
      expect(policy.containsKey('standdown'), isFalse);
      final groups = policy['groups']! as Map;
      for (final g in ['always_open', 'never_open', 'distracting']) {
        expect((groups[g] as Map)['packages'], isEmpty, reason: g);
        expect(
          (groups[g] as Map).containsKey('ios_selection'),
          isFalse,
          reason: g,
        );
      }
      // iOS: the saved picks are dropped, the policy first.
      final deleted = [
        for (final c in freezeCalls)
          if (c.method == 'deleteSelection')
            (c.arguments as Map)['selection_id'],
      ];
      expect(
        deleted,
        containsAll(<String>[
          'sel-f-lecture',
          'sel-usual',
          'sel-always',
          'sel-never',
          'sel-distracting',
          'sel-now',
        ]),
      );
      expect(
        freezeCalls.indexWhere((c) => c.method == 'applyPolicy'),
        lessThan(freezeCalls.indexWhere((c) => c.method == 'deleteSelection')),
      );

      // The widgets were blanked: no next task, no mood week, no minutes.
      // The publish that goes out with the reset (after the picks are
      // dropped, which only the reset does) is blank. Anything later is the
      // next identity's own data loading.
      final resetAt = allCalls.indexWhere((c) => c.method == 'deleteSelection');
      final glance =
          (allCalls
                      .skip(resetAt)
                      .firstWhere((c) => c.method == 'publish')
                      .arguments
                  as Map)
              .cast<String, Object?>();
      expect(glance.containsKey('nextTaskTitle'), isFalse);
      expect(glance['todayFocusMin'], 0);
      expect((glance['weekMoods']! as List).every((m) => m == -1), isTrue);

      // Continuing as a guest: still clean.
      await auth.signInAnonymously();
      await settle();
      expect(container.read(freezeControllerProvider).frosts, isEmpty);
      expect(container.read(linkedTaskProvider), isNull);
    },
  );

  test(
    'signing in as someone else after a sign-out the app never saw starts clean',
    () async {
      // The session died while the app was closed: the phone's state still
      // belongs to the last account when a guest arrives.
      await AccountOwnerStore.instance.setOwner('user-previous');
      final container = boot()..read(freezeControllerProvider);
      await settle(); // the mock guest arrives
      await settle();

      expect(container.read(freezeControllerProvider).frosts, isEmpty);
      expect(lastPolicy()['frosts'], isEmpty);
      expect(AccountOwnerStore.instance.owner, 'guest-local');
    },
  );

  test('the same student coming back keeps their frosts', () async {
    await AccountOwnerStore.instance.setOwner('guest-local');
    final container = boot()..read(freezeControllerProvider);
    await settle();
    await settle();

    expect(container.read(freezeControllerProvider).frosts.map((f) => f.name), [
      'Lecture hours',
      'Weekend',
    ]);
    expect(freezeCalls.where((c) => c.method == 'deleteSelection'), isEmpty);
  });
}
