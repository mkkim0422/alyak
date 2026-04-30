import '../../../core/data/models/recommendation_result.dart';

/// 추천 엔진의 풀 출력. 결과 리스트 외에 1일 영양소 섭취 합산, 매칭된 프로필,
/// 적용된 cap 같은 부가 정보도 함께 들고 다닌다.
///
/// UI 화면에서는 [results] 만 써도 되지만, 디버그/관리자/테스트에서 입력 대비
/// 어떤 결정이 내려졌는지 추적하려면 나머지 필드가 필요하다.
class RecommendationOutput {
  /// 정렬·캡 적용된 최종 추천 결과 리스트 (순서 = 화면 노출 순서).
  final List<RecommendationResult> results;

  /// 사용자가 picker 로 선택한 제품 (currentProductIds) 합산 1일 영양소.
  /// 비어 있으면 빈 맵.
  final Map<String, double> currentIntake;

  /// 매칭된 base 프로필 키 (예: `thirties_female` / `child_male`). 매칭 실패면 null.
  final String? profileMatched;

  /// 노출(visible) 항목 hard cap. 나이대 + takingMedications 분기로 결정.
  final int capsApplied;

  /// 캐시 hit 여부. 캐시 우회된 경우 (takingMedications=true 등) 이거나 캐시 미스
  /// 인 경우 false.
  final bool fromCache;

  const RecommendationOutput({
    required this.results,
    this.currentIntake = const {},
    this.profileMatched,
    required this.capsApplied,
    this.fromCache = false,
  });

  bool get isEmpty => results.isEmpty;
}
