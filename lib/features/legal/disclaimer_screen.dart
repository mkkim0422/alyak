import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// 의료 면책 사항 — 의사/약사 진단을 대체하지 않는다는 안내.
/// 추천 화면 하단의 disclaimer 한 줄과 별개로 풀 본문이 필요한 외부 링크 용도.
class DisclaimerScreen extends StatelessWidget {
  const DisclaimerScreen({super.key});

  static const routeName = '/disclaimer';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('면책 사항')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          Text(
            '알약 서비스 면책 사항',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 16),
          _Block(
            title: '본 서비스는 의료 행위가 아닙니다',
            body:
                '알약은 사용자가 입력한 정보를 바탕으로 일반적인 영양제 정보를 안내하는 도구이며, 의사·약사·영양사의 전문 진단·처방·상담을 대체할 수 없습니다.',
          ),
          _Block(
            title: '추천은 참고용이에요',
            body:
                '제공되는 영양제 추천, 충돌 안내, 복용 시간 가이드는 공개된 자료와 일반적인 권장 기준을 토대로 합니다. 개인의 건강 상태·복용 약물·기저 질환에 따라 적합 여부가 달라질 수 있습니다.',
          ),
          _Block(
            title: '약을 복용 중이라면 반드시 상담하세요',
            body:
                '병의원에서 처방받은 약을 드시는 분, 임산부·수유 중인 분, 만성질환을 가진 분은 영양제를 추가하기 전에 의사·약사와 상담하시기 바랍니다.',
          ),
          _Block(
            title: '제품 추천은 광고 또는 보증이 아닙니다',
            body:
                '표시되는 제품 정보는 공개된 데이터(가격·성분·판매량 등)를 토대로 한 정렬일 뿐, 특정 제품의 효능을 보장하거나 광고를 대신하지 않습니다. 일부 제품 링크는 제휴를 통해 수수료가 발생할 수 있으며, 해당 표기는 카드 내에 별도로 안내됩니다.',
          ),
          _Block(
            title: '응급 상황에는 즉시 의료 기관에 연락하세요',
            body:
                '가슴 통증, 호흡 곤란, 의식 변화, 심한 출혈 등 응급 증상이 있는 경우 본 앱의 정보를 참고하지 말고 119 또는 가까운 응급실로 즉시 연락하세요.',
          ),
          _Block(
            title: '책임의 한계',
            body:
                '회사는 본 서비스의 정보를 신뢰성 있게 유지하기 위해 노력하나, 개별 사용자의 건강 결과에 대한 법적 책임을 지지 않습니다. 이용자는 본 서비스의 정보를 자신의 판단과 책임 하에 이용합니다.',
          ),
          SizedBox(height: 8),
          Center(
            child: Text(
              '알약은 의료기기가 아닙니다.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.subtle,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(fontSize: 14, height: 1.55),
          ),
        ],
      ),
    );
  }
}
