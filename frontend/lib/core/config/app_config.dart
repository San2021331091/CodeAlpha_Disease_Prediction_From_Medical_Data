import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  final String apiBaseUrl;
  final Duration timeout;
  const AppConfig({required this.apiBaseUrl, required this.timeout});

  factory AppConfig.load() {
    const buildUrl = String.fromEnvironment('API_BASE_URL');
    final file = dotenv.isInitialized ? dotenv.env : <String, String>{};
    final url = buildUrl.isNotEmpty
        ? buildUrl
        : file['API_BASE_URL']!;
    final error = validateOrigin(url);
    if (error != null) throw FormatException(error);
    final seconds = int.tryParse(file['API_TIMEOUT_SECONDS'] ?? '25');
    if (seconds == null || seconds < 1 || seconds > 120) {
      throw const FormatException(
        'API_TIMEOUT_SECONDS must be between 1 and 120.',
      );
    }
    return AppConfig(
      apiBaseUrl: url.replaceFirst(RegExp(r'/$'), ''),
      timeout: Duration(seconds: seconds),
    );
  }

  static String? validateOrigin(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.userInfo.isNotEmpty ||
        (uri.path.isNotEmpty && uri.path != '/')) {
      return 'Enter a server origin';
    }
    return null;
  }
}
