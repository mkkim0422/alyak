import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../core/theme/app_theme.dart';
import '../models/notification_settings.dart';
import '../providers/notification_settings_provider.dart';

enum NotificationSettingsMode { onboarding, settings }

/// 가족 통합 알림 설정 화면.
/// - 토글 1개로 알림 ON/OFF
/// - 가장 이른 출발 시간 (default 7:30) → 30분 전에 아침 알림
/// - 저녁 알림 시간 (default 20:00)
class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({
    this.mode = NotificationSettingsMode.onboarding,
    super.key,
  });

  final NotificationSettingsMode mode;

  static const onboardingRoute = '/onboarding/notification';
  static const settingsRoute = '/settings/notification';

  /// Backwards compatibility for older imports.
  static const routeName = onboardingRoute;

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(notificationSettingsProvider);
    final ctrl = ref.read(notificationSettingsProvider.notifier);
    final theme = Theme.of(context);

    final isOnboarding =
        widget.mode == NotificationSettingsMode.onboarding;
    return Scaffold(
      appBar: AppBar(
        title: Text(isOnboarding
            ? AppStrings.notifSettingsTitleOnboarding
            : AppStrings.notifSettingsTitleSettings),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isOnboarding) ...[
                Text(
                  AppStrings.notifSettingsHeading,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  AppStrings.notifSettingsSub,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.subtle,
                  ),
                ),
                const SizedBox(height: 24),
              ] else
                const SizedBox(height: 8),
              _ToggleCard(
                value: settings.enabled,
                onChanged: ctrl.setEnabled,
              ),
              const SizedBox(height: 20),
              if (settings.enabled) ...[
                const Divider(color: AppTheme.line, height: 1),
                const SizedBox(height: 20),
                _Question(
                  text: AppStrings.notifQEarliest,
                  sub: AppStrings.notifQEarliestSub,
                ),
                const SizedBox(height: 12),
                _TimeRow(
                  label: AppStrings.notifSettingsTimeEarliest,
                  emoji: '☀️',
                  time: settings.earliestDepart,
                  onChanged: ctrl.setEarliestDepart,
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 36),
                  child: Text(
                    '실제 알림: ${settings.morningTrigger.hhmm}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.subtle,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _Question(text: AppStrings.notifQEvening),
                const SizedBox(height: 12),
                _TimeRow(
                  label: AppStrings.notifSettingsTimeEvening,
                  emoji: '🌙',
                  time: settings.evening,
                  onChanged: ctrl.setEvening,
                ),
                if (!isOnboarding) ...[
                  const SizedBox(height: 24),
                  const Divider(color: AppTheme.line, height: 1),
                  const SizedBox(height: 16),
                  _ReorderToggleSection(
                    enabled: settings.reorderEnabled,
                    daysBefore: settings.reorderDaysBefore,
                    onToggle: ctrl.setReorderEnabled,
                    onDaysChanged: ctrl.setReorderDaysBefore,
                  ),
                  const SizedBox(height: 16),
                  _CheckupToggle(
                    enabled: settings.checkupEnabled,
                    onChanged: ctrl.setCheckupEnabled,
                  ),
                ],
              ],
              const Spacer(),
              FilledButton(
                onPressed: _saving ? null : _start,
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : Text(isOnboarding
                        ? AppStrings.notifSettingsCtaStart
                        : AppStrings.notifSettingsCtaSave),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _start() async {
    setState(() => _saving = true);
    try {
      final settings = ref.read(notificationSettingsProvider);

      if (settings.enabled) {
        final granted = await NotificationService.requestPermission();
        if (!mounted) return;
        if (!granted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(AppStrings.notifSettingsDenied),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }

      await ref
          .read(notificationSettingsProvider.notifier)
          .persistAndSchedule();
      if (!mounted) return;
      if (widget.mode == NotificationSettingsMode.onboarding) {
        context.go('/home');
      } else {
        context.pop();
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _ToggleCard extends StatelessWidget {
  const _ToggleCard({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.line),
            color: Colors.white,
          ),
          child: Row(
            children: [
              const Text('🔔', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  AppStrings.notifSettingsToggleLabel,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Switch(
                value: value,
                onChanged: onChanged,
                activeThumbColor: AppTheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Question extends StatelessWidget {
  const _Question({required this.text, this.sub});
  final String text;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppTheme.ink,
          ),
        ),
        if (sub != null) ...[
          const SizedBox(height: 4),
          Text(
            sub!,
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.subtle,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}

class _TimeRow extends StatelessWidget {
  const _TimeRow({
    required this.label,
    required this.emoji,
    required this.time,
    required this.onChanged,
  });

  final String label;
  final String emoji;
  final TimeOfDayPersist time;
  final ValueChanged<TimeOfDayPersist> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 22)),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        const Spacer(),
        OutlinedButton(
          onPressed: () => _pick(context),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(96, 44),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            foregroundColor: AppTheme.ink,
            side: const BorderSide(color: AppTheme.line),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            time.hhmm,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pick(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: time.hour, minute: time.minute),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child ?? const SizedBox.shrink(),
      ),
    );
    if (picked != null) {
      onChanged(TimeOfDayPersist(picked.hour, picked.minute));
    }
  }
}

/// 재구매 알림 토글 + 며칠 전 슬라이더 (1~7일).
class _ReorderToggleSection extends StatelessWidget {
  const _ReorderToggleSection({
    required this.enabled,
    required this.daysBefore,
    required this.onToggle,
    required this.onDaysChanged,
  });

  final bool enabled;
  final int daysBefore;
  final ValueChanged<bool> onToggle;
  final ValueChanged<int> onDaysChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('🛒', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                '재구매 알림 (떨어지기 전)',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
            Switch(
              value: enabled,
              onChanged: onToggle,
              activeThumbColor: AppTheme.primary,
            ),
          ],
        ),
        if (enabled) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 32),
            child: Text(
              '$daysBefore일 전 알림',
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.subtle,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Slider(
            value: daysBefore.toDouble().clamp(1, 7),
            min: 1,
            max: 7,
            divisions: 6,
            label: '$daysBefore일 전',
            activeColor: AppTheme.primary,
            onChanged: (v) => onDaysChanged(v.round()),
          ),
        ],
      ],
    );
  }
}

/// 검진 1년 후 알림 토글.
class _CheckupToggle extends StatelessWidget {
  const _CheckupToggle({required this.enabled, required this.onChanged});
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text('🩺', style: TextStyle(fontSize: 20)),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '검진 알림 (1년 후)',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 2),
              Text(
                '마지막 검진일 1년 뒤 자동 안내',
                style: TextStyle(fontSize: 12, color: AppTheme.subtle),
              ),
            ],
          ),
        ),
        Switch(
          value: enabled,
          onChanged: onChanged,
          activeThumbColor: AppTheme.primary,
        ),
      ],
    );
  }
}
