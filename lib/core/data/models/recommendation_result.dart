enum RecommendationCategory {
  mustTake,
  highlyRecommended,
  considerIf,
  /// 사용자가 현재 복용 중이라고 답한 영양제. 추천에서는 별도 섹션으로
  /// 분리되어 "이미 드시는 것 ✅" 으로 표시되고, 홈의 today-take 카드
  /// (visible) 에선 빠진다.
  alreadyTaking,
}

/// 1일 권장량 대비 현재 섭취 상태. 사용자가 picker 로 등록한 제품 (currentProductIds)
/// 와 nutrient_targets 의 1일 권장량을 비교해 산출.
///
/// - appropriate: 권장량의 80~120% — 적정
/// - insufficient: 권장량의 80% 미만 — 부족
/// - excess: 권장량의 120% 초과 — 과다 가능성
/// - notCalculated: nutrient_targets 에 매핑이 없거나 currentProductIds 가 비어
///   계산 불가 — 화면에서 별도 표기 없이 노출.
enum NutrientStatus {
  appropriate,
  insufficient,
  excess,
  notCalculated,
}

class RecommendationResult {
  final String supplementName;
  final String? supplementId;
  final RecommendationCategory category;
  final String reason;
  final int priority;
  final String? condition;
  final List<String> notes;

  /// 사용자에게 보여줄 짧은 한 줄 부가 메시지 (예: "이미 센트룸에 포함되어 있어요").
  /// notes 와 다르게 화면에서 1차 노출 — alreadyTaking/excess 분기에 주로 채워진다.
  final String? note;

  /// 1일 권장량 대비 현재 섭취 상태. 미계산이면 [NutrientStatus.notCalculated].
  final NutrientStatus? nutrientStatus;

  /// 1일 목표량 (gap 산정 시 사용). nutrient_targets 의 권장량.
  final double? targetDosage;

  /// currentProductIds 합산 기준 현재 섭취량.
  final double? currentDosage;

  /// 단위 (mg / IU / mcg / 억 CFU). nutrient_targets 의 키 suffix 에서 도출.
  final String? unit;

  const RecommendationResult({
    required this.supplementName,
    this.supplementId,
    required this.category,
    required this.reason,
    required this.priority,
    this.condition,
    this.notes = const [],
    this.note,
    this.nutrientStatus,
    this.targetDosage,
    this.currentDosage,
    this.unit,
  });

  RecommendationResult withNotes(List<String> extra) {
    return RecommendationResult(
      supplementName: supplementName,
      supplementId: supplementId,
      category: category,
      reason: reason,
      priority: priority,
      condition: condition,
      notes: [...notes, ...extra],
      note: note,
      nutrientStatus: nutrientStatus,
      targetDosage: targetDosage,
      currentDosage: currentDosage,
      unit: unit,
    );
  }

  RecommendationResult copyWith({
    String? supplementName,
    String? supplementId,
    RecommendationCategory? category,
    String? reason,
    int? priority,
    String? condition,
    List<String>? notes,
    String? note,
    NutrientStatus? nutrientStatus,
    double? targetDosage,
    double? currentDosage,
    String? unit,
  }) {
    return RecommendationResult(
      supplementName: supplementName ?? this.supplementName,
      supplementId: supplementId ?? this.supplementId,
      category: category ?? this.category,
      reason: reason ?? this.reason,
      priority: priority ?? this.priority,
      condition: condition ?? this.condition,
      notes: notes ?? this.notes,
      note: note ?? this.note,
      nutrientStatus: nutrientStatus ?? this.nutrientStatus,
      targetDosage: targetDosage ?? this.targetDosage,
      currentDosage: currentDosage ?? this.currentDosage,
      unit: unit ?? this.unit,
    );
  }
}
