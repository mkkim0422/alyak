// Supabase Edge Function: claude-proxy
//
// 클라이언트(Flutter 앱)는 Anthropic API 키를 들고 다니지 않고, 이 함수를
// 호출한다. 함수가 서버 측에서 Claude Messages API로 전달하고 응답을 그대로
// 돌려준다. 함수는 Supabase가 검증한 JWT(Authorization 헤더)로 보호되어
// 익명 호출을 차단한다.
//
// 배포:
//   1) `npx supabase functions new claude-proxy` 가 이미 만들어진 상태.
//   2) `npx supabase secrets set ANTHROPIC_API_KEY=sk-ant-…`
//   3) `npx supabase functions deploy claude-proxy`
//
// 클라이언트 호출 예시:
//   POST {SUPABASE_URL}/functions/v1/claude-proxy
//   Authorization: Bearer <user_session_jwt>
//   Body: { "system_prompt": "...", "payload": { ... }, "max_tokens": 200 }

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';

const ANTHROPIC_API_URL = 'https://api.anthropic.com/v1/messages';
const DEFAULT_MODEL = Deno.env.get('CLAUDE_MODEL') ?? 'claude-sonnet-4-6';
const ANTHROPIC_API_KEY = Deno.env.get('ANTHROPIC_API_KEY') ?? '';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, content-type, apikey, x-client-info',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

interface ProxyRequest {
  system_prompt?: string;
  payload?: Record<string, unknown>;
  model?: string;
  max_tokens?: number;
}

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  if (req.method !== 'POST') {
    return jsonError(405, 'method_not_allowed');
  }

  // Supabase가 JWT 검증을 자동으로 해주므로 (project setting `--no-verify-jwt`
  // 안 쓰는 한) 여기 도달하면 인증된 사용자다. 추가로 Authorization 헤더가
  // 있는지만 가드.
  const auth = req.headers.get('Authorization');
  if (!auth) {
    return jsonError(401, 'unauthorized');
  }

  let body: ProxyRequest;
  try {
    body = await req.json();
  } catch {
    return jsonError(400, 'invalid_json');
  }

  if (!body.system_prompt || !body.payload) {
    return jsonError(400, 'missing_fields');
  }

  if (!ANTHROPIC_API_KEY) {
    // 키가 아직 설정되지 않은 환경 — 클라이언트가 fallback을 쓰도록 503.
    return jsonError(503, 'ai_service_not_configured');
  }

  const upstream = await fetch(ANTHROPIC_API_URL, {
    method: 'POST',
    headers: {
      'x-api-key': ANTHROPIC_API_KEY,
      'anthropic-version': '2023-06-01',
      'content-type': 'application/json',
    },
    body: JSON.stringify({
      model: body.model ?? DEFAULT_MODEL,
      max_tokens: body.max_tokens ?? 1024,
      system: body.system_prompt,
      messages: [
        {
          role: 'user',
          content: JSON.stringify(body.payload),
        },
      ],
    }),
  });

  const text = await upstream.text();
  return new Response(text, {
    status: upstream.status,
    headers: {
      ...corsHeaders,
      'content-type': 'application/json',
    },
  });
});

function jsonError(status: number, code: string): Response {
  return new Response(
    JSON.stringify({ error: code }),
    {
      status,
      headers: {
        ...corsHeaders,
        'content-type': 'application/json',
      },
    },
  );
}
