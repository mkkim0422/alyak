import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/product_repository.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../family/models/family_member.dart';
import '../../family/providers/family_members_provider.dart';
import '../../family/screens/recommendation_detail_screen.dart';
import '../../health_checkup/screens/health_checkup_input_screen.dart';
import '../../onboarding/family_chat/family_chat_screen.dart';
import '../../recommendation/engine/family_input.dart';
import '../../recommendation/engine/health_checkup.dart';
import '../../settings/settings_screen.dart';
import '../../symptoms/screens/symptom_search_screen.dart';

/// 결정 시점 도우미 (Decision-moment helper) 홈 화면.
///
/// 기존의 일일 트래킹 (스트릭, 먹었어요) 모델을 폐기하고, 사용자가 영양제 관련
/// 의사결정이 필요한 순간에 명확히 진입할 5개 entry point 를 노출한다.
///
/// 구조:
///   ① 멤버 selector (드롭다운 → bottom sheet)
///   ② 현재 상황 카드 (지금 드시는 영양제 + 마지막 검진)
///   ③ 5개 entry point 카드
///   ④ 알림/재구매 안내 (있을 때만)
///   ⑤ 면책
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  static const routeName = '/home';

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String? _selectedMemberId;

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(familyMembersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('알약'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: '가족 추가',
            onPressed: () => context.push(FamilyChatScreen.routeName),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: '설정',
            onPressed: () => context.push(SettingsScreen.routeName),
          ),
        ],
      ),
      body: membersAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.primary),
        ),
        error: (e, _) => _ErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(familyMembersProvider),
        ),
        data: (members) {
          if (members.isEmpty) return const _EmptyState();

          // 선택된 memberId 가 없거나 사라진 경우 첫 번째로 폴백.
          final selectedId = _selectedMemberId ??
              (members.contains(members.first) ? members.first.id : null);
          final selected = members.firstWhere(
            (m) => m.id == selectedId,
            orElse: () => members.first,
          );

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _MemberSelector(
                selected: selected,
                allMembers: members,
                onSelect: (id) => setState(() => _selectedMemberId = id),
              ),
              const SizedBox(height: 16),
              _StatusSummaryCard(member: selected),
              const SizedBox(height: 20),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  '🎯 무엇을 도와드릴까요?',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _EntryCard(
                emoji: '🔍',
                title: '검진 결과로 추천받기',
                subtitle: '검진지 입력하면 분석해드려요',
                onTap: () => context.push(
                  '${HealthCheckupInputScreen.routeName}/${selected.id}',
                ),
              ),
              const SizedBox(height: 10),
              _EntryCard(
                emoji: '💊',
                title: '영양제 새로 사고 싶어요',
                subtitle: '부족한 영양소와 추천 제품을 알려드려요',
                onTap: () => context.push(
                  RecommendationDetailScreen.pathFor(selected.id),
                ),
              ),
              const SizedBox(height: 10),
              _EntryCard(
                emoji: '⚠️',
                title: '지금 먹는 것 점검하기',
                subtitle: '충돌과 과다 섭취를 체크해드려요',
                onTap: () => context.push('/current-check/${selected.id}'),
              ),
              const SizedBox(height: 10),
              _EntryCard(
                emoji: '🤒',
                title: '증상에 맞는 영양제',
                subtitle: '어떤 증상이 있으세요?',
                onTap: () => context.push(
                  '${SymptomSearchScreen.routeName}?member=${selected.id}',
                ),
              ),
              if (members.length > 1) ...[
                const SizedBox(height: 10),
                _EntryCard(
                  emoji: '👨‍👩‍👧',
                  title: '다른 가족 영양제 보기',
                  subtitle: '${members.length}명 등록됨',
                  onTap: () => _showMemberPicker(context, members),
                ),
              ],
              const SizedBox(height: 24),
              const _DisclaimerFooter(),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showMemberPicker(
    BuildContext context,
    List<FamilyMember> members,
  ) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  '가족 선택',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              for (final m in members)
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(m.name),
                  subtitle: Text(_memberSubtitle(m)),
                  onTap: () => Navigator.of(ctx).pop(m.id),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked != null && mounted) {
      setState(() => _selectedMemberId = picked);
    }
  }
}

String _memberSubtitle(FamilyMember m) {
  final parts = <String>[];
  if (m.sex != null) parts.add(m.sex!.ko);
  if (m.age > 0) parts.add('${m.age}세');
  return parts.join(' • ');
}

class _MemberSelector extends StatelessWidget {
  const _MemberSelector({
    required this.selected,
    required this.allMembers,
    required this.onSelect,
  });

  final FamilyMember selected;
  final List<FamilyMember> allMembers;
  final void Function(String id) onSelect;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: allMembers.length > 1
            ? () => _show(context)
            : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.line),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(Icons.person, size: 20, color: AppTheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  selected.name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              Text(
                _memberSubtitle(selected),
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
              if (allMembers.length > 1)
                const Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: Icon(
                    Icons.expand_more,
                    color: AppTheme.textSecondary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _show(BuildContext context) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            const Text(
              '가족 선택',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            for (final m in allMembers)
              ListTile(
                leading: Icon(
                  m.id == selected.id
                      ? Icons.check_circle
                      : Icons.person_outline,
                  color: m.id == selected.id
                      ? AppTheme.primary
                      : AppTheme.textSecondary,
                ),
                title: Text(m.name),
                subtitle: Text(_memberSubtitle(m)),
                onTap: () => Navigator.of(ctx).pop(m.id),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (picked != null) onSelect(picked);
  }
}

class _StatusSummaryCard extends ConsumerWidget {
  const _StatusSummaryCard({required this.member});
  final FamilyMember member;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productRepoAsync = ref.watch(productRepositoryProvider);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppTheme.cream,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '📋 ${member.name}님 현재 상황',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _CurrentSupplementsBlock(
            member: member,
            productRepoAsync: productRepoAsync,
          ),
          const SizedBox(height: 14),
          _CheckupBlock(member: member),
        ],
      ),
    );
  }
}

class _CurrentSupplementsBlock extends StatelessWidget {
  const _CurrentSupplementsBlock({
    required this.member,
    required this.productRepoAsync,
  });

  final FamilyMember member;
  final AsyncValue<ProductRepository> productRepoAsync;

  @override
  Widget build(BuildContext context) {
    final ids = member.input.currentProductIds ?? const <String>[];
    final names = <String>[];
    if (ids.isNotEmpty) {
      productRepoAsync.whenData((repo) {
        for (final id in ids) {
          final p = repo.getById(id);
          if (p != null) names.add(p.name);
        }
      });
    }
    final supplements = member.input.currentSupplements ?? const <String>[];
    final allLabels = [
      ...names,
      // currentSupplements 중 product names 와 겹치지 않는 것만 추가.
      ...supplements.where((s) => !names.contains(s)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              '💊 지금 드시는 영양제',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(width: 6),
            if (allLabels.isNotEmpty)
              Text(
                '(${allLabels.length}개)',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        if (allLabels.isEmpty)
          const Text(
            '아직 등록된 영양제가 없어요',
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final n in allLabels.take(3))
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    '· $n',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              if (allLabels.length > 3)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    '· 외 ${allLabels.length - 3}개',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _CheckupBlock extends StatelessWidget {
  const _CheckupBlock({required this.member});
  final FamilyMember member;

  @override
  Widget build(BuildContext context) {
    final c = member.input.lastCheckup;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Text(
              '📊 마지막 검진',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (c == null)
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => context.push(
                '${HealthCheckupInputScreen.routeName}/${member.id}',
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  '검진 결과 입력하면 더 정확한 추천을 받을 수 있어요 →',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                  ),
                ),
              ),
            ),
          )
        else
          _CheckupSummary(checkup: c, memberId: member.id),
      ],
    );
  }
}

class _CheckupSummary extends StatelessWidget {
  const _CheckupSummary({required this.checkup, required this.memberId});
  final HealthCheckup checkup;
  final String memberId;

  @override
  Widget build(BuildContext context) {
    final ymd = '${checkup.checkupDate.year}년 '
        '${checkup.checkupDate.month}월';
    final flags = <String>[];
    if ((checkup.cholesterolLdl ?? 0) > 130) {
      flags.add('LDL ${checkup.cholesterolLdl!.toStringAsFixed(0)} (높음)');
    }
    if (checkup.vitaminD != null && checkup.vitaminD! < 30) {
      flags.add('비타민D ${checkup.vitaminD!.toStringAsFixed(0)} (낮음)');
    }
    if ((checkup.bloodSugar ?? 0) > 100) {
      flags.add('공복혈당 ${checkup.bloodSugar!.toStringAsFixed(0)} (높음)');
    }
    if ((checkup.alt ?? 0) > 40 || (checkup.ast ?? 0) > 40) {
      flags.add('간수치 높음');
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => context.push(
          RecommendationDetailScreen.pathFor(memberId),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ymd,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (flags.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    '특이사항 없음',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                )
              else
                for (final f in flags)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '⚠️ $f',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.warning,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  '상세 보기 →',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String emoji;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppTheme.softShadow,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 30)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: AppTheme.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DisclaimerFooter extends StatelessWidget {
  const _DisclaimerFooter();

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

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '👋',
              style: TextStyle(fontSize: 56),
            ),
            const SizedBox(height: 16),
            const Text(
              AppStrings.homeEmptyHeading,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              AppStrings.homeEmptyBody,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => context.push(FamilyChatScreen.routeName),
              child: const Text(AppStrings.homeAddFamily),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: AppTheme.danger,
            ),
            const SizedBox(height: 12),
            const Text(
              AppStrings.homeLoadFailed,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }
}
