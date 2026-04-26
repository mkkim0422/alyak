import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/env_config.dart';
import 'supabase_client.dart';

/// Strips personally identifiable info before sending profiles to Claude.
/// Names become opaque `M_<hash>` labels, free-text is removed, and only
/// coarse fields (age band, sex, smoker, drinking, diet) are forwarded.
class ClaudePayloadSanitizer {
  static Map<String, dynamic> sanitizeFamilyMember({
    required String memberId,
    required int age,
    required String sex,
    required bool smoker,
    required String drinkingFrequency,
    required String dietHabit,
    Map<String, dynamic>? extras,
  }) {
    return <String, dynamic>{
      'id': 'M_${memberId.hashCode.toUnsigned(32).toRadixString(16)}',
      'age_band': _ageBand(age),
      'sex': sex,
      'smoker': smoker,
      'drinking': drinkingFrequency,
      'diet': dietHabit,
      if (extras != null) 'extras': _scrub(extras),
    };
  }

  static String _ageBand(int age) {
    if (age < 10) return '0-9';
    if (age < 20) return '10-19';
    if (age < 30) return '20-29';
    if (age < 40) return '30-39';
    if (age < 50) return '40-49';
    if (age < 60) return '50-59';
    if (age < 70) return '60-69';
    return '70+';
  }

  static Map<String, dynamic> _scrub(Map<String, dynamic> input) {
    const banned = {'name', 'phone', 'email', 'address', 'birthdate', 'dob'};
    return {
      for (final entry in input.entries)
        if (!banned.contains(entry.key.toLowerCase())) entry.key: entry.value,
    };
  }
}

/// Calls the Supabase Edge Function `claude-proxy` instead of Anthropic
/// directly — the function holds the Anthropic API key server-side, so
/// the app never ships it. The user's Supabase session JWT is used as
/// the Authorization Bearer token.
///
/// `EnvConfig.claudeProxyUrl`가 비어 있거나 Supabase 세션이 없으면 호출이
/// 즉시 실패하고, 호출자 (e.g. AiCommentService) 가 fallback으로 전환한다.
class ClaudeApi {
  ClaudeApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<String> generate({
    required String systemPrompt,
    required Map<String, dynamic> sanitizedPayload,
    int maxTokens = 1024,
  }) async {
    final proxyUrl = EnvConfig.claudeProxyUrl;
    if (proxyUrl == null || proxyUrl.isEmpty) {
      throw const ClaudeApiException(0, 'proxy_not_configured');
    }

    final session = SupabaseService.auth.currentSession;
    final token = session?.accessToken;
    if (token == null || token.isEmpty) {
      // 미로그인 상태에서 AI 코멘트는 호출되지 않아야 정상 — fallback 가도록
      // 명시적으로 실패시킨다.
      throw const ClaudeApiException(401, 'no_session');
    }

    final body = jsonEncode({
      'system_prompt': systemPrompt,
      'payload': sanitizedPayload,
      'model': EnvConfig.claudeModel,
      'max_tokens': maxTokens,
    });

    final response = await _client.post(
      Uri.parse(proxyUrl),
      headers: {
        'authorization': 'Bearer $token',
        'content-type': 'application/json',
      },
      body: body,
    );

    if (response.statusCode >= 400) {
      // 응답 본문을 사용자에게 노출하지 않는다 (요청 ID, 플랜 정보, upstream
      // 스택 누설 방지).
      throw ClaudeApiException(response.statusCode);
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final content = decoded['content'] as List<dynamic>?;
    if (content == null || content.isEmpty) {
      throw ClaudeApiException(response.statusCode, 'empty_content');
    }
    final first = content.first as Map<String, dynamic>;
    return (first['text'] as String?) ?? '';
  }
}

class ClaudeApiException implements Exception {
  const ClaudeApiException(this.statusCode, [this.detail]);
  final int statusCode;
  final String? detail;

  @override
  String toString() => '추천을 가져오지 못했어요. 잠시 후 다시 시도해 주세요.';
}
