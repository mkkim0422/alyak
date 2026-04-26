import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/models/conflict_warning.dart';
import '../../../core/data/models/recommendation_result.dart';
import '../../../core/data/models/schedule_result.dart';
import '../../../core/data/supplement_repository.dart';
import '../../family/models/family_member.dart';
import '../../family/providers/family_members_provider.dart';
import '../data/checkin_service.dart';

class HomeFeedEntry {
  HomeFeedEntry({
    required this.member,
    required this.recommendations,
    required this.schedule,
    required this.conflicts,
    required this.checkedToday,
  });

  final FamilyMember member;

  /// must_take + highly_recommended + condition boosts + considerIf (collapsed).
  /// 화면에서는 category 로 visible vs collapsed 구분.
  final List<RecommendationResult> recommendations;

  /// visible 항목들만 시간대 별로 쪼갠 결과. considerIf 는 schedule 에서 제외.
  /// morning 비중이 60% 를 넘지 않도록 필요시 evening 으로 재분배됨.
  final ScheduleResult schedule;

  /// supplement-supplement / supplement-medication / overdose 경고 (visible 기준).
  final List<ConflictWarning> conflicts;

  /// 오늘 체크된 영양제 한국어 이름.
  final Set<String> checkedToday;

  /// 화면 기본 노출 영양제 (must_take + highly_recommended). 사용자가 이미
  /// 복용 중이라 답한 항목 (alreadyTaking) 도 데일리 카드에서 빠진다.
  List<RecommendationResult> get visibleSupplements => recommendations
      .where((r) =>
          r.category != RecommendationCategory.considerIf &&
          r.category != RecommendationCategory.alreadyTaking)
      .toList();

  /// "추가로 고려할 수 있어요" collapsed 섹션용.
  List<RecommendationResult> get extraSupplements => recommendations
      .where((r) => r.category == RecommendationCategory.considerIf)
      .toList();

  /// 사용자가 직접 "지금 먹고 있어요" 라고 답한 영양제 — 추천 화면 별도 섹션.
  List<RecommendationResult> get alreadyTakingSupplements => recommendations
      .where((r) => r.category == RecommendationCategory.alreadyTaking)
      .toList();

  bool isAllChecked(Iterable<String> picks) {
    final list = picks.toList();
    if (list.isEmpty) return false;
    return list.every((n) => checkedToday.contains(n));
  }

  StatusDot get statusDot {
    final all = <String>{
      ...schedule.morning,
      ...schedule.evening,
      ...schedule.lunch,
      ...schedule.beforeSleep,
    };
    if (all.isEmpty) return StatusDot.none;
    final checked = all.intersection(checkedToday).length;
    if (checked == 0) return StatusDot.red;
    if (checked == all.length) return StatusDot.green;
    return StatusDot.yellow;
  }
}

enum StatusDot { green, yellow, red, none }

extension StatusDotX on StatusDot {
  String get emoji {
    switch (this) {
      case StatusDot.green:
        return '🟢';
      case StatusDot.yellow:
        return '🟡';
      case StatusDot.red:
        return '🔴';
      case StatusDot.none:
        return '⚪';
    }
  }
}

/// 화면이 한 번에 필요로 하는 모든 데이터를 합쳐 반환. SecureStorage 읽기 +
/// 복호화 + 추천/스케줄/충돌 계산이 한 번에 일어남 (워터폴 없음).
final homeFeedProvider = FutureProvider<List<HomeFeedEntry>>((ref) async {
  final repo = await ref.watch(supplementRepositoryProvider.future);
  final members = await ref.watch(familyMembersProvider.future);

  final entries = <HomeFeedEntry>[];
  for (final m in members) {
    final recs = repo.getRecommendations(m.input);
    // schedule 계산에는 considerIf / alreadyTaking 제외 — 이미 사용자가 알아서
    // 챙기고 있는 항목까지 시간대 슬롯에 넣지 않는다.
    final visibleNames = recs
        .where((r) =>
            r.category != RecommendationCategory.considerIf &&
            r.category != RecommendationCategory.alreadyTaking)
        .map((r) => r.supplementName)
        .toList();
    final scheduleRaw = repo.getSchedule(visibleNames);
    final schedule = _balanceMorning(scheduleRaw);
    final conflicts = repo.checkConflicts(visibleNames, const []);
    final checks = await CheckinService.readToday(m.id);
    entries.add(
      HomeFeedEntry(
        member: m,
        recommendations: recs,
        schedule: schedule,
        conflicts: conflicts,
        checkedToday: checks.toSet(),
      ),
    );
  }
  return entries;
});

/// morning + lunch 합이 전체의 60%를 넘으면 초과분을 evening 으로 옮긴다.
/// 너무 한쪽으로 몰리면 챙기기 부담스러우니까. 0~1개일 때는 굳이 균형 안 맞춤.
ScheduleResult _balanceMorning(ScheduleResult s) {
  final total = s.morning.length + s.lunch.length + s.evening.length + s.beforeSleep.length;
  if (total <= 1) return s;
  final dayLoad = s.morning.length + s.lunch.length;
  final cap = (total * 0.6).ceil();
  if (dayLoad <= cap) return s;
  final overflow = dayLoad - cap;
  // morning 끝에서부터 overflow 만큼 evening 앞으로 이동. 데이터 mutation 막기 위해 복사.
  final morning = List<String>.of(s.morning);
  final evening = List<String>.of(s.evening);
  for (var i = 0; i < overflow && morning.isNotEmpty; i++) {
    final moved = morning.removeLast();
    evening.insert(0, moved);
  }
  return ScheduleResult(
    morning: morning,
    lunch: s.lunch,
    evening: evening,
    beforeSleep: s.beforeSleep,
    conflicts: s.conflicts,
    synergies: s.synergies,
  );
}
