import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:alyak/core/data/product_repository.dart';
import 'package:alyak/core/data/supplement_repository.dart';
import 'package:alyak/features/recommendation/engine/conflict_checker.dart';
import 'package:alyak/features/recommendation/engine/family_input.dart';
import 'package:alyak/features/recommendation/engine/health_checkup.dart';
import 'package:alyak/features/recommendation/engine/product_matcher.dart';
import 'package:alyak/features/recommendation/engine/recommendation_engine.dart';
import 'package:alyak/features/recommendation/engine/schedule_engine.dart';

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

bool _hasName(Iterable<RecommendationResult> list, String name) {
  final n = name.toLowerCase().replaceAll(RegExp(r'[\s\-_()/+,.]'), '');
  return list.any((r) {
    final rn = r.supplementName
        .toLowerCase()
        .replaceAll(RegExp(r'[\s\-_()/+,.]'), '');
    return rn.contains(n) || n.contains(rn);
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SupplementRepository supplementRepo;
  late ProductRepository productRepo;
  late RecommendationEngine engine;
  late ScheduleEngine scheduleEngine;
  late ProductMatcher matcher;
  late ConflictChecker conflictChecker;

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
    scheduleEngine = ScheduleEngine(repository: supplementRepo);
    matcher = ProductMatcher(
      productRepository: productRepo,
      supplementRepository: supplementRepo,
    );
    conflictChecker = ConflictChecker(
      repository: supplementRepo,
      productRepository: productRepo,
    );
  });

  test('전체 추천 흐름 (검진 결과 + 제품 매칭)', () {
    // 35세 여성, 검진 결과 LDL 높음 + 비타민D 부족.
    final input = FamilyInput(
      name: '통합테스트',
      age: 35,
      sex: Sex.female,
      smoker: false,
      drinker: true,
      drinkingFrequency: DrinkingFrequency.weekly,
      diet: DietHabit.balanced,
      exercise: ExerciseLevel.sometimes,
      sleep: SleepHours.sevenEight,
      stress: StressLevel.medium,
      currentProductIds: const ['p001'], // 센트룸 우먼
      lastCheckup: HealthCheckup(
        checkupDate: DateTime(2026, 3, 1),
        cholesterolLdl: 145,
        vitaminD: 22,
      ),
      takingMedications: false,
    );

    // Step 1: 추천 엔진이 검진 기반 항목을 must_take 로 올림.
    final out = engine.recommendWithOutput(input);
    expect(out.results, isNotEmpty);
    expect(out.profileMatched, equals('adult_female'));
    expect(out.capsApplied, equals(6));

    final allNames = out.results.map((r) => r.supplementName).toList();
    expect(_hasName(out.results, '오메가3') || _hasName(out.results, '비타민D'),
        isTrue,
        reason: '검진 결과로 오메가3/비타민D 중 하나는 추천돼야 한다 (LDL/vitD low)');

    // Step 2: 스케줄 엔진이 시간대에 배치.
    final schedule = scheduleEngine.scheduleFor(out.results);
    final totalSlotted = schedule.morning.length +
        schedule.lunch.length +
        schedule.evening.length +
        schedule.beforeSleep.length;
    expect(totalSlotted, greaterThan(0),
        reason: '추천된 영양제가 슬롯에 배치돼야 한다');

    // Step 3: 제품 매칭이 3개 카테고리 반환.
    final products = matcher.findProducts(
      recommendations: out.results,
      currentIntake: out.currentIntake,
      input: input,
    );
    expect(products.appropriateTop3.length, lessThanOrEqualTo(3));
    expect(products.popularityTop3.length, lessThanOrEqualTo(3));
    expect(products.valueTop3.length, lessThanOrEqualTo(3));

    // Step 4: 충돌 체크가 ConflictWarning 리스트를 반환 (비어있어도 OK).
    final visibleNames = out.results
        .where((r) =>
            r.category == RecommendationCategory.mustTake ||
            r.category == RecommendationCategory.highlyRecommended)
        .map((r) => r.supplementName)
        .toList();
    final warnings =
        conflictChecker.checkSupplementConflicts(visibleNames);
    expect(warnings, isA<List>(),
        reason: 'checkSupplementConflicts 는 항상 리스트 반환 (충돌 없으면 빈 리스트)');

    // Step 5: 제품 합산 과다 체크.
    final overdose =
        conflictChecker.checkProductCombination(input.currentProductIds!);
    expect(overdose, isA<List>());

    // ignore: avoid_print
    print('전체 추천 결과: ${allNames.length}개');
    // ignore: avoid_print
    print('적정 Top3: ${products.appropriateTop3.length} / '
        '판매량 Top3: ${products.popularityTop3.length} / '
        '가성비 Top3: ${products.valueTop3.length}');
  });

  test('임신 + 현재 복용 제품 통합 흐름', () {
    final input = FamilyInput(
      name: '임산부통합',
      age: 30,
      sex: Sex.female,
      smoker: false,
      drinker: false,
      diet: DietHabit.balanced,
      exercise: ExerciseLevel.sometimes,
      sleep: SleepHours.sevenEight,
      stress: StressLevel.low,
      specialCondition: SpecialCondition.pregnant,
      currentProductIds: const ['p001'],
      takingMedications: false,
    );
    final out = engine.recommendWithOutput(input);
    // 임신 special condition 으로 엽산/철분이 결과에 포함돼야 함 (mustTake 또는
    // currentProductIds 가 이미 채우는 경우 alreadyTaking).
    expect(_hasName(out.results, '엽산'), isTrue,
        reason: '임신 시 엽산이 어떤 카테고리든 추천 결과에 있어야 한다');
    expect(_hasName(out.results, '철분'), isTrue,
        reason: '임신 시 철분이 어떤 카테고리든 추천 결과에 있어야 한다');
    expect(out.currentIntake, isNotEmpty,
        reason: 'currentProductIds 가 currentIntake 로 합산돼야 한다');
  });

  test('어린이 통합 흐름 (캐시 hit + cap 3)', () {
    final input = FamilyInput(
      name: '아이통합',
      age: 4,
      sex: Sex.male,
      pickyEating: true,
    );
    final out = engine.recommendWithOutput(input);
    expect(out.profileMatched, equals('toddler_male'));
    expect(out.capsApplied, equals(3));
    final visible = out.results
        .where((r) =>
            r.category == RecommendationCategory.mustTake ||
            r.category == RecommendationCategory.highlyRecommended)
        .toList();
    expect(visible.length, lessThanOrEqualTo(3),
        reason: '유아 visible 추천은 3개 이하');
  });
}
