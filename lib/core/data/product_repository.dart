import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 단일 보충제 제품 — `assets/data/products.json` 한 항목과 1:1 매핑된다.
///
/// `ingredients` 는 1 unit (정/캡슐/포) 기준 영양소 함량이고,
/// 1일 섭취 기준은 `dailyIngredients` getter 에서 `daily_dose` 를 곱해 계산한다.
class Product {
  final String id;
  final String name;
  final String brandType; // brand | generic | store_brand
  final String category;
  final int pricePerUnitKrw;
  final String unit;
  final int dailyDose;
  final int packageSize;
  final int packagePriceKrw;
  final Map<String, double> ingredients;
  final List<String> goodFor;
  final List<String> alternatives;
  final String notes;

  const Product({
    required this.id,
    required this.name,
    required this.brandType,
    required this.category,
    required this.pricePerUnitKrw,
    required this.unit,
    required this.dailyDose,
    required this.packageSize,
    required this.packagePriceKrw,
    required this.ingredients,
    required this.goodFor,
    required this.alternatives,
    required this.notes,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    final ing = (json['ingredients'] as Map<String, dynamic>? ?? const {});
    return Product(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      brandType: json['brand_type'] as String? ?? 'brand',
      category: json['category'] as String? ?? '',
      pricePerUnitKrw: (json['price_per_unit_krw'] as num?)?.toInt() ?? 0,
      unit: json['unit'] as String? ?? '정',
      dailyDose: (json['daily_dose'] as num?)?.toInt() ?? 1,
      packageSize: (json['package_size'] as num?)?.toInt() ?? 0,
      packagePriceKrw: (json['package_price_krw'] as num?)?.toInt() ?? 0,
      ingredients: {
        for (final e in ing.entries) e.key: (e.value as num).toDouble(),
      },
      goodFor: (json['good_for'] as List? ?? const [])
          .map((e) => e.toString())
          .toList(),
      alternatives: (json['alternatives'] as List? ?? const [])
          .map((e) => e.toString())
          .toList(),
      notes: json['notes'] as String? ?? '',
    );
  }

  /// 1일 복용 기준 영양소 합 (= ingredients * daily_dose).
  Map<String, double> get dailyIngredients => {
        for (final e in ingredients.entries) e.key: e.value * dailyDose,
      };

  /// 1일 복용 기준 비용 (원).
  int get dailyCostKrw => pricePerUnitKrw * dailyDose;
}

/// 1~maxProducts 개 제품 묶음 — 부족 영양소를 함께 채우는 후보.
class ProductCombo {
  final List<Product> products;
  final Map<String, double> totalCoverage; // 영양소별 커버 % (>100 가능)
  final List<String> missingNutrients; // 100% 미만으로 남은 영양소
  final int totalDailyCostKrw;
  final int productCount;

  const ProductCombo({
    required this.products,
    required this.totalCoverage,
    required this.missingNutrients,
    required this.totalDailyCostKrw,
    required this.productCount,
  });

  /// 모든 영양소의 평균 커버리지. 한 영양소 100% 초과는 100% 로 캡 (오버슈팅 점수 방지).
  double get averageCoverage {
    if (totalCoverage.isEmpty) return 0;
    double sum = 0;
    for (final v in totalCoverage.values) {
      final capped = v > 100 ? 100.0 : (v < 0 ? 0.0 : v);
      sum += capped;
    }
    return sum / totalCoverage.length;
  }
}

/// `assets/data/products.json` 을 로드하고 제품 추천/검색/대체 조회를 제공.
///
/// 주요 메서드:
///   • [findOptimalCombos] — 부족 영양소를 가장 적은 수의 제품으로 채우는 조합
///   • [findAlternatives] — 같은 카테고리의 대체 제품 (1일 비용 오름차순)
///   • [getByCategory] / [search] / [getById]
class ProductRepository {
  static const _asset = 'assets/data/products.json';

  List<Product> _products = const [];
  bool _loaded = false;

  bool get isLoaded => _loaded;
  List<Product> get products => List.unmodifiable(_products);

  Future<void> load({AssetBundle? bundle}) async {
    if (_loaded) return;
    final assetBundle = bundle ?? rootBundle;
    final raw = await assetBundle.loadString(_asset);
    final j = json.decode(raw) as Map<String, dynamic>;
    _products = (j['products'] as List<dynamic>? ?? const [])
        .map((e) => Product.fromJson(e as Map<String, dynamic>))
        .toList();
    _loaded = true;
  }

  // ──────────────────────────────────────────────────────────────────────
  // findOptimalCombos
  // ──────────────────────────────────────────────────────────────────────

  /// 부족 영양소를 채우는 제품 조합을 1~[maxProducts] 개까지 탐색해
  /// 상위 3개를 반환한다.
  ///
  /// 알고리즘:
  ///   1) gap = max(0, needed - current) 계산. gap 이 비면 빈 리스트.
  ///   2) 단일 제품 후보 평가 — 평균 커버리지 ≥ 70% 이면 그대로 종료.
  ///   3) 부족하면 2개 조합, 그래도 부족하면 3개 조합 (단, maxProducts 까지).
  ///   4) 정렬 키: 평균 커버리지 desc → 제품 수 asc → 1일 비용 asc.
  List<ProductCombo> findOptimalCombos({
    required Map<String, double> neededNutrients,
    required Map<String, double> currentIntake,
    int maxProducts = 3,
  }) {
    _ensureLoaded();
    if (maxProducts < 1) return const [];

    final gap = <String, double>{};
    for (final e in neededNutrients.entries) {
      final cur = currentIntake[e.key] ?? 0;
      final need = e.value - cur;
      if (need > 0) gap[e.key] = need;
    }
    if (gap.isEmpty) return const [];

    // gap 영양소를 단 1g 이라도 가진 제품만 후보로 추린다.
    final relevant = <Product>[];
    for (final p in _products) {
      final daily = p.dailyIngredients;
      final hits = gap.keys.any((k) => (daily[k] ?? 0) > 0);
      if (hits) relevant.add(p);
    }
    if (relevant.isEmpty) return const [];

    final candidates = <ProductCombo>[];

    // k = 1
    for (final p in relevant) {
      candidates.add(_buildCombo([p], gap));
    }

    bool stillNeedMore() {
      candidates.sort(_compareCombos);
      return candidates.first.averageCoverage < 70;
    }

    // k = 2
    if (maxProducts >= 2 && stillNeedMore()) {
      for (var i = 0; i < relevant.length; i++) {
        for (var j = i + 1; j < relevant.length; j++) {
          candidates.add(_buildCombo([relevant[i], relevant[j]], gap));
        }
      }
    }

    // k = 3
    if (maxProducts >= 3 && stillNeedMore()) {
      for (var i = 0; i < relevant.length; i++) {
        for (var j = i + 1; j < relevant.length; j++) {
          for (var k = j + 1; k < relevant.length; k++) {
            candidates.add(_buildCombo(
              [relevant[i], relevant[j], relevant[k]],
              gap,
            ));
          }
        }
      }
    }

    candidates.sort(_compareCombos);
    return candidates.take(3).toList();
  }

  ProductCombo _buildCombo(List<Product> picks, Map<String, double> gap) {
    final coverage = <String, double>{};
    final missing = <String>[];
    int cost = 0;
    for (final n in gap.keys) {
      double sum = 0;
      for (final p in picks) {
        sum += p.dailyIngredients[n] ?? 0;
      }
      final pct = (sum / gap[n]!) * 100;
      coverage[n] = pct;
      if (pct < 100) missing.add(n);
    }
    for (final p in picks) {
      cost += p.dailyCostKrw;
    }
    return ProductCombo(
      products: List.unmodifiable(picks),
      totalCoverage: coverage,
      missingNutrients: missing,
      totalDailyCostKrw: cost,
      productCount: picks.length,
    );
  }

  int _compareCombos(ProductCombo a, ProductCombo b) {
    final cov = b.averageCoverage.compareTo(a.averageCoverage);
    if (cov != 0) return cov;
    final cnt = a.productCount.compareTo(b.productCount);
    if (cnt != 0) return cnt;
    return a.totalDailyCostKrw.compareTo(b.totalDailyCostKrw);
  }

  // ──────────────────────────────────────────────────────────────────────
  // findAlternatives / getByCategory / search / getById
  // ──────────────────────────────────────────────────────────────────────

  /// 같은 카테고리의 대체 제품을 1일 비용 오름차순으로 반환. 자기 자신 제외.
  List<Product> findAlternatives(String productId) {
    _ensureLoaded();
    Product? source;
    for (final p in _products) {
      if (p.id == productId) {
        source = p;
        break;
      }
    }
    if (source == null) return const [];

    final list = _products
        .where((p) => p.id != productId && p.category == source!.category)
        .toList();
    list.sort((a, b) => a.dailyCostKrw.compareTo(b.dailyCostKrw));
    return list;
  }

  List<Product> getByCategory(String category) {
    _ensureLoaded();
    return _products.where((p) => p.category == category).toList();
  }

  /// 이름·카테고리·brand_type 부분 매칭 (대소문자 무시). 빈 쿼리는 빈 리스트.
  List<Product> search(String query) {
    _ensureLoaded();
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return _products.where((p) {
      return p.name.toLowerCase().contains(q) ||
          p.category.toLowerCase().contains(q) ||
          p.brandType.toLowerCase().contains(q);
    }).toList();
  }

  Product? getById(String id) {
    _ensureLoaded();
    for (final p in _products) {
      if (p.id == id) return p;
    }
    return null;
  }

  void _ensureLoaded() {
    if (!_loaded) {
      throw StateError(
        'ProductRepository.load() must be called before use.',
      );
    }
  }
}

/// 앱 전역에서 single-instance 로 쓰는 ProductRepository.
/// 첫 watch 시 비동기 로드되며, supplement_repository 와 동일한 패턴.
final productRepositoryProvider =
    FutureProvider<ProductRepository>((ref) async {
  final repo = ProductRepository();
  await repo.load();
  return repo;
});
