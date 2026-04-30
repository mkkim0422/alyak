import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/api/supabase_client.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/security/secure_action.dart';
import '../../core/security/secure_storage.dart';
import '../../core/theme/app_theme.dart';
import '../admin/admin_panel_screen.dart';
import '../auth/screens/pin_change_screen.dart';
import '../family/providers/family_members_provider.dart';
import '../family/screens/family_management_screen.dart';
import '../home/providers/home_feed_provider.dart';
import '../legal/disclaimer_screen.dart';
import '../legal/privacy_policy_screen.dart';
import '../notifications/models/notification_settings.dart';
import '../notifications/providers/notification_settings_provider.dart';
import '../notifications/screens/notification_settings_screen.dart';
import '../onboarding/models/user_role.dart';
import '../onboarding/providers/onboarding_providers.dart';
import '../privacy/privacy_consent_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const routeName = '/settings';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(notificationSettingsProvider);
    final roleAsync = ref.watch(userRoleFutureProvider);
    final email = SupabaseService.auth.currentUser?.email ?? '게스트';

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          _SectionHeader(AppStrings.settingsSectionNotifications),
          _Tile(
            icon: Icons.notifications_outlined,
            title: AppStrings.settingsTileNotifTime,
            subtitle: _settingsSubtitle(settings),
            trailing: const Icon(Icons.chevron_right, color: AppTheme.subtle),
            onTap: () =>
                context.push(NotificationSettingsScreen.settingsRoute),
          ),
          const _Divider(),
          _SectionHeader(AppStrings.settingsSectionFamily),
          _Tile(
            icon: Icons.group_outlined,
            title: AppStrings.settingsTileFamilyManage,
            subtitle: AppStrings.settingsTileFamilyManageSub,
            trailing: const Icon(Icons.chevron_right, color: AppTheme.subtle),
            onTap: () => context.push(FamilyManagementScreen.routeName),
          ),
          const _Divider(),
          _SectionHeader('보안'),
          _Tile(
            icon: Icons.lock_outline,
            title: 'PIN 변경',
            subtitle: '4자리 PIN 으로 가족 정보를 보호해요. '
                'PIN 자체는 해제할 수 없고, 데이터 삭제로만 초기화돼요',
            trailing: const Icon(Icons.chevron_right, color: AppTheme.subtle),
            onTap: () => context.push(PinChangeScreen.routeName),
          ),
          const _Divider(),
          _SectionHeader(AppStrings.settingsSectionAccount),
          _Tile(
            icon: Icons.account_circle_outlined,
            title: AppStrings.settingsTileLogin,
            subtitle: email,
          ),
          _Tile(
            icon: Icons.login,
            title: AppStrings.settingsTileGoogleLogin,
            subtitle: AppStrings.settingsTileGoogleLoginSub,
            onTap: () => _toast(context, AppStrings.settingsTileGoogleSoon),
          ),
          _Tile(
            icon: Icons.logout,
            title: AppStrings.settingsTileLogout,
            iconColor: AppTheme.subtle,
            onTap: () => _confirmLogout(context, ref),
          ),
          _Tile(
            icon: Icons.delete_forever_outlined,
            title: AppStrings.settingsTileDeleteAll,
            iconColor: AppTheme.danger,
            titleColor: AppTheme.danger,
            onTap: () => _confirmDeleteAccount(context, ref),
          ),
          if (roleAsync.value == UserRole.manager) ...[
            const _Divider(),
            _SectionHeader(AppStrings.settingsSectionAdmin),
            _Tile(
              icon: Icons.shield_outlined,
              title: AppStrings.settingsTileAdmin,
              trailing:
                  const Icon(Icons.chevron_right, color: AppTheme.subtle),
              onTap: () => context.push(AdminPanelScreen.routeName),
            ),
          ],
          const _Divider(),
          _SectionHeader(AppStrings.settingsSectionInfo),
          _Tile(
            icon: Icons.policy_outlined,
            title: AppStrings.settingsTilePrivacy,
            trailing: const Icon(Icons.chevron_right, color: AppTheme.subtle),
            onTap: () => context.push(PrivacyPolicyScreen.routeName),
          ),
          _Tile(
            icon: Icons.gpp_maybe_outlined,
            title: '면책 사항',
            trailing: const Icon(Icons.chevron_right, color: AppTheme.subtle),
            onTap: () => context.push(DisclaimerScreen.routeName),
          ),
          const _AppVersionTile(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  String _settingsSubtitle(NotificationSettings s) {
    if (!s.enabled) return AppStrings.settingsNotifOff;
    return AppStrings.settingsNotifOn(s.morningTrigger.hhmm, s.evening.hhmm);
  }

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(AppStrings.settingsLogoutDialogTitle),
        content: const Text(AppStrings.settingsLogoutDialogBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(AppStrings.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(AppStrings.settingsTileLogout),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _wipeEverything(ref);
    if (!context.mounted) return;
    context.go(PrivacyConsentScreen.routeName);
  }

  Future<void> _confirmDeleteAccount(
    BuildContext context,
    WidgetRef ref,
  ) async {
    // 0단계: fresh auth (1분 이내) — PIN 설정된 경우 한 번 더 검증.
    if (!await ensureFreshAuth(context)) return;
    if (!context.mounted) return;

    // 1단계: 일반 confirm.
    final firstOk = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(AppStrings.settingsDeleteDialogTitle),
        content: const Text(AppStrings.settingsDeleteDialogBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(AppStrings.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
            child: const Text(AppStrings.delete),
          ),
        ],
      ),
    );
    if (firstOk != true) return;
    if (!context.mounted) return;

    // 2단계: "삭제" 라고 타이핑 받기. 오타 방지.
    final controller = TextEditingController();
    final confirmText = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final canSubmit = controller.text.trim() == '삭제';
          return AlertDialog(
            title: const Text('정말 삭제할까요?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '복구할 수 없어요. 모든 가족 정보 / 체크인 기록 / 알림 설정이 사라집니다.\n'
                  '계속하려면 아래 칸에 "삭제" 라고 입력해주세요.',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: '삭제',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text(AppStrings.cancel),
              ),
              TextButton(
                onPressed: canSubmit ? () => Navigator.pop(ctx, true) : null,
                style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
                child: const Text(AppStrings.delete),
              ),
            ],
          );
        },
      ),
    );
    if (confirmText != true) return;
    await _wipeEverything(ref);
    if (!context.mounted) return;
    context.go(PrivacyConsentScreen.routeName);
  }

  /// SecureStorage 통째로 비우고 알림도 취소. Supabase 로그아웃 시도.
  Future<void> _wipeEverything(WidgetRef ref) async {
    try {
      await SupabaseService.auth.signOut();
    } catch (_) {
      // 게스트 모드라 sign-in이 없을 수 있음.
    }
    await NotificationService.cancelAll();
    await SecureStorage.wipe();
    ref.invalidate(familyMembersProvider);
    ref.invalidate(homeFeedProvider);
    ref.invalidate(userRoleFutureProvider);
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: AppTheme.subtle,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) =>
      const Divider(color: AppTheme.line, height: 24);
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.iconColor,
    this.titleColor,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Color? iconColor;
  final Color? titleColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: iconColor ?? AppTheme.primary, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: titleColor ?? AppTheme.ink,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.subtle,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}

class _AppVersionTile extends StatelessWidget {
  const _AppVersionTile();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snap) {
        final ver = snap.data;
        final subtitle = ver == null
            ? AppStrings.checkingVersion
            : '${ver.version} (build ${ver.buildNumber})';
        return _Tile(
          icon: Icons.info_outline,
          title: '앱 버전',
          subtitle: subtitle,
        );
      },
    );
  }
}
