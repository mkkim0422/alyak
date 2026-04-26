import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/shop_config.dart';
import '../../../core/data/models/conflict_warning.dart';
import '../../../core/data/models/recommendation_result.dart';
import '../../../core/data/models/schedule_result.dart';
import '../../../core/data/models/supplement_guide_model.dart';
import '../../../core/data/supplement_repository.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../core/security/secure_storage.dart';
import '../../../core/theme/app_theme.dart';
import '../../home/providers/home_feed_provider.dart';
import '../../recommendation/engine/family_input.dart';
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

class _Body extends StatelessWidget {
  const _Body({required this.entry});
  final HomeFeedEntry entry;

  @override
  Widget build(BuildContext context) {
    final FamilyMember member = entry.member;
    final recs = entry.recommendations;
    final schedule = entry.schedule;
    final conflicts = entry.conflicts;
    final mustTake = recs
        .where((r) => r.category == RecommendationCategory.mustTake)
        .toList();
    final highly = recs
        .where((r) => r.category == RecommendationCategory.highlyRecommended)
        .toList();
    final consider = recs
        .where((r) => r.category == RecommendationCategory.considerIf)
        .toList();
    final alreadyTaking = recs
        .where((r) => r.category == RecommendationCategory.alreadyTaking)
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _Header(member: member),
        const SizedBox(height: 16),
        if (recs.isEmpty) const _Empty() else ...[
          if (mustTake.isNotEmpty) ...[
            const _SectionTitle(AppStrings.recommendationSectionMustTake),
            const SizedBox(height: 8),
            ...mustTake.map((r) => _RecCard(rec: r, memberId: member.id)),
            const SizedBox(height: 12),
          ],
          if (highly.isNotEmpty) ...[
            const _SectionTitle(AppStrings.recommendationSectionHighly),
            const SizedBox(height: 8),
            ...highly.map((r) => _RecCard(rec: r, memberId: member.id)),
            const SizedBox(height: 12),
          ],
          if (consider.isNotEmpty) ...[
            const _SectionTitle(AppStrings.recommendationSectionConsider),
            const SizedBox(height: 8),
            ...consider.map((r) => _RecCard(rec: r, memberId: member.id)),
            const SizedBox(height: 12),
          ],
          if (alreadyTaking.isNotEmpty) ...[
            const _SectionTitle(
              AppStrings.recommendationSectionAlreadyTaking,
            ),
            const SizedBox(height: 8),
            ...alreadyTaking
                .map((r) => _RecCard(rec: r, memberId: member.id)),
            const SizedBox(height: 12),
          ],
        ],
        if (schedule.synergies.isNotEmpty) ...[
          const _SectionTitle(AppStrings.recommendationSectionSynergy),
          const SizedBox(height: 8),
          ...schedule.synergies.map(
            (s) => _SynergyCard(synergy: s),
          ),
          const SizedBox(height: 12),
        ],
        if (conflicts.isNotEmpty) ...[
          const _SectionTitle(AppStrings.recommendationSectionConflicts),
          const SizedBox(height: 8),
          ...conflicts.map((c) => _ConflictCard(conflict: c)),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 4),
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
          if (ageLabel.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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

class _RecCard extends ConsumerWidget {
  const _RecCard({required this.rec, required this.memberId});
  final RecommendationResult rec;
  final String memberId;

  /// supplement_guide.json 의 `dosage.adult` 를 "1000mg" 형태로 포맷.
  /// amount 가 정수형이면 정수로 표시, 그 외엔 그대로. 데이터 없으면 빈 문자열.
  String _adultDosageText(SupplementGuide? guide) {
    final adult = guide?.dosage.adult;
    if (adult == null || adult.unit.isEmpty) return '';
    final amt = adult.amount;
    final amtStr =
        amt is int || amt == amt.toInt() ? amt.toInt().toString() : amt.toString();
    return '$amtStr${adult.unit}';
  }

  Future<void> _openShop(BuildContext context) async {
    final url = Uri.parse(ShopConfig.searchUrl(rec.supplementName));
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // alreadyTaking 항목엔 검색 링크 노출 안 함 — 이미 사용자가 챙기고 있음.
    final showShopLink =
        rec.category != RecommendationCategory.alreadyTaking;

    final repoAsync = ref.watch(supplementRepositoryProvider);
    final guide = repoAsync.hasValue
        ? repoAsync.requireValue.getSupplementGuide(rec.supplementName)
        : null;
    final dosageText = _adultDosageText(guide);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: rec.supplementId == null
              ? null
              : () => context.push(
                    SupplementGuideScreen.pathFor(
                      rec.supplementId!,
                      memberId,
                    ),
                  ),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        rec.supplementName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (rec.supplementId != null)
                      const Icon(
                        Icons.chevron_right,
                        color: AppTheme.subtle,
                      ),
                  ],
                ),
                if (rec.reason.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    rec.reason,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: AppTheme.ink,
                    ),
                  ),
                ],
                if (rec.notes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...rec.notes.map(
                    (n) => Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '· $n',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.subtle,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
                ],
                if (showShopLink) ...[
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: () => _openShop(context),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 4,
                        horizontal: 2,
                      ),
                      child: Text(
                        AppStrings.searchProductFor(dosageText),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.subtle,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
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
