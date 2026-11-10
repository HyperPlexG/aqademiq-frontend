import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/haptics/haptics_service.dart';

/// Aqademiq's numeric App Store id (`apps.apple.com/app/id6792360288`,
/// "Aqademiq: Study Calmly", bundle `com.r13.aqademiq`). Public and stable: it
/// survived the October 2026 team transfer, because an app's Apple ID does.
const String kAppStoreId = '6792360288';

/// The Android `applicationId` (`android/app/build.gradle.kts`).
const String kAndroidPackage = 'com.r13.aqademiq';

/// Where "Rate Aqademiq" sends someone on [platform], in the order to try.
///
///  * iOS / macOS: the App Store's own write-a-review page. An https
///    `apps.apple.com` link opens the App Store app directly.
///  * Android: the Play listing, through the Play Store app (`market://`) and,
///    when that has no handler (no Play Store, some Huawei / Fire devices), the
///    same listing on the web. Play has no deep link straight into the review
///    box; the listing's "Rate this app" is where every app sends people.
///  * Anything else: nowhere — there is no store to send them to.
List<Uri> storeReviewUris(
  TargetPlatform platform, {
  String appStoreId = kAppStoreId,
  String androidPackage = kAndroidPackage,
}) =>
    switch (platform) {
      TargetPlatform.iOS || TargetPlatform.macOS => [
          Uri.parse('https://apps.apple.com/app/id$appStoreId?action=write-review'),
        ],
      TargetPlatform.android => [
          Uri.parse('market://details?id=$androidPackage'),
          Uri.parse('https://play.google.com/store/apps/details?id=$androidPackage'),
        ],
      _ => const [],
    };

/// Opens one URL outside the app; false when nothing could handle it.
typedef StoreOpener = Future<bool> Function(Uri uri);

/// How a store URL is opened. A provider so tests can see what was tried.
final storeOpenerProvider = Provider<StoreOpener>(
  (ref) => (uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Object {
      // A scheme with no handler can throw rather than return false.
      return false;
    }
  },
);

/// "Rate Aqademiq" / "Rate the app": straight to the store's rating page.
///
/// There used to be an in-app five-star sheet here, which only ever wrote to
/// our own database — nobody's rating reached the App Store or Play.
///
/// Deliberately **not** the native in-app review prompt
/// (`SKStoreReviewController` / Play In-App Review). Both are rationed by the
/// OS and are allowed to show nothing at all — always in TestFlight, and after
/// a few prompts a year in production — and both Apple and Google say not to
/// call them from a button for exactly that reason. Someone who taps "Rate"
/// has already decided to; a tap that silently does nothing is the bug this
/// replaces.
///
/// Haptics: the tap is the commitment, so it gets `rateSubmit` (the latch the
/// sheet's Submit had), fired as the store opens rather than after it.
Future<void> rateApp(BuildContext context) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final messenger = ScaffoldMessenger.maybeOf(context);
  final uris = storeReviewUris(defaultTargetPlatform);
  if (kIsWeb || uris.isEmpty) {
    messenger?.showSnackBar(
      const SnackBar(content: Text('Rate Aqademiq from the App Store or Google Play.')),
    );
    return;
  }
  container.read(hapticsProvider).play(HapticMoment.rateSubmit);
  final open = container.read(storeOpenerProvider);
  for (final uri in uris) {
    if (await open(uri)) return;
  }
  messenger?.showSnackBar(
    const SnackBar(content: Text("Couldn't open the store. Please try again.")),
  );
}
