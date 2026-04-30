import 'package:flutter/foundation.dart';

/// 사용자에게 노출되는 문자열에 의료 행위로 오해될 수 있는 단어가 들어가지 않도록
/// 검사하는 유틸리티.
///
/// 추천/가이드/AI 코멘트 텍스트가 "진단", "치료", "처방" 같은 단어를 포함하면
/// 의료법상 문제가 될 수 있어 디버그 빌드에서 자동 점검한다. release 빌드에서는
/// 검사를 생략하지만, 노출 전 [findUnsafeTerms] 로 미리 체크 가능.
class WordFilter {
  WordFilter._();

  /// 의료 행위로 해석될 수 있는 표현. 100% 차단이 아니라 점검 신호로 사용.
  static const List<String> medicalTerms = [
    '진단',
    '치료',
    '처방',
    '완치',
    '확실히',
    '반드시 효과',
    '의료',
    '약사 추천',
    '의사 추천',
  ];

  /// [text] 에 [medicalTerms] 의 항목이 들어 있으면 매칭된 단어 리스트 반환.
  static List<String> findUnsafeTerms(String text) {
    final lower = text;
    final hits = <String>[];
    for (final term in medicalTerms) {
      if (lower.contains(term)) hits.add(term);
    }
    return hits;
  }

  /// 디버그 빌드에서만 동작. release 에서는 no-op.
  /// 단어가 발견되면 콘솔에 경고 출력 (assertion 은 일부러 안 깸 — 실제 의료 문맥이
  /// 의도된 곳에서도 false-positive 가 발생할 수 있어).
  static void debugAssertSafe(String text, {String? source}) {
    if (!kDebugMode) return;
    final hits = findUnsafeTerms(text);
    if (hits.isEmpty) return;
    final src = source != null ? ' [$source]' : '';
    // ignore: avoid_print
    print('[WordFilter]$src 의료 단어 감지: ${hits.join(", ")} -> "$text"');
  }
}
