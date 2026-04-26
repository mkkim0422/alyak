enum Sex { male, female }

/// 음주 빈도 (음주자에 한해 묻는 후속 질문 답).
enum DrinkingFrequency { monthly, weekly, frequent }

/// 주로 마시는 술의 종류.
enum DrinkingType { soju, beer, wine, liquor, mixed }

/// 흡연자에 한해 묻는 일일 흡연량.
enum SmokingAmount { light, moderate, heavy, veryHeavy }

enum DietHabit { meat, balanced, vegetarian }

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
  final List<String>? currentSupplements;

  AgeGroup? get ageGroup {
    final a = age;
    return a == null ? null : AgeGroupX.fromAge(a);
  }

  /// 나이대에 따라 필요한 필드가 모두 채워졌는지.
  bool get isComplete {
    if (name == null || age == null || sex == null) return false;
    switch (ageGroup!) {
      case AgeGroup.newborn:
        return allergies != null && feeding != null;
      case AgeGroup.toddler:
        return pickyEating != null;
      case AgeGroup.child:
        return diet != null && pickyEating != null && exercise != null;
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
    );
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
      };
}
