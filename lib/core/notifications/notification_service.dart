import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../l10n/app_strings.dart';

/// 매일 반복되는 영양제 알림 한두 건을 로컬에서 띄우는 얇은 래퍼.
///
/// 서버 푸시(FCM)는 아직 연결하지 않았다 — 정해진 시간에 한국어 reminder만
/// 띄우면 되는 MVP라 로컬로 충분하고, FCM은 백엔드 키 준비된 뒤 추가한다.
// TODO(fcm): integrate firebase_messaging once Supabase Edge Functions
// expose server-triggered events (e.g. 가족 추가 알림, 멘션 푸시).
class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const _channelId = 'alyak.daily.reminder';
  static const _channelName = AppStrings.notifChannelName;
  static const _channelDescription = AppStrings.notifChannelDesc;

  static const int _morningId = 1001;
  static const int _eveningId = 1002;

  /// memberId 별 reorder 알림 id. 음수 영역도 사용 가능하지만 양수만 쓰도록
  /// 마스킹하고 base offset (2_000) 위에서 한정. 같은 멤버에 다시 schedule 하면
  /// 같은 id 로 덮어쓴다 (cancel 후 재등록).
  static int reorderIdFor(String memberId) {
    var hash = 0;
    for (final c in memberId.codeUnits) {
      hash = (hash * 31 + c) & 0x3fffffff;
    }
    return 2000 + (hash % 100000);
  }

  static bool _initialized = false;

  static Future<void> ensureInitialized() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      // iOS 권한은 별도 [requestPermission] 호출로 받는다.
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: androidInit,
        iOS: iosInit,
      ),
    );

    _initialized = true;
  }

  /// iOS는 명시적 시스템 프롬프트, Android 13+는 POST_NOTIFICATIONS
  /// 런타임 권한. 거부되면 false.
  static Future<bool> requestPermission() async {
    await ensureInitialized();

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final granted = await ios?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final granted = await android?.requestNotificationsPermission();
      return granted ?? false;
    }

    return true;
  }

  /// 가족 통합 알림 (아침/저녁 각 1건). 기존 일정은 모두 취소 후 재등록.
  /// [morning], [evening] 둘 다 null 이면 전부 취소.
  /// [memberNames] 는 아침 알림 본문에 들어가는 가족 이름들. 빈 리스트도 허용.
  static Future<void> rescheduleDaily({
    required ({int hour, int minute})? morning,
    required ({int hour, int minute})? evening,
    List<String> memberNames = const [],
  }) async {
    await ensureInitialized();
    await cancelAll();

    if (morning != null) {
      await _scheduleDaily(
        id: _morningId,
        title: AppStrings.notifFamilyMorningTitle,
        body: AppStrings.notifFamilyMorningBody(memberNames),
        hour: morning.hour,
        minute: morning.minute,
      );
    }
    if (evening != null) {
      await _scheduleDaily(
        id: _eveningId,
        title: AppStrings.notifFamilyEveningTitle,
        body: AppStrings.notifFamilyEveningBody,
        hour: evening.hour,
        minute: evening.minute,
      );
    }
  }

  static Future<void> cancelAll() async {
    await ensureInitialized();
    await _plugin.cancel(id: _morningId);
    await _plugin.cancel(id: _eveningId);
  }

  static Future<void> _scheduleDaily({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    final scheduled = _nextInstanceOf(hour, minute);
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduled,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      // 매일 같은 시각에 반복.
      matchDateTimeComponents: DateTimeComponents.time,
      // exact alarm 권한 없이도 동작하는 모드. 정확도는 분 단위로 충분.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  /// memberId 기준 reorder 알림을 [days] 일 뒤 같은 시각에 1회 띄우도록
  /// 예약. 기존 동일 id 의 알림은 덮어쓴다 (cancel + schedule).
  static Future<void> scheduleReorderReminder({
    required String memberId,
    int days = 25,
  }) async {
    await ensureInitialized();
    final id = reorderIdFor(memberId);
    await _plugin.cancel(id: id);
    final scheduled = tz.TZDateTime.now(tz.local).add(Duration(days: days));
    await _plugin.zonedSchedule(
      id: id,
      title: AppStrings.notifReorderTitle,
      body: AppStrings.notifReorderBody(days),
      scheduledDate: scheduled,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      // 1회성 — matchDateTimeComponents 없음.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  static Future<void> cancelReorderReminder(String memberId) async {
    await ensureInitialized();
    await _plugin.cancel(id: reorderIdFor(memberId));
  }

  /// 제품별 재구매 알림 — 사용자가 새 제품을 currentProducts 에 추가했을 때 호출.
  /// `package_size / daily_dose` 기준으로 떨어질 시점을 계산해 그 [daysBefore]
  /// 일 전 같은 시각에 1회 알림.
  ///
  /// 동일 (memberId, productId) 는 덮어씀.
  static Future<void> scheduleProductReorderReminder({
    required String memberId,
    required String productId,
    required String productName,
    required DateTime startedDate,
    required int packageSize,
    required int dailyDose,
    int daysBefore = 3,
  }) async {
    await ensureInitialized();
    if (dailyDose <= 0 || packageSize <= 0) return;
    final daysToFinish = packageSize ~/ dailyDose;
    final estimatedFinish = startedDate.add(Duration(days: daysToFinish));
    final reminder = estimatedFinish.subtract(Duration(days: daysBefore));
    final now = DateTime.now();
    if (!reminder.isAfter(now)) return;

    final id = productReorderIdFor(memberId, productId);
    await _plugin.cancel(id: id);
    final scheduled = tz.TZDateTime.from(reminder, tz.local);
    await _plugin.zonedSchedule(
      id: id,
      title: AppStrings.notifReorderProductTitle,
      body: AppStrings.notifReorderProductBody(productName, daysBefore),
      scheduledDate: scheduled,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: 'reorder:$memberId:$productId',
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  static Future<void> cancelProductReorderReminder({
    required String memberId,
    required String productId,
  }) async {
    await ensureInitialized();
    await _plugin.cancel(id: productReorderIdFor(memberId, productId));
  }

  /// 검진 1년 알림 — `HealthCheckup.checkupDate + 365일` 시점 동일 시각.
  static Future<void> scheduleCheckupReminder({
    required String memberId,
    required DateTime lastCheckupDate,
  }) async {
    await ensureInitialized();
    final reminder = lastCheckupDate.add(const Duration(days: 365));
    if (!reminder.isAfter(DateTime.now())) return;

    final id = checkupReminderIdFor(memberId);
    await _plugin.cancel(id: id);
    final scheduled = tz.TZDateTime.from(reminder, tz.local);
    await _plugin.zonedSchedule(
      id: id,
      title: AppStrings.notifCheckupReminderTitle,
      body: AppStrings.notifCheckupReminderBody,
      scheduledDate: scheduled,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: 'checkup:$memberId',
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  static Future<void> cancelCheckupReminder(String memberId) async {
    await ensureInitialized();
    await _plugin.cancel(id: checkupReminderIdFor(memberId));
  }

  /// memberId + productId → 3000~12999 범위 안 1회성 알림 id.
  static int productReorderIdFor(String memberId, String productId) {
    var hash = 0;
    for (final c in '$memberId|$productId'.codeUnits) {
      hash = (hash * 31 + c) & 0x3fffffff;
    }
    return 3000 + (hash % 10000);
  }

  /// memberId → 13000~22999 범위. 검진 알림 id.
  static int checkupReminderIdFor(String memberId) {
    var hash = 0;
    for (final c in memberId.codeUnits) {
      hash = (hash * 31 + c) & 0x3fffffff;
    }
    return 13000 + (hash % 10000);
  }

  static tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var next = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!next.isAfter(now)) {
      next = next.add(const Duration(days: 1));
    }
    return next;
  }
}
