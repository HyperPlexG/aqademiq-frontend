// Apple / Google from the Create account screen, as a guest.
//
// That screen says "Everything you've made as a guest comes with you". For an
// SSO upgrade the only way to keep that promise is to LINK the identity to the
// anonymous user (same id, same data). The dangerous path is the fallback: a
// plain signInWithIdToken from a guest replaces the session with another
// account — and with manual linking off in Supabase, a brand-new empty one.
// These tests pin which GoTrue call each situation is allowed to reach.

import 'package:aqademiq/core/error/failure.dart';
import 'package:aqademiq/core/theme/app_colors.dart';
import 'package:aqademiq/core/theme/app_theme.dart';
import 'package:aqademiq/data/auth/auth_repository.dart';
import 'package:aqademiq/data/auth/sso_exchange.dart';
import 'package:aqademiq/features/auth/presentation/signup_screen.dart';
import 'package:aqademiq/features/auth/presentation/widgets/sso_buttons.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeAuth implements IdTokenAuth {
  _FakeAuth({required this.isAnonymous, this.linkError});

  @override
  final bool isAnonymous;

  final AuthException? linkError;
  final calls = <String>[];

  @override
  Future<AuthResponse> link(OAuthProvider provider, String idToken, String? nonce) async {
    calls.add('link:${provider.name}:$idToken:$nonce');
    if (linkError != null) throw linkError!;
    return AuthResponse();
  }

  @override
  Future<AuthResponse> signIn(OAuthProvider provider, String idToken, String? nonce) async {
    calls.add('signIn:${provider.name}:$idToken:$nonce');
    return AuthResponse();
  }
}

const _disabled = AuthException(
  'Manual linking is disabled',
  statusCode: '404',
  code: 'manual_linking_disabled',
);
const _taken = AuthException(
  'Identity is already linked to another user',
  statusCode: '422',
  code: 'identity_already_exists',
);

void main() {
  group('exchangeSsoToken', () {
    test('a guest upgrading is linked, never signed in', () async {
      final auth = _FakeAuth(isAnonymous: true);
      await exchangeSsoToken(
        auth,
        provider: OAuthProvider.google,
        idToken: 'tok',
        nonce: 'raw',
        upgradeGuest: true,
      );
      expect(auth.calls, ['link:google:tok:raw']);
    });

    test('manual linking off: the guest stays a guest, told so, no new account', () async {
      final auth = _FakeAuth(isAnonymous: true, linkError: _disabled);
      await expectLater(
        exchangeSsoToken(
          auth,
          provider: OAuthProvider.apple,
          idToken: 'tok',
          upgradeGuest: true,
        ),
        throwsA(
          isA<AuthFailure>().having((f) => f.message, 'message', ssoLinkFailedMessage(OAuthProvider.apple)),
        ),
      );
      expect(auth.calls, ['link:apple:tok:null'], reason: 'signInWithIdToken would create an empty account');
    });

    test('an identity that already has an account is refused, with the reason', () async {
      final auth = _FakeAuth(isAnonymous: true, linkError: _taken);
      await expectLater(
        exchangeSsoToken(
          auth,
          provider: OAuthProvider.google,
          idToken: 'tok',
          upgradeGuest: true,
        ),
        throwsA(
          isA<AuthFailure>().having(
            (f) => f.message,
            'message',
            ssoIdentityTakenMessage(OAuthProvider.google),
          ),
        ),
      );
      expect(auth.calls.where((c) => c.startsWith('signIn')), isEmpty);
    });

    test('from the sign-in screen a failed link still signs in, as before', () async {
      // Someone on "Sign in" is asking for the account they already have.
      final auth = _FakeAuth(isAnonymous: true, linkError: _taken);
      await exchangeSsoToken(auth, provider: OAuthProvider.google, idToken: 'tok');
      expect(auth.calls, ['link:google:tok:null', 'signIn:google:tok:null']);
    });

    test('someone who is not a guest just signs in (or up)', () async {
      final auth = _FakeAuth(isAnonymous: false);
      await exchangeSsoToken(
        auth,
        provider: OAuthProvider.apple,
        idToken: 'tok',
        nonce: 'n',
        upgradeGuest: true,
      );
      expect(auth.calls, ['signIn:apple:tok:n']);
    });
  });

  group('MockAuthRepository (mock == real)', () {
    test('a guest who picks Google keeps their id and stops being a guest', () async {
      final repo = MockAuthRepository();
      addTearDown(repo.dispose);
      final guest = await repo.signInAnonymously();
      final user = await repo.signInWithGoogle('tok', upgradeGuest: true);
      expect(user.id, guest.id);
      expect(user.isGuest, isFalse);
    });

    test('someone who never chose guest mode lands on the provider account', () async {
      final repo = MockAuthRepository();
      addTearDown(repo.dispose);
      final user = await repo.signInWithApple(identityToken: 'tok');
      expect(user.id, 'user-apple');
    });
  });

  group('Create account screen', () {
    setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    Future<void> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: buildAppTheme(brightness: Brightness.light, accent: AppAccent.violet),
            home: const SignupScreen(),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('iOS offers Apple; Google only with its client ids (7d5244b9)', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await pump(tester);
      expect(find.text('Continue with Apple'), findsOneWidget);
      // Tests run with no dart-defines, so GOOGLE_IOS_CLIENT_ID is missing and
      // the button must not exist — a visible one would wedge the screen.
      expect(ssoGoogleAvailable, isFalse);
      expect(find.text('Continue with Google'), findsNothing);
      expect(find.text('or email'), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('Android never offers Apple, and with no config no divider either', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await pump(tester);
      expect(find.text('Continue with Apple'), findsNothing);
      expect(find.text('Continue with Google'), findsNothing);
      expect(find.text('or email'), findsNothing);
      expect(find.text('Create account →'), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    });
  });
}
