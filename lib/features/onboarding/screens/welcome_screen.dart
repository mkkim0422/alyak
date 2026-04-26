import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/security/secure_storage.dart';
import '../../../core/theme/app_theme.dart';
import '../models/user_role.dart';
import 'family_select_screen.dart';

/// Toss 스타일 환영 화면.
///
/// 흰 배경에 봇 메시지 3개가 시간차로 나타나고, 마지막에 두 개의 CTA 버튼이
/// 떠오른다. 헤더·아이콘 같은 정적 요소는 모두 빠지고 대화 흐름에 집중.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  static const routeName = '/onboarding/welcome';

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _showM1 = false;
  bool _showM2 = false;
  bool _showM3 = false;
  bool _showButtons = false;

  final List<Timer> _timers = [];

  @override
  void initState() {
    super.initState();
    _timers.add(Timer(const Duration(milliseconds: 200),
        () => mounted ? setState(() => _showM1 = true) : null));
    _timers.add(Timer(const Duration(milliseconds: 1000),
        () => mounted ? setState(() => _showM2 = true) : null));
    _timers.add(Timer(const Duration(milliseconds: 1600),
        () => mounted ? setState(() => _showM3 = true) : null));
    _timers.add(Timer(const Duration(milliseconds: 2400),
        () => mounted ? setState(() => _showButtons = true) : null));
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    super.dispose();
  }

  Future<void> _ensureRole() async {
    final existing = await SecureStorage.read(SecureStorage.kUserRole);
    if (existing == null) {
      await SecureStorage.write(
        SecureStorage.kUserRole,
        UserRole.manager.storageValue,
      );
    }
  }

  Future<void> _onSelf() async {
    await _ensureRole();
    if (!mounted) return;
    context.go('/onboarding/family-add?mode=own');
  }

  Future<void> _onFamily() async {
    await _ensureRole();
    if (!mounted) return;
    context.go(FamilySelectScreen.routeName);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(flex: 2),
              _Message(text: AppStrings.welcomeMsg1, show: _showM1),
              const SizedBox(height: 14),
              _Message(text: AppStrings.welcomeMsg2, show: _showM2),
              const SizedBox(height: 14),
              _Message(text: AppStrings.welcomeMsg3, show: _showM3),
              const Spacer(flex: 3),
              _Buttons(
                show: _showButtons,
                onSelf: _onSelf,
                onFamily: _onFamily,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, required this.show});
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

class _Buttons extends StatelessWidget {
  const _Buttons({
    required this.show,
    required this.onSelf,
    required this.onFamily,
  });

  final bool show;
  final VoidCallback onSelf;
  final VoidCallback onFamily;

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: show ? Offset.zero : const Offset(0, 0.3),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: show ? 1 : 0,
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeOut,
        child: IgnorePointer(
          ignoring: !show,
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onSelf,
                  child: const Text(AppStrings.welcomeCtaSelf),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: onFamily,
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.subtle,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    AppStrings.welcomeCtaFamily,
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
      ),
    );
  }
}
