import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/models/symptom_result.dart';
import '../../../core/data/supplement_repository.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../family/models/family_member.dart';
import '../../family/providers/family_members_provider.dart';
import '../../family/screens/supplement_guide_screen.dart';
import '../../family/services/family_service.dart';
import '../../home/providers/home_feed_provider.dart';

/// `/symptom-search?member=<id>`
///
/// 증상을 검색해서 영양제를 안내하거나 의료 권고를 띄운다.
/// 결과 하단의 "내 추천에 반영하기" 버튼은 선택된 멤버의 symptomIds 에 추가.
class SymptomSearchScreen extends ConsumerStatefulWidget {
  const SymptomSearchScreen({this.initialMemberId, super.key});

  final String? initialMemberId;

  static const routeName = '/symptom-search';
  static String pathForMember(String memberId) =>
      '$routeName?member=$memberId';

  @override
  ConsumerState<SymptomSearchScreen> createState() =>
      _SymptomSearchScreenState();
}

class _SymptomSearchScreenState extends ConsumerState<SymptomSearchScreen> {
  final _searchCtrl = TextEditingController();
  String? _selectedMemberId;
  SymptomResult? _result;
  String? _lastQuery;
  bool _searching = false;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _selectedMemberId = widget.initialMemberId;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _runSearch(String raw) {
    final q = raw.trim();
    if (q.isEmpty) return;
    final repo = ref.read(supplementRepositoryProvider).asData?.value;
    if (repo == null) return;
    setState(() {
      _lastQuery = q;
      _result = repo.getSymptomsInfo(q);
      _searching = false;
      _saved = false;
    });
  }

  Future<void> _saveToMember() async {
    final member = _resolveMember();
    final symptom = _result;
    if (member == null || symptom == null) return;
    setState(() => _saving = true);
    try {
      final existing = member.input.symptomIds ?? const <String>[];
      if (existing.contains(symptom.symptomId)) {
        setState(() => _saved = true);
        return;
      }
      final updated = member.input.copyWith(
        symptomIds: [...existing, symptom.symptomId],
      );
      await FamilyService.updateMember(member.id, updated);
      ref.invalidate(familyMembersProvider);
      ref.invalidate(homeFeedProvider);
      setState(() => _saved = true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  bool _saving = false;

  FamilyMember? _resolveMember() {
    final id = _selectedMemberId;
    if (id == null) return null;
    final members = ref.read(familyMembersProvider).asData?.value;
    if (members == null) return null;
    for (final m in members) {
      if (m.id == id) return m;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final repoAsync = ref.watch(supplementRepositoryProvider);
    final membersAsync = ref.watch(familyMembersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.symptomTitle)),
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: repoAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(AppStrings.symptomLoadFailed),
              ),
            ),
            data: (repo) => ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                _MemberSelector(
                  membersAsync: membersAsync,
                  selectedId: _selectedMemberId,
                  onPick: (id) => setState(() {
                    _selectedMemberId = id;
                    _saved = false;
                  }),
                ),
                const SizedBox(height: 12),
                _SearchField(
                  controller: _searchCtrl,
                  onSubmit: _runSearch,
                ),
                const SizedBox(height: 20),
                if (_lastQuery == null) ...[
                  const Text(
                    AppStrings.symptomCommon,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _TopSymptomsGrid(
                    symptoms: repo.getTopSymptoms().take(12).toList(),
                    onTap: (label) {
                      _searchCtrl.text = label;
                      _runSearch(label);
                    },
                  ),
                ] else
                  _ResultBlock(
                    query: _lastQuery!,
                    result: _result,
                    searching: _searching,
                    selectedMember: _resolveMember(),
                    saved: _saved,
                    saving: _saving,
                    onApply: _saveToMember,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MemberSelector extends StatelessWidget {
  const _MemberSelector({
    required this.membersAsync,
    required this.selectedId,
    required this.onPick,
  });

  final AsyncValue<List<FamilyMember>> membersAsync;
  final String? selectedId;
  final ValueChanged<String?> onPick;

  @override
  Widget build(BuildContext context) {
    return membersAsync.when(
      loading: () => const SizedBox(height: 36),
      error: (e, s) => const SizedBox.shrink(),
      data: (members) {
        if (members.isEmpty) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.cream,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.line),
            ),
            child: const Text(
              AppStrings.symptomNoMember,
              style: TextStyle(fontSize: 12, color: AppTheme.subtle),
            ),
          );
        }
        return SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: members.length,
            separatorBuilder: (c, i) => const SizedBox(width: 6),
            itemBuilder: (c, i) {
              final m = members[i];
              final selected = m.id == selectedId;
              return InkWell(
                onTap: () => onPick(m.id),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppTheme.primary.withValues(alpha: 0.1)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected ? AppTheme.primary : AppTheme.line,
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  child: Text(
                    m.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: selected ? AppTheme.primary : AppTheme.ink,
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onSubmit});

  final TextEditingController controller;
  final ValueChanged<String> onSubmit;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: AppStrings.symptomSearchHint,
        prefixIcon: const Icon(Icons.search, color: AppTheme.subtle),
        suffixIcon: IconButton(
          onPressed: () => onSubmit(controller.text),
          icon: const Icon(Icons.arrow_forward, color: AppTheme.primary),
        ),
        filled: true,
        fillColor: AppTheme.cream,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
      onSubmitted: onSubmit,
    );
  }
}

class _TopSymptomsGrid extends StatelessWidget {
  const _TopSymptomsGrid({required this.symptoms, required this.onTap});

  final List<String> symptoms;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: symptoms.map((s) {
        return InkWell(
          onTap: () => onTap(s),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.line),
            ),
            child: Text(
              s,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ResultBlock extends StatelessWidget {
  const _ResultBlock({
    required this.query,
    required this.result,
    required this.searching,
    required this.selectedMember,
    required this.saved,
    required this.saving,
    required this.onApply,
  });

  final String query;
  final SymptomResult? result;
  final bool searching;
  final FamilyMember? selectedMember;
  final bool saved;
  final bool saving;
  final Future<void> Function() onApply;

  @override
  Widget build(BuildContext context) {
    if (searching) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final r = result;
    if (r == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cream,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.symptomNotFound(query),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              AppStrings.symptomNotFoundTip,
              style: TextStyle(fontSize: 12, color: AppTheme.subtle, height: 1.5),
            ),
          ],
        ),
      );
    }
    if (r.isMedical) {
      return _TypeBCard(result: r);
    }
    return _TypeACard(
      result: r,
      selectedMember: selectedMember,
      saved: saved,
      saving: saving,
      onApply: onApply,
    );
  }
}

class _TypeACard extends StatelessWidget {
  const _TypeACard({
    required this.result,
    required this.selectedMember,
    required this.saved,
    required this.saving,
    required this.onApply,
  });

  final SymptomResult result;
  final FamilyMember? selectedMember;
  final bool saved;
  final bool saving;
  final Future<void> Function() onApply;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                result.symptom,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                result.category,
                style: const TextStyle(fontSize: 12, color: AppTheme.subtle),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          AppStrings.symptomSectionRelated,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        ...result.relatedSupplements.map(
          (s) => _SupplementResultCard(
            link: s,
            memberId: selectedMember?.id,
          ),
        ),
        if (result.lifestyleTips.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text(
            AppStrings.symptomSectionTips,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          ...result.lifestyleTips.map(
            (t) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '· $t',
                style: const TextStyle(fontSize: 13, height: 1.5),
              ),
            ),
          ),
        ],
        if ((result.whenToSeeDoctor ?? '').isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: AppTheme.warning.withValues(alpha: 0.5)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.local_hospital_outlined, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    result.whenToSeeDoctor!,
                    style: const TextStyle(fontSize: 13, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        if (selectedMember != null)
          FilledButton.icon(
            onPressed: saved || saving ? null : onApply,
            icon: saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(saved ? Icons.check : Icons.add),
            label: Text(
              saved
                  ? AppStrings.symptomReflectedFor(selectedMember!.name)
                  : AppStrings.symptomReflectFor(selectedMember!.name),
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        const SizedBox(height: 12),
        Text(
          result.disclaimer,
          style: const TextStyle(fontSize: 11, color: AppTheme.subtle),
        ),
      ],
    );
  }
}

class _SupplementResultCard extends StatelessWidget {
  const _SupplementResultCard({required this.link, this.memberId});
  final SymptomSupplementLink link;
  final String? memberId;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    link.supplementName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _RelevanceBadge(relevance: link.relevance),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              link.safeExpression,
              style: const TextStyle(
                fontSize: 13,
                height: 1.45,
                color: AppTheme.ink,
              ),
            ),
            if (link.explanation.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                link.explanation,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.subtle,
                  height: 1.45,
                ),
              ),
            ],
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: () => context.push(
                memberId != null
                    ? SupplementGuideScreen.pathFor(
                        link.supplementId,
                        memberId!,
                      )
                    : SupplementGuideScreen.pathForId(link.supplementId),
              ),
              icon: const Icon(Icons.menu_book_outlined, size: 16),
              label: const Text('복용 가이드 보기'),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RelevanceBadge extends StatelessWidget {
  const _RelevanceBadge({required this.relevance});
  final String relevance;

  @override
  Widget build(BuildContext context) {
    final isPrimary = relevance == 'primary';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isPrimary
            ? AppTheme.primary.withValues(alpha: 0.1)
            : AppTheme.line.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isPrimary ? AppStrings.symptomBadgePrimary : AppStrings.symptomBadgeSecondary,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: isPrimary ? AppTheme.primary : AppTheme.subtle,
        ),
      ),
    );
  }
}

class _TypeBCard extends StatelessWidget {
  const _TypeBCard({required this.result});
  final SymptomResult result;

  @override
  Widget build(BuildContext context) {
    final tone = result.urgency == SymptomUrgency.high
        ? AppTheme.danger
        : AppTheme.warning;
    final urgencyLabel = result.urgency == SymptomUrgency.high
        ? '긴급'
        : (result.urgency == SymptomUrgency.medium ? '중요' : '주의');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: tone.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: tone.withValues(alpha: 0.6)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.local_hospital, color: tone),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: tone,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      urgencyLabel,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                AppStrings.symptomMedicalWarning(result.symptom),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                result.medicalMessage ??
                    AppStrings.symptomMedicalFallback,
                style: const TextStyle(fontSize: 13, height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          result.disclaimer,
          style: const TextStyle(fontSize: 11, color: AppTheme.subtle),
        ),
      ],
    );
  }
}
