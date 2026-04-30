import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:alyak/core/data/models/recommendation_result.dart';
import 'package:alyak/core/data/product_repository.dart';
import 'package:alyak/core/data/supplement_repository.dart';
import 'package:alyak/features/recommendation/engine/product_matcher.dart';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProductRepository productRepo;
  late SupplementRepository supplementRepo;
  late ProductMatcher matcher;

  setUpAll(() async {
    final root = Directory.current.path;
    final bundle = _DiskAssetBundle(root);
    productRepo = ProductRepository();
    await productRepo.load(bundle: bundle);
    supplementRepo = SupplementRepository();
    await supplementRepo.load(bundle: bundle);
    matcher = ProductMatcher(
      productRepository: productRepo,
      supplementRepository: supplementRepo,
    );
  });

  test('비타민D + 종합비타민 추천 시 적정/판매량/가성비 Top 3 반환', () {
    final recs = const [
      RecommendationResult(
        supplementName: '비타민D',
        category: RecommendationCategory.mustTake,
        reason: 'test',
        priority: 1,
      ),
      RecommendationResult(
        supplementName: '종합비타민',
        category: RecommendationCategory.highlyRecommended,
        reason: 'test',
        priority: 50,
      ),
    ];
    final r = matcher.findProducts(recommendations: recs);
    expect(r.appropriateTop3, isNotEmpty,
        reason: '적정 함량 Top 3 가 비어있지 않아야 한다');
    expect(r.appropriateTop3.length, lessThanOrEqualTo(3));
    expect(r.popularityTop3.length, lessThanOrEqualTo(3));
    expect(r.valueTop3.length, lessThanOrEqualTo(3));
    // 가성비 Top 3 는 카테고리 다양성 보장 — 같은 카테고리 2개 이상이면 안 됨.
    final cats = r.valueTop3.map((m) => m.product.category).toSet();
    expect(cats.length, equals(r.valueTop3.length),
        reason: '가성비 Top 3 는 서로 다른 카테고리여야 한다');
  });

  test('alreadyTaking 만 들어있으면 매치 결과는 비어있다', () {
    final recs = const [
      RecommendationResult(
        supplementName: '비타민D',
        category: RecommendationCategory.alreadyTaking,
        reason: 'test',
        priority: 100,
      ),
    ];
    final r = matcher.findProducts(recommendations: recs);
    expect(r.isEmpty, isTrue);
  });
}
