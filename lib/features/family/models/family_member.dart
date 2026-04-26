import '../../recommendation/engine/family_input.dart';

/// 홈 화면에 표시할 가족 한 명. 평문은 메모리에만 둔다.
class FamilyMember {
  const FamilyMember({required this.id, required this.input});

  final String id;
  final FamilyInput input;

  String get name => input.name ?? '이름 없음';
  int get age => input.age ?? 0;
  Sex? get sex => input.sex;

  factory FamilyMember.fromDraft({
    required String id,
    required Map<String, dynamic> draft,
  }) {
    return FamilyMember(
      id: id,
      input: FamilyInput(
        name: draft['name'] as String?,
        age: draft['age'] as int?,
        sex: _parseEnum(draft['sex'] as String?, Sex.values),
        smoker: draft['smoker'] as bool?,
        smokingAmount: _parseEnum(
          draft['smoking_amount'] as String?,
          SmokingAmount.values,
        ),
        drinker: draft['drinker'] as bool?,
        drinkingType: _parseEnum(
          draft['drinking_type'] as String?,
          DrinkingType.values,
        ),
        drinkingFrequency: _parseEnum(
          draft['drinking_frequency'] as String?,
          DrinkingFrequency.values,
        ),
        diet: _parseEnum(draft['diet'] as String?, DietHabit.values),
        allergies: draft['allergies'] as bool?,
        feeding: _parseEnum(draft['feeding'] as String?, FeedingType.values),
        pickyEating: draft['picky_eating'] as bool?,
        exercise: _parseEnum(
          draft['exercise'] as String?,
          ExerciseLevel.values,
        ),
        sleep: _parseEnum(draft['sleep'] as String?, SleepHours.values),
        stress: _parseEnum(draft['stress'] as String?, StressLevel.values),
        digestiveIssues: draft['digestive_issues'] as bool?,
        takingMedications: draft['taking_medications'] as bool?,
        symptomIds: (draft['symptom_ids'] as List?)
            ?.map((e) => e.toString())
            .toList(),
        currentSupplements: (draft['current_supplements'] as List?)
            ?.map((e) => e.toString())
            .toList(),
      ),
    );
  }

  static T? _parseEnum<T extends Enum>(String? raw, List<T> values) {
    if (raw == null) return null;
    for (final v in values) {
      if (v.name == raw) return v;
    }
    return null;
  }
}
