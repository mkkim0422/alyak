import 'package:flutter/material.dart';

import '../../features/auth/screens/pin_lock_screen.dart';
import 'auth_service.dart';

/// 민감 액션 (데이터 삭제, 내보내기) 직전에 호출하는 fresh-auth 가드.
///
/// 동작:
/// 1) PIN 미설정 → 통과 (단계 강제 흐름이 미완료된 시점이거나 디버그).
/// 2) 마지막 인증이 [within] 이내면 통과.
/// 3) 그렇지 않으면 [PinLockScreen] 을 풀스크린 모달로 띄워 재인증 받고,
///    성공 시 true / 취소·실패 시 false.
///
/// [within] 의 기본값은 1분 — Settings 의 5분 세션 보다 더 좁은 윈도우.
/// 사용자가 설정 화면 들어와 한참 후에 삭제 누르는 시나리오에서도 한 번 더
/// 검증해 destructive 동작을 방지한다.
Future<bool> ensureFreshAuth(
  BuildContext context, {
  Duration within = const Duration(minutes: 1),
}) async {
  final auth = AuthService.instance;
  if (!await auth.isPinSet()) return true;

  final last = await auth.getLastAuthTime();
  if (last != null) {
    final elapsed = DateTime.now().toUtc().difference(last);
    if (elapsed < within) return true;
  }

  if (!context.mounted) return false;

  // 풀스크린 모달로 PIN 잠금 화면 푸시. onUnlocked 가 호출되면 true 반환.
  final ok = await Navigator.of(context, rootNavigator: true).push<bool>(
    MaterialPageRoute<bool>(
      fullscreenDialog: true,
      builder: (ctx) => PinLockScreen(
        onUnlocked: () => Navigator.of(ctx).pop(true),
      ),
    ),
  );
  return ok == true;
}
