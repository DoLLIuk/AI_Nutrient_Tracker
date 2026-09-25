import 'package:flutter/foundation.dart' show kIsWeb;

class AppConfig {
  final String apiBaseUrl;
  final String apiKey;

  const AppConfig({required this.apiBaseUrl, required this.apiKey});

  factory AppConfig.fromEnvironment() {
    final config = tryFromEnvironment();
    if (config != null) return config;
    throw StateError(
      kIsWeb
          ? 'Missing DEMO_API_BASE_URL for the web demo.'
          : 'Missing dart-define values. Pass API_BASE_URL and API_KEY.',
    );
  }

  static AppConfig? tryFromEnvironment() {
    // The mobile key protects diagnostic endpoints too and must never enter a
    // public web bundle. Web builds use a separately rate-limited demo gateway.
    if (kIsWeb) {
      const demoBaseUrl = String.fromEnvironment('DEMO_API_BASE_URL');
      return demoBaseUrl.isEmpty
          ? null
          : const AppConfig(apiBaseUrl: demoBaseUrl, apiKey: '');
    }
    const baseUrl = String.fromEnvironment('API_BASE_URL');
    const key = String.fromEnvironment('API_KEY');
    if (baseUrl.isEmpty || key.isEmpty) {
      return null;
    }
    return const AppConfig(apiBaseUrl: baseUrl, apiKey: key);
  }
}
