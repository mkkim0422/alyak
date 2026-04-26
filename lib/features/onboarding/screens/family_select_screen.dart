import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/security/secure_storage.dart';
import '../../../core/theme/app_theme.dart';
import '../../notifications/screens/notification_settings_screen.dart';

/// 가족 선택 화면 — 누구를 먼저 등록할지 고르는 카드 그리드.
///
/// 진입 경로:
/// - 웰컴 "가족 먼저 등록할게요" → 본인 없이 가족부터.
/// - 본인 등록 완료 → "네, 가족 등록할게요".
/// - 가족 등록 완료 → "다른 가족도 등록할게요" (재진입).
///
/// 카드 탭 → /onboarding/family-add?mode=onboarding&relation=...
/// 우상단 "완료" → 알림 미설정이면 알림 화면, 설정됐으면 홈.
class FamilySelectScreen extends ConsumerStatefulWidget {
  const FamilySelectScreen({super.key});

  static const routeName = '/onboarding/family-select';

  @override
  ConsumerState<FamilySelectScreen> createState() => _FamilySelectScreenState();
}

class _FamilySelectScreenState extends ConsumerState<FamilySelectScreen> {
  bool _showQuestion = false;
  bool _showCards = false;

  final List<Timer> _timers = [];

  @override
  void initState() {
    super.initState();
    _timers.add(Timer(const Duration(milliseconds: 180),
        () => mounted ? setState(() => _showQuestion = true) : null));
    _timers.add(Timer(const Duration(milliseconds: 700),
        () => mounted ? setState(() => _showCards = true) : null));
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    super.dispose();
  }

  void _onTapRelation(String relation) {
    final encoded = Uri.encodeQueryComponent(relation);
    context.go('/onboarding/family-add?mode=onboarding&relation=$encoded');
  }

  Future<void> _onDone() async {
    final notif =
        await SecureStorage.read(SecureStorage.kNotificationSettings);
    if (!mounted) return;
    if (notif != null) {
      context.go('/home');
    } else {
      context.go(NotificationSettingsScreen.onboardingRoute);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 48),
                  _BotLine(
                    text: AppStrings.familySelectQuestion,
                    show: _showQuestion,
                  ),
                  const SizedBox(height: 32),
                  Expanded(
                    child: AnimatedOpacity(
                      opacity: _showCards ? 1 : 0,
                      duration: const Duration(milliseconds: 480),
                      curve: Curves.easeOut,
                      child: _RelationGrid(onTap: _onTapRelation),
                    ),
                  ),
                ],
              ),
            ),
            // 우상단 완료 버튼.
            Positioned(
              top: 8,
              right: 12,
              child: TextButton(
                onPressed: _onDone,
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.subtle,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                child: const Text(
                  AppStrings.familySelectDone,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BotLine extends StatelessWidget {
  const _BotLine({required this.text, required this.show});
  final String text;
  final bool show;

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: show ? Offset.zero : const Offset(0, 0.25),
      duration: const Duration(milliseconds: 480),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: show ? 1 : 0,
        duration: const Duration(milliseconds: 480),
        curve: Curves.easeOut,
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 22,
            height: 1.45,
            fontWeight: FontWeight.w700,
            color: AppTheme.ink,
          ),
        ),
      ),
    );
  }
}

class _RelationGrid extends StatelessWidget {
  const _RelationGrid({required this.onTap});
  final void Function(String relation) onTap;

  static const List<_Relation> _items = [
    _Relation(AppStrings.relationSpouse, AppStrings.relationSpouseEmoji),
    _Relation(AppStrings.relationSon, AppStrings.relationSonEmoji),
    _Relation(AppStrings.relationDaughter, AppStrings.relationDaughterEmoji),
    _Relation(AppStrings.relationMom, AppStrings.relationMomEmoji),
    _Relation(AppStrings.relationDad, AppStrings.relationDadEmoji),
    _Relation(AppStrings.relationOther, AppStrings.relationOtherEmoji),
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.4,
      physics: const BouncingScrollPhysics(),
      children: [
        for (final r in _items)
          _RelationCard(
            relation: r.label,
            emoji: r.emoji,
            onTap: () => onTap(r.label),
          ),
      ],
    );
  }
}

class _Relation {
  const _Relation(this.label, this.emoji);
  final String label;
  final String emoji;
}

class _RelationCard extends StatelessWidget {
  const _RelationCard({
    required this.relation,
    required this.emoji,
    required this.onTap,
  });

  final String relation;
  final String emoji;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.cream,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 36)),
              const SizedBox(height: 10),
              Text(
                relation,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
