import '../../../core/data/product_repository.dart';
import 'health_checkup.dart';

enum Sex { male, female }

/// 아이 변 빈도. 변비/설사 신호에 활용.
enum StoolFrequency { daily, twoToThreeDays, weekly, less }

/// 아이 변 형태.
enum StoolForm { hard, normal, soft, watery }

/// 음주 빈도 (음주자에 한해 묻는 후속 질문 답).
enum DrinkingFrequency { monthly, weekly, frequent }

/// 주로 마시는 술의 종류.
enum DrinkingType { soju, beer, wine, liquor, mixed }

/// 흡연자에 한해 묻는 일일 흡연량.
enum SmokingAmount { light, moderate, heavy, veryHeavy }

enum DietHabit { meat, balanced, vegetarian }

/// 성인 여성의 임신/수유 상태. 추천 엔진이 안전성/우선순위를 조정한다.
/// - none: 해당 없음 (기본값)
/// - pregnant: 임신 중 (엽산/철분/DHA 우선, 비타민A 고용량 회피)
/// - breastfeeding: 수유 중 (DHA/칼슘/비타민D 보충 우선)
enum SpecialCondition { none, pregnant, breastfeeding }

enum FeedingType { breastMilk, formula, solidFood }

enum ExerciseLevel { none, sometimes, often }

enum SleepHours { lessSix, sevenEight, nineOrMore }

enum StressLevel { low, medium, high }

/// 가족 구성원의 나이대. UI 흐름·추천 엔진 양쪽에서 분기 기준으로 쓴다.
/// - newborn: 0-1세 (모유/분유/이유식 중심)
/// - toddler: 2-6세 (편식 위주)
enum AgeGroup { newborn, toddler, child, teen, adult, elderly }

extension AgeGroupX on AgeGroup {
  static AgeGroup fromAge(int age) {
    if (age <= 1) return AgeGroup.newborn;
    if (age <= 6) return AgeGroup.toddler;
    if (age <= 12) return AgeGroup.child;
    if (age <= 18) return AgeGroup.teen;
    if (age <= 59) return AgeGroup.adult;
    return AgeGroup.elderly;
  }
}

extension SexX on Sex {
  String get ko => this == Sex.male ? '남성' : '여성';
  String get storage => this == Sex.male ? 'male' : 'female';
}

extension DrinkingFrequencyX on DrinkingFrequency {
  String get ko {
    switch (this) {
      case DrinkingFrequency.monthly:
        return '월 1-2회';
      case DrinkingFrequency.weekly:
        return '주 1-2회';
      case DrinkingFrequency.frequent:
        return '주 3회 이상';
    }
  }

  String get storage => name;
}

extension DrinkingTypeX on DrinkingType {
  String get ko {
    switch (this) {
      case DrinkingType.soju:
        return '소주';
      case DrinkingType.beer:
        return '맥주';
      case DrinkingType.wine:
        return '와인';
      case DrinkingType.liquor:
        return '양주';
      case DrinkingType.mixed:
        return '혼합';
    }
  }

  String get storage => name;
}

extension SmokingAmountX on SmokingAmount {
  String get ko {
    switch (this) {
      case SmokingAmount.light:
        return '5개비 이하';
      case SmokingAmount.moderate:
        return '6-10개비';
      case SmokingAmount.heavy:
        return '11-20개비';
      case SmokingAmount.veryHeavy:
        return '20개비 이상';
    }
  }

  String get storage => name;
}

extension DietHabitX on DietHabit {
  String get ko {
    switch (this) {
      case DietHabit.meat:
        return '육류 위주';
      case DietHabit.balanced:
        return '균형 잡힘';
      case DietHabit.vegetarian:
        return '채식 위주';
    }
  }

  String get storage => name;
}

extension FeedingTypeX on FeedingType {
  String get ko {
    switch (this) {
      case FeedingType.breastMilk:
        return '모유';
      case FeedingType.formula:
        return '분유';
      case FeedingType.solidFood:
        return '이유식';
    }
  }

  String get storage => name;
}

extension ExerciseLevelX on ExerciseLevel {
  String get ko {
    switch (this) {
      case ExerciseLevel.none:
        return '안 함';
      case ExerciseLevel.sometimes:
        return '가끔';
      case ExerciseLevel.often:
        return '자주';
    }
  }

  String get storage => name;
}

extension SleepHoursX on SleepHours {
  String get ko {
    switch (this) {
      case SleepHours.lessSix:
        return '6시간 이하';
      case SleepHours.sevenEight:
        return '7-8시간';
      case SleepHours.nineOrMore:
        return '9시간 이상';
    }
  }

  String get storage => name;
}

extension StressLevelX on StressLevel {
  String get ko {
    switch (this) {
      case StressLevel.low:
        return '낮음';
      case StressLevel.medium:
        return '보통';
      case StressLevel.high:
        return '높음';
    }
  }

  String get storage => name;
}

extension StoolFrequencyX on StoolFrequency {
  String get ko {
    switch (this) {
      case StoolFrequency.daily:
        return '매일 보내요';
      case StoolFrequency.twoToThreeDays:
        return '2-3일에 한 번';
      case StoolFrequency.weekly:
        return '일주일에 한 번';
      case StoolFrequency.less:
        return '거의 못 봐요';
    }
  }

  String get storage => name;
}

extension SpecialConditionX on SpecialCondition {
  String get ko {
    switch (this) {
      case SpecialCondition.none:
        return '해당 없음';
      case SpecialCondition.pregnant:
        return '임신 중';
      case SpecialCondition.breastfeeding:
        return '수유 중';
    }
  }

  String get storage => name;
}

extension StoolFormX on StoolForm {
  String get ko {
    switch (this) {
      case StoolForm.hard:
        return '딱딱해요 (변비)';
      case StoolForm.normal:
        return '보통이에요';
      case StoolForm.soft:
        return '무른 편이에요';
      case StoolForm.watery:
        return '설사 같아요';
    }
  }

  String get storage => name;
}

/// 채팅 온보딩에서 모은 답변. 부분 입력도 허용 (실시간 미리보기 용도).
///
/// 나이대별로 묻는 질문이 다르기 때문에 모든 필드는 nullable.
/// 완료 여부는 [isComplete]가 나이대를 보고 필요한 필드만 검사한다.
class FamilyInput {
  const FamilyInput({
    this.name,
    this.age,
    this.sex,
    this.smoker,
    this.smokingAmount,
    this.drinker,
    this.drinkingType,
    this.drinkingFrequency,
    this.diet,
    this.allergies,
    this.feeding,
    this.pickyEating,
    this.exercise,
    this.sleep,
    this.stress,
    this.digestiveIssues,
    this.takingMedications,
    this.symptomIds,
    this.currentSupplements,
    this.currentProductIds,
    this.lastCheckup,
    this.heightCm,
    this.weightKg,
    this.heightWeightUpdated,
    this.stoolFrequency,
    this.stoolForm,
    this.allergyItems,
    this.eatsVegetables,
    this.eatsFish,
    this.specialCondition = SpecialCondition.none,
  });

  final String? name;
  final int? age;
  final Sex? sex;

  // 성인/노인용
  final bool? smoker;
  final SmokingAmount? smokingAmount;

  final bool? drinker;
  final DrinkingType? drinkingType;
  final DrinkingFrequency? drinkingFrequency;

  // 어린이부터 노인까지 공통
  final DietHabit? diet;

  // 영아/유아
  final bool? allergies;
  final FeedingType? feeding;

  // 어린이
  final bool? pickyEating;

  // 어린이~노인
  final ExerciseLevel? exercise;

  // 청소년~노인
  final SleepHours? sleep;

  // 청소년~성인
  final StressLevel? stress;

  // 노인
  final bool? digestiveIssues;
  final bool? takingMedications;

  /// 증상 검색에서 "내 추천에 반영" 으로 추가된 symptom_id 들. 추천 엔진이
  /// 이 리스트를 보고 관련 영양제를 추가 부스트한다. null 또는 빈 리스트면 무시.
  final List<String>? symptomIds;

  /// 사용자가 채팅 끝 단계에서 "지금 이걸 먹고 있어요" 라고 답한 영양제 한국어
  /// 이름들. 추천 엔진이 이 리스트와 매칭되는 추천 항목을 [alreadyTaking]
  /// 으로 강등(섹션 분리) 시킨다. null/빈 리스트면 무시 (사용자가 "없어요"
  /// 답했거나 미응답).
  ///
  /// 제품 picker(products.json) 를 사용한 흐름에서는 [currentProductIds] 와
  /// 함께 자동 동기화 — 제품 카테고리에서 도출된 supplement 이름이 채워진다.
  final List<String>? currentSupplements;

  /// 사용자가 picker 에서 선택한 실제 제품의 ID 리스트 (예: [p001, p004]).
  /// 정확한 영양소 합산 ([getCurrentNutrientIntake]) 에 사용되며, 빈 리스트면
  /// "선택 안 했음" 으로 간주.
  final List<String>? currentProductIds;

  /// 사용자가 직접 입력한 최근 검진 결과. null 이면 검진 데이터 없음.
  final HealthCheckup? lastCheckup;

  // ───────────────────────────────────────────────────────────── 아이 상세
  // 영아/유아/어린이/청소년 흐름에서 추가로 묻는 항목들. 성인은 모두 null.

  /// 아이 키 (cm). 또래 대비 percentile 계산에 사용.
  final double? heightCm;

  /// 아이 몸무게 (kg).
  final double? weightKg;

  /// 키/몸무게 마지막 업데이트 시점.
  final DateTime? heightWeightUpdated;

  /// 변 빈도 (장 건강 신호).
  final StoolFrequency? stoolFrequency;

  /// 변 형태 (장 건강 신호).
  final StoolForm? stoolForm;

  /// 알레르기 항목 리스트 (예: 우유, 계란, 견과류). [allergies] (bool) 가
  /// 영아 흐름에서 단순 yes/no 로 쓰이는 것과 별도.
  final List<String>? allergyItems;

  /// 어린이/청소년 채소 섭취 여부.
  final bool? eatsVegetables;

  /// 어린이 생선 섭취 여부 (오메가3 신호).
  final bool? eatsFish;

  /// 임신/수유 상태. 가임기 여성에 한해 의미 있는 값. 기본값은 [SpecialCondition.none].
  final SpecialCondition specialCondition;

  AgeGroup? get ageGroup {
    final a = age;
    return a == null ? null : AgeGroupX.fromAge(a);
  }

  /// 나이대에 따라 필요한 필드가 모두 채워졌는지.
  ///
  /// 각 분기는 [stepsForAge] 의 흐름과 1:1 일치해야 한다 — 흐름에서 묻지 않는
  /// 필드를 여기서 요구하면 사용자가 모든 단계를 끝내도 isComplete=false 가 되어
  /// `FamilyChatScreen._finish()` 가 silent return → 완료 버튼이 죽은 듯이 보이는
  /// 버그가 발생한다 (실제로 child/newborn 에서 발생했음).
  bool get isComplete {
    if (name == null || age == null || sex == null) return false;
    switch (ageGroup!) {
      case AgeGroup.newborn:
        // 영아 흐름: allergyItems (다중 선택) + feeding. allergies (bool) 는
        // legacy 필드라 흐름에서 안 묻는다 — 요구 대상에서 제외.
        return feeding != null;
      case AgeGroup.toddler:
        return pickyEating != null;
      case AgeGroup.child:
        // 어린이 흐름: heightWeight + diet + eatsVegetables + eatsFish + exercise
        // + stoolFrequency + stoolForm. pickyEating 은 흐름에 없으므로 제외.
        return diet != null && exercise != null;
      case AgeGroup.teen:
        return diet != null &&
            exercise != null &&
            sleep != null &&
            stress != null;
      case AgeGroup.adult:
        return smoker != null &&
            drinker != null &&
            diet != null &&
            exercise != null &&
            sleep != null &&
            stress != null;
      case AgeGroup.elderly:
        return smoker != null &&
            drinker != null &&
            diet != null &&
            exercise != null &&
            sleep != null &&
            digestiveIssues != null &&
            takingMedications != null;
    }
  }

  FamilyInput copyWith({
    String? name,
    int? age,
    Sex? sex,
    bool? smoker,
    SmokingAmount? smokingAmount,
    bool? drinker,
    DrinkingType? drinkingType,
    DrinkingFrequency? drinkingFrequency,
    DietHabit? diet,
    bool? allergies,
    FeedingType? feeding,
    bool? pickyEating,
    ExerciseLevel? exercise,
    SleepHours? sleep,
    StressLevel? stress,
    bool? digestiveIssues,
    bool? takingMedications,
    List<String>? symptomIds,
    List<String>? currentSupplements,
    List<String>? currentProductIds,
    HealthCheckup? lastCheckup,
    double? heightCm,
    double? weightKg,
    DateTime? heightWeightUpdated,
    StoolFrequency? stoolFrequency,
    StoolForm? stoolForm,
    List<String>? allergyItems,
    bool? eatsVegetables,
    bool? eatsFish,
    SpecialCondition? specialCondition,
  }) {
    return FamilyInput(
      name: name ?? this.name,
      age: age ?? this.age,
      sex: sex ?? this.sex,
      smoker: smoker ?? this.smoker,
      smokingAmount: smokingAmount ?? this.smokingAmount,
      drinker: drinker ?? this.drinker,
      drinkingType: drinkingType ?? this.drinkingType,
      drinkingFrequency: drinkingFrequency ?? this.drinkingFrequency,
      diet: diet ?? this.diet,
      allergies: allergies ?? this.allergies,
      feeding: feeding ?? this.feeding,
      pickyEating: pickyEating ?? this.pickyEating,
      exercise: exercise ?? this.exercise,
      sleep: sleep ?? this.sleep,
      stress: stress ?? this.stress,
      digestiveIssues: digestiveIssues ?? this.digestiveIssues,
      takingMedications: takingMedications ?? this.takingMedications,
      symptomIds: symptomIds ?? this.symptomIds,
      currentSupplements: currentSupplements ?? this.currentSupplements,
      currentProductIds: currentProductIds ?? this.currentProductIds,
      lastCheckup: lastCheckup ?? this.lastCheckup,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      heightWeightUpdated: heightWeightUpdated ?? this.heightWeightUpdated,
      stoolFrequency: stoolFrequency ?? this.stoolFrequency,
      stoolForm: stoolForm ?? this.stoolForm,
      allergyItems: allergyItems ?? this.allergyItems,
      eatsVegetables: eatsVegetables ?? this.eatsVegetables,
      eatsFish: eatsFish ?? this.eatsFish,
      specialCondition: specialCondition ?? this.specialCondition,
    );
  }

  /// 사용자가 선택한 제품들로부터 1일 영양소 섭취량을 합산.
  /// 각 제품의 `ingredients` * `daily_dose` 를 ingredient 키 기준으로 합친다.
  /// `currentProductIds` 가 비었으면 빈 맵.
  Map<String, double> getCurrentNutrientIntake(ProductRepository repo) {
    final ids = currentProductIds;
    if (ids == null || ids.isEmpty) return const {};
    final totals = <String, double>{};
    for (final id in ids) {
      final p = repo.getById(id);
      if (p == null) continue;
      for (final e in p.dailyIngredients.entries) {
        totals[e.key] = (totals[e.key] ?? 0) + e.value;
      }
    }
    return totals;
  }

  /// 평문 JSON. 저장 전에 EncryptionService로 암호화한 뒤에만 디스크에 쓴다.
  Map<String, dynamic> toJson() => {
        'name': name,
        'age': age,
        'sex': sex?.storage,
        'smoker': smoker,
        'smoking_amount': smokingAmount?.storage,
        'drinker': drinker,
        'drinking_type': drinkingType?.storage,
        'drinking_frequency': drinkingFrequency?.storage,
        'diet': diet?.storage,
        'allergies': allergies,
        'feeding': feeding?.storage,
        'picky_eating': pickyEating,
        'exercise': exercise?.storage,
        'sleep': sleep?.storage,
        'stress': stress?.storage,
        'digestive_issues': digestiveIssues,
        'taking_medications': takingMedications,
        'symptom_ids': symptomIds,
        'current_supplements': currentSupplements,
        'current_product_ids': currentProductIds,
        'last_checkup': lastCheckup?.toJson(),
        'height_cm': heightCm,
        'weight_kg': weightKg,
        'height_weight_updated': heightWeightUpdated?.toIso8601String(),
        'stool_frequency': stoolFrequency?.storage,
        'stool_form': stoolForm?.storage,
        'allergy_items': allergyItems,
        'eats_vegetables': eatsVegetables,
        'eats_fish': eatsFish,
        'special_condition': specialCondition.storage,
      };
}
