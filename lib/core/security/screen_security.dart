import 'dart:ui';

import 'package:flutter/material.dart';

import '../../features/auth/screens/pin_lock_screen.dart';
import '../theme/app_theme.dart';
import 'auth_service.dart';

/// 앱을 감싸 (a) 백그라운드 진입 시 블러 오버레이로 민감 정보를 가리고,
/// (b) PIN 설정된 사용자가 5분 이상 백그라운드 후 복귀 시 PIN 잠금 화면을 띄운다.
///
/// CRITICAL: 이 위젯은 MaterialApp.router 의 builder 안쪽에 두어야 한다.
/// 그래야 PinLockScreen 의 Scaffold 가 Material/Theme/Navigator 조상을 찾을 수 있음.
///
/// 블러 오버레이는 PIN 설정 여부와 무관하게 항상 활성 — 첫 사용자(동의 화면) 도
/// 백그라운드 스냅샷에서 가려야 일관된 프라이버시 보호.
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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        _backgroundedAt = DateTime.now().toUtc();
        // 블러는 PIN 여부와 무관하게 즉시 활성 — 스냅샷 노출 방지.
        // 동기 setState 라 framework 가 다음 frame 에 즉시 반영.
        if (mounted && !_showBlur) {
          setState(() => _showBlur = true);
        }
        break;
      case AppLifecycleState.resumed:
        // 세션 만료 검사 — PIN 설정 + 5분 이상 background 면 PIN 잠금.
        // async 내부에서 PIN 체크하지만, 그 전에 블러는 일단 유지하다 결과 반영.
        _checkLockAndUnblur();
        break;
      case AppLifecycleState.detached:
        break;
    }
  }

  Future<void> _checkLockAndUnblur() async {
    final bg = _backgroundedAt;
    bool shouldLock = false;
    if (bg != null) {
      final elapsed = DateTime.now().toUtc().difference(bg);
      if (elapsed >= AuthService.sessionTimeout) {
        if (await AuthService.instance.isPinSet()) {
          shouldLock = true;
        }
      }
    }
    if (!mounted) return;
    setState(() {
      _showBlur = false;
      if (shouldLock) _showLock = true;
    });
  }

  void _onUnlocked() {
    if (!mounted) return;
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
