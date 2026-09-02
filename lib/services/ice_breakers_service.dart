import 'package:shared_preferences/shared_preferences.dart';

/// Which Ice Breakers the student has already watched.
///
/// | Key                     | Meaning                       | Default |
/// |-------------------------|-------------------------------|---------|
/// | `ice_breakers_watched`  | Ids already watched, as a list| empty   |
///
/// Local on purpose, and not only because it is small. The card is the one
/// thing on the profile a **guest** must see in full — a guest is precisely the
/// person who needs it — and a guest has no server profile to sync against.
/// There is also nowhere on the server to put it today: `/v1/me/settings` and
/// `/v1/profile` are strictly-typed allowlists with no JSON column, so an
/// unknown key is dropped by the DTO validator before it reaches the service.
/// Syncing would mean a migration; it can be added later without the UI
/// noticing, because everything reads through this one object.
///
/// Same shape as `services/haptic_settings_service.dart`: sync getters with a
/// default so a screen can read them during `build`, futures for the writes.
class IceBreakersService {
  IceBreakersService._();

  static final IceBreakersService instance = IceBreakersService._();

  static const _kWatched = 'ice_breakers_watched';

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Ids already watched. Order is not meaningful — the shelf orders by the
  /// curriculum, not by when something happened to be watched.
  Set<String> get watched =>
      (_prefs?.getStringList(_kWatched) ?? const <String>[]).toSet();

  bool isWatched(String id) => watched.contains(id);

  /// Marked once the student has actually seen it through, never on open —
  /// see `IceBreakerScreen`, which waits for the end of playback.
  Future<void> markWatched(String id) async {
    final next = watched..add(id);
    await _prefs?.setStringList(_kWatched, next.toList());
  }

  /// Only for tests and a debug reset; nothing in the UI clears this.
  Future<void> clear() async => _prefs?.remove(_kWatched);
}
