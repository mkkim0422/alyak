import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/models/supplement_guide_model.dart';
import '../../../core/data/supplement_repository.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../family/models/family_member.dart';
import '../../family/providers/family_members_provider.dart';
import '../../recommendation/engine/family_input.dart';

/// `/supplement-guide/:supplementId?member=<id>`
///
/// 멤버 중심 가이드. 화면을 열자마자 멤버에게 필요한 핵심 3줄(언제/얼마나/주의)
/// 만 보이고, "자세히 보기 ↓" 로 6섹션 전체를 펼친다.
class SupplementGuideScreen extends ConsumerStatefulWidget {
  const SupplementGuideScreen({
    required this.supplementId,
    this.memberId,
    super.key,
  });

  final String supplementId;

  /// 어느 멤버 컨텍스트에서 보는지. 권장량/약물 상호작용 표시 기준.
  /// null 이면 fallback (성인 기준, 헤더는 generic).
  final String? memberId;

  static const routeName = '/supplement-guide/:supplementId';

  /// 멤버 컨텍스트가 없을 때만 사용 (encyclopedia mode).
  static String pathForId(String id) => '/supplement-guide/$id';

  /// 멤버 컨텍스트가 있을 때. 가능한 경우 항상 이 쪽을 사용.
  static String pathFor(String id, String memberId) =>
      '/supplement-guide/$id?member=$memberId';

  @override
  ConsumerState<SupplementGuideScreen> createState() =>
      _SupplementGuideScreenState();
}

class _SupplementGuideScreenState
    extends ConsumerState<SupplementGuideScreen> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final repoAsync = ref.watch(supplementRepositoryProvider);
    final membersAsync = ref.watch(familyMembersProvider);

    return Scaffold(
      appBar: AppBar(title: Text(_appBarTitle(repoAsync.asData?.value, membersAsync.asData?.value))),
      body: repoAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => const Center(child: Text(AppStrings.guideLoadFailed)),
        data: (repo) {
          final guide = repo.getSupplementById(widget.supplementId);
          if (guide == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(AppStrings.guideNotFound),
              ),
            );
          }
          final member = _resolveMember(membersAsync.asData?.value);
          return _Body(
            guide: guide,
            member: member,
            expanded: _expanded,
            onToggle: () => setState(() => _expanded = !_expanded),
          );
        },
      ),
    );
  }

  String _appBarTitle(SupplementRepository? repo, List<FamilyMember>? members) {
    final guide = repo?.getSupplementById(widget.supplementId);
    final member = _resolveMember(members);
    if (guide == null) return AppStrings.guideTitleFallback;
    if (member == null) return guide.nameKorean;
    return AppStrings.guideTitleFor(guide.nameKorean, member.name);
  }

  FamilyMember? _resolveMember(List<FamilyMember>? members) {
    final id = widget.memberId;
    if (id == null || members == null) return null;
    for (final m in members) {
      if (m.id == id) return m;
    }
    return null;
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.guide,
    required this.member,
    required this.expanded,
    required this.onToggle,
  });

  final SupplementGuide guide;
  final FamilyMember? member;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _Summary(guide: guide, member: member),
        const SizedBox(height: 16),
        Center(
          child: TextButton.icon(
            onPressed: onToggle,
            icon: Icon(expanded ? Icons.expand_less : Icons.expand_more),
            label: Text(expanded ? AppStrings.guideCollapse : AppStrings.guideExpand),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.primary,
              minimumSize: const Size.fromHeight(44),
            ),
          ),
        ),
        if (expanded) _DetailSections(guide: guide, member: member),
        const SizedBox(height: 24),
        _Disclaimer(text: guide.disclaimer),
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.guide, required this.member});
  final SupplementGuide guide;
  final FamilyMember? member;

  @override
  Widget build(BuildContext context) {
    final timeLine = _formatTiming(guide.timing);
    final dosageLine = _formatDosage(guide, member);
    final cautionLine = guide.badCombinations.isEmpty
        ? null
        : _formatCaution(guide.badCombinations.first);

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
          _SummaryRow(emoji: '⏰', label: AppStrings.guideSummaryWhen, body: timeLine),
          const SizedBox(height: 10),
          _SummaryRow(emoji: '⚖️', label: AppStrings.guideSummaryAmount, body: dosageLine),
          if (cautionLine != null) ...[
            const SizedBox(height: 10),
            _SummaryRow(emoji: '⚠️', label: AppStrings.guideSummaryCaution, body: cautionLine),
          ],
        ],
      ),
    );
  }

  String _formatTiming(TimingInfo t) {
    final time = t.bestTime.map(_translateTime).join(' · ');
    final timeLabel = time.isEmpty ? AppStrings.guideTimingAnytime : time;
    final meal = t.mealRelation.isEmpty ? '' : ' · ${t.mealRelation}';
    return '$timeLabel$meal';
  }

  String _formatDosage(SupplementGuide guide, FamilyMember? member) {
    final band = _bandFor(guide.dosage, member);
    if (band == null) return AppStrings.guideDosageMissing;
    final freq = (band.frequency == null || band.frequency!.isEmpty)
        ? ''
        : ' · ${band.frequency}';
    return '${band.amount} ${band.unit}$freq';
  }

  DosageBand? _bandFor(DosageInfo dosage, FamilyMember? member) {
    final age = member?.age;
    if (age == null) return dosage.adult;
    if (age <= 12) return dosage.child7to12 ?? dosage.adult;
    if (age <= 18) return dosage.teen13to18 ?? dosage.adult;
    if (age >= 60) return dosage.elderly60plus ?? dosage.adult;
    return dosage.adult;
  }

  String _formatCaution(CombinationLink combo) {
    final reason = combo.reason ?? combo.solution ?? '';
    if (reason.isEmpty) return AppStrings.guideCautionWith(combo.supplement);
    return '${combo.supplement}: $reason';
  }

  String _translateTime(String t) {
    switch (t) {
      case 'morning':
        return AppStrings.guideTimeMorning;
      case 'afternoon':
        return AppStrings.guideTimeNoon;
      case 'lunch':
        return AppStrings.guideTimeLunch;
      case 'evening':
        return AppStrings.guideTimeEvening;
      case 'before_sleep':
        return AppStrings.guideTimeBeforeSleep;
      default:
        return t;
    }
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.emoji,
    required this.label,
    required this.body,
  });

  final String emoji;
  final String label;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 10),
        SizedBox(
          width: 56,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.subtle,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Expanded(
          child: Text(
            body,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _DetailSections extends StatelessWidget {
  const _DetailSections({required this.guide, required this.member});

  final SupplementGuide guide;
  final FamilyMember? member;

  @override
  Widget build(BuildContext context) {
    final showDrugWarnings = member?.input.takingMedications == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        if (guide.mainBenefits.isNotEmpty) ...[
          _SectionTitle(AppStrings.guideSectionEffects),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: guide.mainBenefits
                .map(
                  (b) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      b,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
        ],
        _SectionTitle(AppStrings.guideSectionWhen),
        const SizedBox(height: 8),
        _TimingDetailCard(timing: guide.timing),
        const SizedBox(height: 16),
        _SectionTitle(AppStrings.guideSectionDosage),
        const SizedBox(height: 8),
        _DosageDetailCard(dosage: guide.dosage, member: member),
        if (guide.goodCombinations.isNotEmpty) ...[
          const SizedBox(height: 16),
          _SectionTitle(AppStrings.guideSectionGoodCombo),
          const SizedBox(height: 8),
          ...guide.goodCombinations.map((c) => _GoodComboCard(combo: c)),
        ],
        if (guide.badCombinations.isNotEmpty ||
            (showDrugWarnings && guide.drugInteractions.isNotEmpty)) ...[
          const SizedBox(height: 16),
          _SectionTitle(AppStrings.guideSectionCautions),
          const SizedBox(height: 8),
          ...guide.badCombinations.map((c) => _BadComboCard(combo: c)),
          if (showDrugWarnings)
            ...guide.drugInteractions.map(
              (d) => _DrugInteractionCard(interaction: d),
            ),
        ],
        if (guide.foodAlternatives.isNotEmpty) ...[
          const SizedBox(height: 16),
          _SectionTitle(AppStrings.guideSectionFood),
          const SizedBox(height: 8),
          ...guide.foodAlternatives.map((f) => _FoodAlternativeCard(food: f)),
        ],
        if (guide.effectTimeline.isNotEmpty) ...[
          const SizedBox(height: 16),
          _SectionTitle(AppStrings.guideSectionEffectTime),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.line),
            ),
            child: Text(
              guide.effectTimeline,
              style: const TextStyle(fontSize: 13, height: 1.5),
            ),
          ),
        ],
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
    );
  }
}

class _TimingDetailCard extends StatelessWidget {
  const _TimingDetailCard({required this.timing});
  final TimingInfo timing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (timing.mealRelation.isNotEmpty) ...[
            Row(
              children: [
                const Icon(
                  Icons.restaurant_outlined,
                  size: 14,
                  color: AppTheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  timing.mealRelation,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],
          if (timing.reason.isNotEmpty)
            Text(
              timing.reason,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.subtle,
                height: 1.5,
              ),
            ),
        ],
      ),
    );
  }
}

class _DosageDetailCard extends StatelessWidget {
  const _DosageDetailCard({required this.dosage, required this.member});

  final DosageInfo dosage;
  final FamilyMember? member;

  @override
  Widget build(BuildContext context) {
    // 다른 나이대는 default 숨김. "다른 나이대 보기" 버튼으로 토글.
    return _OtherAgeGroupsToggle(dosage: dosage, member: member);
  }
}

class _OtherAgeGroupsToggle extends StatefulWidget {
  const _OtherAgeGroupsToggle({required this.dosage, required this.member});
  final DosageInfo dosage;
  final FamilyMember? member;

  @override
  State<_OtherAgeGroupsToggle> createState() =>
      _OtherAgeGroupsToggleState();
}

class _OtherAgeGroupsToggleState extends State<_OtherAgeGroupsToggle> {
  bool _showOthers = false;

  @override
  Widget build(BuildContext context) {
    final highlightLabel = _highlightFor(widget.member?.input.ageGroup);
    final entries = <_DosageRow>[];
    if (widget.dosage.adult != null) {
      entries.add(_DosageRow(AppStrings.guideAgeAdult, widget.dosage.adult!));
    }
    if (widget.dosage.child7to12 != null) {
      entries.add(_DosageRow(AppStrings.guideAgeChild, widget.dosage.child7to12!));
    }
    if (widget.dosage.teen13to18 != null) {
      entries.add(_DosageRow(AppStrings.guideAgeTeen, widget.dosage.teen13to18!));
    }
    if (widget.dosage.elderly60plus != null) {
      entries.add(_DosageRow(AppStrings.guideAgeElderly, widget.dosage.elderly60plus!));
    }
    final mine = entries.where((e) => e.label == highlightLabel).toList();
    final others = entries.where((e) => e.label != highlightLabel).toList();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (mine.isNotEmpty)
            ...mine.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _row(e, highlight: true),
              ),
            )
          else if (entries.isNotEmpty)
            // 멤버 정보가 없거나 매칭되지 않으면 성인 기준만 보여 준다.
            ...entries.take(1).map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _row(e, highlight: false),
                  ),
                ),
          if (widget.dosage.upperLimitAdult != null) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppTheme.warning.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('⚠️', style: TextStyle(fontSize: 13)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '상한 (성인): ${widget.dosage.upperLimitAdult!.amount} '
                          '${widget.dosage.upperLimitAdult!.unit}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if ((widget.dosage.upperLimitAdult!.note ?? '')
                            .isNotEmpty)
                          Text(
                            widget.dosage.upperLimitAdult!.note!,
                            style: const TextStyle(
                              fontSize: 11,
                              height: 1.4,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (others.isNotEmpty) ...[
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => setState(() => _showOthers = !_showOthers),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 28),
                foregroundColor: AppTheme.subtle,
              ),
              child: Text(
                _showOthers ? AppStrings.guideHideOtherAges : AppStrings.guideShowOtherAges,
                style: const TextStyle(fontSize: 12),
              ),
            ),
            if (_showOthers)
              ...others.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: _row(e, highlight: false),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _row(_DosageRow e, {required bool highlight}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: highlight
            ? AppTheme.primary.withValues(alpha: 0.08)
            : AppTheme.cream,
        borderRadius: BorderRadius.circular(10),
        border: highlight
            ? Border.all(color: AppTheme.primary.withValues(alpha: 0.6))
            : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              e.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: highlight ? AppTheme.primary : AppTheme.ink,
              ),
            ),
          ),
          Expanded(
            child: Text(
              '${e.band.amount} ${e.band.unit}'
              '${e.band.frequency != null ? ' · ${e.band.frequency}' : ''}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _highlightFor(AgeGroup? g) {
    if (g == null) return null;
    switch (g) {
      case AgeGroup.newborn:
      case AgeGroup.toddler:
        return AppStrings.guideAgeInfantToddler;
      case AgeGroup.child:
        return AppStrings.guideAgeChild;
      case AgeGroup.teen:
        return AppStrings.guideAgeTeen;
      case AgeGroup.adult:
        return AppStrings.guideAgeAdult;
      case AgeGroup.elderly:
        return AppStrings.guideAgeElderly;
    }
  }
}

class _DosageRow {
  const _DosageRow(this.label, this.band);
  final String label;
  final DosageBand band;
}

class _GoodComboCard extends StatelessWidget {
  const _GoodComboCard({required this.combo});
  final CombinationLink combo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '+ ${combo.supplement}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppTheme.primary,
              ),
            ),
            if ((combo.reason ?? '').isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                combo.reason!,
                style: const TextStyle(fontSize: 12, height: 1.45),
              ),
            ],
            if ((combo.timingNote ?? '').isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                combo.timingNote!,
                style: const TextStyle(
                  fontSize: 11,
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

class _BadComboCard extends StatelessWidget {
  const _BadComboCard({required this.combo});
  final CombinationLink combo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.warning.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.warning.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '+ ${combo.supplement}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if ((combo.severity ?? '').isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.warning,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      combo.severity!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            if ((combo.reason ?? '').isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                combo.reason!,
                style: const TextStyle(fontSize: 12, height: 1.45),
              ),
            ],
            if ((combo.solution ?? '').isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                combo.solution!,
                style: const TextStyle(
                  fontSize: 11,
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

class _DrugInteractionCard extends StatelessWidget {
  const _DrugInteractionCard({required this.interaction});
  final DrugInteractionEntry interaction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.danger.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.danger.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.medication, size: 16, color: AppTheme.danger),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    interaction.drugCategory,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.danger,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    interaction.severity,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              interaction.reason,
              style: const TextStyle(fontSize: 12, height: 1.45),
            ),
            const SizedBox(height: 4),
            Text(
              interaction.recommendation,
              style: const TextStyle(
                fontSize: 11,
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

class _FoodAlternativeCard extends StatelessWidget {
  const _FoodAlternativeCard({required this.food});
  final FoodAlternative food;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.line),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '${food.food} (${food.amount})',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              food.equivalent,
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

class _Disclaimer extends StatelessWidget {
  const _Disclaimer({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.danger.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.danger.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber, color: AppTheme.danger, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text.isEmpty ? AppStrings.guideDisclaimerFallback : text,
              style: const TextStyle(fontSize: 11, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
