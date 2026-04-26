/// 영양제 검색·구매 링크를 한 곳에서 관리하는 region-aware 설정.
///
/// 1차 타겟은 한국(KR — 네이버 쇼핑). 후속으로 일본(JP — Amazon.co.jp)과
/// 일반 영문(EN — Amazon.com)을 두고, 그 외 지역은 Google 검색으로 fallback.
///
/// 사용 예:
/// ```dart
/// final url = ShopConfig.searchUrl('비타민D');
/// // KR: https://search.shopping.naver.com/search/all?query=비타민D 영양제
/// ```
///
/// 시장이 바뀌면 [region] 한 곳만 갈아끼우면 된다 (빌드 플레이버나 원격
/// 컨피그로 주입할 수 있게 일부러 mutable static 한 [_region] 을 둠).
class ShopConfig {
  ShopConfig._();

  /// 현재 지역 코드. 'KR' / 'JP' / 'EN' / 그 외.
  ///
  /// 빌드 플레이버 / 런처 환경에서 한 번만 갈아끼운다 — 런타임 토글 용도가
  /// 아니라 (캐시·라벨이 region 의존적인 경우가 있어서) 1회 설정 후 유지.
  static String region = 'KR';

  /// 영양제 이름으로 region 별 검색 URL 을 만든다. 한국어/영문/일본어 키워드는
  /// caller 가 직접 넣고, 본 함수는 region 기본 키워드(영양제 / サプリ /
  /// supplement) 만 자동으로 덧붙인다.
  static String searchUrl(String supplementName) {
    final q = Uri.encodeQueryComponent(supplementName);
    switch (region) {
      case 'KR':
        return 'https://search.shopping.naver.com/search/all'
            '?query=$q ${Uri.encodeQueryComponent('영양제')}';
      case 'JP':
        return 'https://www.amazon.co.jp/s'
            '?k=$q ${Uri.encodeQueryComponent('サプリ')}';
      case 'EN':
        return 'https://www.amazon.com/s?k=$q supplement';
      default:
        return 'https://www.google.com/search?q=$q supplement buy';
    }
  }
}
