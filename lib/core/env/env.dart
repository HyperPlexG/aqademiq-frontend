/// Compile-time environment configuration, supplied via `--dart-define`.
///
/// This is the single switch (README §7, seam 3) that flips the whole app
/// between mock data sources and the live Aqademiq backend (NestJS on Cloud
/// Run). See `backend_contract/FRONTEND_INTEGRATION_CONTRACT.md` §1.
///
/// Example (live against local dev):
/// ```sh
/// flutter run --dart-define=USE_MOCKS=false \
///   --dart-define=API_BASE_URL=http://localhost:8080/v1 \
///   --dart-define=SOCKET_URL=http://localhost:8080
/// ```
///
/// Example (live against Cloud Run):
/// ```sh
/// flutter run --dart-define=USE_MOCKS=false \
///   --dart-define=API_BASE_URL=https://aqademiq-backend-<num>.europe-west1.run.app/v1 \
///   --dart-define=SOCKET_URL=https://aqademiq-backend-<num>.europe-west1.run.app
/// ```
abstract final class Env {
  /// When `true` (the default) every repository is backed by a `MockXxxSource`
  /// returning delayed fixtures. Flip to `false` to hit the live backend.
  static const bool useMocks =
      bool.fromEnvironment('USE_MOCKS', defaultValue: true);

  /// Base URL of the NestJS REST API (includes the global `/v1` prefix).
  /// Defaults to local dev so flipping [useMocks] off "just works" locally.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080/v1',
  );

  /// Base origin for the Socket.IO connection (the `/me/revisions` namespace is
  /// appended by `RealtimeRepository`). No `/v1` here — Socket.IO mounts at the
  /// server root. Defaults to local dev.
  static const String socketUrl = String.fromEnvironment(
    'SOCKET_URL',
    defaultValue: 'http://localhost:8080',
  );

  /// Whether a non-mock base URL is configured.
  static bool get hasLiveConfig => apiBaseUrl.isNotEmpty;

  /// Supabase project URL — identity (auth) is Supabase Auth. Required live.
  /// e.g. https://qwvuoooentacjslzpbqy.supabase.co
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  /// Supabase anon/publishable key — safe to ship in the client.
  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Whether Supabase Auth is configured (live builds).
  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Google OAuth **iOS** client ID (`…apps.googleusercontent.com`) — used for
  /// native Google sign-in on iOS; its reversed form is the Info.plist URL
  /// scheme. Empty when Google sign-in isn't configured.
  static const String googleIosClientId =
      String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');

  /// Google OAuth **Web** client ID, passed as `serverClientId` so the returned
  /// ID token carries the audience Supabase's Google provider expects.
  static const String googleServerClientId =
      String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');

  /// Whether native Google sign-in is configured (the web/server client ID is
  /// the minimum; iOS additionally needs the iOS client ID + URL scheme).
  static bool get hasGoogleSignIn => googleServerClientId.isNotEmpty;
}
