import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/models/recommendation_result.dart';
import '../../../core/data/nutrient_targets.dart';
import '../../../core/data/product_repository.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../family/providers/family_members_provider.dart';
import '../../recommendation/engine/family_input.dart';
import '../../recommendation/engine/recommendation_engine.dart';
import '../../recommendation/providers/recommendation_providers.dart';

/// "지금 먹는 것 점검" — 사용자가 현재 등록한 영양제(currentProductIds) 를
/// 빠르게 분석해 보여준다. 4 섹션:
///   1. 현재 복용 중인 제품 카드 리스트
///   2. 충분히 챙기는 영양소 (적정 ratio 80~120%)
///   3. 충돌 / 과다 / 흡수 방해 경고
///   4. 추가로 필요한 영양소 (간단 — 1~3개만)
class CurrentCheckScreen extends ConsumerWidget {
  const CurrentCheckScreen({required this.memberId, super.key});

  final String memberId;
  static const routeName = '/current-check';
  static String pathFor(String id) => '$routeName/$id';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(familyMembersProvider);
    final productRepoAsync = ref.watch(productRepositoryProvider);
    final engineAsync = ref.watch(recommendationEngineProvider);
    final matcherAsync = ref.watch(productMatcherProvider);
    final conflictAsync = ref.watch(conflictCheckerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('현재 영양제 점검')),
      body: membersAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.primary),
        ),
        error: (e, _) => _Error(message: e.toString()),
        data: (members) {
          final member = members.firstWhere(
            (m) => m.id == memberId,
            orElse: () => members.isNotEmpty
                ? members.first
                : throw StateError('member not found'),
          );
          if (productRepoAsync.isLoading ||
              engineAsync.isLoading ||
              matcherAsync.isLoading ||
              conflictAsync.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            );
          }
          if (productRepoAsync.hasError) {
            return _Error(message: productRepoAsync.error.toString());
          }

          final productRepo = productRepoAsync.requireValue;
          final engine = engineAsync.requireValue;
          final matcher = matcherAsync.requireValue;
          final conflictChecker = conflictAsync.requireValue;

          final productIds = member.input.currentProductIds ?? const <String>[];
          final products = <Product>[];
          for (final id in productIds) {
            final p = productRepo.getById(id);
            if (p != null) products.add(p);
          }

          // 추천 결과 (전체 파이프라인) — 부족 영양소와 covered 분석에 사용.
          final out = engine.recommendWithOutput(member.input);

          final overdoseWarnings =
              conflictChecker.checkProductCombination(productIds);
          final supplementWarnings =
              conflictChecker.checkSupplementConflicts(
            out.results
                .where((r) =>
                    r.category == RecommendationCategory.mustTake ||
                    r.category == RecommendationCategory.highlyRecommended)
                .map((r) => r.supplementName)
                .toList(),
          );
          final allWarnings = [...overdoseWarnings, ...supplementWarnings];

          // matcher 는 status 분석에 직접 활용 (적정 점수 계산).
          // ignore: unused_local_variable
          final _ = matcher; // 향후 추천 제품 미니 카드 추가 자리.

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _Header(name: member.name, productCount: products.length),
              const SizedBox(height: 16),
              _CurrentProductsSection(
                memberId: member.id,
                products: products,
              ),
              const SizedBox(height: 24),
              _CoveredNutrientsSection(
                products: products,
                input: member.input,
              ),
              const SizedBox(height: 24),
              _ConflictsSection(warnings: allWarnings),
              const SizedBox(height: 24),
              _GapsSection(
                gaps: out.results
                    .where((r) =>
                        (r.category == RecommendationCategory.mustTake ||
                            r.category ==
                                RecommendationCategory.highlyRecommended) &&
                        (r.nutrientStatus == null ||
                            r.nutrientStatus !=
                                NutrientStatus.appropriate))
                    .take(3)
                    .toList(),
                memberId: member.id,
              ),
              const SizedBox(height: 28),
              const _Disclaimer(),
            ],
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.name, required this.productCount});
  final String name;
  final int productCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$name님 현재 영양제',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          productCount == 0
              ? '아직 등록된 제품이 없어요'
              : '$productCount개 등록되어 있어요',
          style: const TextStyle(
            fontSize: 13,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _CurrentProductsSection extends StatelessWidget {
  const _CurrentProductsSection({
    required this.memberId,
    required this.products,
  });

  final String memberId;
  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '💊 현재 복용 중',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        if (products.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.cream,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              '등록된 제품이 없어요. 가족 정보 수정 화면에서 추가할 수 있어요',
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
          )
        else
          for (final p in products) ...[
            _ProductCard(product: p),
            const SizedBox(height: 8),
          ],
      ],
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
    final ingredientCount = product.ingredients.keys.length;
    final ingredientLabels = product.ingredients.keys
        .take(6)
        .map((k) {
      // ingredient key 를 사람이 읽을 라벨로. 매핑 없으면 underscore→space.
      final ko = productCategoryDisplayName[k];
      if (ko != null) return ko;
      return k.replaceAll(RegExp(r'_(mg|mcg|iu|billion)$'), '')
          .replaceAll('_', ' ');
    }).toList();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('💊', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  product.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${product.dailyDose}${product.unit} / 일 · ${product.packageSize}${product.unit} 한 통',
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '포함: ${ingredientLabels.join(", ")}'
            '${ingredientCount > ingredientLabels.length ? " 등 $ingredientCount종" : ""}',
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _CoveredNutrientsSection extends StatelessWidget {
  const _CoveredNutrientsSection({
    required this.products,
    required this.input,
  });

  final List<Product> products;
  final FamilyInput input;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) return const SizedBox.shrink();

    final intake = <String, double>{};
    for (final p in products) {
      for (final e in p.dailyIngredients.entries) {
        intake[e.key] = (intake[e.key] ?? 0) + e.value;
      }
    }

    // 권장량 대비 80% 이상 채워진 영양소만 표기. 권장량은 nutrient_targets 의
    // 핵심 supplement 이름으로부터 도출 (모든 영양소를 다 보여주지 않고 의미 있는
    // 11개 정도로 한정).
    const trackedKeys = <String, String>{
      'vitamin_c_mg': '비타민C',
      'vitamin_d_iu': '비타민D',
      'vitamin_e_mg': '비타민E',
      'vitamin_b1_mg': '비타민B1',
      'vitamin_b6_mg': '비타민B6',
      'vitamin_b12_mcg': '비타민B12',
      'vitamin_b9_mcg': '엽산',
      'calcium_mg': '칼슘',
      'magnesium_mg': '마그네슘',
      'iron_mg': '철분',
      'zinc_mg': '아연',
      'omega3_total_mg': '오메가3',
      'probiotics_cfu_billion': '유산균',
    };

    // nutrient_targets 의 supplement → ingredient 매핑을 역으로 활용.
    // 각 ingredient 의 recommended (target) 을 가져오기 위해 supplement name
    // (한글) 으로 targetsForSupplements 호출.
    final targets = targetsForSupplements(trackedKeys.values.toList());

    final covered = <(String label, double pct)>[];
    targets.forEach((key, target) {
      final cur = intake[key] ?? 0;
      if (target <= 0) return;
      final pct = (cur / target * 100).clamp(0.0, 999.0);
      if (pct >= 80) {
        covered.add((trackedKeys[key] ?? key, pct));
      }
    });
    covered.sort((a, b) => b.$2.compareTo(a.$2));

    if (covered.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '✅ 충분히 챙기는 영양소',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        for (final (label, pct) in covered)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '· $label  (${pct.toStringAsFixed(0)}% 충족)',
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
      ],
    );
  }
}

class _ConflictsSection extends StatelessWidget {
  const _ConflictsSection({required this.warnings});
  final List<ConflictWarning> warnings;

  @override
  Widget build(BuildContext context) {
    if (warnings.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            Text('✨', style: TextStyle(fontSize: 22)),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                '잘 드시고 계세요. 큰 문제 없어요',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '⚠️ 충돌 / 과다 경고',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppTheme.warning,
          ),
        ),
        const SizedBox(height: 10),
        for (final w in warnings) ...[
          _ConflictCard(warning: w),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _ConflictCard extends StatelessWidget {
  const _ConflictCard({required this.warning});
  final ConflictWarning warning;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            warning.message,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
              height: 1.45,
            ),
          ),
          if (warning.recommendation.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              warning.recommendation,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GapsSection extends StatelessWidget {
  const _GapsSection({required this.gaps, required this.memberId});
  final List<RecommendationResult> gaps;
  final String memberId;

  @override
  Widget build(BuildContext context) {
    if (gaps.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '❌ 추가로 필요해요',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        for (final r in gaps)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '· ${r.supplementName}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                if (r.reason.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 12, top: 2),
                    child: Text(
                      r.reason,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 6),
        OutlinedButton(
          onPressed: () => context.push('/family/$memberId/recommendations'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(44),
            side: const BorderSide(color: AppTheme.primary),
            foregroundColor: AppTheme.primary,
          ),
          child: const Text(
            '영양제 새로 사고 싶어요 →',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _Disclaimer extends StatelessWidget {
  const _Disclaimer();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        AppStrings.disclaimerMain,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 11,
          color: AppTheme.textSecondary.withValues(alpha: 0.8),
          height: 1.5,
        ),
      ),
    );
  }
}

class _Error extends StatelessWidget {
  const _Error({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Center(
        child: Text(
          '데이터를 불러오지 못했어요\n$message',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            color: AppTheme.textSecondary,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}
