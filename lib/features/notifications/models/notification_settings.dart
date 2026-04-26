/// 알림 설정 모델. 이전 버전은 멤버 단위 once/twice 였지만 v2 부터는
/// 가족 통합 1쌍(아침/저녁) 으로 단순화 — `enabled` + `earliestDepart` + `evening`.
///
/// `earliestDepart` 는 가족 중 가장 이른 출발 시간이고, 실제 아침 알림은
/// 그보다 30분 일찍 발사된다 ([morningTrigger] getter 참조).
class TimeOfDayPersist {
  const TimeOfDayPersist(this.hour, this.minute);
  final int hour;
  final int minute;

  Map<String, dynamic> toJson() => {'hour': hour, 'minute': minute};

  factory TimeOfDayPersist.fromJson(Map<String, dynamic> json) =>
      TimeOfDayPersist(json['hour'] as int, json['minute'] as int);

  String get hhmm =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  /// `minutes` 분 만큼 빼서 새 시간 반환. 자정을 넘어가면 wrap-around.
  TimeOfDayPersist subtractMinutes(int minutes) {
    final total = (hour * 60 + minute - minutes) % (24 * 60);
    final wrapped = (total + 24 * 60) % (24 * 60);
    return TimeOfDayPersist(wrapped ~/ 60, wrapped % 60);
  }
}

class NotificationSettings {
  const NotificationSettings({
    required this.enabled,
    required this.earliestDepart,
    required this.evening,
  });

  final bool enabled;
  /// 가족 중 가장 이른 출발 시간. 실제 알림은 [morningTrigger] (이 시간 -30분).
  final TimeOfDayPersist earliestDepart;
  final TimeOfDayPersist evening;

  static const defaults = NotificationSettings(
    enabled: true,
    earliestDepart: TimeOfDayPersist(7, 30),
    evening: TimeOfDayPersist(20, 0),
  );

  /// 실제 아침 알림이 울리는 시각 — `earliestDepart - 30분`.
  TimeOfDayPersist get morningTrigger =>
      earliestDepart.subtractMinutes(30);

  NotificationSettings copyWith({
    bool? enabled,
    TimeOfDayPersist? earliestDepart,
    TimeOfDayPersist? evening,
  }) {
    return NotificationSettings(
      enabled: enabled ?? this.enabled,
      earliestDepart: earliestDepart ?? this.earliestDepart,
      evening: evening ?? this.evening,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'earliestDepart': earliestDepart.toJson(),
        'evening': evening.toJson(),
      };

  /// v2 포맷 ('enabled' 키) 우선 파싱. v1 ('frequency' / 'morning') 발견 시
  /// frequency!=off → enabled=true 로만 옮기고 시간은 새 default 로 리셋.
  /// — 통합 알림으로 의미가 바뀌어 시간 그대로 옮기면 사용자 의도와 어긋남.
  factory NotificationSettings.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('enabled')) {
      return NotificationSettings(
        enabled: json['enabled'] as bool,
        earliestDepart: TimeOfDayPersist.fromJson(
          (json['earliestDepart'] as Map).cast<String, dynamic>(),
        ),
        evening: TimeOfDayPersist.fromJson(
          (json['evening'] as Map).cast<String, dynamic>(),
        ),
      );
    }
    final freq = json['frequency'] as String?;
    return NotificationSettings(
      enabled: freq != 'off',
      earliestDepart: defaults.earliestDepart,
      evening: defaults.evening,
    );
  }
}
