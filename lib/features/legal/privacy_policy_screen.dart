import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// 개인정보처리방침 — 전체 한국어 본문. 외부 webview 대신 정적 화면.
/// 법적 점검 완료 전까지 placeholder 상태이며, 변경 시 PrivacyConsentScreen
/// 의 consentVersion을 함께 올려서 사용자에게 재동의를 받아야 한다.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const routeName = '/privacy-policy';
  static const _effectiveDate = '2026-04-25';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('개인정보처리방침')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            '알약 개인정보처리방침',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            '시행일: $_effectiveDate',
            style: const TextStyle(fontSize: 12, color: AppTheme.subtle),
          ),
          const SizedBox(height: 16),
          const Text(
            '주식회사 에스피에이치인포(이하 "회사")는 「개인정보 보호법」 등 관련 법령을 준수하며, 알약 서비스(이하 "서비스") 이용자의 개인정보를 보호하기 위하여 다음과 같이 개인정보처리방침을 수립·공개합니다.',
            style: TextStyle(fontSize: 14, height: 1.6),
          ),
          const SizedBox(height: 24),
          _Section(
            number: '1',
            title: '수집하는 개인정보의 항목',
            body: [
              '필수 항목: 이름(별칭), 나이, 성별, 흡연 여부, 음주 빈도, 식습관 정보',
              '선택 항목: 가족 구성원 별 위 동일 항목, 복용 중인 약물 키워드, 영양제 복용 체크 여부',
              '자동 수집 항목: 기기 식별 정보(앱 인스턴스 ID), OS 종류 및 버전, 앱 버전, 알림 설정값, 로그 기록',
            ],
          ),
          _Section(
            number: '2',
            title: '개인정보의 수집 및 이용목적',
            body: [
              '맞춤 영양제 추천 및 영양제 간 충돌 감지',
              '약물·영양제 상호작용 알림',
              '복용 일정 알림 발송 및 체크 기록 관리',
              '서비스 안정성 확보, 부정이용 방지',
              '서비스 개선을 위한 통계 분석 (식별 정보를 제거한 형태로만 사용)',
            ],
          ),
          _Section(
            number: '3',
            title: '개인정보의 보유 및 이용기간',
            body: [
              '회원 탈퇴 또는 "데이터 삭제" 요청 시: 즉시 파기',
              '개별 가족 구성원 삭제 시: 해당 구성원의 모든 정보 즉시 파기 (체크인 기록, AI 코멘트 캐시 포함)',
              '서비스 미이용 30일 경과 시: 자동 로그아웃 후 기기 내 모든 정보 파기',
              '관계 법령에 따라 보존이 필요한 경우 해당 법령에서 정한 기간 동안만 보관 후 파기',
            ],
          ),
          _Section(
            number: '4',
            title: '개인정보의 제3자 제공',
            body: [
              '회사는 이용자의 개인정보를 원칙적으로 외부에 제공하지 않습니다.',
              '단, AI 추천 생성을 위해 Anthropic, PBC(Claude API)에 다음과 같이 비식별 정보만 전송합니다.',
              '  · 제공 항목: 연령대(10세 단위), 성별, 흡연 여부, 음주 빈도, 식습관, 추천된 영양제 한글명 목록',
              '  · 제공 형태: 이름·연락처·생년월일 등 개인 식별 정보를 제거한 익명 요약',
              '  · 보유 기간: Anthropic, PBC가 자체 정책에 따라 처리 (별도 학습 사용 안 함을 약정)',
              '  · 제공 목적: 한국어 코멘트 생성 및 추천 텍스트 가공',
              '이 외 법률에 특별한 규정이 있거나 수사기관의 적법한 절차에 따른 요구가 있는 경우에 한해 제공합니다.',
            ],
          ),
          _Section(
            number: '5',
            title: '개인정보의 처리 위탁',
            body: [
              '회사는 안정적 서비스 제공을 위해 다음과 같이 개인정보 처리 업무를 위탁할 수 있습니다.',
              '  · Supabase Inc. — 백엔드 호스팅 및 데이터 저장 (예정)',
              '  · Google LLC — 푸시 알림 발송 (Firebase Cloud Messaging, 예정)',
              '위탁 시 「개인정보 보호법」 제26조에 따라 위탁계약을 체결하고 안전하게 처리되도록 관리·감독합니다.',
            ],
          ),
          _Section(
            number: '6',
            title: '개인정보의 파기 절차 및 방법',
            body: [
              '파기 절차: 이용자가 입력한 정보는 목적 달성 후 즉시 또는 별도의 데이터베이스로 옮긴 뒤 내부 정책 및 관계 법령에 의한 정보 보호 사유에 따라 일정 기간 저장된 후 파기됩니다.',
              '파기 방법:',
              '  · 전자적 파일 형태의 정보: 복구 및 재생이 불가능한 방법으로 영구 삭제',
              '  · 기기 내 보관된 정보: SecureStorage(Keychain/Keystore) 통째 삭제',
              '  · 종이로 출력된 개인정보: 분쇄기로 분쇄하거나 소각',
              '암호화된 데이터에 한해서는 복호화 키 폐기로 파기를 갈음할 수 있습니다.',
            ],
          ),
          _Section(
            number: '7',
            title: '이용자의 권리와 행사 방법',
            body: [
              '이용자는 언제든지 자신의 개인정보를 조회·수정·삭제할 수 있습니다.',
              '  · 조회/수정: 앱 내 "가족 관리" 화면',
              '  · 삭제: 앱 내 "설정 → 계정 및 데이터 삭제"',
              '  · 회원 탈퇴: 앱 내 "설정 → 로그아웃"',
              '14세 미만 아동의 개인정보를 등록할 경우 법정대리인의 동의가 필요합니다.',
            ],
          ),
          _Section(
            number: '8',
            title: '개인정보의 안전성 확보 조치',
            body: [
              '암호화: 건강 정보는 기기 내 AES-256-GCM으로 암호화하여 저장합니다. 암호화 키는 첫 실행 시 기기에서 생성되어 Keychain/Keystore에 보관되며, 외부로 반출되지 않습니다.',
              '전송 보안: 모든 외부 통신은 HTTPS로만 이루어지며, cleartext 통신은 차단되어 있습니다.',
              '접근 통제: 본인의 가족 데이터만 조회 가능하도록 Supabase Row Level Security를 적용합니다(연동 후).',
              '스크린샷 방지: 민감 정보가 표시되는 화면에서 OS 차원의 스크린샷 차단(Android FLAG_SECURE, iOS 백그라운드 블러)을 적용합니다.',
              '루팅·탈옥 기기 차단: 기기 무결성 손상이 감지되면 앱이 실행되지 않습니다.',
              '보안 점검: 정기적으로 취약점 점검 및 보안 업데이트를 수행합니다.',
            ],
          ),
          _Section(
            number: '9',
            title: '쿠키 및 유사 기술',
            body: [
              '본 앱은 모바일 앱이며 일반적인 웹 쿠키를 사용하지 않습니다.',
              '서비스 분석을 위한 익명 식별자(앱 인스턴스 ID)만 사용하며, 사용자가 앱을 삭제하면 함께 제거됩니다.',
            ],
          ),
          _Section(
            number: '10',
            title: '개인정보 보호책임자 및 문의',
            body: [
              '개인정보 보호책임자: (성함은 정식 출시 전 지정 예정)',
              '연락처: help@sphinfo.co.kr',
              '본 방침에 관한 의견이나 개인정보 침해 신고는 위 이메일로 접수해 주세요.',
              '개인정보 침해 관련 신고·상담이 필요하신 경우 다음 기관에 문의하실 수 있습니다.',
              '  · 개인정보분쟁조정위원회 (1833-6972, kopico.go.kr)',
              '  · 개인정보침해신고센터 (118, privacy.kisa.or.kr)',
              '  · 대검찰청 사이버수사과 (02-3480-3573, www.spo.go.kr)',
              '  · 경찰청 사이버수사국 (182, ecrm.cyber.go.kr)',
            ],
          ),
          _Section(
            number: '11',
            title: '개정 사항',
            body: [
              '본 방침의 내용 추가·삭제 또는 수정이 있을 경우 시행일 7일 전부터 앱 내 공지를 통해 고지합니다.',
              '중요한 변경사항(수집 항목·이용 목적 추가, 제3자 제공 추가 등)이 있을 경우 사용자 재동의를 받습니다.',
            ],
          ),
          const SizedBox(height: 16),
          const Center(
            child: Text(
              '본 방침은 정식 출시 전 법무 검토를 거쳐 최종 확정됩니다.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.subtle,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.number,
    required this.title,
    required this.body,
  });

  final String number;
  final String title;
  final List<String> body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$number. $title',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          ...body.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                line,
                style: const TextStyle(fontSize: 14, height: 1.55),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
