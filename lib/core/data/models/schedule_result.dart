enum ScheduleSlot { morning, lunch, evening, beforeSleep }

String scheduleSlotKo(ScheduleSlot slot) {
  switch (slot) {
    case ScheduleSlot.morning:
      return '아침';
    case ScheduleSlot.lunch:
      return '점심';
    case ScheduleSlot.evening:
      return '저녁';
    case ScheduleSlot.beforeSleep:
      return '취침 전';
  }
}

class ScheduleConflict {
  final String supplementA;
  final String supplementB;
  final String type;
  final String reason;
  final String solution;

  const ScheduleConflict({
    required this.supplementA,
    required this.supplementB,
    required this.type,
    required this.reason,
    required this.solution,
  });
}

class ScheduleSynergy {
  final String supplementA;
  final String supplementB;
  final String benefit;
  final String recommendation;

  const ScheduleSynergy({
    required this.supplementA,
    required this.supplementB,
    required this.benefit,
    required this.recommendation,
  });
}

class ScheduleResult {
  final List<String> morning;
  final List<String> lunch;
  final List<String> evening;
  final List<String> beforeSleep;
  final List<ScheduleConflict> conflicts;
  final List<ScheduleSynergy> synergies;

  const ScheduleResult({
    required this.morning,
    required this.lunch,
    required this.evening,
    required this.beforeSleep,
    required this.conflicts,
    required this.synergies,
  });

  Map<ScheduleSlot, List<String>> toMap() => {
        ScheduleSlot.morning: morning,
        ScheduleSlot.lunch: lunch,
        ScheduleSlot.evening: evening,
        ScheduleSlot.beforeSleep: beforeSleep,
      };

  bool get isEmpty =>
      morning.isEmpty &&
      lunch.isEmpty &&
      evening.isEmpty &&
      beforeSleep.isEmpty;
}
