import 'package:flutter/material.dart';

import '../../core/branding/app_icon_painter.dart';
import '../../core/theme/app_theme.dart';

/// 루팅/탈옥된 기기에서만 띄우는 단독 앱 트리.
///
/// 라우터·Riverpod 트리 자체를 만들지 않는다 → 어떤 화면으로도 진입 불가.
/// AppBar 뒤로가기, 시스템 뒤로 모두 막힌다 (back 누르면 앱 minimize되거나
/// onWillPop으로 차단).
class RootBlockedApp extends StatelessWidget {
  const RootBlockedApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '알약',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const _BlockedScreen(),
    );
  }
}

class _BlockedScreen extends StatelessWidget {
  const _BlockedScreen();

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const BrandIcon(size: 96),
                  const SizedBox(height: 24),
                  const Icon(
                    Icons.shield_outlined,
                    color: AppTheme.danger,
                    size: 56,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '실행할 수 없는 기기예요',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '보안을 위해 루팅 / 탈옥된 기기에서는 실행할 수 없어요.\n'
                    '일반 기기에서 다시 실행해 주세요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      color: AppTheme.subtle,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
