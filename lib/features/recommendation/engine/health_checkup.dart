/// 사용자가 직접 입력한 건강검진 결과. 모든 수치 필드는 nullable —
/// 검진지에서 일부만 입력해도 추천 엔진이 가능한 신호만 활용한다.
///
/// 단위는 한국 검진 결과지에 가장 흔히 표기되는 단위로 통일.
class HealthCheckup {
  const HealthCheckup({
    required this.checkupDate,
    this.cholesterolTotal,
    this.cholesterolLdl,
    this.cholesterolHdl,
    this.bloodSugar,
    this.hemoglobin,
    this.alt,
    this.ast,
    this.vitaminD,
    this.bloodPressureSystolic,
    this.bloodPressureDiastolic,
  });

  final DateTime checkupDate;
  final double? cholesterolTotal; // 총콜레스테롤 mg/dL
  final double? cholesterolLdl; // LDL mg/dL
  final double? cholesterolHdl; // HDL mg/dL
  final double? bloodSugar; // 공복혈당 mg/dL
  final double? hemoglobin; // 헤모글로빈 g/dL
  final double? alt; // 간수치 ALT U/L
  final double? ast; // 간수치 AST U/L
  final double? vitaminD; // 비타민D 25(OH)D ng/mL
  final double? bloodPressureSystolic; // 수축기 mmHg
  final double? bloodPressureDiastolic; // 이완기 mmHg

  /// 채워진 측정 항목 수 (날짜는 제외). 정확도 표기에 사용.
  int get filledCount {
    var n = 0;
    if (cholesterolTotal != null) n++;
    if (cholesterolLdl != null) n++;
    if (cholesterolHdl != null) n++;
    if (bloodSugar != null) n++;
    if (hemoglobin != null) n++;
    if (alt != null) n++;
    if (ast != null) n++;
    if (vitaminD != null) n++;
    if (bloodPressureSystolic != null) n++;
    if (bloodPressureDiastolic != null) n++;
    return n;
  }

  HealthCheckup copyWith({
    DateTime? checkupDate,
    double? cholesterolTotal,
    double? cholesterolLdl,
    double? cholesterolHdl,
    double? bloodSugar,
    double? hemoglobin,
    double? alt,
    double? ast,
    double? vitaminD,
    double? bloodPressureSystolic,
    double? bloodPressureDiastolic,
  }) {
    return HealthCheckup(
      checkupDate: checkupDate ?? this.checkupDate,
      cholesterolTotal: cholesterolTotal ?? this.cholesterolTotal,
      cholesterolLdl: cholesterolLdl ?? this.cholesterolLdl,
      cholesterolHdl: cholesterolHdl ?? this.cholesterolHdl,
      bloodSugar: bloodSugar ?? this.bloodSugar,
      hemoglobin: hemoglobin ?? this.hemoglobin,
      alt: alt ?? this.alt,
      ast: ast ?? this.ast,
      vitaminD: vitaminD ?? this.vitaminD,
      bloodPressureSystolic:
          bloodPressureSystolic ?? this.bloodPressureSystolic,
      bloodPressureDiastolic:
          bloodPressureDiastolic ?? this.bloodPressureDiastolic,
    );
  }

  Map<String, dynamic> toJson() => {
        'checkup_date': checkupDate.toIso8601String(),
        'cholesterol_total': cholesterolTotal,
        'cholesterol_ldl': cholesterolLdl,
        'cholesterol_hdl': cholesterolHdl,
        'blood_sugar': bloodSugar,
        'hemoglobin': hemoglobin,
        'alt': alt,
        'ast': ast,
        'vitamin_d': vitaminD,
        'blood_pressure_systolic': bloodPressureSystolic,
        'blood_pressure_diastolic': bloodPressureDiastolic,
      };

  static HealthCheckup? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final dateRaw = json['checkup_date'] as String?;
    if (dateRaw == null) return null;
    final date = DateTime.tryParse(dateRaw);
    if (date == null) return null;
    double? d(String key) {
      final v = json[key];
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return null;
    }

    return HealthCheckup(
      checkupDate: date,
      cholesterolTotal: d('cholesterol_total'),
      cholesterolLdl: d('cholesterol_ldl'),
      cholesterolHdl: d('cholesterol_hdl'),
      bloodSugar: d('blood_sugar'),
      hemoglobin: d('hemoglobin'),
      alt: d('alt'),
      ast: d('ast'),
      vitaminD: d('vitamin_d'),
      bloodPressureSystolic: d('blood_pressure_systolic'),
      bloodPressureDiastolic: d('blood_pressure_diastolic'),
    );
  }
}
