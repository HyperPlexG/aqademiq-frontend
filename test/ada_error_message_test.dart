// What Ada says when a turn fails.
//
// It used to say nothing. `send()` caught the failure with `catch (_)`, cleared
// the typing indicator and returned — so the dots stopped, no reply arrived, and
// the message just sat there. That is indistinguishable from Ada ignoring
// someone, and it left them with nothing to act on even when the cause was
// something they could fix in ten seconds.
//
// The distinctions below are the whole point. "Something went wrong" is true of
// every case here and useful in none: being offline, having spent the day's
// allowance, and the pool being busy each call for a different response from the
// user, and only some are worth retrying now. A wrong message is worse than a
// vague one — telling someone to retry when the daily cap is spent sends them
// into a loop that cannot succeed.

import 'package:aqademiq/core/error/failure.dart';
import 'package:aqademiq/data/repositories/ada_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('offline points at the connection, not at Ada', () {
    final msg = adaErrorMessage(const NetworkFailure(message: 'no route'));
    expect(msg.toLowerCase(), contains('connection'));
  });

  test('an expired session tells them to sign in', () {
    final msg = adaErrorMessage(const AuthFailure(message: 'jwt expired'));
    expect(msg.toLowerCase(), contains('sign in'));
  });

  test('the daily cap does NOT invite an immediate retry', () {
    // The failure mode this guards: "try again" on a limit that resets at
    // midnight is advice that cannot work, and the user will follow it.
    final msg = adaErrorMessage(
      const ServerFailure('', statusCode: 429),
    );
    expect(msg.toLowerCase(), isNot(contains('try again')));
    expect(msg.toLowerCase(), anyOf(contains('limit'), contains('tomorrow')));
  });

  test('a busy pool does invite a retry, because waiting works', () {
    final msg = adaErrorMessage(
      const ServerFailure('', statusCode: 503),
    );
    expect(msg.toLowerCase(), contains('try again'));
  });

  test("the server's own message wins when it has one", () {
    // The backend knows what was actually wrong — e.g. "No subject available".
    // A generic client string would throw away the only useful sentence.
    const detail = 'No subject available — create a subject first';
    final msg = adaErrorMessage(
      const ServerFailure(detail, statusCode: 422),
    );
    expect(msg, detail);
  });

  test('an unknown failure still says something actionable', () {
    final msg = adaErrorMessage(Exception('boom'));
    expect(msg, isNotEmpty);
    expect(msg.toLowerCase(), contains('retry'));
  });

  test('every mapped case produces a distinct, non-empty sentence', () {
    final messages = <String>{
      adaErrorMessage(const NetworkFailure()),
      adaErrorMessage(const AuthFailure()),
      adaErrorMessage(const ServerFailure('', statusCode: 429)),
      adaErrorMessage(const ServerFailure('', statusCode: 503)),
      adaErrorMessage(Exception('x')),
    };
    expect(messages.length, 5, reason: 'two cases collapsed onto one message');
    expect(messages.every((m) => m.trim().isNotEmpty), isTrue);
  });
}
