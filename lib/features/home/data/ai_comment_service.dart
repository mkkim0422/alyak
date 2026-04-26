import '../../../core/api/claude_api.dart';
import '../../../core/data/models/recommendation_result.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/security/secure_storage.dart';
import '../../family/models/family_member.dart';
import '../../recommendation/engine/family_input.dart';
import 'checkin_service.dart';

/// 하루 한 번, 가족 한 명마다 보여 줄 따뜻한 한 마디.
///
/// 1) `ai_comment.<memberId>.<오늘>` 캐시 확인 →
/// 2) Claude API 호출 (이름·식별 정보 제거된 sanitized payload만 전송) →
/// 3) 실패 시 10개의 한국어 fallback 중 하나를 (memberId + 날짜) 기반으로 골라서 반환.
///
/// Claude 호출이 실패해도 캐시에는 fallback을 저장하지 않는다 — 다음 시도 때
/// 다시 API를 시도하기 위함. 성공한 응답만 캐싱.
class AiCommentService {
  AiCommentService._();

  // 단일 i18n 소스에서 가져온다 — 후보 메시지 자체는 [AppStrings.aiFallbacks].
  static const List<String> _fallbackMessages = AppStrings.aiFallbacks;

  static const _systemPrompt = '''
당신은 가족 영양제 관리 앱의 AI 코치입니다. 사용자에게 오늘 하루 따뜻한 한 마디를 건네 주세요.

규칙:
- 한국어로 답하세요.
- 두 문장 이내, 80자 이내로 짧게.
- 친근한 어조 (반말 또는 부드러운 존댓말).
- 이름·연락처 등 개인 식별 정보는 사용하지 마세요 (제공되지도 않습니다).
- 의학적 진단/처방 단정 금지. "도움이 될 수 있어요" 정도의 표현만.
- 이모지 1개까지 허용.
- 따옴표 없이 본문만.
''';

  static Future<String> getDailyComment({
    required FamilyMember member,
    required List<RecommendationResult> recommendations,
    ClaudeApi? api,
  }) async {
    final today = CheckinService.todayKey();
    final cacheKey = SecureStorage.aiCommentKey(member.id, today);

    final cached = await SecureStorage.read(cacheKey);
    if (cached != null && cached.trim().isNotEmpty) return cached;

    final fallback = _pickFallback(member.id, today);

    final input = member.input;
    if (!input.isComplete) return fallback;

    try {
      final claude = api ?? ClaudeApi();
      // smoker/drinker/diet은 성인·노인 흐름에서만 묻기 때문에 다른 나이대는 null.
      // sanitizer 시그니처는 non-null이라 안전한 기본값으로 채워서 보낸다.
      // 음주자가 아닌 경우 'none' 으로 (DrinkingFrequency 가 더이상 none 을
      // 갖지 않으므로 별도 sentinel 문자열).
      final freqStr = input.drinker == false
          ? 'none'
          : input.drinkingFrequency?.storage ?? 'none';
      final sanitized = ClaudePayloadSanitizer.sanitizeFamilyMember(
        memberId: member.id,
        age: input.age!,
        sex: input.sex!.storage,
        smoker: input.smoker ?? false,
        drinkingFrequency: freqStr,
        dietHabit: input.diet?.storage ?? 'balanced',
      );

      final payload = <String, dynamic>{
        'profile': sanitized,
        'today_supplements':
            recommendations.map((r) => r.supplementName).toList(),
      };

      final text = await claude
          .generate(
            systemPrompt: _systemPrompt,
            sanitizedPayload: payload,
            maxTokens: 200,
          )
          .timeout(const Duration(seconds: 8));

      final cleaned = text.trim();
      if (cleaned.isEmpty) return fallback;

      await SecureStorage.write(cacheKey, cleaned);
      return cleaned;
    } catch (_) {
      return fallback;
    }
  }

  static String _pickFallback(String memberId, String today) {
    // memberId+date 기반 안정적 해시 → 같은 멤버는 하루 동안 같은 메시지를 본다.
    var hash = 0;
    final src = '$memberId|$today';
    for (final code in src.codeUnits) {
      hash = (hash * 31 + code) & 0x7fffffff;
    }
    return _fallbackMessages[hash % _fallbackMessages.length];
  }
}
