/// The content type a picked file is uploaded as.
///
/// The iOS file picker (`file_selector_ios`) returns a bare path with no MIME,
/// so every upload used to go out as `application/octet-stream` — a CV in PDF,
/// a PNG screenshot — and Ada refused them as "a format I can't read". Android
/// usually reports a type, but not always. So the picker's answer is a hint:
///
///   1. the file's first bytes (`%PDF`, the PNG/JPEG/GIF/WebP signatures) win;
///   2. then a specific declared type;
///   3. then the file name's extension;
///   4. otherwise `application/octet-stream`.
///
/// The backend applies the same rules (`_shared/media.ts`), so files uploaded
/// before this fix are read correctly too.
library;

const String octetStream = 'application/octet-stream';

const Set<String> _generic = {
  '',
  octetStream,
  'binary/octet-stream',
  'application/binary',
  'application/unknown',
  'application/x-unknown',
  'application/x-download',
  'application/force-download',
  'unknown/unknown',
};

const Map<String, String> _aliases = {
  'image/jpg': 'image/jpeg',
  'image/pjpeg': 'image/jpeg',
  'image/x-png': 'image/png',
  'application/x-pdf': 'application/pdf',
  'text/x-markdown': 'text/markdown',
};

const Map<String, String> _byExtension = {
  'pdf': 'application/pdf',
  'png': 'image/png',
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'gif': 'image/gif',
  'webp': 'image/webp',
  'heic': 'image/heic',
  'heif': 'image/heif',
  'txt': 'text/plain',
  'md': 'text/markdown',
  'markdown': 'text/markdown',
  'csv': 'text/csv',
  'doc': 'application/msword',
  'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'ppt': 'application/vnd.ms-powerpoint',
  'pptx': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
};

/// Lower-cased, parameters stripped, aliases folded; null when empty.
String? normalizeMime(String? mime) {
  if (mime == null) return null;
  final m = mime.split(';').first.trim().toLowerCase();
  if (m.isEmpty) return null;
  return _aliases[m] ?? m;
}

/// True when [mime] says nothing about the file (absent or octet-stream).
bool isGenericMime(String? mime) {
  final m = normalizeMime(mime);
  return m == null || _generic.contains(m);
}

/// The type [name]'s extension implies, or null.
String? mimeFromName(String name) {
  final dot = name.lastIndexOf('.');
  if (dot < 0 || dot == name.length - 1) return null;
  return _byExtension[name.substring(dot + 1).trim().toLowerCase()];
}

bool _startsWith(List<int> bytes, List<int> sig, [int offset = 0]) {
  if (bytes.length < offset + sig.length) return false;
  for (var i = 0; i < sig.length; i++) {
    if (bytes[offset + i] != sig[i]) return false;
  }
  return true;
}

/// The type a file's first bytes prove, or null.
String? sniffMime(List<int> bytes) {
  const pdf = [0x25, 0x50, 0x44, 0x46, 0x2d]; // %PDF-
  final head = bytes.length > 1024 ? 1024 : bytes.length;
  for (var i = 0; i + pdf.length <= head; i++) {
    if (_startsWith(bytes, pdf, i)) return 'application/pdf';
  }
  if (_startsWith(bytes, const [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])) return 'image/png';
  if (_startsWith(bytes, const [0xff, 0xd8, 0xff])) return 'image/jpeg';
  if (_startsWith(bytes, 'GIF87a'.codeUnits) || _startsWith(bytes, 'GIF89a'.codeUnits)) return 'image/gif';
  if (_startsWith(bytes, 'RIFF'.codeUnits) && _startsWith(bytes, 'WEBP'.codeUnits, 8)) return 'image/webp';
  if (_startsWith(bytes, 'ftyp'.codeUnits, 4) && bytes.length >= 12) {
    final brand = String.fromCharCodes(bytes.sublist(8, 12));
    if (const {'heic', 'heix', 'hevc', 'hevx', 'heim', 'heis'}.contains(brand)) return 'image/heic';
    if (const {'mif1', 'msf1'}.contains(brand)) return 'image/heif';
  }
  return null;
}

/// The content type to upload a file as. See the library doc for the order.
String uploadMimeType({required String name, String? declared, List<int>? bytes}) {
  final sniffed = bytes == null ? null : sniffMime(bytes);
  if (sniffed != null) return sniffed;
  final d = normalizeMime(declared);
  if (d != null && !_generic.contains(d)) return d;
  return mimeFromName(name) ?? octetStream;
}
