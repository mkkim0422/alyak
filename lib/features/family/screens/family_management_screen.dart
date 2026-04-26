import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/security/secure_storage.dart';
import '../../home/providers/home_feed_provider.dart';
import '../../notifications/providers/notification_settings_provider.dart';
import '../../onboarding/family_chat/family_chat_screen.dart';
import '../../onboarding/models/user_role.dart';
import '../../onboarding/providers/onboarding_providers.dart';
import '../../recommendation/engine/family_input.dart';
import '../models/family_member.dart';
import '../providers/family_members_provider.dart';
import '../services/family_service.dart';
import '../../symptoms/screens/symptom_search_screen.dart';
import 'family_edit_screen.dart';
import 'recommendation_detail_screen.dart';

class FamilyManagementScreen extends ConsumerWidget {
  const FamilyManagementScreen({super.key});

  static const routeName = '/family';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final familyAsync = ref.watch(familyMembersProvider);
    final roleAsync = ref.watch(userRoleFutureProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.familyTitle),
      ),
      body: familyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => const _ErrorState(),
        data: (allMembers) {
          final role = roleAsync.value;
          // solo 사용자는 첫 멤버(=본인)만 본다.
          final visible = role == UserRole.solo && allMembers.isNotEmpty
              ? [allMembers.first]
              : allMembers;

          if (visible.isEmpty) return const _EmptyState();

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: visible.length,
            separatorBuilder: (context, i) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final m = visible[i];
              final isSelf = role == UserRole.solo;
              return _MemberCard(
                member: m,
                isSelf: isSelf,
                onTap: () =>
                    context.push(FamilyEditScreen.pathFor(m.id)),
                onViewRecommendations: () => context.push(
                  RecommendationDetailScreen.pathFor(m.id),
                ),
                onAddSymptom: () => context.push(
                  SymptomSearchScreen.pathForMember(m.id),
                ),
                onDelete: isSelf
                    ? null
                    : () => _confirmDelete(context, ref, m),
              );
            },
          );
        },
      ),
      floatingActionButton: roleAsync.value == UserRole.solo
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.push(FamilyChatScreen.routeName),
              icon: const Icon(Icons.add),
              label: const Text(AppStrings.familyAdd),
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
            ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    FamilyMember member,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(AppStrings.familyDeleteTitle),
        content: Text(
          AppStrings.familyDeleteConfirm(member.name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(AppStrings.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style:
                TextButton.styleFrom(foregroundColor: AppTheme.danger),
            child: const Text(AppStrings.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await FamilyService.deleteMember(member.id);
    ref.invalidate(familyMembersProvider);
    ref.invalidate(homeFeedProvider);

    // 알림 본문에 들어 있던 가족 이름이 한 명 줄었으니 stale — 알림이 활성화된
    // 상태일 때만 재예약 (아직 알림 미설정이면 그냥 둔다).
    final notifRaw =
        await SecureStorage.read(SecureStorage.kNotificationSettings);
    if (notifRaw != null) {
      await ref
          .read(notificationSettingsProvider.notifier)
          .persistAndSchedule();
    }
  }
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({
    required this.member,
    required this.isSelf,
    required this.onTap,
    required this.onViewRecommendations,
    required this.onAddSymptom,
    required this.onDelete,
  });

  final FamilyMember member;
  final bool isSelf;
  final VoidCallback onTap;
  final VoidCallback onViewRecommendations;
  final VoidCallback onAddSymptom;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final card = _buildCardContent(context);
    if (onDelete == null) return card;
    return Dismissible(
      key: ValueKey('family-${member.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: AppTheme.danger,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_outline, color: Colors.white),
            SizedBox(width: 8),
            Text(
              AppStrings.familyDeleteSwipe,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      confirmDismiss: (_) async {
        onDelete!();
        return false; // 실제 제거는 confirmDelete 내부의 invalidate가 처리.
      },
      child: card,
    );
  }

  Widget _buildCardContent(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppTheme.cream,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _avatarFor(member),
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              member.name,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 6),
                            if (isSelf)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  AppStrings.familySelfBadge,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [
                            if (member.age > 0) '${member.age}세',
                            if (member.sex != null) member.sex!.ko,
                          ].join(' · '),
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.subtle,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onAddSymptom,
                    icon: const Icon(Icons.search),
                    tooltip: AppStrings.familyTooltipAddSymptom,
                    color: AppTheme.primary,
                  ),
                  IconButton(
                    onPressed: onViewRecommendations,
                    icon: const Icon(Icons.medication_outlined),
                    tooltip: AppStrings.familyTooltipShowRec,
                    color: AppTheme.primary,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: _lifestyleChips(member),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _avatarFor(FamilyMember m) {
    final age = m.age;
    if (age <= 12) return '🧒';
    if (age <= 17) return '🧑‍🎓';
    if (age >= 60) return '🧓';
    return m.sex == Sex.male ? '👨' : '👩';
  }

  List<Widget> _lifestyleChips(FamilyMember m) {
    String? smokingLabel;
    if (m.input.smoker == true) {
      smokingLabel = m.input.smokingAmount == null
          ? '흡연'
          : '흡연 ${m.input.smokingAmount!.ko}';
    } else if (m.input.smoker == false) {
      smokingLabel = '비흡연';
    }
    String? drinkingLabel;
    if (m.input.drinker == true) {
      final freq = m.input.drinkingFrequency?.ko;
      drinkingLabel = freq == null ? '음주' : '음주 $freq';
    } else if (m.input.drinker == false) {
      drinkingLabel = '비음주';
    }
    final diet = m.input.diet?.ko;
    return [
      if (smokingLabel != null) _chip(icon: '🚬', label: smokingLabel),
      if (drinkingLabel != null) _chip(icon: '🍶', label: drinkingLabel),
      if (diet != null) _chip(icon: '🍱', label: diet),
    ];
  }

  Widget _chip({required String icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.cream,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('👨‍👩‍👧‍👦', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            const Text(
              AppStrings.familyEmptyHeading,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            const Text(
              AppStrings.familyEmptyBody,
              style: TextStyle(color: AppTheme.subtle),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () =>
                  context.push(FamilyChatScreen.routeName),
              child: const Text(AppStrings.familyAddBtn),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          AppStrings.familyLoadFailed,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
