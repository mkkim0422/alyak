import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/product_repository.dart';
import '../../../core/data/supplement_repository.dart';
import '../engine/conflict_checker.dart';
import '../engine/product_matcher.dart';
import '../engine/recommendation_engine.dart';
import '../engine/schedule_engine.dart';

/// SupplementRepository / ProductRepository 가 둘 다 비동기 로드되므로,
/// 엔진 provider 도 둘이 모두 준비된 뒤에야 instance 를 반환할 수 있게 한다.

final recommendationEngineProvider =
    FutureProvider<RecommendationEngine>((ref) async {
  final supplementRepo = await ref.watch(supplementRepositoryProvider.future);
  final productRepo = await ref.watch(productRepositoryProvider.future);
  return RecommendationEngine(
    repository: supplementRepo,
    productRepository: productRepo,
  );
});

final scheduleEngineProvider = FutureProvider<ScheduleEngine>((ref) async {
  final supplementRepo = await ref.watch(supplementRepositoryProvider.future);
  return ScheduleEngine(repository: supplementRepo);
});

final productMatcherProvider = FutureProvider<ProductMatcher>((ref) async {
  final supplementRepo = await ref.watch(supplementRepositoryProvider.future);
  final productRepo = await ref.watch(productRepositoryProvider.future);
  return ProductMatcher(
    productRepository: productRepo,
    supplementRepository: supplementRepo,
  );
});

final conflictCheckerProvider = FutureProvider<ConflictChecker>((ref) async {
  final supplementRepo = await ref.watch(supplementRepositoryProvider.future);
  final productRepo = await ref.watch(productRepositoryProvider.future);
  return ConflictChecker(
    repository: supplementRepo,
    productRepository: productRepo,
  );
});
