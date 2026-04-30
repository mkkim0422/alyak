import '../../../core/data/models/recommendation_result.dart';
import '../../../core/data/nutrient_targets.dart';
import '../../../core/data/product_repository.dart';
import '../../../core/data/supplement_repository.dart';
import 'family_input.dart';

/// 추천된 영양제(이름)를 실제 [Product] 로 매핑해 사용자가 살 만한 후보 제품을
/// 3가지 기준으로 묶어 돌려준다:
///   - appropriateTop3: 권장량 대비 적정 + 과다 위험 없는 제품 Top 3 (커버리지 우선)
///   - popularityTop3: 같은 조건 + 가장 흔히 팔리는 (대용량/저렴 단가 우선)
///   - valueTop3: 1정당 가격이 가장 저렴한 제품 (성분 묶음 1개당 1제품)
class ProductMatcher {
  ProductMatcher({
    required this.productRepository,
    required this.supplementRepository,
  });

  final ProductRepository productRepository;
  final SupplementRepository supplementRepository;

  ProductMatchResult findProducts({
    required List<RecommendationResult> recommendations,
    Map<String, double> currentIntake = const {},
    FamilyInput? input,
  }) {
    // 1) 추천 항목에서 visible (must_take/highly_recommended) 만 추려 needed 계산.
    final visibleNames = <String>[];
    for (final r in recommendations) {
      if (r.category == RecommendationCategory.mustTake ||
          r.category == RecommendationCategory.highlyRecommended) {
        visibleNames.add(r.supplementName);
      }
    }
    if (visibleNames.isEmpty) {
      return const ProductMatchResult(
        appropriateTop3: [],
        popularityTop3: [],
        valueTop3: [],
        allCandidates: [],
      );
    }

    final needed = targetsForSupplements(visibleNames);
    if (needed.isEmpty) {
      return const ProductMatchResult(
        appropriateTop3: [],
        popularityTop3: [],
        valueTop3: [],
        allCandidates: [],
      );
    }

    // 2) 후보 = needed 영양소를 1개라도 가진 제품.
    final candidates = <Product>[];
    for (final p in productRepository.products) {
      final daily = p.dailyIngredients;
      final hits = needed.keys.any((k) => (daily[k] ?? 0) > 0);
      if (hits) candidates.add(p);
    }
    if (candidates.isEmpty) {
      return const ProductMatchResult(
        appropriateTop3: [],
        popularityTop3: [],
        valueTop3: [],
        allCandidates: [],
      );
    }

    final allergies = (input?.allergyItems ?? const <String>[])
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final isPregnant = input?.specialCondition == SpecialCondition.pregnant;

    final matches = <ProductMatch>[];
    for (final p in candidates) {
      final base = _evaluate(p, needed, currentIntake);
      final safe = _applySafety(base, allergies, isPregnant);
      matches.add(safe);
    }

    // 3) 적정 함량 Top 3 — 과다 위험 없는 제품 중 커버리지 가장 높은 순.
    final appropriate = matches
        .where((m) => !m.causesOverdose)
        .toList()
      ..sort((a, b) {
        final cov = b.coverageScore.compareTo(a.coverageScore);
        if (cov != 0) return cov;
        return b.appropriateScore.compareTo(a.appropriateScore);
      });

    // 4) 판매량 Top 3 — products.json 의 popularity_rank 가 없으므로
    //    package_size desc → daily_cost asc 로 휴리스틱 (대용량 + 저렴 단가).
    final popularity = matches
        .where((m) => !m.causesOverdose)
        .toList()
      ..sort((a, b) {
        final ps = b.product.packageSize.compareTo(a.product.packageSize);
        if (ps != 0) return ps;
        return a.product.dailyCostKrw.compareTo(b.product.dailyCostKrw);
      });

    // 5) 가성비 Top 3 — 카테고리별 1제품, 1일 비용 오름차순.
    //    가성비 비교는 같은 카테고리 + 알레르기 안전 제품으로 한정.
    //    각 후보에 comparisonMethod 채워 사용자에게 비교 기준을 명시.
    final byCategory = <String, ProductMatch>{};
    final sortedByPrice = matches
        .where((m) => !m.causesOverdose)
        .where((m) => m.allergyConflict == null)
        .toList()
      ..sort((a, b) =>
          a.product.dailyCostKrw.compareTo(b.product.dailyCostKrw));
    for (final m in sortedByPrice) {
      final cat = m.product.category;
      byCategory.putIfAbsent(
        cat,
        () => m.copyWith(
          comparisonMethod:
              '${productCategoryDisplayName[cat] ?? cat} 카테고리 동일 성분 기준 1정당 비용',
        ),
      );
      if (byCategory.length >= 3) break;
    }
    final value = byCategory.values.toList();

    return ProductMatchResult(
      appropriateTop3: appropriate.take(3).toList(),
      popularityTop3: popularity.take(3).toList(),
      valueTop3: value.take(3).toList(),
      allCandidates: candidates,
    );
  }

  /// 단일 제품에 대해 커버리지 + 과다 위험 + 적정 점수 산출.
  ProductMatch _evaluate(
    Product p,
    Map<String, double> needed,
    Map<String, double> currentIntake,
  ) {
    final daily = p.dailyIngredients;
    final covered = <String>[];
    final missing = <String>[];
    double coverageSum = 0;
    int coverageCount = 0;
    bool overdose = false;
    String? warning;

    for (final entry in needed.entries) {
      final key = entry.key;
      final target = entry.value;
      final fromProduct = daily[key] ?? 0;
      final fromCurrent = currentIntake[key] ?? 0;
      final total = fromProduct + fromCurrent;
      if (target <= 0) continue;
      final ratio = (total / target).clamp(0.0, 2.0);
      coverageSum += ratio.clamp(0.0, 1.0);
      coverageCount += 1;
      if (fromProduct > 0) {
        covered.add(key);
      } else if (fromCurrent < target) {
        missing.add(key);
      }
      if (total > target * 1.5) {
        overdose = true;
        warning =
            '${_displayName(key)} 합산이 권장량의 ${((total / target) * 100).round()}% 로 과다 가능성이 있어요';
      }
    }

    final coverage = coverageCount == 0 ? 0.0 : coverageSum / coverageCount;
    // 적정 점수: 0~1. 모든 영양소 합산이 target 의 80~120% 안에 있을수록 높음.
    double appropriateScore = 0;
    int aprCount = 0;
    for (final entry in needed.entries) {
      final fromProduct = daily[entry.key] ?? 0;
      final fromCurrent = currentIntake[entry.key] ?? 0;
      final total = fromProduct + fromCurrent;
      if (entry.value <= 0) continue;
      final ratio = total / entry.value;
      double score;
      if (ratio >= 0.8 && ratio <= 1.2) {
        score = 1.0;
      } else if (ratio < 0.8) {
        score = ratio / 0.8; // 0~1
      } else {
        // ratio > 1.2 → 점수 빠르게 감소.
        score = (2.0 - ratio).clamp(0.0, 1.0);
      }
      appropriateScore += score;
      aprCount += 1;
    }
    if (aprCount > 0) appropriateScore /= aprCount;

    return ProductMatch(
      product: p,
      coverageScore: coverage,
      coveredNutrients: covered,
      missingNutrients: missing,
      causesOverdose: overdose,
      warning: warning,
      appropriateScore: appropriateScore,
    );
  }

  /// 알레르기 / 임신 조건으로 제품에 경고 또는 차단 라벨 추가.
  /// - 알레르기: products.json 의 categorySupplementName 매핑으로 supplement
  ///   이름 도출 → guide 의 commonAllergens 와 사용자 allergies 교집합.
  /// - 임신: 카테고리 기반 차단(다이어트/카페인 함유 / 호르몬 작용 허브 카테고리).
  ProductMatch _applySafety(
    ProductMatch base,
    List<String> userAllergies,
    bool isPregnant,
  ) {
    String? allergyConflict;
    String? warning = base.warning;

    // 알레르기 검사 — 제품 카테고리 → 대표 supplement 이름 → guide 의 allergen.
    if (userAllergies.isNotEmpty) {
      final supplementName =
          productCategorySupplementName[base.product.category];
      if (supplementName != null) {
        final guide = supplementRepository.getSupplementGuide(supplementName);
        if (guide != null && guide.commonAllergens.isNotEmpty) {
          for (final ua in userAllergies) {
            for (final ga in guide.commonAllergens) {
              if (ua.contains(ga) || ga.contains(ua)) {
                allergyConflict = ga;
                warning ??= '$ga 알레르기가 있어 이 제품은 피하시는 게 좋아요';
                break;
              }
            }
            if (allergyConflict != null) break;
          }
        }
      }
    }

    // 임신 시 위험 카테고리 차단.
    bool pregnancyConflict = false;
    if (isPregnant) {
      const blocked = <String>{'diet', 'fat_burn', 'caffeine', 'herb_hormone'};
      if (blocked.contains(base.product.category)) {
        pregnancyConflict = true;
        warning ??= '임신 중에는 이 제품군은 권장하지 않아요';
      }
    }

    return base.copyWith(
      warning: warning,
      allergyConflict: allergyConflict,
      pregnancyConflict: pregnancyConflict,
    );
  }

  /// 같은 카테고리의 대체 제품 — 1일 비용 오름차순.
  List<Product> findAlternatives(String productId) {
    return productRepository.findAlternatives(productId);
  }

  String _displayName(String key) {
    final hit = productCategoryDisplayName[key];
    if (hit != null) return hit;
    // ingredient key 는 "vitamin_d_iu" 같은 snake_case 라 사람이 보기에는 부적절하지만
    // 매핑이 없는 경우의 fallback 라벨로만 쓰여 무난.
    return key.replaceAll('_', ' ');
  }
}

class ProductMatch {
  final Product product;

  /// 0.0~1.0 — needed 영양소를 product 가 몇 % 채우는지 평균.
  final double coverageScore;

  final List<String> coveredNutrients;
  final List<String> missingNutrients;

  final bool causesOverdose;
  final String? warning;

  /// 0.0~1.0 — needed 영양소 합산이 target 의 80~120% 에 있을수록 높은 점수.
  final double appropriateScore;

  /// "1순위와 동일 성분, 1정당 N% 저렴" 같은 비교 라벨. 호출 측에서 채움.
  final String? comparisonNote;

  /// 가성비 Top 3 카테고리에서만 사용 — "비타민D 1000IU 동일 함량 기준 1정당 가격"
  /// 처럼 어떤 기준으로 비교됐는지를 사용자에게 명시.
  final String? comparisonMethod;

  /// 사용자 알레르기와 충돌하는 원료가 있으면 그 원료 이름 (예: "생선").
  /// null 이면 알레르기 안전.
  final String? allergyConflict;

  /// 임신 중 권장 안 되는 카테고리(다이어트/카페인 등) 인지 여부.
  final bool pregnancyConflict;

  const ProductMatch({
    required this.product,
    required this.coverageScore,
    required this.coveredNutrients,
    required this.missingNutrients,
    required this.causesOverdose,
    this.warning,
    required this.appropriateScore,
    this.comparisonNote,
    this.comparisonMethod,
    this.allergyConflict,
    this.pregnancyConflict = false,
  });

  ProductMatch copyWith({
    Product? product,
    double? coverageScore,
    List<String>? coveredNutrients,
    List<String>? missingNutrients,
    bool? causesOverdose,
    String? warning,
    double? appropriateScore,
    String? comparisonNote,
    String? comparisonMethod,
    String? allergyConflict,
    bool? pregnancyConflict,
  }) {
    return ProductMatch(
      product: product ?? this.product,
      coverageScore: coverageScore ?? this.coverageScore,
      coveredNutrients: coveredNutrients ?? this.coveredNutrients,
      missingNutrients: missingNutrients ?? this.missingNutrients,
      causesOverdose: causesOverdose ?? this.causesOverdose,
      warning: warning ?? this.warning,
      appropriateScore: appropriateScore ?? this.appropriateScore,
      comparisonNote: comparisonNote ?? this.comparisonNote,
      comparisonMethod: comparisonMethod ?? this.comparisonMethod,
      allergyConflict: allergyConflict ?? this.allergyConflict,
      pregnancyConflict: pregnancyConflict ?? this.pregnancyConflict,
    );
  }
}

class ProductMatchResult {
  final List<ProductMatch> appropriateTop3;
  final List<ProductMatch> popularityTop3;
  final List<ProductMatch> valueTop3;
  final List<Product> allCandidates;

  const ProductMatchResult({
    required this.appropriateTop3,
    required this.popularityTop3,
    required this.valueTop3,
    required this.allCandidates,
  });

  bool get isEmpty =>
      appropriateTop3.isEmpty &&
      popularityTop3.isEmpty &&
      valueTop3.isEmpty;
}
