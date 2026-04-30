import 'dart:ui';

import 'package:flutter/material.dart';

import '../../features/auth/screens/pin_lock_screen.dart';
import '../theme/app_theme.dart';
import 'auth_service.dart';

/// 앱을 감싸 (a) 백그라운드 진입 시 블러 오버레이로 민감 정보를 가리고,
/// (b) 5분 이상 백그라운드 후 복귀 시 PIN 잠금 화면을 띄운다.
///
/// PIN 미설정 사용자는 모든 기능을 그대로 사용 — lifecycle 분기는 PIN 설정된
/// 경우에만 활성화된다.
class SecureAppShell extends StatefulWidget {
  const SecureAppShell({required this.child, super.key});

  final Widget child;

  @override
  State<SecureAppShell> createState() => _SecureAppShellState();
}

class _SecureAppShellState extends State<SecureAppShell>
    with WidgetsBindingObserver {
  DateTime? _backgroundedAt;
  bool _showBlur = false;
  bool _showLock = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    final pinSet = await AuthService.instance.isPinSet();
    if (!mounted) return;

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        // 백그라운드 진입 시점 기록 + 블러 오버레이 (스냅샷에 민감 정보 노출 방지).
        _backgroundedAt = DateTime.now().toUtc();
        if (pinSet) {
          setState(() => _showBlur = true);
        }
        break;
      case AppLifecycleState.resumed:
        final bg = _backgroundedAt;
        // 세션 만료 검사 — 5분 이상 background 면 PIN 잠금 띄움.
        if (pinSet && bg != null) {
          final elapsed = DateTime.now().toUtc().difference(bg);
          if (elapsed >= AuthService.sessionTimeout) {
            setState(() => _showLock = true);
          }
        }
        setState(() => _showBlur = false);
        break;
      case AppLifecycleState.detached:
        break;
    }
  }

  void _onUnlocked() {
    setState(() => _showLock = false);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (_showBlur && !_showLock) const _BlurOverlay(),
        if (_showLock) PinLockScreen(onUnlocked: _onUnlocked),
      ],
    );
  }
}

class _BlurOverlay extends StatelessWidget {
  const _BlurOverlay();

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
      child: Container(
        color: Colors.white.withValues(alpha: 0.55),
        alignment: Alignment.center,
        child: const Icon(
          Icons.lock_outline,
          color: AppTheme.subtle,
          size: 36,
        ),
      ),
    );
  }
}
