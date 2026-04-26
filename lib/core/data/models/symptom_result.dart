enum SymptomType { typeA, typeB }

enum SymptomUrgency { medium, high, none }

class SymptomSupplementLink {
  final String supplementId;
  final String supplementName;
  final String relevance;
  final String explanation;
  final String safeExpression;

  const SymptomSupplementLink({
    required this.supplementId,
    required this.supplementName,
    required this.relevance,
    required this.explanation,
    required this.safeExpression,
  });

  factory SymptomSupplementLink.fromJson(Map<String, dynamic> json) {
    return SymptomSupplementLink(
      supplementId: json['supplement_id'] as String? ?? '',
      supplementName: json['supplement_name'] as String? ?? '',
      relevance: json['relevance'] as String? ?? 'secondary',
      explanation: json['explanation'] as String? ?? '',
      safeExpression: json['safe_expression'] as String? ?? '',
    );
  }
}

class SymptomResult {
  final String symptomId;
  final String symptom;
  final List<String> keywords;
  final String category;
  final SymptomType type;

  // Type A
  final List<SymptomSupplementLink> relatedSupplements;
  final List<String> lifestyleTips;
  final String? whenToSeeDoctor;

  // Type B
  final String? medicalMessage;
  final SymptomUrgency urgency;

  final String disclaimer;

  const SymptomResult({
    required this.symptomId,
    required this.symptom,
    required this.keywords,
    required this.category,
    required this.type,
    this.relatedSupplements = const [],
    this.lifestyleTips = const [],
    this.whenToSeeDoctor,
    this.medicalMessage,
    this.urgency = SymptomUrgency.none,
    required this.disclaimer,
  });

  bool get isMedical => type == SymptomType.typeB;

  factory SymptomResult.fromJson(Map<String, dynamic> json) {
    final typeRaw = (json['type'] as String? ?? 'A').toUpperCase();
    final type = typeRaw == 'B' ? SymptomType.typeB : SymptomType.typeA;
    final urgencyRaw = json['urgency'] as String?;
    SymptomUrgency urgency = SymptomUrgency.none;
    if (urgencyRaw == 'high') urgency = SymptomUrgency.high;
    if (urgencyRaw == 'medium') urgency = SymptomUrgency.medium;

    return SymptomResult(
      symptomId: json['symptom_id'] as String? ?? '',
      symptom: json['symptom'] as String? ?? '',
      keywords: (json['keywords'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      category: json['category'] as String? ?? '',
      type: type,
      relatedSupplements:
          (json['related_supplements'] as List<dynamic>? ?? const [])
              .map((e) => SymptomSupplementLink.fromJson(
                  e as Map<String, dynamic>))
              .toList(),
      lifestyleTips: (json['lifestyle_tips'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      whenToSeeDoctor: json['when_to_see_doctor'] as String?,
      medicalMessage: json['medical_message'] as String?,
      urgency: urgency,
      disclaimer: json['disclaimer'] as String? ?? '',
    );
  }
}
