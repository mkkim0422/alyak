enum ConflictKind {
  supplementSupplement,
  supplementMedication,
  overdoseRisk,
}

enum ConflictSeverity { info, caution, warning }

const _severityKoMap = {
  ConflictSeverity.warning: '경고',
  ConflictSeverity.caution: '주의',
  ConflictSeverity.info: '정보',
};

String conflictSeverityKo(ConflictSeverity s) => _severityKoMap[s] ?? '정보';

ConflictSeverity conflictSeverityFromKo(String? raw) {
  switch (raw) {
    case '경고':
      return ConflictSeverity.warning;
    case '주의':
      return ConflictSeverity.caution;
    case '정보':
      return ConflictSeverity.info;
    default:
      return ConflictSeverity.caution;
  }
}

class ConflictWarning {
  final ConflictKind kind;
  final ConflictSeverity severity;
  final String supplementA;
  final String? supplementB;
  final String? medicationCategory;
  final String? nutrient;
  final String message;
  final String recommendation;

  const ConflictWarning({
    required this.kind,
    required this.severity,
    required this.supplementA,
    this.supplementB,
    this.medicationCategory,
    this.nutrient,
    required this.message,
    required this.recommendation,
  });

  String get severityKo => conflictSeverityKo(severity);
}
