import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/referral_link.dart';

/// Incoming links, and the referral code one may carry.
///
/// `app_links` is already in the tree — `supabase_flutter` uses it for OAuth
/// callbacks — so this adds a listener rather than a dependency. Both can
/// observe the same platform stream; nothing here consumes or swallows a link,
/// so the Supabase auth callback is unaffected.
///
/// The service only ever *remembers* a code. It does not navigate, does not
/// call the API, and does not redeem anything — see `referral_link.dart` for
/// why a link is never allowed to act on its own.
class DeepLinkService {
  DeepLinkService({AppLinks? links}) : _links = links ?? AppLinks();

  final AppLinks _links;
  StreamSubscription<Uri>? _sub;

  /// The most recent referral code seen, or null. Read once by the onboarding
  /// referral step; a link that arrives afterwards is harmless because
  /// attribution only ever happens at `POST /onboarding/complete`.
  String? pendingReferralCode;

  /// Starts listening, and picks up the link that launched the app.
  ///
  /// Best-effort throughout: a platform channel that is unavailable (an old
  /// OS, a test harness, a desktop build) must not stop the app from starting.
  /// A referral is an optional nicety; losing one is a worse outcome than a
  /// crash only if you have never seen a crash.
  Future<void> start() async {
    try {
      // The cold-start case: the app was launched *by* the link, so there is no
      // stream event to wait for.
      _absorb(await _links.getInitialLink());
    } on Object catch (e) {
      debugPrint('[deeplink] initial link unavailable: $e');
    }
    try {
      _sub ??= _links.uriLinkStream.listen(
        _absorb,
        onError: (Object e) => debugPrint('[deeplink] stream error: $e'),
      );
    } on Object catch (e) {
      debugPrint('[deeplink] stream unavailable: $e');
    }
  }

  void _absorb(Uri? uri) {
    final code = referralCodeFrom(uri);
    if (code == null) return;
    // First one wins. A second link cannot silently replace a code the student
    // has already been shown.
    pendingReferralCode ??= code;
  }

  /// Hands the code over exactly once, so a student who clears the prefilled
  /// field does not get it put back the next time the step rebuilds.
  String? takeReferralCode() {
    final code = pendingReferralCode;
    pendingReferralCode = null;
    return code;
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
  }
}

final deepLinkServiceProvider = Provider<DeepLinkService>((ref) {
  final service = DeepLinkService();
  ref.onDispose(service.dispose);
  return service;
});
