import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/notifications/notification_service.dart';
import '../core/security/screen_security.dart';
import '../core/security/secure_storage.dart';
import '../core/security/session_guard.dart';
import '../core/theme/app_theme.dart';
import '../features/privacy/privacy_consent_screen.dart';
import 'app_router.dart';

class AlyakApp extends ConsumerStatefulWidget {
  const AlyakApp({super.key});

  @override
  ConsumerState<AlyakApp> createState() => _AlyakAppState();
}

class _AlyakAppState extends ConsumerState<AlyakApp> {
  late final _router = AppRouter.build();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _enforceIdleLogout();
      await SessionGuard.touch();
    });
  }

  Future<void> _enforceIdleLogout() async {
    if (!await SessionGuard.shouldForceLogout()) return;
    await NotificationService.cancelAll();
    await SecureStorage.wipe();
    final ctx = _router.routerDelegate.navigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return;
    ctx.go(PrivacyConsentScreen.routeName);
  }

  @override
  Widget build(BuildContext context) {
    // SecureAppShell 은 MaterialApp 안쪽 builder 로 두어야 한다.
    // 그래야 백그라운드 잠금 시 띄우는 PinLockScreen (Scaffold 사용) 이
    // Material/Theme/Navigator 조상을 찾을 수 있다. 바깥에 두면 production 에서
    // "No Material widget found" assertion 으로 크래시.
    return MaterialApp.router(
      title: '알약',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: _router,
      builder: (context, child) =>
          SecureAppShell(child: child ?? const SizedBox.shrink()),
    );
  }
}
