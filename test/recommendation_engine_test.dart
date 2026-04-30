import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:alyak/core/data/product_repository.dart';
import 'package:alyak/core/data/supplement_repository.dart';
import 'package:alyak/features/recommendation/engine/family_input.dart';
import 'package:alyak/features/recommendation/engine/recommendation_engine.dart';

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

bool _hasSupplement(List<RecommendationResult> list, String name) {
  final n = name.toLowerCase().replaceAll(RegExp(r'[\s\-_()/+,.]'), '');
  for (final r in list) {
    final rn =
        r.supplementName.toLowerCase().replaceAll(RegExp(r'[\s\-_()/+,.]'), '');
    if (rn.contains(n) || n.contains(rn)) return true;
  }
  return false;
}

bool _isVisible(RecommendationResult r) =>
    r.category == RecommendationCategory.mustTake ||
    r.category == RecommendationCategory.highlyRecommended;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SupplementRepository supplementRepo;
  late ProductRepository productRepo;
  late RecommendationEngine engine;

  setUpAll(() async {
    final root = Directory.current.path;
    final bundle = _DiskAssetBundle(root);
    supplementRepo = SupplementRepository();
    await supplementRepo.load(bundle: bundle);
    await supplementRepo.loadCache(bundle: bundle);
    productRepo = ProductRepository();
    await productRepo.load(bundle: bundle);
    engine = RecommendationEngine(
      repository: supplementRepo,
      productRepository: productRepo,
    );
  });

  test('어린이는 유산균/철분/비타민D가 추천에 포함된다', () {
    final input = FamilyInput(
      name: '아이',
      age: 10,
      sex: Sex.male,
      diet: DietHabit.balanced,
      pickyEating: false,
      exercise: ExerciseLevel.sometimes,
    );
    final result = engine.recommend(input);
    expect(_hasSupplement(result, '유산균'), isTrue,
        reason: '어린이 추천에 유산균이 있어야 한다');
    expect(_hasSupplement(result, '철분'), isTrue,
        reason: '어린이 추천에 철분이 있어야 한다');
    expect(_hasSupplement(result, '비타민D'), isTrue,
        reason: '어린이 추천에 비타민D가 있어야 한다');
  });

  test('흡연자는 비타민C 추천이 visible 카테고리에 들어간다', () {
    final input = FamilyInput(
      name: '흡연',
      age: 35,
      sex: Sex.male,
      smoker: true,
      smokingAmount: SmokingAmount.heavy,
      drinker: false,
      diet: DietHabit.balanced,
      exercise: ExerciseLevel.sometimes,
      sleep: SleepHours.sevenEight,
      stress: StressLevel.medium,
    );
    final result = engine.recommend(input);
    final visibleVitC = result
        .where((r) => _isVisible(r))
        .any((r) => _hasSupplement([r], '비타민C'));
    expect(visibleVitC, isTrue,
        reason: '흡연자에게 비타민C가 visible 추천에 있어야 한다');
  });

  test('자주 음주는 밀크씨슬을 visible 추천에 포함한다', () {
    // takingMedications: false 로는 캐시가 archetype id 만으로 매칭되어
    // drinkingFrequency 신호가 묻힐 수 있다. 캐시 우회로 boost 경로를 직접
    // 검증하기 위해 takingMedications=true 로 강제.
    final input = FamilyInput(
      name: '음주',
      age: 40,
      sex: Sex.male,
      smoker: false,
      drinker: true,
      drinkingFrequency: DrinkingFrequency.frequent,
      diet: DietHabit.meat,
      exercise: ExerciseLevel.sometimes,
      sleep: SleepHours.sevenEight,
      stress: StressLevel.medium,
      takingMedications: true,
    );
    final result = engine.recommend(input);
    expect(_hasSupplement(result, '밀크씨슬'), isTrue,
        reason: '잦은 음주에 밀크씨슬이 추천 리스트에 있어야 한다');
  });

  test('임신 중에는 엽산/철분/DHA 가 must_take 로 추천된다', () {
    final input = FamilyInput(
      name: '임산부',
      age: 32,
      sex: Sex.female,
      smoker: false,
      drinker: false,
      diet: DietHabit.balanced,
      exercise: ExerciseLevel.sometimes,
      sleep: SleepHours.sevenEight,
      stress: StressLevel.medium,
      specialCondition: SpecialCondition.pregnant,
    );
    final result = engine.recommend(input);
    bool isMustTake(String name) {
      for (final r in result) {
        if (r.category != RecommendationCategory.mustTake) continue;
        if (_hasSupplement([r], name)) return true;
      }
      return false;
    }

    expect(isMustTake('엽산'), isTrue, reason: '임신 중 엽산은 must_take');
    expect(isMustTake('철분'), isTrue, reason: '임신 중 철분은 must_take');
    expect(isMustTake('DHA') || isMustTake('오메가3'), isTrue,
        reason: '임신 중 DHA/오메가3 는 must_take');
  });

  test('currentProductIds 가 있으면 alreadyTaking 으로 강등된다', () {
    // p001 (센트룸 우먼) — 종합비타민 카테고리, 비타민D 400 IU 등 포함.
    final base = FamilyInput(
      name: '복용중',
      age: 30,
      sex: Sex.female,
      smoker: false,
      drinker: false,
      diet: DietHabit.balanced,
      exercise: ExerciseLevel.sometimes,
      sleep: SleepHours.sevenEight,
      stress: StressLevel.high,
      currentSupplements: const ['종합비타민'],
      currentProductIds: const ['p001'],
    );
    final result = engine.recommend(base);
    // currentSupplements 매칭으로 종합비타민이 alreadyTaking 으로 가야 함.
    final anyAlreadyTaking = result
        .any((r) => r.category == RecommendationCategory.alreadyTaking);
    expect(anyAlreadyTaking, isTrue,
        reason: 'currentSupplements/currentProductIds 가 있을 때 alreadyTaking 항목이 있어야 한다');
  });

  test('유아 (toddler) 는 visible 추천이 cap (3개) 이내', () {
    final input = FamilyInput(
      name: '유아',
      age: 4,
      sex: Sex.female,
      pickyEating: true,
    );
    final result = engine.recommend(input);
    final visibleCount = result.where(_isVisible).length;
    expect(visibleCount, lessThanOrEqualTo(3),
        reason: '유아 visible 추천은 3개 이하여야 한다');
  });

  test('알레르기 (생선) 가 있으면 오메가3 가 considerIf 로 강등 + note', () {
    final input = FamilyInput(
      name: '알레르기',
      age: 35,
      sex: Sex.female,
      smoker: false,
      drinker: false,
      diet: DietHabit.balanced,
      exercise: ExerciseLevel.sometimes,
      sleep: SleepHours.sevenEight,
      stress: StressLevel.medium,
      allergyItems: const ['생선'],
      takingMedications: true, // 캐시 우회 → boost 로 오메가3 들어가도록
    );
    final result = engine.recommend(input);
    final omega = result.firstWhere(
      (r) => r.supplementName.toLowerCase().contains('오메가') ||
          r.supplementName.toLowerCase().contains('omega'),
      orElse: () => const RecommendationResult(
        supplementName: '',
        category: RecommendationCategory.considerIf,
        reason: '',
        priority: 999,
      ),
    );
    if (omega.supplementName.isNotEmpty) {
      expect(omega.category, RecommendationCategory.considerIf,
          reason: '생선 알레르기 → 오메가3 (어유) 는 considerIf 로 강등');
      expect(omega.note, contains('알레르기'),
          reason: 'note 에 알레르기 안내가 들어가야 한다');
    }
  });

  test('영아(newborn) 는 화이트리스트(비타민D/유산균/DHA)외 항목 노출 안 됨', () {
    final input = FamilyInput(
      name: '영아',
      age: 0,
      sex: Sex.female,
      allergies: false,
      feeding: FeedingType.breastMilk,
    );
    final result = engine.recommend(input);
    const allowed = ['비타민d', '유산균', '프로바이오틱스', '오메가3', 'dha'];
    for (final r in result) {
      final n = r.supplementName
          .toLowerCase()
          .replaceAll(RegExp(r'[\s\-_()/+,.]'), '');
      final isAllowed =
          allowed.any((w) => n.contains(w) || w.contains(n));
      expect(isAllowed, isTrue,
          reason: '영아 노출 항목은 화이트리스트만이어야 한다 (현재: ${r.supplementName})');
    }
  });

  test('recommendWithOutput 은 currentIntake/profile/cap 을 함께 돌려준다', () {
    final input = FamilyInput(
      name: '풀출력',
      age: 35,
      sex: Sex.male,
      smoker: false,
      drinker: false,
      diet: DietHabit.balanced,
      exercise: ExerciseLevel.sometimes,
      sleep: SleepHours.sevenEight,
      stress: StressLevel.medium,
      currentProductIds: const ['p001'],
    );
    final out = engine.recommendWithOutput(input);
    expect(out.results, isNotEmpty);
    expect(out.currentIntake, isNotEmpty,
        reason: 'currentProductIds 가 있을 때 currentIntake 합산이 있어야 한다');
    expect(out.profileMatched, equals('adult_male'));
    expect(out.capsApplied, equals(6));
  });
}
