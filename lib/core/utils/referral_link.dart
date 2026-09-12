/// Building and reading the referral link.
///
/// The share sheet used to send the code as bare text next to the marketing
/// URL, so the only way to use a referral was to install the app, reach
/// onboarding step 2, and hand-type eight hex characters. Thirty-one codes had
/// been issued and not one had ever been redeemed.
///
/// Two link shapes are accepted, and both matter:
///
///  * `https://www.aqademiq.com/join?ref=CODE` — what gets shared. It is a real
///    web link, so it works in every chat app and does something sensible when
///    the app is not installed. It opens the app directly **only once
///    `.well-known/assetlinks.json` (Android) and `apple-app-site-association`
///    (iOS) are hosted on the domain** — until then it opens the site, which is
///    no worse than the bare URL it replaces.
///  * `aqademiq://join?ref=CODE` — the custom scheme, which needs nothing
///    hosted and works the moment the app is installed. It is not clickable in
///    most chat clients, which is exactly why it is not the one we share.
///
/// ## Why a link is only ever allowed to *prefill*
///
/// A deep link is attacker-controlled input: anyone can send anyone a URL. The
/// worst realistic outcome here is attribution theft — a victim being credited
/// to a stranger — which is also precisely what a legitimate referral link
/// does, so it cannot be distinguished by intent. What makes it safe is that a
/// link never *acts*:
///
///  * it fills the field and nothing else, so the code is on screen and can be
///    cleared before it is submitted;
///  * it never overwrites something already typed;
///  * [referralCodeFrom] returns null unless the value is exactly the shape a
///    real code has, so a link cannot stuff arbitrary text into the input.
///
/// The server still holds the real guarantees regardless of any of this: the
/// code must exist and be active, self-referral is refused, and
/// `referral_redemptions.referred_user_id` is unique, so one person can be
/// attributed exactly once.
library;

/// Host the shared link points at.
const String kReferralHost = 'www.aqademiq.com';

/// Custom scheme, registered on both platforms. Needs nothing server-side.
const String kReferralScheme = 'aqademiq';

/// The path a referral link lands on, for both shapes.
const String kReferralPath = 'join';

/// Query parameter carrying the code.
const String kReferralParam = 'ref';

/// Codes are exactly 8 uppercase hex characters (`randomBytes(4).hex`), which
/// is also what the onboarding field renders boxes for. Anything else is not a
/// code, and the strictness is the point: this pattern is the whole reason a
/// hostile link cannot put arbitrary text into the input.
final RegExp _codePattern = RegExp(r'^[0-9A-F]{8}$');

/// The link to share for [code].
///
/// Returns the bare site URL when there is no code — a share with an empty
/// `?ref=` looks broken and attributes nothing anyway.
String referralLink(String code) {
  final clean = _normalize(code);
  if (!_codePattern.hasMatch(clean)) return 'https://$kReferralHost';
  return 'https://$kReferralHost/$kReferralPath?$kReferralParam=$clean';
}

/// The referral code carried by [uri], or null if it carries none.
///
/// Deliberately strict. It accepts only the two shapes this app publishes, and
/// only a value that already looks exactly like a real code — an unknown host,
/// an unknown path, a missing parameter or a malformed code all return null
/// rather than something the caller has to re-check.
String? referralCodeFrom(Uri? uri) {
  if (uri == null) return null;

  final scheme = uri.scheme.toLowerCase();
  final isCustom = scheme == kReferralScheme;
  final isWeb = (scheme == 'https' || scheme == 'http') &&
      _hostMatches(uri.host.toLowerCase());
  if (!isCustom && !isWeb) return null;

  // `aqademiq://join?ref=X` puts "join" in the host, not the path.
  final segments = [
    if (isCustom && uri.host.isNotEmpty) uri.host.toLowerCase(),
    ...uri.pathSegments.map((s) => s.toLowerCase()),
  ].where((s) => s.isNotEmpty).toList();
  if (!segments.contains(kReferralPath)) return null;

  final raw = uri.queryParameters[kReferralParam];
  if (raw == null) return null;

  final clean = _normalize(raw);
  return _codePattern.hasMatch(clean) ? clean : null;
}

/// `aqademiq.com` and `www.aqademiq.com`, and nothing that merely ends with it —
/// `evil-aqademiq.com` and `aqademiq.com.attacker.net` must not match.
bool _hostMatches(String host) =>
    host == kReferralHost || host == 'aqademiq.com';

String _normalize(String raw) => raw.replaceAll(RegExp(r'\s+'), '').toUpperCase();
