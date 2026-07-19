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
}
