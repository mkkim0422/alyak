/// Region-specific tuning for supplement recommendations.
///
/// Only KR is wired up for the current launch — JP / US / SEA defaults are
/// kept as a structural placeholder so the recommendation engine can branch
/// on region without further refactoring when those markets go live.
class RegionConfig {
  static const String region = 'KR';

  static RegionAdjustment get adjustment {
    switch (region) {
      case 'KR':
        return const RegionAdjustment(
          vitaminDPriority: 'high',
          omega3Priority: 'medium',
          ironCaution: false,
          highSunlight: false,
          note: '실내 생활 많음. 생선 섭취로 오메가3 일부 보충 가능',
        );
      case 'JP':
        return const RegionAdjustment(
          vitaminDPriority: 'high',
          omega3Priority: 'low',
          ironCaution: false,
          highSunlight: false,
          note: '생선 섭취량 높음. 오메가3 우선순위 낮춤',
        );
      case 'US':
        return const RegionAdjustment(
          vitaminDPriority: 'high',
          omega3Priority: 'medium',
          ironCaution: true,
          highSunlight: false,
          note: '육류 과다 섭취로 철분 주의',
        );
      case 'TH':
      case 'VN':
      case 'ID':
        return const RegionAdjustment(
          vitaminDPriority: 'low',
          omega3Priority: 'medium',
          ironCaution: false,
          highSunlight: true,
          note: '열대 기후. 일조량 충분하여 비타민D 우선순위 낮춤',
        );
      default:
        return const RegionAdjustment(
          vitaminDPriority: 'high',
          omega3Priority: 'medium',
          ironCaution: false,
          highSunlight: false,
          note: 'Default global recommendation',
        );
    }
  }
}

class RegionAdjustment {
  final String vitaminDPriority; // high / medium / low
  final String omega3Priority;
  final bool ironCaution;
  final bool highSunlight;
  final String note;

  const RegionAdjustment({
    required this.vitaminDPriority,
    required this.omega3Priority,
    required this.ironCaution,
    required this.highSunlight,
    required this.note,
  });
}
