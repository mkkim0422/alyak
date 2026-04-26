# claude-proxy Edge Function

가족 영양제 추천에 쓰는 Anthropic Claude 호출을 서버 측에서 대리하는 함수.
앱에 API 키를 심지 않기 위함.

## 배포

```bash
# 한 번만:
npx supabase login
npx supabase link --project-ref <YOUR_PROJECT_REF>

# 키 설정:
npx supabase secrets set ANTHROPIC_API_KEY=sk-ant-...
npx supabase secrets set CLAUDE_MODEL=claude-sonnet-4-6

# 함수 배포:
npx supabase functions deploy claude-proxy
```

배포 후 엔드포인트는 `https://<project>.supabase.co/functions/v1/claude-proxy`.

## 클라이언트 사용

Flutter `lib/core/api/claude_api.dart`가 `EnvConfig.claudeProxyUrl`을 읽어서
이 엔드포인트로 POST한다. 인증 헤더는 현재 Supabase 세션 JWT.

## 입력 / 출력

```jsonc
// Request
POST /functions/v1/claude-proxy
Authorization: Bearer <user_jwt>
{
  "system_prompt": "당신은 …",
  "payload": { "profile": { ... }, "today_supplements": [...] },
  "max_tokens": 200
}

// Response (200)
// Anthropic Messages API 응답 그대로.
{
  "content": [{ "type": "text", "text": "…" }],
  ...
}
```

## 에러 코드

| 상태 | 의미 |
|---|---|
| 400 | 본문 형식 오류 / 필수 필드 누락 |
| 401 | Authorization 헤더 없음 |
| 405 | POST 외 메서드 |
| 503 | 서버에 ANTHROPIC_API_KEY 미설정 — 클라이언트는 fallback 사용 |
