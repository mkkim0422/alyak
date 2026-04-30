import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/security/secure_storage.dart';
import '../../core/theme/app_theme.dart';

/// 첫 실행 시 노출. 동의해야 다음 화면으로 진행 가능.
class PrivacyConsentScreen extends ConsumerStatefulWidget {
  const PrivacyConsentScreen({super.key});

  static const routeName = '/privacy-consent';
  static const consentVersion = '1';

  @override
  ConsumerState<PrivacyConsentScreen> createState() =>
      _PrivacyConsentScreenState();
}

class _PrivacyConsentScreenState extends ConsumerState<PrivacyConsentScreen> {
  bool _agreed = false;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Text(
                '시작하기 전에',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: AppTheme.subtle,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '개인정보 수집·이용 동의',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.line),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _section(
                          title: '수집 항목',
                          body:
                              '이름(별칭), 나이, 성별, 흡연 여부, 음주 빈도, 식습관 정보',
                        ),
                        _section(
                          title: '수집 목적',
                          body:
                              'AI 영양제 추천, 충돌 감지, 복용 가이드 생성, 알림 발송',
                        ),
                        _section(
                          title: '보관·파기',
                          body:
                              '회원 탈퇴 또는 “데이터 삭제” 요청 시 모든 정보가 즉시 삭제됩니다.',
                        ),
                        _section(
                          title: '안전 조치',
                          body:
                              '건강 정보는 기기 내 암호화된 저장소에 보관되고, 서버 전송 시 AES-256으로 암호화됩니다. 외부 AI 호출 시 이름·연락처 등 식별 정보는 제거된 후 전송됩니다.',
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '본 앱은 의사·약사의 전문 진단을 대체하지 않습니다.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppTheme.subtle,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () => setState(() => _agreed = !_agreed),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Icon(
                        _agreed
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: _agreed ? AppTheme.primary : AppTheme.subtle,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '위 내용을 모두 확인했고, 수집·이용에 동의합니다.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _agreed && !_saving ? _continue : null,
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : const Text('동의하고 시작하기'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section({required String title, required String body}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: AppTheme.ink,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _continue() async {
    setState(() => _saving = true);
    try {
      await SecureStorage.write(
        SecureStorage.kPrivacyConsentAt,
        DateTime.now().toUtc().toIso8601String(),
      );
      await SecureStorage.write(
        SecureStorage.kPrivacyConsentVersion,
        PrivacyConsentScreen.consentVersion,
      );
      if (!mounted) return;
      // /boot 으로 보내 redirect 가 PIN 설정 / 세션 / 온보딩 단계를 결정하게 한다.
      // 직접 /onboarding/welcome 으로 보내면 PIN 강제 단계가 우회되어 보안 구멍.
      context.go('/boot');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
