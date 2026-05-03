import '../../../core/security/secure_storage.dart';

/// 제품 별 "복용 시작 날짜" 저장.
///
/// Pivot 후 일일 체크인 (먹었어요) 트래킹은 제거되고, 이제 이 서비스는
/// **재구매 알림 계산** 의 anchor 로만 쓰인다:
///   started_date + (package_size / daily_dose - reminderDaysBefore) 가
///   `NotificationService.scheduleReorderReminder` 의 트리거 시점.
///
/// 키 포맷: `started.<memberId>.<productId>` = ISO8601 (yyyy-MM-dd).
class CheckinService {
  CheckinService._();

  static String _key(String memberId, String productId) =>
      'started.$memberId.$productId';

  static String _todayIso() {
    final n = DateTime.now();
    return '${n.year.toString().padLeft(4, '0')}-'
        '${n.month.toString().padLeft(2, '0')}-'
        '${n.day.toString().padLeft(2, '0')}';
  }

  /// 제품 복용 시작일 기록. 이미 기록돼 있으면 그대로 유지 (덮어쓰기 안 함) —
  /// 재구매 알림 시점이 매번 리셋되는 걸 막는다. 사용자가 명시적으로 재시작하면
  /// [resetStarted] 사용.
  static Future<void> markStarted(String memberId, String productId) async {
    final existing = await SecureStorage.read(_key(memberId, productId));
    if (existing != null && existing.isNotEmpty) return;
    await SecureStorage.write(_key(memberId, productId), _todayIso());
  }

  /// 시작일을 명시적으로 갱신. 새 통을 개봉했을 때 사용.
  static Future<void> resetStarted(String memberId, String productId) async {
    await SecureStorage.write(_key(memberId, productId), _todayIso());
  }

  /// 시작일 조회. 없으면 null.
  static Future<DateTime?> readStarted(
    String memberId,
    String productId,
  ) async {
    final raw = await SecureStorage.read(_key(memberId, productId));
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  /// 제품 등록 해제 시 anchor 정리. 재구매 알림 cancel 과 짝.
  static Future<void> clearStarted(String memberId, String productId) async {
    await SecureStorage.delete(_key(memberId, productId));
  }
}
