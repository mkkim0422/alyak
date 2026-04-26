import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Loads runtime configuration from `.env` (bundled as an asset).
/// Never reference these values from a `print` or shipped log line.
class EnvConfig {
  EnvConfig._();

  static Future<void> load() async {
    await dotenv.load(fileName: '.env');
  }

  static String get supabaseUrl => _required('SUPABASE_URL');
  static String get supabaseAnonKey => _required('SUPABASE_ANON_KEY');

  /// `<SUPABASE_URL>/functions/v1/claude-proxy` 형태. 앱은 Anthropic 키를
  /// 직접 갖지 않고 이 엔드포인트만 호출한다. 비어 있으면 ClaudeApi 호출이
  /// 즉시 실패해서 fallback 메시지로 전환된다.
  static String? get claudeProxyUrl => dotenv.maybeGet('CLAUDE_PROXY_URL');

  static String get claudeModel =>
      dotenv.maybeGet('CLAUDE_MODEL') ?? 'claude-sonnet-4-6';

  /// 디바이스 키체인 접근이 실패한 디버그 빌드용 폴백 키. 프로덕션 빌드에선
  /// 사용되지 않으며, 비어 있어도 정상 동작한다.
  static String? get appEncryptionKeyDevFallback =>
      dotenv.maybeGet('APP_ENCRYPTION_KEY');

  /// 호환성 — 디버그 빌드에서만 EncryptionService가 폴백할 때 호출.
  static String get appEncryptionKey {
    final v = appEncryptionKeyDevFallback;
    if (v == null || v.isEmpty) {
      throw StateError(
        'APP_ENCRYPTION_KEY is empty. Only used as a debug fallback when '
        'Keychain access fails. Set it in .env if running tests on a '
        'simulator.',
      );
    }
    return v;
  }

  static String? get googleWebClientId => dotenv.maybeGet('GOOGLE_WEB_CLIENT_ID');
  static String? get googleIosClientId => dotenv.maybeGet('GOOGLE_IOS_CLIENT_ID');

  static String _required(String key) {
    final value = dotenv.maybeGet(key);
    if (value == null || value.isEmpty) {
      throw StateError('Missing env: $key. Check .env / .env.example.');
    }
    return value;
  }
}
