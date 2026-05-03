import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/shop_config.dart';
import '../../../core/data/models/conflict_warning.dart';
import '../../../core/data/models/recommendation_result.dart';
import '../../../core/data/models/schedule_result.dart';
import '../../../core/data/models/supplement_guide_model.dart';
import '../../../core/data/nutrient_targets.dart';
import '../../../core/data/product_repository.dart';
import '../../../core/data/supplement_repository.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../core/security/secure_storage.dart';
import '../../../core/theme/app_theme.dart';
import '../../home/providers/home_feed_provider.dart';
import '../../recommendation/engine/family_input.dart';
import '../../recommendation/engine/recommendation_engine.dart' as engine;
import '../../symptoms/screens/symptom_search_screen.dart';
import '../models/family_member.dart';
import 'supplement_guide_screen.dart';

class RecommendationDetailScreen extends ConsumerWidget {
  const RecommendationDetailScreen({required this.memberId, super.key});

  final String memberId;

  static const routeName = '/family/:id/recommendations';
  static String pathFor(String id) => '/family/$id/recommendations';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(homeFeedProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.recommendationTitle)),
      body: feedAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(AppStrings.recommendationLoadFailed),
          ),
        ),
        data: (entries) {
          final entry = entries.firstWhere(
            (e) => e.member.id == memberId,
            orElse: () => entries.first,
          );
          return _Body(entry: entry);
        },
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.entry});
  final HomeFeedEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final FamilyMember member = entry.member;
    final recs = entry.recommendations;
    final conflicts = entry.conflicts;

    final isChild = engine.isChildAgeGroup(member.input);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // ───── HEADER
        _Header(member: member),
        const SizedBox(height: 16),
        if (isChild) ...[
          const _ChildSectionBanner(),
          const SizedBox(height: 12),
        ],

        // ───── SECTION 1: 오늘의 영양제 스케줄
        const _SectionTitle('오늘의 영양제 스케줄'),
        const SizedBox(height: 8),
        _ScheduleSection(entry: entry),
        const SizedBox(height: 16),

        // ───── SECTION 2: 지금 드시는 영양제 (있으면)
        _CurrentlyTakingSection(member: member, recs: recs),

        // ───── SECTION 3: 부족한 영양소
        _MissingNutrientsSection(member: member, recs: recs),

        // ───── SECTION 4: 추천 제품
        _ProductRecommendationsSection(member: member, recs: recs),
        const SizedBox(height: 16),

        // ───── SECTION 5: 충돌 / 시너지
        if (entry.schedule.synergies.isNotEmpty) ...[
          const _SectionTitle('🤝 함께 드시면 좋아요'),
          const SizedBox(height: 8),
          ...entry.schedule.synergies.map((s) => _SynergyCard(synergy: s)),
          const SizedBox(height: 12),
        ],
        if (conflicts.isNotEmpty) ...[
          const _SectionTitle('⚠️ 같이 드시면 안 돼요'),
          const SizedBox(height: 8),
          ...conflicts.map((c) => _ConflictCard(conflict: c)),
          const SizedBox(height: 12),
        ],

        // ───── 보조 액션
        OutlinedButton.icon(
          onPressed: () => context.push(
            SymptomSearchScreen.pathForMember(member.id),
          ),
          icon: const Icon(Icons.search),
          label: const Text(AppStrings.homeAddSymptom),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
        ),
        const SizedBox(height: 8),
        _ReorderButton(memberId: member.id),
        const SizedBox(height: 16),

        // ───── SECTION 6: 면책
        const _Disclaimer(),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.member});
  final FamilyMember member;

  @override
  Widget build(BuildContext context) {
    final ageGroup = member.input.ageGroup;
    final ageLabel = ageGroup == null ? '' : _ageGroupKo(ageGroup);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.recommendationHeader(member.name),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (ageLabel.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    AppStrings.recommendationSubHeader(ageLabel, member.age),
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _ageGroupKo(AgeGroup g) {
    switch (g) {
      case AgeGroup.newborn:
        return AppStrings.ageLabelNewborn;
      case AgeGroup.toddler:
        return AppStrings.ageLabelToddler;
      case AgeGroup.child:
        return AppStrings.ageLabelChild;
      case AgeGroup.teen:
        return AppStrings.ageLabelTeen;
      case AgeGroup.adult:
        return AppStrings.ageLabelAdult;
      case AgeGroup.elderly:
        return AppStrings.ageLabelElderly;
    }
  }
}

class _SynergyCard extends StatelessWidget {
  const _SynergyCard({required this.synergy});
  final ScheduleSynergy synergy;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${synergy.supplementA} + ${synergy.supplementB}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              synergy.benefit,
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 4),
            Text(
              synergy.recommendation,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.subtle,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConflictCard extends StatelessWidget {
  const _ConflictCard({required this.conflict});
  final ConflictWarning conflict;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.warning.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.warning.withValues(alpha: 0.6)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('⚠️', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${conflict.supplementA}${conflict.supplementB == null ? '' : ' + ${conflict.supplementB}'} (${conflict.severityKo})',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    conflict.message,
                    style: const TextStyle(fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    conflict.recommendation,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.subtle,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Text(
        text,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.line),
      ),
      child: const Text(
        AppStrings.recommendationEmpty,
        style: TextStyle(color: AppTheme.subtle, height: 1.5),
      ),
    );
  }
}

/// "주문했어요 🛒" 버튼. SecureStorage 에 주문 시점을 기록하고 25일 뒤
/// 1회 로컬 알림을 예약. UI 는 가장 최근 주문 일자를 함께 보여 준다.
class _ReorderButton extends StatefulWidget {
  const _ReorderButton({required this.memberId});
  final String memberId;

  @override
  State<_ReorderButton> createState() => _ReorderButtonState();
}

class _ReorderButtonState extends State<_ReorderButton> {
  DateTime? _lastOrderedAt;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadLast();
  }

  Future<void> _loadLast() async {
    final raw = await SecureStorage.read(SecureStorage.reorderKey(widget.memberId));
    if (raw == null) return;
    final dt = DateTime.tryParse(raw);
    if (dt == null) return;
    if (!mounted) return;
    setState(() => _lastOrderedAt = dt);
  }

  Future<void> _markOrdered() async {
    setState(() => _saving = true);
    try {
      final now = DateTime.now();
      await SecureStorage.write(
        SecureStorage.reorderKey(widget.memberId),
        now.toIso8601String(),
      );
      await NotificationService.scheduleReorderReminder(
        memberId: widget.memberId,
      );
      if (!mounted) return;
      setState(() => _lastOrderedAt = now);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(AppStrings.recommendationOrderSnack),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final last = _lastOrderedAt;
    final subtitle = last == null
        ? null
        : AppStrings.reorderLastDate(last.year, last.month, last.day);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: _saving ? null : _markOrdered,
          icon: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('🛒', style: TextStyle(fontSize: 16)),
          label: const Text(AppStrings.recommendationOrdered),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            side: const BorderSide(color: AppTheme.line),
            foregroundColor: AppTheme.ink,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: AppTheme.subtle),
          ),
        ],
      ],
    );
  }
}

class _ChildSectionBanner extends StatelessWidget {
  const _ChildSectionBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
      ),
      child: const Row(
        children: [
          Text('💚', style: TextStyle(fontSize: 18)),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '우리 아이 영양제',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primary,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  '핵심 항목 위주로 추렸어요',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.subtle,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Disclaimer extends StatelessWidget {
  const _Disclaimer();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.danger.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.danger.withValues(alpha: 0.4)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber, color: AppTheme.danger, size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              AppStrings.recommendationDisclaimer,
              style: TextStyle(fontSize: 12, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

/// "💊 이런 제품 어떠세요?" 섹션.
///
/// 1) 추천 영양제 이름 → 1일 목표 영양소 맵으로 변환 (`targetsForSupplements`)
/// 2) 사용자가 선택한 제품 합산 영양소 (`getCurrentNutrientIntake`) 차감
/// 3) `findOptimalCombos` 호출 → 상위 3 조합을 1순위/2순위/3순위 카드로 노출
///
/// 입력 미응답 / 부족 영양소 0 인 케이스도 각각 다른 안내로 처리.
class _ProductRecommendationsSection extends ConsumerWidget {
  const _ProductRecommendationsSection({
    required this.member,
    required this.recs,
  });

  final FamilyMember member;
  final List<RecommendationResult> recs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repoAsync = ref.watch(productRepositoryProvider);
    if (!repoAsync.hasValue) return const SizedBox.shrink();
    final repo = repoAsync.requireValue;

    // alreadyTaking 은 이미 챙기고 있으니 gap 계산에서 제외.
    final visibleNames = recs
        .where((r) => r.category != RecommendationCategory.alreadyTaking)
        .map((r) => r.supplementName)
        .toList();
    if (visibleNames.isEmpty) return const SizedBox.shrink();

    final targets = targetsForSupplements(visibleNames);
    if (targets.isEmpty) return const SizedBox.shrink();

    final current = member.input.getCurrentNutrientIntake(repo);

    // gap 이 비면 → 충분 안내 / 사용자 입력 미응답이면 → 입력 권유
    final hasInput = (member.input.currentProductIds?.isNotEmpty ?? false);
    bool hasGap = false;
    for (final e in targets.entries) {
      if ((current[e.key] ?? 0) < e.value) {
        hasGap = true;
        break;
      }
    }

    Widget body;
    if (!hasGap) {
      body = const _ProductEmptyEnough();
    } else {
      final combos = repo.findOptimalCombos(
        neededNutrients: targets,
        currentIntake: current,
      );
      if (combos.isEmpty) {
        body = const _ProductEmptyEnough();
      } else {
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < combos.length; i++)
              _ProductComboCard(
                combo: combos[i],
                rank: i + 1,
                topCombo: combos.first,
                repo: repo,
              ),
          ],
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionTitle(AppStrings.productSectionTitle),
        const SizedBox(height: 8),
        if (!hasInput) ...[
          const _ProductMissingInputBanner(),
          const SizedBox(height: 8),
        ],
        body,
      ],
    );
  }
}

class _ProductEmptyEnough extends StatelessWidget {
  const _ProductEmptyEnough();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.4)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.productEmptyEnough,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppTheme.primary,
            ),
          ),
          SizedBox(height: 4),
          Text(
            AppStrings.productEmptyEnoughSub,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.subtle,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductMissingInputBanner extends StatelessWidget {
  const _ProductMissingInputBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cream,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.productMissingDataTitle,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.ink,
            ),
          ),
          SizedBox(height: 2),
          Text(
            AppStrings.productMissingDataSub,
            style: TextStyle(fontSize: 12, color: AppTheme.subtle),
          ),
        ],
      ),
    );
  }
}

class _ProductComboCard extends StatelessWidget {
  const _ProductComboCard({
    required this.combo,
    required this.rank,
    required this.topCombo,
    required this.repo,
  });

  final ProductCombo combo;
  final int rank;
  final ProductCombo topCombo;
  final ProductRepository repo;

  @override
  Widget build(BuildContext context) {
    final compareLine = rank == 1 ? null : _compareToTop();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: rank == 1
                ? AppTheme.primary
                : AppTheme.line,
            width: rank == 1 ? 1.6 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 순위 배지
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: rank == 1
                    ? AppTheme.primary
                    : AppTheme.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                AppStrings.productRank(rank),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: rank == 1 ? Colors.white : AppTheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 10),
            for (var i = 0; i < combo.products.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              _ProductInComboBlock(product: combo.products[i], combo: combo),
            ],
            const SizedBox(height: 10),
            const Divider(height: 1, color: AppTheme.line),
            const SizedBox(height: 10),
            Row(
              children: [
                const Text(
                  '1일 총 비용',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.subtle,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  AppStrings.krw(combo.totalDailyCostKrw),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            if (compareLine != null) ...[
              const SizedBox(height: 6),
              Text(
                compareLine,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        _showAlternatives(context, combo.products.first),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(40),
                      side: const BorderSide(color: AppTheme.line),
                      foregroundColor: AppTheme.ink,
                      padding: EdgeInsets.zero,
                    ),
                    child: const Text(
                      AppStrings.productAlternativesButton,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: () =>
                        _openShop(context, combo.products.first.name),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(40),
                      backgroundColor:
                          AppTheme.primary.withValues(alpha: 0.12),
                      foregroundColor: AppTheme.primary,
                      padding: EdgeInsets.zero,
                    ),
                    child: const Text(
                      '구매 검색 🔍',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openShop(BuildContext context, String query) async {
    final url = Uri.parse(ShopConfig.searchUrl(query));
    final ok = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('브라우저를 열 수 없어요'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// 1순위 대비 사실 기반 비교. 가격이 더 싸거나, 더 적은 제품으로 같은
  /// 커버리지면 그것만 노출. 주관적 표현 없음.
  String? _compareToTop() {
    if (combo.products.isEmpty || topCombo.products.isEmpty) return null;
    if (combo.totalDailyCostKrw < topCombo.totalDailyCostKrw &&
        topCombo.totalDailyCostKrw > 0) {
      final diff = topCombo.totalDailyCostKrw - combo.totalDailyCostKrw;
      final pct = ((diff / topCombo.totalDailyCostKrw) * 100).round();
      if (pct > 0) {
        return '1일 비용 1순위 대비 $pct% 낮음 (-${AppStrings.krw(diff)})';
      }
    }
    if (combo.productCount < topCombo.productCount) {
      return '1순위 대비 챙길 제품이 ${topCombo.productCount - combo.productCount}개 적음';
    }
    if (combo.productCount > topCombo.productCount) {
      return '1순위 대비 제품 ${combo.productCount - topCombo.productCount}개 추가';
    }
    return null;
  }

  void _showAlternatives(BuildContext context, Product source) {
    final alts = repo.findAlternatives(source.id);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) =>
          _AlternativesSheet(source: source, alternatives: alts),
    );
  }
}

class _ProductInComboBlock extends StatelessWidget {
  const _ProductInComboBlock({required this.product, required this.combo});

  final Product product;
  final ProductCombo combo;

  @override
  Widget build(BuildContext context) {
    final brand = productBrandTypeLabel[product.brandType] ?? product.brandType;
    final category = productCategoryDisplayName[product.category] ??
        product.category;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                product.name,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                brand,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppTheme.subtle,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          category,
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.subtle,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          AppStrings.productCardPackage(
            product.packageSize,
            product.unit,
            product.packagePriceKrw,
          ),
          style: const TextStyle(fontSize: 12, color: AppTheme.ink),
        ),
        Text(
          AppStrings.productCardDaily(
            product.dailyDose,
            product.unit,
            product.dailyCostKrw,
          ),
          style: const TextStyle(fontSize: 12, color: AppTheme.subtle),
        ),
        const SizedBox(height: 6),
        // 이 제품이 채우는 영양소 요약 — combo.totalCoverage 에서 본 제품 기여분만.
        for (final entry in _contributingIngredients()) ...[
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              '✓ $entry',
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// 이 제품의 daily ingredient 중 combo 가 추적 중인 영양소만 골라 보여 줌.
  List<String> _contributingIngredients() {
    final lines = <String>[];
    final daily = product.dailyIngredients;
    for (final key in combo.totalCoverage.keys) {
      final v = daily[key];
      if (v == null || v <= 0) continue;
      lines.add('${_nutrientLabel(key)} ${_formatAmount(v, key)}');
    }
    return lines;
  }
}

/// ingredient 키를 사용자에게 보일 한글 라벨로.
String _nutrientLabel(String key) {
  switch (key) {
    case 'vitamin_a_mcg':
      return '비타민A';
    case 'vitamin_c_mg':
      return '비타민C';
    case 'vitamin_d_iu':
      return '비타민D';
    case 'vitamin_e_mg':
      return '비타민E';
    case 'vitamin_k_mcg':
      return '비타민K';
    case 'vitamin_b1_mg':
      return '비타민B1';
    case 'vitamin_b2_mg':
      return '비타민B2';
    case 'vitamin_b3_mg':
      return '비타민B3';
    case 'vitamin_b5_mg':
      return '비타민B5';
    case 'vitamin_b6_mg':
      return '비타민B6';
    case 'vitamin_b7_mcg':
      return '비오틴';
    case 'vitamin_b9_mcg':
      return '엽산';
    case 'vitamin_b12_mcg':
      return '비타민B12';
    case 'calcium_mg':
      return '칼슘';
    case 'magnesium_mg':
      return '마그네슘';
    case 'iron_mg':
      return '철분';
    case 'zinc_mg':
      return '아연';
    case 'selenium_mcg':
      return '셀레늄';
    case 'iodine_mcg':
      return '요오드';
    case 'copper_mg':
      return '구리';
    case 'manganese_mg':
      return '망간';
    case 'chromium_mcg':
      return '크롬';
    case 'omega3_total_mg':
      return '오메가3';
    case 'epa_mg':
      return 'EPA';
    case 'dha_mg':
      return 'DHA';
    case 'probiotics_cfu_billion':
      return '유산균';
  }
  return key;
}

String _formatAmount(double v, String key) {
  String unit;
  if (key.endsWith('_mcg')) {
    unit = 'mcg';
  } else if (key.endsWith('_mg')) {
    unit = 'mg';
  } else if (key.endsWith('_iu')) {
    unit = 'IU';
  } else if (key == 'probiotics_cfu_billion') {
    final billion = v;
    return '${_intOrDecimal(billion)}억 CFU';
  } else {
    unit = '';
  }
  return '${_intOrDecimal(v)}$unit';
}

String _intOrDecimal(double v) {
  if (v == v.truncateToDouble()) return v.toInt().toString();
  return v.toStringAsFixed(1);
}

class _AlternativesSheet extends StatelessWidget {
  const _AlternativesSheet({
    required this.source,
    required this.alternatives,
  });

  final Product source;
  final List<Product> alternatives;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              AppStrings.productAlternativesSheetTitle,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              '${source.name} 와 같은 카테고리',
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.subtle,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            if (alternatives.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  '등록된 대체 제품이 없어요',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.subtle, fontSize: 13),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: alternatives.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) =>
                      _AlternativeRow(product: alternatives[i]),
                ),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  side: const BorderSide(color: AppTheme.line),
                  foregroundColor: AppTheme.ink,
                ),
                child: const Text('닫기'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlternativeRow extends StatelessWidget {
  const _AlternativeRow({required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
    final brand = productBrandTypeLabel[product.brandType] ?? product.brandType;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  product.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  brand,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppTheme.subtle,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            AppStrings.productCardPackage(
              product.packageSize,
              product.unit,
              product.packagePriceKrw,
            ),
            style: const TextStyle(fontSize: 12, color: AppTheme.ink),
          ),
          Text(
            AppStrings.productCardDaily(
              product.dailyDose,
              product.unit,
              product.dailyCostKrw,
            ),
            style: const TextStyle(fontSize: 12, color: AppTheme.subtle),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// SECTION 1 — 오늘의 영양제 스케줄 (시간대별 카드)
// ════════════════════════════════════════════════════════════════════

class _ScheduleSection extends ConsumerWidget {
  const _ScheduleSection({required this.entry});
  final HomeFeedEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = entry.schedule;
    final blocks = <Widget>[];
    void addBlock(String emoji, String title, List<String> names) {
      if (names.isEmpty) return;
      blocks.add(_ScheduleBlock(
        emoji: emoji,
        title: title,
        names: names,
        recs: entry.recommendations,
        memberId: entry.member.id,
      ));
    }

    addBlock('☀️', '아침', s.morning);
    addBlock('🌤️', '점심', s.lunch);
    addBlock('🌙', '저녁', s.evening);
    addBlock('🛌', '취침 전', s.beforeSleep);

    if (blocks.isEmpty) {
      return const _Empty();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < blocks.length; i++) ...[
          if (i > 0) const SizedBox(height: 16),
          blocks[i],
        ],
      ],
    );
  }
}

class _ScheduleBlock extends ConsumerWidget {
  const _ScheduleBlock({
    required this.emoji,
    required this.title,
    required this.names,
    required this.recs,
    required this.memberId,
  });

  final String emoji;
  final String title;
  final List<String> names;
  final List<RecommendationResult> recs;
  final String memberId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repoAsync = ref.watch(supplementRepositoryProvider);
    final repo = repoAsync.hasValue ? repoAsync.requireValue : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppTheme.ink,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final n in names)
          _ScheduleSupplementCard(
            name: n,
            slotTitle: title,
            guide: repo?.getSupplementGuide(n),
            rec: _findRec(n),
            memberId: memberId,
          ),
      ],
    );
  }

  RecommendationResult? _findRec(String name) {
    for (final r in recs) {
      if (r.supplementName == name) return r;
    }
    return null;
  }
}

class _ScheduleSupplementCard extends StatelessWidget {
  const _ScheduleSupplementCard({
    required this.name,
    required this.slotTitle,
    required this.guide,
    required this.rec,
    required this.memberId,
  });

  final String name;
  final String slotTitle;
  final SupplementGuide? guide;
  final RecommendationResult? rec;
  final String memberId;

  String _dosageText() {
    final adult = guide?.dosage.adult;
    if (adult == null || adult.unit.isEmpty) return '';
    final amt = adult.amount;
    final s = amt is int || amt == amt.toInt()
        ? amt.toInt().toString()
        : amt.toString();
    return '$s${adult.unit}';
  }

  String _mealText() {
    final mr = guide?.timing.mealRelation;
    if (mr == null || mr.isEmpty) return '';
    return mr;
  }

  @override
  Widget build(BuildContext context) {
    final dosage = _dosageText();
    final meal = _mealText();
    final reason = rec?.reason.trim() ?? '';

    final lineParts = [
      slotTitle,
      if (meal.isNotEmpty) meal,
      if (dosage.isNotEmpty) dosage,
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: rec?.supplementId == null
            ? null
            : () => context.push(
                  SupplementGuideScreen.pathFor(
                    rec!.supplementId!,
                    memberId,
                  ),
                ),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.line),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('💊', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            dosage.isEmpty ? name : '$name $dosage',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (rec?.supplementId != null)
                          const Icon(
                            Icons.chevron_right,
                            color: AppTheme.subtle,
                            size: 18,
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      lineParts.join(' / '),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.subtle,
                      ),
                    ),
                    if (reason.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        reason,
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: AppTheme.ink,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// SECTION 2 — 지금 드시는 영양제 + 이미 충분한 영양소
// ════════════════════════════════════════════════════════════════════

class _CurrentlyTakingSection extends ConsumerWidget {
  const _CurrentlyTakingSection({required this.member, required this.recs});
  final FamilyMember member;
  final List<RecommendationResult> recs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ids = member.input.currentProductIds ?? const [];
    if (ids.isEmpty) return const SizedBox.shrink();
    final repoAsync = ref.watch(productRepositoryProvider);
    if (!repoAsync.hasValue) return const SizedBox.shrink();
    final repo = repoAsync.requireValue;

    final products = <Product>[];
    for (final id in ids) {
      final p = repo.getById(id);
      if (p != null) products.add(p);
    }
    if (products.isEmpty) return const SizedBox.shrink();

    final intake = member.input.getCurrentNutrientIntake(repo);
    final visibleNames = recs
        .where((r) => r.category != RecommendationCategory.alreadyTaking)
        .map((r) => r.supplementName)
        .toList();
    final targets = targetsForSupplements(visibleNames);
    final covered = <String>[];
    for (final e in targets.entries) {
      if ((intake[e.key] ?? 0) >= e.value) covered.add(e.key);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionTitle('현재 복용 중인 제품'),
        const SizedBox(height: 8),
        for (final p in products) _CurrentProductCard(product: p),
        if (covered.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '이미 충분한 영양소',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final k in covered)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppTheme.primary.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Text(
                          '✓ ${_nutrientLabel(k)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }
}

class _CurrentProductCard extends StatelessWidget {
  const _CurrentProductCard({required this.product});
  final Product product;

  String _ingredientList() {
    final keys = product.ingredients.keys.toList();
    if (keys.isEmpty) return '';
    final names = keys.map(_nutrientLabel).toSet().toList();
    if (names.length <= 6) return names.join(', ');
    return '${names.take(6).join(', ')} 등 ${names.length}종';
  }

  @override
  Widget build(BuildContext context) {
    final ingredients = _ingredientList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    product.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '${product.dailyDose}${product.unit}/일',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.subtle,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            if (ingredients.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '포함: $ingredients',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.subtle,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// SECTION 3 — 부족한 영양소
// ════════════════════════════════════════════════════════════════════

class _MissingNutrientsSection extends ConsumerWidget {
  const _MissingNutrientsSection({required this.member, required this.recs});
  final FamilyMember member;
  final List<RecommendationResult> recs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repoAsync = ref.watch(productRepositoryProvider);
    if (!repoAsync.hasValue) return const SizedBox.shrink();
    final repo = repoAsync.requireValue;

    final visibleNames = recs
        .where((r) => r.category != RecommendationCategory.alreadyTaking)
        .map((r) => r.supplementName)
        .toList();
    final targets = targetsForSupplements(visibleNames);
    if (targets.isEmpty) return const SizedBox.shrink();

    final intake = member.input.getCurrentNutrientIntake(repo);
    final missing = <String>[];
    for (final e in targets.entries) {
      if ((intake[e.key] ?? 0) < e.value) missing.add(e.key);
    }
    if (missing.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionTitle('이 영양소가 더 필요해요'),
        const SizedBox(height: 8),
        for (final k in missing)
          _MissingNutrientRow(
            nutrientKey: k,
            reason: _reasonFor(k, member, recs),
          ),
        const SizedBox(height: 16),
      ],
    );
  }

  /// 영양소 키 → 사용자에게 보여줄 한 줄 사유.
  /// 1) 검진 신호와 매칭되는 영양소면 검진 기반 사유 우선.
  /// 2) 그 외엔 매칭되는 추천 항목의 reason.
  /// 3) 둘 다 없으면 빈 문자열.
  String _reasonFor(
    String key,
    FamilyMember member,
    List<RecommendationResult> recs,
  ) {
    final c = member.input.lastCheckup;
    if (c != null) {
      switch (key) {
        case 'vitamin_d_iu':
          if ((c.vitaminD ?? 1000) < 30) {
            return '검진 결과 비타민D ${c.vitaminD!.toStringAsFixed(1)} ng/mL 로 부족해요';
          }
          break;
        case 'iron_mg':
          final hb = c.hemoglobin;
          if (hb != null) {
            final isFemale = member.input.sex == Sex.female;
            final low = isFemale ? hb < 12 : hb < 13;
            if (low) return '검진 결과 헤모글로빈 ${hb.toStringAsFixed(1)} g/dL 로 낮아요';
          }
          break;
        case 'omega3_total_mg':
          if ((c.cholesterolLdl ?? 0) > 130) {
            return '검진 결과 LDL ${c.cholesterolLdl!.toStringAsFixed(0)} mg/dL — 혈행 케어가 필요해요';
          }
          break;
        case 'magnesium_mg':
          if ((c.bloodSugar ?? 0) > 100) {
            return '검진 결과 공복혈당 ${c.bloodSugar!.toStringAsFixed(0)} mg/dL — 혈당 보조가 필요해요';
          }
          break;
      }
    }

    final label = _nutrientLabel(key);
    for (final r in recs) {
      if (r.supplementName.contains(label) ||
          label.contains(r.supplementName)) {
        return r.reason;
      }
    }
    return '';
  }
}

class _MissingNutrientRow extends StatelessWidget {
  const _MissingNutrientRow({
    required this.nutrientKey,
    required this.reason,
  });
  final String nutrientKey;
  final String reason;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.warning.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.warning.withValues(alpha: 0.4)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('❌', style: TextStyle(fontSize: 14)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _nutrientLabel(nutrientKey),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (reason.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      reason,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.ink,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
