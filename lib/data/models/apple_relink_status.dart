/// What the server did when asked to re-link this account's Apple sign-in
/// (`POST /v1/me/apple-relink`). See [AppleRelinkSource].
enum AppleRelinkStatus {
  /// Moved to the id Apple issues now.
  linked,

  /// It was already on it.
  already,

  /// The new id already has an account of its own. Nothing was taken over;
  /// the server recorded it to be merged by hand.
  conflict,

  /// This account does not sign in with Apple.
  noAppleIdentity;

  /// Anything unrecognised reads as "nothing to do", never as success.
  static AppleRelinkStatus parse(Object? raw) => switch (raw) {
        'linked' => linked,
        'already' => already,
        'conflict' => conflict,
        _ => noAppleIdentity,
      };
}
