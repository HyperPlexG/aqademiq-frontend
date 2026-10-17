// GST-4 (16 Oct 2026 test report): a guest could not become a real account
// without losing what they had made. Signing up from guest mode created a
// brand-new account, leaving every task and subject on the old guest id.
//
// The fix upgrades the guest in place — the same id, now with an email — and
// the verify screen needs to know which kind of code it is waiting for, so a
// guest who already set the app up is not sent through onboarding again.
// These run against the mock, which mirrors the live flow (README §7 seam 3).

import 'package:aqademiq/data/auth/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a guest who signs up keeps the same account', () async {
    final repo = MockAuthRepository();
    final guest = await repo.signInAnonymously();

    await repo.signUp(name: 'sam', email: 'sam@example.com', password: 'pw123456');
    expect(repo.isGuestUpgradePending, isTrue);

    await repo.verifyOtp('123456');
    final user = repo.currentUser!;
    expect(user.id, guest.id, reason: 'same id, so their data is still theirs');
    expect(user.isGuest, isFalse);
    expect(user.email, 'sam@example.com');
    expect(repo.isGuestUpgradePending, isFalse);
  });

  test('someone who never chose guest mode signs up as a new account', () async {
    final repo = MockAuthRepository();
    await repo.signUp(name: 'ali', email: 'ali@example.com', password: 'pw123456');
    expect(repo.isGuestUpgradePending, isFalse);

    await repo.verifyOtp('123456');
    expect(repo.currentUser!.isGuest, isFalse);
    expect(repo.currentUser!.email, 'ali@example.com');
  });

  test('an address that already has an account is still refused for a guest', () async {
    final repo = MockAuthRepository();
    await repo.signInAnonymously();
    await expectLater(
      repo.signUp(name: 'x', email: 'taken@example.com', password: 'pw123456'),
      throwsA(anything),
    );
    expect(repo.isGuestUpgradePending, isFalse);
    expect(repo.currentUser!.isGuest, isTrue, reason: 'still the same guest');
  });
}
