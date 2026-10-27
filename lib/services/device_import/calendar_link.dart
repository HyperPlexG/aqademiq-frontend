// Calendar import → "Calendar link" / "Calendar file": the rules that need no
// network, kept apart from ics_fetcher.dart so screens can use them without
// reaching Dio (README seam 1).

/// Large enough for years of a busy calendar; small enough not to stall.
const int maxCalendarBytes = 5 * 1024 * 1024;

/// The link as something fetchable, or null when it is not a web address.
///
/// `webcal://` is just "subscribe to this", served over HTTPS. Plain `http`
/// is upgraded too: both platforms refuse cleartext by default, and calendar
/// hosts serve HTTPS.
Uri? normalizeCalendarLink(String input) {
  var s = input.trim();
  if (s.isEmpty) return null;
  final lower = s.toLowerCase();
  if (lower.startsWith('webcals://')) {
    s = 'https://${s.substring('webcals://'.length)}';
  } else if (lower.startsWith('webcal://')) {
    s = 'https://${s.substring('webcal://'.length)}';
  } else if (lower.startsWith('http://')) {
    s = 'https://${s.substring('http://'.length)}';
  } else if (!lower.startsWith('https://')) {
    if (s.contains('://')) return null;
    s = 'https://$s';
  }
  final uri = Uri.tryParse(s);
  if (uri == null || uri.host.isEmpty || !uri.host.contains('.')) return null;
  return uri;
}
