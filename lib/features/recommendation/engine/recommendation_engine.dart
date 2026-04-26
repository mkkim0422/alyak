import '../../../core/data/models/recommendation_result.dart';
import '../../../core/data/models/schedule_result.dart';
import '../../../core/data/models/conflict_warning.dart';
import '../../../core/data/supplement_repository.dart';
import 'family_input.dart';

// 화면 코드는 결과 타입을 여기서 re-export 받는다 — 모델 파일 경로를 직접
// 외울 필요가 없도록.
export '../../../core/data/models/recommendation_result.dart'
    show RecommendationResult, RecommendationCategory;
export '../../../core/data/models/schedule_result.dart'
    show ScheduleResult, ScheduleSlot, ScheduleConflict, ScheduleSynergy, scheduleSlotKo;
export '../../../core/data/models/conflict_warning.dart'
    show ConflictWarning, ConflictKind, ConflictSeverity, conflictSeverityKo;

/// 얇은 facade — 실제 추천 / 스케줄 / 충돌 로직은 [SupplementRepository]
/// 안에 있다. 엔진은 화면이 의존성 주입 받기 편하도록 묶어 두는 그릇.
class RecommendationEngine {
  RecommendationEngine({required this.repository});

  final SupplementRepository repository;

  List<RecommendationResult> recommend(FamilyInput input) =>
      repository.getRecommendations(input);

  ScheduleResult schedule(List<String> supplementNames) =>
      repository.getSchedule(supplementNames);

  List<ConflictWarning> conflicts(
    List<String> supplementNames, {
    List<String> medicationCategories = const [],
  }) =>
      repository.checkConflicts(supplementNames, medicationCategories);
}
