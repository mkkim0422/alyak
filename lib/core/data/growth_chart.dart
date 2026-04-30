/// 한국 소아청소년 성장도표 (KCDC 2017 기준 50% percentile 근사값) 기반의
/// "또래 대비 키 위치" 라벨링 헬퍼.
///
/// 정확한 의학 도표가 아닌, 사용자에게 보일 한 줄 피드백 생성을 목적으로 한
/// 휴리스틱이다. 1세 단위 보간 없이 가장 가까운 1세 구간으로 매핑한다.
library;

class _GrowthBand {
  final int age;
  final double p10;
  final double p50;
  final double p90;
  const _GrowthBand(this.age, this.p10, this.p50, this.p90);
}

/// (연령, p10, p50, p90) cm. 0~18세.
const List<_GrowthBand> _maleHeight = [
  _GrowthBand(0, 49.0, 49.9, 51.0),
  _GrowthBand(1, 73.0, 76.1, 79.0),
  _GrowthBand(2, 84.0, 87.1, 90.0),
  _GrowthBand(3, 91.0, 95.7, 100.0),
  _GrowthBand(4, 98.5, 103.4, 108.0),
  _GrowthBand(5, 105.0, 109.9, 115.0),
  _GrowthBand(6, 111.0, 115.9, 121.0),
  _GrowthBand(7, 117.0, 122.1, 127.5),
  _GrowthBand(8, 122.0, 127.9, 134.0),
  _GrowthBand(9, 127.0, 133.4, 140.0),
  _GrowthBand(10, 132.0, 138.8, 146.0),
  _GrowthBand(11, 136.0, 143.8, 152.0),
  _GrowthBand(12, 141.0, 149.7, 159.5),
  _GrowthBand(13, 148.0, 156.5, 167.0),
  _GrowthBand(14, 156.0, 163.1, 172.5),
  _GrowthBand(15, 161.5, 167.7, 175.5),
  _GrowthBand(16, 164.0, 170.0, 177.0),
  _GrowthBand(17, 165.0, 171.0, 178.0),
  _GrowthBand(18, 165.5, 171.4, 178.3),
];

const List<_GrowthBand> _femaleHeight = [
  _GrowthBand(0, 48.5, 49.1, 50.5),
  _GrowthBand(1, 71.5, 74.6, 77.5),
  _GrowthBand(2, 83.0, 85.7, 89.0),
  _GrowthBand(3, 90.0, 94.2, 98.0),
  _GrowthBand(4, 96.5, 101.5, 106.0),
  _GrowthBand(5, 103.0, 108.6, 113.5),
  _GrowthBand(6, 109.0, 114.7, 120.0),
  _GrowthBand(7, 115.0, 121.0, 126.5),
  _GrowthBand(8, 120.0, 126.6, 133.0),
  _GrowthBand(9, 125.0, 132.5, 139.5),
  _GrowthBand(10, 131.0, 139.1, 146.5),
  _GrowthBand(11, 137.5, 145.8, 154.0),
  _GrowthBand(12, 144.0, 151.7, 159.5),
  _GrowthBand(13, 148.5, 155.9, 163.0),
  _GrowthBand(14, 151.5, 158.3, 164.5),
  _GrowthBand(15, 153.0, 159.5, 165.5),
  _GrowthBand(16, 153.7, 160.0, 166.0),
  _GrowthBand(17, 154.0, 160.2, 166.0),
  _GrowthBand(18, 154.0, 160.2, 166.0),
];

/// 또래 대비 키 위치를 사용자에게 보일 한 줄 라벨로 반환.
/// 입력이 부족(나이/성별/키 중 하나라도 null) 하거나 도표 범위 밖이면 null.
String? heightPeerLabel({
  required int? ageYears,
  required String? sexStorage,
  required double? heightCm,
}) {
  if (ageYears == null || sexStorage == null || heightCm == null) return null;
  if (heightCm <= 0) return null;
  final table = sexStorage == 'male' ? _maleHeight : _femaleHeight;
  if (ageYears < 0 || ageYears > 18) return null;

  // 가장 가까운 1세 구간 선택.
  _GrowthBand? band;
  for (final b in table) {
    if (b.age == ageYears) {
      band = b;
      break;
    }
  }
  band ??= table.last;

  if (heightCm < band.p10) return '또래 대비: 평균보다 작아요';
  if (heightCm > band.p90) return '또래 대비: 큰 편이에요';
  return '또래 대비: 평균이에요';
}

/// percentile 추정 — 10미만/10-50/50-90/90초과 4구간으로 단순화한 근사 분류.
/// 0~3 사이 정수: 0=below p10, 1=p10~p50, 2=p50~p90, 3=>p90.
/// 사용 불가 시 null.
int? heightPercentileBand({
  required int? ageYears,
  required String? sexStorage,
  required double? heightCm,
}) {
  if (ageYears == null || sexStorage == null || heightCm == null) return null;
  if (heightCm <= 0) return null;
  final table = sexStorage == 'male' ? _maleHeight : _femaleHeight;
  if (ageYears < 0 || ageYears > 18) return null;
  _GrowthBand? band;
  for (final b in table) {
    if (b.age == ageYears) {
      band = b;
      break;
    }
  }
  band ??= table.last;
  if (heightCm < band.p10) return 0;
  if (heightCm < band.p50) return 1;
  if (heightCm < band.p90) return 2;
  return 3;
}
