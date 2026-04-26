import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/api/supabase_client.dart';
import 'core/config/env_config.dart';
import 'core/notifications/notification_service.dart';
import 'core/security/encryption_service.dart';
import 'core/security/root_detection.dart';
import 'features/security/root_blocked_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations(
    const [DeviceOrientation.portraitUp],
  );

  await EnvConfig.load();

  // 루팅/탈옥 감지: 컴프롬마이즈 확인되면 일반 앱 트리는 띄우지 않고
  // 차단 화면만 보여 준다. 디버그 빌드에선 false-positive 회피를 위해 통과.
  final rootStatus = await RootDetection.check();
  if (rootStatus == RootStatus.compromised) {
    runApp(const RootBlockedApp());
    return;
  }

  // SecureStorage 의존 → encryption은 root check 이후, 그러나 Supabase 등
  // 다른 init 전에 마쳐야 한다 (Supabase 자체는 키를 안 쓰지만 다른 서비스가
  // 초기 로드 시 암호화된 데이터를 건드릴 수 있어서).
  await EncryptionService.initialize();
  await SupabaseService.initialize();
  await NotificationService.ensureInitialized();

  runApp(const ProviderScope(child: AlyakApp()));
}
