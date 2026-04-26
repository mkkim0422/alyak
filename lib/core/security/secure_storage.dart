import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Wrapper around `flutter_secure_storage` that pins safe defaults
/// (Android EncryptedSharedPreferences, iOS Keychain w/ first-unlock).
///
/// All sensitive data — auth tokens, encryption material refs,
/// onboarding state with health info — must go through here. Never
/// SharedPreferences for these.
class SecureStorage {
  SecureStorage._();

  // flutter_secure_storage 10+ uses Keystore-backed ciphers automatically
  // on Android. iOS uses Keychain w/ first-unlock-this-device, so the
  // value never leaves the device via iCloud Keychain backup.
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  // Keys
  static const kAuthRefreshToken = 'auth.refresh_token';
  static const kAuthAccessToken = 'auth.access_token';
  static const kLastActivityAt = 'session.last_activity_at';
  static const kPrivacyConsentAt = 'privacy.consent_at';
  static const kPrivacyConsentVersion = 'privacy.consent_version';
  static const kUserRole = 'user.role'; // "manager" | "solo"
  static const kOnboardingCompleted = 'onboarding.completed';
  static const kCryptoMasterKey = 'crypto.master_key';
  static const kFamilyDraftsIndex = 'family.drafts.index';
  static String familyDraftKey(String id) => 'family.draft.$id';

  /// 사용자가 홈에서 가족 아바타 순서를 드래그로 바꿨을 때 저장되는 id 배열.
  /// drafts.index 와 동기화되지 않을 수 있어 화면에서 교집합으로 한 번 걸러 사용.
  static const kFamilyOrder = 'family.order';
  static const kNotificationSettings = 'notification.settings';
  static String checkinKey(String memberId, String yyyymmdd) =>
      'checkin.$memberId.$yyyymmdd';
  static String aiCommentKey(String memberId, String yyyymmdd) =>
      'ai_comment.$memberId.$yyyymmdd';

  /// 가장 최근 영양제 주문 시점 (ISO8601 millis). 25일 후 재주문 알림 트리거.
  static String reorderKey(String memberId) => 'reorder.$memberId';

  /// 날씨 캐시 (JSON, 6시간 TTL). [WeatherService] 가 관리.
  static const kWeatherCache = 'weather.cache';

  /// 가족 전체 연속 챙김 일수 캐시. 자세한 갱신 규칙은 [StreakService] 참고.
  static const kStreakCount = 'streak.count';
  static const kStreakLastDate = 'streak.last_date';
  static const kStreakBest = 'streak.best';

  static Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  static Future<String?> read(String key) => _storage.read(key: key);

  static Future<void> delete(String key) => _storage.delete(key: key);

  static Future<bool> contains(String key) => _storage.containsKey(key: key);

  /// Returns every key/value currently in secure storage. Callers must not
  /// log values; intended for prefix-based cleanup (e.g. removing all
  /// historical check-in keys for a deleted family member).
  static Future<Map<String, String>> readAll() => _storage.readAll();

  /// Wipe everything. Used on account deletion / sign-out / 30-day idle.
  static Future<void> wipe() => _storage.deleteAll();
}
