import 'package:cellscope/core/config/app_config.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(dotenv.clean);
  test('client loads public dotenv values and timeout', () {
    dotenv.loadFromString(
      envString: 'API_BASE_URL=http://localhost:8089\nAPI_TIMEOUT_SECONDS=18',
    );
    final config = AppConfig.load();
    expect(config.apiBaseUrl, 'http://localhost:8089');
    expect(config.timeout, const Duration(seconds: 18));
  });
  test('origin validation rejects paths, credentials, and non-HTTP URLs', () {
    for (final url in [
      'file:///tmp/backend',
      'http://user:pass@localhost:8080',
      'http://localhost:8080/api',
      'http://localhost:8080?q=x',
    ]) {
      expect(AppConfig.validateOrigin(url), isNotNull);
    }
    expect(AppConfig.validateOrigin('https://example.com'), isNull);
  });
}
