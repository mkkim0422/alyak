import '../../../core/data/models/conflict_warning.dart';
import '../../../core/data/nutrient_targets.dart';
import '../../../core/data/product_repository.dart';
import '../../../core/data/supplement_repository.dart';

/// 영양제 간 충돌, 약물 상호작용, 그리고 제품 합산 시 영양소 과다를
/// 일관된 [ConflictWarning] 리스트로 반환한다.
///
/// SupplementRepository.checkConflicts 가 이미 supplement-supplement /
/// supplement-medication / overdose 세 종류를 처리하므로, 이 클래스는
/// (a) 제품 ID 입력 → 영양소 합산 → 과다 검사 와 (b) 두 가지 입력 (이름 / 제품)
/// 을 합쳐 하나의 결과로 묶는 wrapper 역할을 한다.
class ConflictChecker {
  ConflictChecker({
    required this.repository,
    this.productRepository,
  });

  final SupplementRepository repository;
  final ProductRepository? productRepository;

  /// 영양제 이름 리스트만으로 충돌 검사.
  List<ConflictWarning> checkSupplementConflicts(
    List<String> supplementNames, {
    List<String> medicationCategories = const [],
  }) {
    return repository.checkConflicts(supplementNames, medicationCategories);
  }

  /// 영양제 합산 + 현재 섭취량 (currentIntake) 으로 과다 검사.
  ///
  /// nutrient_targets 에 매핑된 영양소만 대상이며, 영양제 간 합 + currentIntake
  /// 합계가 권장량의 150% 를 넘으면 [ConflictKind.overdoseRisk] 경고.
  List<ConflictWarning> checkOverdose(
    List<String> supplementNames,
    Map<String, double> currentIntake,
  ) {
    final targets = targetsForSupplements(supplementNames);
    if (targets.isEmpty) return const [];

    final out = <ConflictWarning>[];
    for (final entry in targets.entries) {
      final key = entry.key;
      final target = entry.value;
      if (target <= 0) continue;
      final cur = currentIntake[key] ?? 0;
      // 추천된 영양제로부터의 1일 섭취량은 권장량 자체로 가정 (사용자가 추천을
      // 모두 권장량대로 복용한다는 conservative 가정).
      final total = cur + target;
      if (total <= target * 1.5) continue;
      final pct = ((total / target) * 100).round();
      out.add(ConflictWarning(
        kind: ConflictKind.overdoseRisk,
        severity: ConflictSeverity.caution,
        supplementA: supplementNames.isNotEmpty ? supplementNames.first : key,
        nutrient: key,
        message:
            '$key 합산 섭취량이 권장량의 $pct% 로 과다 가능성이 있어요',
        recommendation: '제품 성분표를 확인해 $key 합산 용량을 조정해 주세요',
      ));
    }
    return out;
  }

  /// 제품 ID 리스트만으로 영양소 과다 + 카테고리 중복 검사.
  List<ConflictWarning> checkProductCombination(List<String> productIds) {
    final repo = productRepository;
    if (repo == null || productIds.isEmpty) return const [];

    final intake = <String, double>{};
    final productNames = <String>[];
    final categoryCount = <String, int>{};
    for (final id in productIds) {
      final p = repo.getById(id);
      if (p == null) continue;
      productNames.add(p.name);
      categoryCount[p.category] = (categoryCount[p.category] ?? 0) + 1;
      for (final e in p.dailyIngredients.entries) {
        intake[e.key] = (intake[e.key] ?? 0) + e.value;
      }
    }
    if (intake.isEmpty) return const [];

    final out = <ConflictWarning>[];

    // 카테고리 중복 (같은 종합비타민 2개, 오메가3 2개 등).
    for (final entry in categoryCount.entries) {
      if (entry.value < 2) continue;
      final label = productCategoryDisplayName[entry.key] ?? entry.key;
      out.add(ConflictWarning(
        kind: ConflictKind.overdoseRisk,
        severity: ConflictSeverity.caution,
        supplementA: label,
        message: '$label 카테고리 제품을 ${entry.value}개 동시에 드시면 영양소 과다 가능성이 있어요',
        recommendation: '같은 카테고리는 1개만 유지하시는 게 안전해요',
      ));
    }

    // 영양소 과다 검사 — nutrient_targets 의 모든 키 대상.
    const safeUpper = <String, double>{
      'vitamin_a_mcg': 3000,
      'vitamin_c_mg': 2000,
      'vitamin_d_iu': 4000,
      'vitamin_e_mg': 540,
      'vitamin_b6_mg': 100,
      'vitamin_b9_mcg': 1000,
      'calcium_mg': 2500,
      'magnesium_mg': 350,
      'iron_mg': 45,
      'zinc_mg': 35,
      'selenium_mcg': 400,
    };
    for (final entry in intake.entries) {
      final upper = safeUpper[entry.key];
      if (upper == null) continue;
      if (entry.value <= upper) continue;
      out.add(ConflictWarning(
        kind: ConflictKind.overdoseRisk,
        severity: ConflictSeverity.warning,
        supplementA: productNames.isNotEmpty ? productNames.first : entry.key,
        nutrient: entry.key,
        message: '${entry.key} 1일 합산이 ${entry.value.toStringAsFixed(0)} 로 상한선 ($upper) 을 넘어요',
        recommendation: '제품을 줄이거나 의사·약사와 상담 후 복용하세요',
      ));
    }

    return out;
  }
}
