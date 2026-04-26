enum RecommendationCategory {
  mustTake,
  highlyRecommended,
  considerIf,
  /// 사용자가 현재 복용 중이라고 답한 영양제. 추천에서는 별도 섹션으로
  /// 분리되어 "이미 드시는 것 ✅" 으로 표시되고, 홈의 today-take 카드
  /// (visible) 에선 빠진다.
  alreadyTaking,
}

class RecommendationResult {
  final String supplementName;
  final String? supplementId;
  final RecommendationCategory category;
  final String reason;
  final int priority;
  final String? condition;
  final List<String> notes;

  const RecommendationResult({
    required this.supplementName,
    this.supplementId,
    required this.category,
    required this.reason,
    required this.priority,
    this.condition,
    this.notes = const [],
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
    );
  }
}
