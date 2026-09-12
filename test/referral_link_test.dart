// Reading a referral code out of a link someone else sent you.
//
// This is the only place in the app where a stranger's input reaches a form
// field, so the interesting tests are the ones about what it REFUSES. The
// permissive cases are easy and would pass under almost any implementation;
// the strict ones are what stop a hostile link doing something the sender
// intended and the recipient did not.
//
// What is deliberately NOT defended against: a link that carries a real,
// working code belonging to a stranger. That is indistinguishable from a
// legitimate referral, because it *is* one — the sender wants credit. It stays
// safe because a link only ever prefills a visible field, and because the
// server still refuses self-referral and allows one redemption per person
// forever.

import 'package:aqademiq/core/utils/referral_link.dart';
import 'package:flutter_test/flutter_test.dart';

const _code = 'A1B2C3D4';

String? from(String url) => referralCodeFrom(Uri.tryParse(url));

void main() {
  group('the link we share', () {
    test('carries the code and is a real web URL', () {
      // It has to survive being pasted into a chat app as a clickable link,
      // which is the whole reason the shared form is https and not the custom
      // scheme.
      final link = referralLink(_code);
      expect(link, 'https://www.aqademiq.com/join?ref=$_code');
      expect(Uri.parse(link).scheme, 'https');
    });

    test('round-trips: what we build is what we read back', () {
      expect(from(referralLink(_code)), _code);
    });

    test('falls back to the bare site when there is no code', () {
      // A share with an empty ?ref= looks broken and attributes nothing.
      expect(referralLink(''), 'https://www.aqademiq.com');
      expect(referralLink('   '), 'https://www.aqademiq.com');
    });

    test('never emits a malformed code into a link', () {
      // Guards the share path against a corrupted or truncated code from the
      // API — better a plain site link than one that always fails to redeem.
      expect(referralLink('SHORT'), 'https://www.aqademiq.com');
      expect(referralLink('NOTHEXXX'), 'https://www.aqademiq.com');
    });
  });

  group('links we accept', () {
    test('the shared https form', () {
      expect(from('https://www.aqademiq.com/join?ref=$_code'), _code);
    });

    test('the apex domain, which is what people actually type', () {
      expect(from('https://aqademiq.com/join?ref=$_code'), _code);
    });

    test('the custom scheme, where "join" lands in the host', () {
      // aqademiq://join?ref=X has an empty path — "join" is parsed as the host.
      // The parser has to look in both places or the scheme that needs nothing
      // hosted is the one that never works.
      expect(from('aqademiq://join?ref=$_code'), _code);
    });

    test('lowercase and spaced codes, because people retype them', () {
      expect(from('https://www.aqademiq.com/join?ref=a1b2c3d4'), _code);
      expect(from('aqademiq://join?ref=A1B2%20C3D4'), _code);
    });

    test('extra query parameters, which every link tracker adds', () {
      expect(
        from('https://www.aqademiq.com/join?utm_source=x&ref=$_code&utm_medium=y'),
        _code,
      );
    });
  });

  group('links we refuse', () {
    test('a lookalike host does not match', () {
      // The one that a suffix check would let through. Both of these end in or
      // contain "aqademiq.com" and neither is us.
      expect(from('https://evil-aqademiq.com/join?ref=$_code'), isNull);
      expect(from('https://aqademiq.com.attacker.net/join?ref=$_code'), isNull);
      expect(from('https://notaqademiq.com/join?ref=$_code'), isNull);
    });

    test('a subdomain we do not publish does not match', () {
      expect(from('https://blog.aqademiq.com/join?ref=$_code'), isNull);
    });

    test('another path on our own domain does not match', () {
      // Our marketing site owns the rest of the domain; only /join is ours.
      expect(from('https://www.aqademiq.com/?ref=$_code'), isNull);
      expect(from('https://www.aqademiq.com/privacy?ref=$_code'), isNull);
    });

    test('a different app scheme does not match', () {
      expect(from('otherapp://join?ref=$_code'), isNull);
      // The Google sign-in scheme already registered on iOS must not be read
      // as a referral.
      expect(from('com.googleusercontent.apps.123://join?ref=$_code'), isNull);
    });

    test('a missing or empty parameter yields nothing', () {
      expect(from('https://www.aqademiq.com/join'), isNull);
      expect(from('https://www.aqademiq.com/join?ref='), isNull);
      expect(from('https://www.aqademiq.com/join?code=$_code'), isNull);
    });

    test('anything that is not exactly a code shape is rejected', () {
      // The point of the strictness: a link cannot put arbitrary text into the
      // onboarding field, so there is nothing to inject and nothing to render.
      for (final bad in [
        'SHORT',
        'WAYTOOLONGCODE',
        'A1B2C3DZ', // Z is not hex
        '<script>',
        "'; drop table--",
        'A1B2-C3D4',
        '../../etc',
      ]) {
        expect(
          from('https://www.aqademiq.com/join?ref=${Uri.encodeQueryComponent(bad)}'),
          isNull,
          reason: 'accepted "$bad"',
        );
      }
    });

    test('a null or unparseable URI is not an error', () {
      // getInitialLink returns null when the app was not opened by a link, on
      // every cold start that is not a referral — by far the common case.
      expect(referralCodeFrom(null), isNull);
      expect(from('not a uri at all'), isNull);
      expect(from(''), isNull);
    });
  });
}
