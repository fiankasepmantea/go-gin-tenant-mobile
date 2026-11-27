/// Build-time configuration. Values come from `--dart-define` (see README.md); nothing secret belongs here.
class AppConfig {
  const AppConfig({required this.apiBaseUrl, this.appName = 'Tenant Console'});

  /// Origin of the API without a trailing slash, for example `https://api.example.com`.
  final String apiBaseUrl;
  final String appName;

  static const String _origin = String.fromEnvironment(
    'API_BASE_URL',
    // 10.0.2.2 is the host machine as seen from the Android emulator.
    defaultValue: 'http://10.0.2.2:8080',
  );

  factory AppConfig.fromEnvironment() => AppConfig(apiBaseUrl: normalizeOrigin(_origin));

  /// Base URL of the versioned API.
  String get apiUrl => '$apiBaseUrl/api/v1';

  /// Turns a path from an API answer (`/api/v1/public/...`) into an absolute URL. Absolute URLs stay as they are.
  String resolve(String pathOrUrl) {
    final value = pathOrUrl.trim();
    if (value.startsWith('http://') || value.startsWith('https://')) return value;
    return '$apiBaseUrl${value.startsWith('/') ? '' : '/'}$value';
  }

  /// `" https://api.example.com// "` becomes `https://api.example.com`.
  static String normalizeOrigin(String raw) {
    var value = raw.trim();
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    return value;
  }
}
