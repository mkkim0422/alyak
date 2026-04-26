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
    return SecureAppShell(
      child: MaterialApp.router(
        title: '알약',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        routerConfig: _router,
      ),
    );
  }
}
