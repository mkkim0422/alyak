// Pre-generates `assets/data/recommendation_cache.json` from the existing
// JSON-driven recommendation logic. No Claude API calls — the local
// SupplementRepository is the "API" here.
//
// Run with:
//   flutter test scripts/generate_cache.dart
//
// It is implemented as a flutter_test entry so that we get a Flutter
// binding (needed by anything that touches `package:flutter/services.dart`)
// and so we can write the output file via `dart:io` to the project root.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:alyak/core/data/models/recommendation_result.dart';
import 'package:alyak/core/data/supplement_repository.dart';
import 'package:alyak/features/recommendation/engine/family_input.dart';

/// Reads asset files from the local filesystem so the script works without
/// a packaged app build.
class _DiskAssetBundle extends CachingAssetBundle {
  _DiskAssetBundle(this.root);
  final String root;

  @override
  Future<ByteData> load(String key) async {
    final f = File('$root/$key');
    final bytes = await f.readAsBytes();
    return ByteData.sublistView(bytes);
  }
}

/// One adult archetype — collapses the 11k+ adult combinatoric explosion to
/// 20 representative profiles. Each one becomes a row in the cache table for
/// every adult age × gender bucket.
class _Archetype {
  const _Archetype({
    required this.id,
    required this.label,
    required this.smoker,
    this.smokingAmount,
    required this.drinker,
    this.drinkingFrequency,
    required this.diet,
    this.symptomId,
  });

  final int id;
  final String label;
  final bool smoker;
  final SmokingAmount? smokingAmount;
  final bool drinker;
  final DrinkingFrequency? drinkingFrequency;
  final DietHabit diet;
  final String? symptomId;

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'smoker': smoker,
        if (smokingAmount != null) 'smoking_amount': smokingAmount!.storage,
        'drinker': drinker,
        if (drinkingFrequency != null)
          'drinking_frequency': drinkingFrequency!.storage,
        'diet': diet.storage,
        if (symptomId != null) 'symptom_id': symptomId,
      };
}

const _archetypes = <_Archetype>[
  _Archetype(
    id: 1, label: '비흡연,음주없음,균형,피로',
    smoker: false, drinker: false, diet: DietHabit.balanced,
    symptomId: 'sym008',
  ),
  _Archetype(
    id: 2, label: '비흡연,음주없음,균형,면역',
    smoker: false, drinker: false, diet: DietHabit.balanced,
    symptomId: 'sym024',
  ),
  _Archetype(
    id: 3, label: '비흡연,가끔음주,균형,피로',
    smoker: false,
    drinker: true, drinkingFrequency: DrinkingFrequency.monthly,
    diet: DietHabit.balanced, symptomId: 'sym008',
  ),
  _Archetype(
    id: 4, label: '흡연,주음주,육류,피로',
    smoker: true, smokingAmount: SmokingAmount.heavy,
    drinker: true, drinkingFrequency: DrinkingFrequency.weekly,
    diet: DietHabit.meat, symptomId: 'sym008',
  ),
  _Archetype(
    id: 5, label: '흡연,자주음주,육류,간건강',
    smoker: true, smokingAmount: SmokingAmount.heavy,
    drinker: true, drinkingFrequency: DrinkingFrequency.frequent,
    diet: DietHabit.meat,
  ),
  _Archetype(
    id: 6, label: '비흡연,음주없음,채식,피로',
    smoker: false, drinker: false, diet: DietHabit.vegetarian,
    symptomId: 'sym008',
  ),
  _Archetype(
    id: 7, label: '비흡연,음주없음,채식,빈혈',
    smoker: false, drinker: false, diet: DietHabit.vegetarian,
    symptomId: 'sym031',
  ),
  _Archetype(
    id: 8, label: '비흡연,가끔음주,육류,관절',
    smoker: false,
    drinker: true, drinkingFrequency: DrinkingFrequency.monthly,
    diet: DietHabit.meat, symptomId: 'sym006',
  ),
  _Archetype(
    id: 9, label: '비흡연,음주없음,균형,수면',
    smoker: false, drinker: false, diet: DietHabit.balanced,
    symptomId: 'sym032',
  ),
  _Archetype(
    id: 10, label: '비흡연,음주없음,균형,눈건강',
    smoker: false, drinker: false, diet: DietHabit.balanced,
    symptomId: 'sym037',
  ),
  _Archetype(
    id: 11, label: '비흡연,음주없음,균형,피부',
    smoker: false, drinker: false, diet: DietHabit.balanced,
    symptomId: 'sym015',
  ),
  _Archetype(
    id: 12, label: '비흡연,가끔음주,균형,집중력',
    smoker: false,
    drinker: true, drinkingFrequency: DrinkingFrequency.monthly,
    diet: DietHabit.balanced, symptomId: 'sym010',
  ),
  _Archetype(
    id: 13, label: '흡연,음주없음,균형,폐건강',
    smoker: true, smokingAmount: SmokingAmount.heavy,
    drinker: false, diet: DietHabit.balanced,
  ),
  _Archetype(
    id: 14, label: '비흡연,자주음주,육류,간건강',
    smoker: false,
    drinker: true, drinkingFrequency: DrinkingFrequency.frequent,
    diet: DietHabit.meat,
  ),
  _Archetype(
    id: 15, label: '비흡연,음주없음,균형,소화',
    smoker: false, drinker: false, diet: DietHabit.balanced,
    symptomId: 'sym021',
  ),
  _Archetype(
    id: 16, label: '비흡연,음주없음,균형,체중',
    smoker: false, drinker: false, diet: DietHabit.balanced,
  ),
  _Archetype(
    id: 17, label: '비흡연,음주없음,채식,단백질',
    smoker: false, drinker: false, diet: DietHabit.vegetarian,
  ),
  _Archetype(
    id: 18, label: '흡연,가끔음주,균형,피로',
    smoker: true, smokingAmount: SmokingAmount.light,
    drinker: true, drinkingFrequency: DrinkingFrequency.monthly,
    diet: DietHabit.balanced, symptomId: 'sym008',
  ),
  _Archetype(
    id: 19, label: '비흡연,음주없음,육류,심혈관',
    smoker: false, drinker: false, diet: DietHabit.meat,
  ),
  _Archetype(
    id: 20, label: '비흡연,음주없음,균형,스트레스',
    smoker: false, drinker: false, diet: DietHabit.balanced,
    symptomId: 'sym034',
  ),
];

const _adultAgeKeys = <String, int>{
  'twenties': 25,
  'thirties': 35,
  'forties': 45,
  'fifties': 55,
  'elderly': 65,
};

Map<String, List<String>> _bucketize(List<RecommendationResult> results) {
  final mustTake = <String>[];
  final highly = <String>[];
  final consider = <String>[];
  for (final r in results) {
    switch (r.category) {
      case RecommendationCategory.mustTake:
        mustTake.add(r.supplementName);
        break;
      case RecommendationCategory.highlyRecommended:
        highly.add(r.supplementName);
        break;
      case RecommendationCategory.considerIf:
        consider.add(r.supplementName);
        break;
      case RecommendationCategory.alreadyTaking:
        // 캐시 생성 시점엔 currentSupplements 가 없어 alreadyTaking 가
        // 발생하지 않지만 enum exhaustive 보장을 위해 고려 섹션에 둔다.
        consider.add(r.supplementName);
        break;
    }
  }
  return {
    'must_take': mustTake,
    'highly_recommended': highly,
    'consider': consider,
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Generate recommendation cache', () async {
    final root = Directory.current.path;
    final repo = SupplementRepository();
    await repo.load(bundle: _DiskAssetBundle(root));

    final entries = <String, Map<String, List<String>>>{};

    // ─── Pre-adult tier ─────────────────────────────────────────────
    // newborn (age 0): 2 genders × 2 feeding types = 4
    for (final sex in const [Sex.male, Sex.female]) {
      for (final feeding in const [FeedingType.breastMilk, FeedingType.formula]) {
        final input = FamilyInput(
          name: 'cache',
          age: 0,
          sex: sex,
          allergies: false,
          feeding: feeding,
        );
        final r = repo.getRecommendations(input);
        entries['newborn_${sex.storage}_${feeding.storage}'] = _bucketize(r);
      }
    }

    // toddler (age 4): 2 genders × picky yes/no = 4
    for (final sex in const [Sex.male, Sex.female]) {
      for (final picky in const [false, true]) {
        final input = FamilyInput(
          name: 'cache',
          age: 4,
          sex: sex,
          pickyEating: picky,
        );
        final r = repo.getRecommendations(input);
        final tag = picky ? 'yes' : 'no';
        entries['toddler_${sex.storage}_picky_$tag'] = _bucketize(r);
      }
    }

    // child (age 10): 2 genders × picky yes/no = 4
    for (final sex in const [Sex.male, Sex.female]) {
      for (final picky in const [false, true]) {
        final input = FamilyInput(
          name: 'cache',
          age: 10,
          sex: sex,
          diet: DietHabit.balanced,
          pickyEating: picky,
          exercise: ExerciseLevel.sometimes,
        );
        final r = repo.getRecommendations(input);
        final tag = picky ? 'yes' : 'no';
        entries['child_${sex.storage}_picky_$tag'] = _bucketize(r);
      }
    }

    // teen (age 16): 2 genders × stress low/high = 4
    for (final sex in const [Sex.male, Sex.female]) {
      for (final stress in const [StressLevel.low, StressLevel.high]) {
        final input = FamilyInput(
          name: 'cache',
          age: 16,
          sex: sex,
          diet: DietHabit.balanced,
          exercise: ExerciseLevel.sometimes,
          sleep: SleepHours.sevenEight,
          stress: stress,
        );
        final r = repo.getRecommendations(input);
        entries['teen_${sex.storage}_stress_${stress.storage}'] =
            _bucketize(r);
      }
    }

    // ─── Adult tier ─────────────────────────────────────────────────
    // 5 ages × 2 genders × 20 archetypes = 200
    for (final ageEntry in _adultAgeKeys.entries) {
      final ageKey = ageEntry.key;
      final age = ageEntry.value;
      for (final sex in const [Sex.male, Sex.female]) {
        for (final arch in _archetypes) {
          final input = FamilyInput(
            name: 'cache',
            age: age,
            sex: sex,
            smoker: arch.smoker,
            smokingAmount: arch.smoker
                ? (arch.smokingAmount ?? SmokingAmount.light)
                : null,
            drinker: arch.drinker,
            drinkingFrequency:
                arch.drinker ? arch.drinkingFrequency : null,
            diet: arch.diet,
            exercise: ExerciseLevel.sometimes,
            sleep: SleepHours.sevenEight,
            stress: StressLevel.medium,
            digestiveIssues: ageKey == 'elderly' ? false : null,
            takingMedications: ageKey == 'elderly' ? false : null,
            symptomIds:
                arch.symptomId != null ? <String>[arch.symptomId!] : null,
          );
          final r = repo.getRecommendations(input);
          entries['${ageKey}_${sex.storage}_${arch.id}'] = _bucketize(r);
        }
      }
    }

    // ─── Write output ───────────────────────────────────────────────
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final out = <String, dynamic>{
      'generated_at': today,
      'version': '1.0',
      'archetypes': _archetypes.map((a) => a.toJson()).toList(),
      'entries': entries,
    };

    final outFile = File('$root/assets/data/recommendation_cache.json');
    await outFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(out),
    );

    final size = await outFile.length();
    // ignore: avoid_print
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    // ignore: avoid_print
    print('Generated ${entries.length} cache entries');
    // ignore: avoid_print
    print('File: ${outFile.path}');
    // ignore: avoid_print
    print('Size: $size bytes (${(size / 1024).toStringAsFixed(1)} KB)');
    // ignore: avoid_print
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    expect(entries.isNotEmpty, true);
    expect(entries.length, greaterThanOrEqualTo(200));
  });
}
