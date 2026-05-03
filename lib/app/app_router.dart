import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/security/secure_storage.dart';
import '../core/theme/app_theme.dart';
import '../features/admin/admin_panel_screen.dart';
import '../features/auth/screens/pin_change_screen.dart';
import '../features/current_check/screens/current_check_screen.dart';
import '../features/auth/screens/pin_lock_screen.dart';
import '../features/auth/screens/pin_setup_screen.dart';
import '../features/family/screens/family_edit_screen.dart';
import '../features/family/screens/family_management_screen.dart';
import '../features/family/screens/manual_supplement_input_screen.dart';
import '../features/family/screens/recommendation_detail_screen.dart';
import '../features/family/screens/supplement_guide_screen.dart';
import '../features/health_checkup/screens/health_checkup_input_screen.dart';
import '../features/home/screens/home_screen.dart';
import '../features/legal/disclaimer_screen.dart';
import '../features/legal/privacy_policy_screen.dart';
import '../features/notifications/screens/notification_settings_screen.dart';
import '../features/onboarding/family_chat/family_chat_screen.dart';
import '../features/onboarding/screens/family_select_screen.dart';
import '../features/onboarding/screens/welcome_screen.dart';
import '../features/privacy/privacy_consent_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/symptoms/screens/symptom_search_screen.dart';

class AppRouter {
  static GoRouter build() {
    return GoRouter(
      initialLocation: '/boot',
      redirect: _redirect,
      routes: [
        GoRoute(
          path: '/boot',
          builder: (context, state) => const _BootSplash(),
        ),
        GoRoute(
          path: PrivacyConsentScreen.routeName,
          builder: (context, state) => const PrivacyConsentScreen(),
        ),
        GoRoute(
          path: PinSetupScreen.routeName,
          builder: (context, state) => const PinSetupScreen(),
        ),
        GoRoute(
          path: PinLockScreen.routeName,
          builder: (context, state) => const PinLockScreen(),
        ),
        GoRoute(
          path: PinChangeScreen.routeName,
          builder: (context, state) => const PinChangeScreen(),
        ),
        GoRoute(
          path: WelcomeScreen.routeName,
          builder: (context, state) => const WelcomeScreen(),
        ),
        GoRoute(
          path: FamilyChatScreen.routeName,
          builder: (context, state) {
            final modeStr = state.uri.queryParameters['mode'];
            final mode = switch (modeStr) {
              'own' => FamilyChatMode.own,
              'onboarding' => FamilyChatMode.onboarding,
              _ => FamilyChatMode.manage,
            };
            return FamilyChatScreen(
              mode: mode,
              relation: state.uri.queryParameters['relation'],
            );
          },
        ),
        GoRoute(
          path: FamilySelectScreen.routeName,
          builder: (context, state) => const FamilySelectScreen(),
        ),
        GoRoute(
          path: NotificationSettingsScreen.onboardingRoute,
          builder: (context, state) => const NotificationSettingsScreen(),
        ),
        GoRoute(
          path: NotificationSettingsScreen.settingsRoute,
          builder: (context, state) => const NotificationSettingsScreen(
            mode: NotificationSettingsMode.settings,
          ),
        ),
        GoRoute(
          path: HomeScreen.routeName,
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: FamilyManagementScreen.routeName,
          builder: (context, state) => const FamilyManagementScreen(),
        ),
        GoRoute(
          path: '${FamilyEditScreen.routeName}/:id',
          builder: (context, state) =>
              FamilyEditScreen(memberId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/family/:id/recommendations',
          builder: (context, state) => RecommendationDetailScreen(
            memberId: state.pathParameters['id']!,
          ),
        ),
        GoRoute(
          path: SettingsScreen.routeName,
          builder: (context, state) => const SettingsScreen(),
        ),
        GoRoute(
          path: AdminPanelScreen.routeName,
          builder: (context, state) => const AdminPanelScreen(),
        ),
        GoRoute(
          path: PrivacyPolicyScreen.routeName,
          builder: (context, state) => const PrivacyPolicyScreen(),
        ),
        GoRoute(
          path: DisclaimerScreen.routeName,
          builder: (context, state) => const DisclaimerScreen(),
        ),
        GoRoute(
          path: SymptomSearchScreen.routeName,
          builder: (context, state) => SymptomSearchScreen(
            initialMemberId: state.uri.queryParameters['member'],
          ),
        ),
        GoRoute(
          path: '/supplement-guide/:supplementId',
          builder: (context, state) => SupplementGuideScreen(
            supplementId: state.pathParameters['supplementId']!,
            memberId: state.uri.queryParameters['member'],
          ),
        ),
        GoRoute(
          path: '${HealthCheckupInputScreen.routeName}/:memberId',
          builder: (context, state) => HealthCheckupInputScreen(
            memberId: state.pathParameters['memberId']!,
          ),
        ),
        GoRoute(
          path: '${CurrentCheckScreen.routeName}/:memberId',
          builder: (context, state) => CurrentCheckScreen(
            memberId: state.pathParameters['memberId']!,
          ),
        ),
        GoRoute(
          path: ManualSupplementInputScreen.routeName,
          builder: (context, state) => ManualSupplementInputScreen(
            memberId: state.uri.queryParameters['member_id'] ?? '',
          ),
        ),
      ],
    );
  }

  /// 첫 진입 시 동의/온보딩 완료 상태를 보고 진입점을 결정.
  ///
  /// 진입 순서:
  ///   privacy_consent → welcome → family_add → notification → home
  ///
  /// PIN 강제 단계는 사용자 요청으로 제거됨 — 의료법 대상 의료기기가 아니라
  /// 영양제 가이드 일반 정보 제공이라 강제 잠금이 과도함. PIN 화면/AuthService
  /// 코드는 유지 (향후 옵션으로 다시 노출 가능).
  static Future<String?> _redirect(
    BuildContext context,
    GoRouterState state,
  ) async {
    if (state.matchedLocation != '/boot') return null;

    final consent = await SecureStorage.read(SecureStorage.kPrivacyConsentAt);
    if (consent == null) return PrivacyConsentScreen.routeName;
    // TODO(legal): when PrivacyConsentScreen.consentVersion bumps, compare with
    // the stored kPrivacyConsentVersion and re-prompt if outdated.

    final notif =
        await SecureStorage.read(SecureStorage.kNotificationSettings);
    if (notif == null) return WelcomeScreen.routeName;
    return HomeScreen.routeName;
  }
}

class _BootSplash extends StatelessWidget {
  const _BootSplash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(color: AppTheme.primary),
      ),
    );
  }
}
