import '../../../core/data/models/conflict_warning.dart';
import '../../../core/data/models/recommendation_result.dart';
import '../../../core/data/models/schedule_result.dart';
import '../../../core/data/supplement_repository.dart';

/// 추천된 영양제를 시간대(아침/점심/저녁/취침 전)에 배치하고, 분리 필요·시너지·
/// 상한 초과 경고를 함께 산출한다.
///
/// SupplementRepository 의 getSchedule / checkConflicts 를 facade 로 감싼다 —
/// repository 가 이미 시간대 배치 + 충돌 분리 + 시너지 정렬 로직을 들고 있기
/// 때문에 이 클래스는 (a) RecommendationResult 받아 처리하는 입구와
/// (b) overdose 경고를 ScheduleResult 옆에 함께 노출하는 wrapper 역할만 한다.
class ScheduleEngine {
  ScheduleEngine({required this.repository});

  final SupplementRepository repository;

  /// [recommendations] 중 alreadyTaking 은 자동 제외 — 사용자가 이미 다른
  /// 제품으로 챙기고 있는 항목까지 today-take 카드에 띄우면 중복.
  ScheduleResult scheduleFor(List<RecommendationResult> recommendations) {
    final names = <String>[];
    for (final r in recommendations) {
      if (r.category == RecommendationCategory.alreadyTaking) continue;
      if (r.supplementName.trim().isEmpty) continue;
      names.add(r.supplementName);
    }
    if (names.isEmpty) {
      return const ScheduleResult(
        morning: [],
        lunch: [],
        evening: [],
        beforeSleep: [],
        conflicts: [],
        synergies: [],
      );
    }
    return repository.getSchedule(names);
  }

  /// 영양제 이름만으로 스케줄 계산 (관리자/디버그 용도). UI 흐름에서는
  /// [scheduleFor] 를 우선 사용.
  ScheduleResult scheduleForNames(List<String> supplementNames) {
    return repository.getSchedule(supplementNames);
  }

  /// 시간대 배치 + 분리/시너지 + overdose 경고를 한 번에 반환. Stage 3 화면
  /// 단에서 ScheduleResult 외 추가 경고 카드를 띄울 때 사용.
  ScheduleWithWarnings scheduleWithWarnings(
    List<RecommendationResult> recommendations, {
    List<String> medicationCategories = const [],
  }) {
    final schedule = scheduleFor(recommendations);
    final names = recommendations
        .where((r) => r.category != RecommendationCategory.alreadyTaking)
        .map((r) => r.supplementName)
        .where((n) => n.trim().isNotEmpty)
        .toList();
    final warnings =
        repository.checkConflicts(names, medicationCategories);
    return ScheduleWithWarnings(schedule: schedule, warnings: warnings);
  }
}

class ScheduleWithWarnings {
  final ScheduleResult schedule;
  final List<ConflictWarning> warnings;

  const ScheduleWithWarnings({
    required this.schedule,
    required this.warnings,
  });
}
