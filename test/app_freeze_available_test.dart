import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aqademiq/features/freeze/data/app_freeze_channel.dart';
import 'package:aqademiq/features/freeze/providers/freeze_controller.dart';

// App freeze hides its doors (the onboarding steps, the timer's pill, the
// Settings row) on a phone that can't run it — an iOS build without Apple's
// Family Controls approval reports `supported: false`.
void main() {
  Future<bool> availableWith(FreezeAccess access) async {
    final container = ProviderContainer(
      overrides: [freezeAccessProvider.overrideWith((ref) async => access)],
    );
    addTearDown(container.dispose);
    await container.read(freezeAccessProvider.future);
    return container.read(appFreezeAvailableProvider);
  }

  test('a phone that supports App freeze shows it', () async {
    expect(await availableWith(const FreezeAccess(supported: true)), isTrue);
  });

  test('a build without the entitlement hides it', () async {
    expect(await availableWith(FreezeAccess.unsupported), isFalse);
  });

  test('while loading, Android shows it and iOS does not', () {
    for (final (platform, expected) in [(TargetPlatform.android, true), (TargetPlatform.iOS, false)]) {
      debugDefaultTargetPlatformOverride = platform;
      final container = ProviderContainer(
        overrides: [freezeAccessProvider.overrideWith((ref) => Future.any([]))],
      );
      expect(container.read(appFreezeAvailableProvider), expected, reason: '$platform');
      container.dispose();
    }
    debugDefaultTargetPlatformOverride = null;
  });
}
