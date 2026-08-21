// Password reset — the escape hatch for accounts with no password.
//
// It matters more than "I forgot my password". 18 of 45 real accounts (40%)
// were created with Apple or Google and have NO email identity, so signing up
// with their own address silently does nothing and signing in answers "invalid
// credentials". Completing a reset sets a password, which CREATES that missing
// identity — this is the only route by which those users ever get an email
// login.
//
// The property under test is the routing decision: a recovery code proves the
// address but finishes nothing, so the verify screen must send the user on to
// set a password rather than into onboarding. Getting that wrong leaves an
// account signed in with no usable password and no way back to this flow.

import 'package:aqademiq/data/auth/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MockAuthRepository repo;

  setUp(() => repo = MockAuthRepository());
  tearDown(() => repo.dispose());

  test('nothing is pending recovery to begin with', () {
    expect(repo.isRecoveryPending, isFalse);
  });

  test('sending a reset marks recovery pending and remembers the address', () async {
    await repo.sendPasswordReset('ridhwan@example.com');
    expect(repo.isRecoveryPending, isTrue);
    // The verify screen shows this address, and verifyOtp needs it.
    expect(repo.pendingEmail, 'ridhwan@example.com');
  });

  test('setting the password ends the recovery', () async {
    // Leaving it pending would send the NEXT signup verification to the
    // password screen instead of onboarding.
    await repo.sendPasswordReset('ridhwan@example.com');
    await repo.setPassword('a-good-password');
    expect(repo.isRecoveryPending, isFalse);
  });

  test('a signup is never mistaken for a recovery', () async {
    // Both flows share the OTP screen, and only this flag separates them.
    await repo.signUp(
      name: 'New Person',
      email: 'brand-new@example.com',
      password: 'pw123456',
    );
    expect(
      repo.isRecoveryPending,
      isFalse,
      reason: 'a signup must still land on onboarding, not the password screen',
    );
  });

  test('reset works for an address that already has an account', () async {
    // The whole point: signUp REFUSES a taken address, while reset must accept
    // it — that is the difference between a dead end and a way in.
    final taken = kMockTakenEmails.first;
    await expectLater(
      repo.signUp(name: 'X', email: taken, password: 'pw123456'),
      throwsA(isA<Object>()),
    );
    await repo.sendPasswordReset(taken);
    expect(repo.isRecoveryPending, isTrue);
  });
}
