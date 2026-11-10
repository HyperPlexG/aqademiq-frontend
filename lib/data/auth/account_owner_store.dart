import 'package:shared_preferences/shared_preferences.dart';

/// Whose the phone's own state is: the user id that App freeze, the focus
/// setup and the ambient surfaces were last kept for (SharedPreferences
/// `local_state_owner`).
///
/// A sign-out inside the app is seen as it happens. This is for the one that
/// is not: a session that died while the app was closed starts the next run
/// signed out, and whoever signs in next — a guest, another account — must not
/// inherit the last account's frosts. Initialised in `main.dart` so it can be
/// read synchronously the moment the first identity arrives.
class AccountOwnerStore {
  AccountOwnerStore._();

  static final AccountOwnerStore instance = AccountOwnerStore._();

  static const _key = 'local_state_owner';

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// The owner, or null: nobody yet, signed out, or not initialised (tests).
  String? get owner => _prefs?.getString(_key);

  Future<void> setOwner(String? id) async {
    final prefs = _prefs;
    if (prefs == null) return;
    if (id == null) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, id);
    }
  }
}
