import 'dart:convert';

import 'package:aqademiq/core/utils/mime_type.dart';
import 'package:aqademiq/data/sources/ada_source.dart';
import 'package:flutter_test/flutter_test.dart';

// The TestFlight bug: the iOS picker gives no MIME, so a CV PDF and a PNG
// were uploaded as application/octet-stream and Ada refused both.

const _png = <int>[0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0, 0, 0, 13];
const _jpeg = <int>[0xff, 0xd8, 0xff, 0xe0, 0, 16];
final List<int> _pdf = utf8.encode('%PDF-1.7\n1 0 obj << /Type /Catalog >> endobj');

void main() {
  group('uploadMimeType', () {
    test('the iOS case: no type from the picker, the name decides', () {
      expect(uploadMimeType(name: 'CV.pdf'), 'application/pdf');
      expect(uploadMimeType(name: 'Ada _ intro state.png'), 'image/png');
      expect(uploadMimeType(name: 'photo.JPG'), 'image/jpeg');
      expect(uploadMimeType(name: 'notes.md'), 'text/markdown');
    });

    test('a generic octet-stream gives way to the bytes and the name', () {
      expect(uploadMimeType(name: 'CV.pdf', declared: octetStream), 'application/pdf');
      expect(uploadMimeType(name: 'shot', declared: octetStream, bytes: _png), 'image/png');
    });

    test('the bytes win over a wrong label or a wrong extension', () {
      expect(uploadMimeType(name: 'scan.jpg', declared: 'image/jpeg', bytes: _png), 'image/png');
      expect(uploadMimeType(name: 'document', bytes: _pdf), 'application/pdf');
      expect(uploadMimeType(name: 'x.png', bytes: _jpeg), 'image/jpeg');
    });

    test('a specific declared type is kept (normalised) when the bytes say nothing', () {
      expect(
        uploadMimeType(name: 'a.txt', declared: 'text/plain; charset=utf-8', bytes: utf8.encode('hi')),
        'text/plain',
      );
      expect(uploadMimeType(name: 'a', declared: 'IMAGE/JPG'), 'image/jpeg');
    });

    test('nothing to go on: octet-stream', () {
      expect(uploadMimeType(name: 'mystery'), octetStream);
      expect(uploadMimeType(name: 'trailing.', declared: ''), octetStream);
    });
  });

  test('sniffMime recognises PDF, PNG, JPEG, GIF, WebP and HEIC', () {
    expect(sniffMime(_pdf), 'application/pdf');
    expect(sniffMime(utf8.encode('\r\n%PDF-1.4')), 'application/pdf');
    expect(sniffMime(_png), 'image/png');
    expect(sniffMime(_jpeg), 'image/jpeg');
    expect(sniffMime(utf8.encode('GIF89a..')), 'image/gif');
    expect(sniffMime(utf8.encode('RIFF\x00\x00\x00\x00WEBPVP8 ')), 'image/webp');
    expect(sniffMime(utf8.encode('\x00\x00\x00\x18ftypheic\x00\x00')), 'image/heic');
    expect(sniffMime(utf8.encode('plain text')), isNull);
    expect(sniffMime(const []), isNull);
  });

  test('isGenericMime and mimeFromName', () {
    expect(isGenericMime(null), isTrue);
    expect(isGenericMime('application/octet-stream'), isTrue);
    expect(isGenericMime('application/pdf'), isFalse);
    expect(mimeFromName('Slides.PPTX'), 'application/vnd.openxmlformats-officedocument.presentationml.presentation');
    expect(mimeFromName('README'), isNull);
  });

  test('a staged Ada attachment carries the resolved type, even with none from the picker', () async {
    final ref = await MockAdaSource().upload(name: 'CV.pdf', bytes: _pdf);
    expect(ref.mimeType, 'application/pdf');
  });
}
