/// 추천된 영양제 이름을 `products.json` 의 ingredient 키 + 1일 권장량 으로
/// 매핑하는 정적 테이블.
///
/// 이 파일이 존재하는 이유: supplement_guide.json 의 dosage 단위가
/// 영양제마다 제각각(mg / IU / 억 CFU / 정)이라 그대로 사용할 수 없다.
/// 제품 추천 (gap = needed - current) 을 계산하려면 모든 양을 같은 키 +
/// 같은 단위로 통일해야 하므로 별도 테이블로 분리한다.
library;

class NutrientTarget {
  final String key;
  final double amount;
  const NutrientTarget(this.key, this.amount);
}

/// 영양제 한국어 이름 → 1일 목표 영양소 리스트.
///
/// 단일 성분 영양제는 1개, 복합(B군/종합비타민) 은 여러 개를 반환한다.
/// 권장량은 한국 식약처 KDRI 성인 기준치 (대략값) — 정확한 의학적 RDA 가
/// 아니라 "이 정도면 부족하지 않다" 는 휴리스틱으로 사용된다.
const Map<String, List<NutrientTarget>> _targets = {
  '비타민A': [NutrientTarget('vitamin_a_mcg', 700)],
  '베타카로틴': [NutrientTarget('vitamin_a_mcg', 700)],
  '비타민C': [NutrientTarget('vitamin_c_mg', 100)],
  '비타민D': [NutrientTarget('vitamin_d_iu', 1000)],
  '비타민E': [NutrientTarget('vitamin_e_mg', 15)],
  '비타민K': [NutrientTarget('vitamin_k_mcg', 75)],
  '비타민K2': [NutrientTarget('vitamin_k_mcg', 75)],
  '비타민B1(티아민)': [NutrientTarget('vitamin_b1_mg', 1.2)],
  '비타민B2': [NutrientTarget('vitamin_b2_mg', 1.4)],
  '비타민B6': [NutrientTarget('vitamin_b6_mg', 1.5)],
  '비타민B12': [NutrientTarget('vitamin_b12_mcg', 2.4)],
  '엽산': [NutrientTarget('vitamin_b9_mcg', 400)],
  '비오틴': [NutrientTarget('vitamin_b7_mcg', 30)],
  '비타민B군': [
    NutrientTarget('vitamin_b1_mg', 1.2),
    NutrientTarget('vitamin_b2_mg', 1.4),
    NutrientTarget('vitamin_b6_mg', 1.5),
    NutrientTarget('vitamin_b12_mcg', 2.4),
    NutrientTarget('vitamin_b9_mcg', 400),
  ],
  '칼슘': [NutrientTarget('calcium_mg', 700)],
  '마그네슘': [NutrientTarget('magnesium_mg', 350)],
  '철분': [NutrientTarget('iron_mg', 14)],
  '아연': [NutrientTarget('zinc_mg', 10)],
  '셀레늄': [NutrientTarget('selenium_mcg', 55)],
  '크롬': [NutrientTarget('chromium_mcg', 30)],
  '오메가3': [NutrientTarget('omega3_total_mg', 1000)],
  '오메가3(DHA)': [NutrientTarget('dha_mg', 500)],
  'DHA': [NutrientTarget('dha_mg', 500)],
  '유산균(프로바이오틱스)': [NutrientTarget('probiotics_cfu_billion', 1)],
  '유산균': [NutrientTarget('probiotics_cfu_billion', 1)],
  '프로바이오틱스': [NutrientTarget('probiotics_cfu_billion', 1)],
  '종합비타민': [
    NutrientTarget('vitamin_a_mcg', 700),
    NutrientTarget('vitamin_c_mg', 100),
    NutrientTarget('vitamin_d_iu', 1000),
    NutrientTarget('vitamin_e_mg', 15),
    NutrientTarget('vitamin_b1_mg', 1.2),
    NutrientTarget('vitamin_b2_mg', 1.4),
    NutrientTarget('vitamin_b6_mg', 1.5),
    NutrientTarget('vitamin_b12_mcg', 2.4),
    NutrientTarget('vitamin_b9_mcg', 400),
    NutrientTarget('iron_mg', 14),
    NutrientTarget('zinc_mg', 10),
  ],
};

/// 추천 영양제 이름 리스트를 ingredient 키 → 1일 목표량 맵으로 변환.
///
/// 같은 영양소 키가 여러 영양제(예: 종합비타민 + 비타민C) 에서 중복으로
/// 나오면 더 큰 권장량을 채택한다 (보수적으로 더 많이 필요하다고 가정).
Map<String, double> targetsForSupplements(List<String> names) {
  final out = <String, double>{};
  for (final raw in names) {
    final entries = _resolveTargets(raw);
    for (final t in entries) {
      final cur = out[t.key] ?? 0;
      if (t.amount > cur) out[t.key] = t.amount;
    }
  }
  return out;
}

List<NutrientTarget> _resolveTargets(String name) {
  final direct = _targets[name];
  if (direct != null) return direct;
  // 괄호 접미사 ("비타민D(D3)" → "비타민D") 시도.
  final idx = name.indexOf('(');
  if (idx > 0) {
    final stripped = name.substring(0, idx).trim();
    final hit = _targets[stripped];
    if (hit != null) return hit;
  }
  return const [];
}

/// 제품 카테고리(`products.json` 의 `category`) → 사용자에게 보일 한글 라벨.
const Map<String, String> productCategoryDisplayName = {
  'multivitamin': '종합비타민',
  'vitamin_d_complex': '비타민D',
  'omega3': '오메가3',
  'magnesium_complex': '마그네슘',
  'calcium_complex': '칼슘',
  'b_complex': 'B군',
  'probiotics': '유산균',
};

/// 제품 카테고리 → "이미 드시는 것" 추천 매칭에 쓰일 supplement 한글 이름.
/// 사용자가 제품을 picker 에서 선택하면 이 매핑으로
/// `currentSupplements` 도 동시에 채워서 기존 alreadyTaking 로직 호환을 유지.
const Map<String, String> productCategorySupplementName = {
  'multivitamin': '종합비타민',
  'vitamin_d_complex': '비타민D',
  'omega3': '오메가3',
  'magnesium_complex': '마그네슘',
  'calcium_complex': '칼슘',
  'b_complex': '비타민B군',
  'probiotics': '유산균(프로바이오틱스)',
};

/// brand_type → 사용자에게 보일 한글 라벨.
const Map<String, String> productBrandTypeLabel = {
  'brand': '브랜드',
  'generic': '일반의약품',
  'store_brand': '약국 PB',
};
