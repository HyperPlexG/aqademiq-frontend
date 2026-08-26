// The Idempotency-Key has to be derived from the request, not from a dice roll.
//
// The backend dedupes mutations by this header. With a fresh random key per
// attempt, a retry of the SAME write arrived under a different key and ran
// again — which is precisely the case the header exists to prevent: a request
// that timed out on the client but succeeded on the server, retried by hand,
// producing a second task.
//
// Two properties are in tension here, and both are tested: identical intent
// within the window must collapse to one key, and genuinely different intent
// must never collide (a collision would silently REPLAY the wrong response and
// lose a write).

import 'package:aqademiq/core/network/auth_interceptor.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

RequestOptions req(
  String method,
  String path, {
  Object? data,
  Map<String, dynamic>? query,
}) =>
    RequestOptions(
      path: path,
      method: method,
      data: data,
      queryParameters: query ?? const {},
    );

final _t0 = DateTime.utc(2026, 8, 26, 10, 30);

void main() {
  test('the same mutation retried immediately produces the same key', () {
    // The double-tap / manual-retry case. Same key → backend replays instead of
    // creating a second task.
    final a = idempotencyKeyFor(
      req('POST', '/tasks', data: {'title': 'Read ch. 4', 'due': '2026-08-27'}),
      at: _t0,
    );
    final b = idempotencyKeyFor(
      req('POST', '/tasks', data: {'title': 'Read ch. 4', 'due': '2026-08-27'}),
      at: _t0.add(const Duration(milliseconds: 900)),
    );
    expect(a, b);
  });

  test('key order in the body does not change the key', () {
    // Dart Maps iterate in insertion order, so an unsorted encode would make two
    // structurally identical bodies hash differently and defeat the whole thing.
    final a = idempotencyKeyFor(
      req('POST', '/tasks', data: {'title': 'Essay', 'subject_id': 's1'}),
      at: _t0,
    );
    final b = idempotencyKeyFor(
      req('POST', '/tasks', data: {'subject_id': 's1', 'title': 'Essay'}),
      at: _t0,
    );
    expect(a, b);
  });

  test('a different body produces a different key', () {
    final a = idempotencyKeyFor(req('POST', '/tasks', data: {'title': 'Essay'}), at: _t0);
    final b = idempotencyKeyFor(req('POST', '/tasks', data: {'title': 'Lab report'}), at: _t0);
    expect(a, isNot(b));
  });

  test('a different path produces a different key', () {
    final a = idempotencyKeyFor(req('POST', '/tasks', data: {'x': 1}), at: _t0);
    final b = idempotencyKeyFor(req('POST', '/focus/sessions', data: {'x': 1}), at: _t0);
    expect(a, isNot(b));
  });

  test('a different method produces a different key', () {
    // DELETE /tasks/1 must never replay the response of PATCH /tasks/1.
    final a = idempotencyKeyFor(req('PATCH', '/tasks/1', data: {'done': true}), at: _t0);
    final b = idempotencyKeyFor(req('DELETE', '/tasks/1', data: {'done': true}), at: _t0);
    expect(a, isNot(b));
  });

  test('query parameters are part of the key, order-independently', () {
    final a = idempotencyKeyFor(req('POST', '/sync', query: {'from': '1', 'to': '2'}), at: _t0);
    final b = idempotencyKeyFor(req('POST', '/sync', query: {'to': '2', 'from': '1'}), at: _t0);
    final c = idempotencyKeyFor(req('POST', '/sync', query: {'from': '9', 'to': '2'}), at: _t0);
    expect(a, b);
    expect(a, isNot(c));
  });

  test('the same mutation repeated after the window is treated as new', () {
    // The other half of the trade: deliberately adding the same focus block
    // twice must create two, so the key cannot be stable forever.
    final a = idempotencyKeyFor(req('POST', '/tasks', data: {'title': 'Revise'}), at: _t0);
    final b = idempotencyKeyFor(
      req('POST', '/tasks', data: {'title': 'Revise'}),
      at: _t0.add(kIdempotencyDedupeWindow * 3),
    );
    expect(a, isNot(b));
  });

  test('a null body is handled without throwing', () {
    // Plenty of mutations carry no body at all (POST /tasks/:id/complete).
    final a = idempotencyKeyFor(req('POST', '/tasks/1/complete'), at: _t0);
    expect(a, isNotEmpty);
    expect(a.length, 32);
  });

  test('a raw string body is hashed as sent', () {
    final a = idempotencyKeyFor(req('POST', '/x', data: '{"a":1}'), at: _t0);
    final b = idempotencyKeyFor(req('POST', '/x', data: '{"a":2}'), at: _t0);
    expect(a, isNot(b));
  });

  test('nested maps are canonicalised too', () {
    final a = idempotencyKeyFor(
      req('POST', '/tasks', data: {
        'title': 'T',
        'meta': {'a': 1, 'b': 2},
      }),
      at: _t0,
    );
    final b = idempotencyKeyFor(
      req('POST', '/tasks', data: {
        'meta': {'b': 2, 'a': 1},
        'title': 'T',
      }),
      at: _t0,
    );
    expect(a, b);
  });

  test('list order is significant, because it is to the server', () {
    // Reordering steps of a breakdown is a real edit, not a duplicate.
    final a = idempotencyKeyFor(req('POST', '/x', data: {'steps': ['a', 'b']}), at: _t0);
    final b = idempotencyKeyFor(req('POST', '/x', data: {'steps': ['b', 'a']}), at: _t0);
    expect(a, isNot(b));
  });
}
