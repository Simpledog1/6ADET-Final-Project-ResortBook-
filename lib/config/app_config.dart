/// Build-time configuration. The one place the PocketBase address is set.
///
/// Development (default): the local PocketBase at http://127.0.0.1:8090.
/// Production: pass the public PocketBase URL when building, e.g.
///
///     flutter build web --release --dart-define=POCKETBASE_URL=https://pb.example.com
///
/// The URL is not a secret (it is visible in any web build); the PocketBase
/// API rules and the login are what protect the data.
class AppConfig {
  AppConfig._();

  static const String pocketBaseUrl = String.fromEnvironment(
    'POCKETBASE_URL',
    defaultValue: 'http://127.0.0.1:8090',
  );
}
