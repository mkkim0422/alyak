import 'dart:convert';

import '../../../core/security/secure_storage.dart';

/// "어떤 가족이, 어떤 날짜에, 어떤 영양제를 먹었다고 체크했는지"를
/// 영양제 한국어 이름 리스트로 보관한다.
///
/// 키 포맷: `checkin.<memberId>.<YYYY-MM-DD>` — 자정이 지나면 새 키가
/// 만들어지므로 "오늘 체크" 상태는 자동으로 비워진다.
class CheckinService {
  CheckinService._();

  static String todayKey() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  static Future<List<String>> readToday(String memberId) async {
    final raw = await SecureStorage.read(
      SecureStorage.checkinKey(memberId, todayKey()),
    );
    if (raw == null) return const [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => e.toString()).toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  /// 카드 단위 일괄 체크 / 체크 해제. 기존 리스트에 합집합으로 더한다.
  static Future<List<String>> markChecked(
    String memberId,
    Iterable<String> supplementKoNames,
  ) async {
    final current = await readToday(memberId);
    final merged = {...current, ...supplementKoNames}.toList();
    await SecureStorage.write(
      SecureStorage.checkinKey(memberId, todayKey()),
      jsonEncode(merged),
    );
    return merged;
  }

  static Future<List<String>> clearChecks(
    String memberId,
    Iterable<String> supplementKoNames,
  ) async {
    final current = await readToday(memberId);
    final remove = supplementKoNames.toSet();
    final filtered = current.where((n) => !remove.contains(n)).toList();
    await SecureStorage.write(
      SecureStorage.checkinKey(memberId, todayKey()),
      jsonEncode(filtered),
    );
    return filtered;
  }
}
