import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/notifications/notification_service.dart';
import '../../../core/security/secure_storage.dart';
import '../../family/providers/family_members_provider.dart';
import '../models/notification_settings.dart';

class NotificationSettingsController extends Notifier<NotificationSettings> {
  @override
  NotificationSettings build() {
    _hydrate();
    return NotificationSettings.defaults;
  }

  Future<void> _hydrate() async {
    final raw = await SecureStorage.read(SecureStorage.kNotificationSettings);
    if (raw == null) return;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      state = NotificationSettings.fromJson(json);
    } catch (_) {
      // 손상된 값은 default 로 두고 덮어쓴다.
    }
  }

  void setEnabled(bool enabled) {
    state = state.copyWith(enabled: enabled);
  }

  void setEarliestDepart(TimeOfDayPersist t) {
    state = state.copyWith(earliestDepart: t);
  }

  void setEvening(TimeOfDayPersist t) {
    state = state.copyWith(evening: t);
  }

  void setReorderEnabled(bool enabled) {
    state = state.copyWith(reorderEnabled: enabled);
  }

  void setReorderDaysBefore(int days) {
    state = state.copyWith(reorderDaysBefore: days);
  }

  void setCheckupEnabled(bool enabled) {
    state = state.copyWith(checkupEnabled: enabled);
  }

  /// 1. 디스크 저장 (식별 정보 아님)
  /// 2. OS 알림 일정에 반영. 가족 이름은 현재 등록된 가족에서 읽어 본문에 박는다.
  /// 가족이 추가/삭제될 때 다시 호출해 주면 본문이 갱신된다.
  Future<void> persistAndSchedule() async {
    final s = state;
    await SecureStorage.write(
      SecureStorage.kNotificationSettings,
      jsonEncode(s.toJson()),
    );

    if (!s.enabled) {
      await NotificationService.cancelAll();
      return;
    }

    // 본문에 들어갈 가족 이름. 가족이 아직 없으면 빈 리스트 — 본문 fallback 사용.
    List<String> names = const [];
    try {
      final members = await ref.read(familyMembersProvider.future);
      names = members.map((m) => m.name).toList();
    } catch (_) {
      // 멤버 로드 실패는 알림 스케줄을 막지 않는다.
    }

    final m = s.morningTrigger;
    await NotificationService.rescheduleDaily(
      morning: (hour: m.hour, minute: m.minute),
      evening: (hour: s.evening.hour, minute: s.evening.minute),
      memberNames: names,
    );
  }
}

final notificationSettingsProvider = NotifierProvider<
    NotificationSettingsController, NotificationSettings>(
  NotificationSettingsController.new,
);
