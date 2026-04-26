import 'dart:convert';
import 'dart:math' as math;

import '../../core/security/secure_storage.dart';

/// 가족 전체 연속 챙김 일수 (streak) 계산기.
///
/// 정의: 등록된 가족 모든 구성원이 그 날 영양제를 1개 이상 체크한 날만
/// "챙긴 날" 로 카운트. 하루라도 빠진 멤버가 있으면 그 날 streak 는 끊긴다.
///
/// 자정 cron 같은 배경 작업 없이도 동작하도록, [computeAndSave] 가 호출될 때마다
/// 오늘 / 어제 → 더 이상 안 챙긴 날까지 거꾸로 훑어 가며 다시 계산한다.
/// 결과는 `streak.count` / `streak.last_date` / `streak.best` 로 캐시.
class StreakSnapshot {
  const StreakSnapshot({
    required this.count,
    required this.allTodayChecked,
    required this.best,
  });

  /// 연속 일수. 오늘이 모두 체크면 오늘 포함, 아니면 어제까지로 계산된 길이.
  final int count;
  /// 오늘 모든 가족이 1개 이상 체크했는지. 축하 메시지 노출 조건.
  final bool allTodayChecked;
  /// 역대 최고 streak.
  final int best;

  static const empty = StreakSnapshot(
    count: 0,
    allTodayChecked: false,
    best: 0,
  );
}

class StreakService {
  StreakService._();

  /// 외부에서 walk-back 비용을 막기 위한 안전 상한. 1년이면 충분.
  static const int _maxWalkDays = 365;

  static String _dateKey(DateTime d) {
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  /// 특정 날짜에 모든 멤버가 ≥1 개의 영양제를 체크했는지.
  static Future<bool> _allCheckedOn(
    List<String> memberIds,
    DateTime date,
  ) async {
    final dateStr = _dateKey(date);
    for (final id in memberIds) {
      final raw =
          await SecureStorage.read(SecureStorage.checkinKey(id, dateStr));
      if (raw == null) return false;
      try {
        final list = jsonDecode(raw) as List;
        if (list.isEmpty) return false;
      } catch (_) {
        return false;
      }
    }
    return true;
  }

  /// streak 을 새로 계산하고 SecureStorage 에 저장한 뒤 [StreakSnapshot] 반환.
  /// 가족이 0명이면 0/false/저장된 best 그대로 반환.
  static Future<StreakSnapshot> computeAndSave(
    List<String> memberIds,
  ) async {
    final today = DateTime.now();
    final todayKey = _dateKey(today);

    final bestRaw = await SecureStorage.read(SecureStorage.kStreakBest);
    final prevBest = int.tryParse(bestRaw ?? '0') ?? 0;

    if (memberIds.isEmpty) {
      // 가족 없으면 streak 의미 없음. 캐시는 갱신하지 않음.
      return StreakSnapshot(count: 0, allTodayChecked: false, best: prevBest);
    }

    final allTodayChecked = await _allCheckedOn(memberIds, today);

    // 오늘이 안 채워졌으면 어제부터 거꾸로, 채워졌으면 오늘부터.
    DateTime cursor =
        allTodayChecked ? today : today.subtract(const Duration(days: 1));
    var count = 0;
    for (var i = 0; i < _maxWalkDays; i++) {
      final ok = await _allCheckedOn(memberIds, cursor);
      if (!ok) break;
      count++;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    final best = math.max(count, prevBest);
    await SecureStorage.write(SecureStorage.kStreakCount, count.toString());
    await SecureStorage.write(SecureStorage.kStreakLastDate, todayKey);
    await SecureStorage.write(SecureStorage.kStreakBest, best.toString());

    return StreakSnapshot(
      count: count,
      allTodayChecked: allTodayChecked,
      best: best,
    );
  }
}
