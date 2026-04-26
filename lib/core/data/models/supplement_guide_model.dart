class TimingInfo {
  final List<String> bestTime;
  final String mealRelation;
  final String reason;

  const TimingInfo({
    required this.bestTime,
    required this.mealRelation,
    required this.reason,
  });

  factory TimingInfo.fromJson(Map<String, dynamic> json) {
    return TimingInfo(
      bestTime: (json['best_time'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      mealRelation: json['meal_relation'] as String? ?? '',
      reason: json['reason'] as String? ?? '',
    );
  }
}

class DosageBand {
  final num amount;
  final String unit;
  final String? frequency;
  final String? note;

  const DosageBand({
    required this.amount,
    required this.unit,
    this.frequency,
    this.note,
  });

  factory DosageBand.fromJson(Map<String, dynamic> json) {
    return DosageBand(
      amount: json['amount'] as num? ?? 0,
      unit: json['unit'] as String? ?? '',
      frequency: json['frequency'] as String?,
      note: json['note'] as String?,
    );
  }
}

class DosageInfo {
  final DosageBand? adult;
  final DosageBand? child7to12;
  final DosageBand? teen13to18;
  final DosageBand? elderly60plus;
  final DosageBand? upperLimitAdult;

  const DosageInfo({
    this.adult,
    this.child7to12,
    this.teen13to18,
    this.elderly60plus,
    this.upperLimitAdult,
  });

  factory DosageInfo.fromJson(Map<String, dynamic> json) {
    DosageBand? band(String key) {
      final v = json[key];
      return v is Map<String, dynamic> ? DosageBand.fromJson(v) : null;
    }

    return DosageInfo(
      adult: band('adult'),
      child7to12: band('child_7_12'),
      teen13to18: band('teen_13_18'),
      elderly60plus: band('elderly_60plus'),
      upperLimitAdult: band('upper_limit_adult'),
    );
  }
}

class CombinationLink {
  final String supplement;
  final String? reason;
  final String? timingNote;
  final String? severity;
  final String? solution;

  const CombinationLink({
    required this.supplement,
    this.reason,
    this.timingNote,
    this.severity,
    this.solution,
  });

  factory CombinationLink.fromJson(Map<String, dynamic> json) {
    return CombinationLink(
      supplement: json['supplement'] as String? ?? '',
      reason: json['reason'] as String?,
      timingNote: json['timing_note'] as String?,
      severity: json['severity'] as String?,
      solution: json['solution'] as String?,
    );
  }
}

class DrugInteractionEntry {
  final String drugCategory;
  final String severity;
  final String reason;
  final String recommendation;

  const DrugInteractionEntry({
    required this.drugCategory,
    required this.severity,
    required this.reason,
    required this.recommendation,
  });

  factory DrugInteractionEntry.fromJson(Map<String, dynamic> json) {
    return DrugInteractionEntry(
      drugCategory: json['drug_category'] as String? ?? '',
      severity: json['severity'] as String? ?? '',
      reason: json['reason'] as String? ?? '',
      recommendation: json['recommendation'] as String? ?? '',
    );
  }
}

class SpecialWarnings {
  final String pregnant;
  final String nursing;
  final String infant0to6;
  final String child;
  final String elderly;
  final String smoker;

  const SpecialWarnings({
    required this.pregnant,
    required this.nursing,
    required this.infant0to6,
    required this.child,
    required this.elderly,
    required this.smoker,
  });

  factory SpecialWarnings.fromJson(Map<String, dynamic> json) {
    return SpecialWarnings(
      pregnant: json['pregnant'] as String? ?? '',
      nursing: json['nursing'] as String? ?? '',
      infant0to6: json['infant_0_6'] as String? ?? '',
      child: json['child'] as String? ?? '',
      elderly: json['elderly'] as String? ?? '',
      smoker: json['smoker'] as String? ?? '',
    );
  }
}

class FoodAlternative {
  final String food;
  final String amount;
  final String equivalent;

  const FoodAlternative({
    required this.food,
    required this.amount,
    required this.equivalent,
  });

  factory FoodAlternative.fromJson(Map<String, dynamic> json) {
    return FoodAlternative(
      food: json['food'] as String? ?? '',
      amount: json['amount'] as String? ?? '',
      equivalent: json['equivalent'] as String? ?? '',
    );
  }
}

class SupplementGuide {
  final String id;
  final String nameKorean;
  final String nameEnglish;
  final String category;
  final TimingInfo timing;
  final DosageInfo dosage;
  final List<CombinationLink> goodCombinations;
  final List<CombinationLink> badCombinations;
  final List<DrugInteractionEntry> drugInteractions;
  final SpecialWarnings specialWarnings;
  final List<FoodAlternative> foodAlternatives;
  final String effectTimeline;
  final List<String> mainBenefits;
  /// 사용자 프로필에 따라 골라 쓰는 한 줄 사유. 키는 `smoker`, `heavy_drinker`,
  /// `elderly`, `child`, `female_30s`, `vegetarian` 등. supplement_guide.json
  /// 데이터가 미비하면 빈 맵 — repository 가 mainBenefits/기본 reason 으로 폴백.
  final Map<String, String> personalizedReasons;
  final String disclaimer;

  const SupplementGuide({
    required this.id,
    required this.nameKorean,
    required this.nameEnglish,
    required this.category,
    required this.timing,
    required this.dosage,
    required this.goodCombinations,
    required this.badCombinations,
    required this.drugInteractions,
    required this.specialWarnings,
    required this.foodAlternatives,
    required this.effectTimeline,
    required this.mainBenefits,
    required this.personalizedReasons,
    required this.disclaimer,
  });

  factory SupplementGuide.fromJson(Map<String, dynamic> json) {
    return SupplementGuide(
      id: json['id'] as String? ?? '',
      nameKorean: json['name_korean'] as String? ?? '',
      nameEnglish: json['name_english'] as String? ?? '',
      category: json['category'] as String? ?? '',
      timing: TimingInfo.fromJson(
          (json['timing'] as Map?)?.cast<String, dynamic>() ?? const {}),
      dosage: DosageInfo.fromJson(
          (json['dosage'] as Map?)?.cast<String, dynamic>() ?? const {}),
      goodCombinations: (json['good_combinations'] as List<dynamic>? ?? [])
          .map((e) => CombinationLink.fromJson(e as Map<String, dynamic>))
          .toList(),
      badCombinations: (json['bad_combinations'] as List<dynamic>? ?? [])
          .map((e) => CombinationLink.fromJson(e as Map<String, dynamic>))
          .toList(),
      drugInteractions: (json['drug_interactions'] as List<dynamic>? ?? [])
          .map((e) =>
              DrugInteractionEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      specialWarnings: SpecialWarnings.fromJson(
          (json['special_warnings'] as Map?)?.cast<String, dynamic>() ??
              const {}),
      foodAlternatives: (json['food_alternatives'] as List<dynamic>? ?? [])
          .map((e) => FoodAlternative.fromJson(e as Map<String, dynamic>))
          .toList(),
      effectTimeline: json['effect_timeline'] as String? ?? '',
      mainBenefits: (json['main_benefits'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      personalizedReasons: ((json['personalized_reasons'] as Map?) ??
              const <String, dynamic>{})
          .map((k, v) => MapEntry(k.toString(), v.toString())),
      disclaimer: json['disclaimer'] as String? ?? '',
    );
  }
}
