import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/error/failure.dart';

/// Shown when a guest tries to upgrade with an Apple ID or Google account that
/// already has an Aqademiq account of its own. Supabase cannot merge two
/// accounts, so the guest's work cannot move into that one.
String ssoIdentityTakenMessage(OAuthProvider provider) =>
    'That ${_providerName(provider)} account already has an Aqademiq account, '
    "so what you made as a guest can't move into it. Sign in to use that "
    'account, or create one with your email here.';

/// Shown when a guest's Apple or Google identity could not be linked for any
/// other reason — most likely manual linking being off in Supabase. The guest
/// is still signed in as the guest; nothing was lost.
String ssoLinkFailedMessage(OAuthProvider provider) =>
    "Couldn't add ${_providerName(provider)} to your guest account, and "
    'nothing you made has moved. Create your account with email instead.';

String _providerName(OAuthProvider provider) =>
    provider == OAuthProvider.apple ? 'Apple' : 'Google';

/// The two GoTrue calls an Apple or Google ID token can be exchanged with.
///
/// An interface so the decision in [exchangeSsoToken] can be tested without a
/// live Supabase client.
abstract interface class IdTokenAuth {
  /// Whether the current session is a guest (a Supabase anonymous user).
  bool get isAnonymous;

  /// `linkIdentityWithIdToken`: attach the identity to the current user, who
  /// keeps their id. Needs **manual linking** enabled in Supabase
  /// (Authentication → Sign In / Providers → "Allow manual linking").
  Future<AuthResponse> link(OAuthProvider provider, String idToken, String? nonce);

  /// `signInWithIdToken`: sign in to the account that owns the identity, or
  /// create one. Replaces the current session.
  Future<AuthResponse> signIn(OAuthProvider provider, String idToken, String? nonce);
}

/// [IdTokenAuth] over the real Supabase client.
class GoTrueIdTokenAuth implements IdTokenAuth {
  const GoTrueIdTokenAuth(this._auth);

  final GoTrueClient _auth;

  @override
  bool get isAnonymous => _auth.currentUser?.isAnonymous ?? false;

  @override
  Future<AuthResponse> link(OAuthProvider provider, String idToken, String? nonce) =>
      _auth.linkIdentityWithIdToken(provider: provider, idToken: idToken, nonce: nonce);

  @override
  Future<AuthResponse> signIn(OAuthProvider provider, String idToken, String? nonce) =>
      _auth.signInWithIdToken(provider: provider, idToken: idToken, nonce: nonce);
}

/// Exchanges an Apple or Google ID token for a session.
///
/// A guest's identity is **linked** to the guest account, which makes it a
/// real account with the same id, so every task and subject they made stays
/// theirs (the email path does the same with `updateUser`; GST-4).
///
/// What happens when linking fails depends on [upgradeGuest]:
///
///  * `false` — the sign-in screen. Someone there is asking for an account
///    they already have, so this falls back to signing in to it, as before.
///  * `true` — the Create account screen, which promises "Everything you've
///    made as a guest comes with you". Falling back there would either open
///    a different account or, with manual linking switched off in Supabase,
///    quietly create a brand-new empty one and abandon the guest's data. So it
///    throws an [AuthFailure] instead and leaves the guest session alone.
///
/// Someone who is not a guest is simply signed in (or signed up) either way.
Future<AuthResponse> exchangeSsoToken(
  IdTokenAuth auth, {
  required OAuthProvider provider,
  required String idToken,
  String? nonce,
  bool upgradeGuest = false,
}) async {
  if (auth.isAnonymous) {
    try {
      return await auth.link(provider, idToken, nonce);
    } on AuthException catch (e) {
      debugPrint('guest link with ${provider.name} not possible: '
          '${e.code ?? '-'} ${e.message}');
      if (upgradeGuest) {
        throw AuthFailure(
          message: _isIdentityTaken(e)
              ? ssoIdentityTakenMessage(provider)
              : ssoLinkFailedMessage(provider),
          cause: e,
        );
      }
    }
  }
  return auth.signIn(provider, idToken, nonce);
}

bool _isIdentityTaken(AuthException e) =>
    e.code == ErrorCode.identityAlreadyExists.code ||
    e.message.toLowerCase().contains('already linked') ||
    e.message.toLowerCase().contains('identity is already');
