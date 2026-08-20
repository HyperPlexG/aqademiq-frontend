// Signing up with an address that already has an account must SAY so.
//
// Supabase deliberately will not: revealing that an email is taken is a
// user-enumeration hole, so for an existing address `signUp` returns a fake
// success — no session, an empty `identities` list, and no email sent at all.
// The app only checked `session != null`, so it dropped the user on an OTP
// screen awaiting a code that would never arrive, and "Resend" was dead too
// because there was no pending signup to resend.
//
// It matters more than it sounds: 18 of 45 real accounts (40%) exist only via
// Apple or Google. Their owners do not remember signing up, so to them this is a
// brand-new registration that silently goes nowhere.
//
// The sign-in half is the same bug wearing a different mask — Supabase answers
// "Invalid login credentials" whether the password was wrong or the account
// never had a password, which sends those users to reset one that does not
// exist (and password reset is not built).

import 'package:aqademiq/core/error/failure.dart';
import 'package:aqademiq/data/auth/auth_repository.dart';
import 'package:aqademiq/features/auth/controllers/auth_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('signUp with an address that already has an account', () {
    test('fails loudly instead of showing a dead OTP screen', () async {
      final repo = MockAuthRepository();
      await expectLater(
        repo.signUp(name: 'Ridhwan', email: 'taken@example.com', password: 'pw123456'),
        throwsA(isA<AuthFailure>()),
      );
    });

    test('the message points at the social buttons', () async {
      final repo = MockAuthRepository();
      try {
        await repo.signUp(name: 'Ridhwan', email: 'taken@example.com', password: 'pw123456');
        fail('expected an AuthFailure');
      } on AuthFailure catch (e) {
        // Naming the providers is the point: these users do not know they have
        // an account, so "already registered" alone leaves them stuck.
        expect(e.message.toLowerCase(), contains('apple'));
        expect(e.message.toLowerCase(), contains('google'));
      }
    });

    test('a genuinely new address still proceeds to verification', () async {
      final repo = MockAuthRepository();
      final user = await repo.signUp(
        name: 'New Person',
        email: 'brand-new@example.com',
        password: 'pw123456',
      );
      expect(user.email, 'brand-new@example.com');
      expect(repo.pendingEmail, 'brand-new@example.com');
    });

    test('the check is case- and whitespace-insensitive', () async {
      // Emails are matched case-insensitively by the provider, so the guard has
      // to be too or the dead-end returns for "Taken@Example.com".
      final repo = MockAuthRepository();
      await expectLater(
        repo.signUp(name: 'X', email: '  TAKEN@Example.COM  ', password: 'pw123456'),
        throwsA(isA<AuthFailure>()),
      );
    });
  });

  group('authErrorMessage', () {
    test('invalid credentials mentions the social buttons', () {
      final msg = authErrorMessage(const AuthException('Invalid login credentials'));
      expect(msg.toLowerCase(), contains('apple'));
      expect(msg.toLowerCase(), contains('google'));
      expect(
        msg.toLowerCase(),
        isNot(contains('invalid login credentials')),
        reason: 'the raw wording is what sends people to reset a password they never had',
      );
    });

    test('matching is case-insensitive', () {
      expect(
        authErrorMessage(const AuthException('invalid login credentials')).toLowerCase(),
        contains('apple'),
      );
    });

    test('other auth errors are passed through unchanged', () {
      // Only the one ambiguous message is rewritten; rewriting more would hide
      // real errors behind a guess about social sign-in.
      expect(
        authErrorMessage(const AuthException('Email rate limit exceeded')),
        'Email rate limit exceeded',
      );
    });

    test('domain failures and unknowns still work', () {
      expect(authErrorMessage(const AuthFailure(message: 'Nope')), 'Nope');
      expect(authErrorMessage(Object()), 'Something went wrong. Please try again.');
    });
  });
}
