import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// 보안 키패드 — PinSetup / PinLock / PinChange 3 화면 공용.
///
/// 기본은 0~9 + backspace. [shuffle] 이 true 면 0~9 가 매번 다른 위치에 배치되어
/// 어깨너머 관찰 (shoulder-surfing) 으로 PIN 추측을 어렵게 만든다.
class PinNumpad extends StatelessWidget {
  const PinNumpad({
    required this.digits,
    required this.onKey,
    required this.onBackspace,
    super.key,
  });

  /// 0~9 의 순열. [PinShuffleController.shuffle] 또는 호출 측이 만들어 전달.
  final List<int> digits;
  final void Function(int) onKey;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.5,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: [
        for (var i = 0; i < 9; i++) _key(digits[i]),
        const SizedBox.shrink(),
        _key(digits[9]),
        InkWell(
          onTap: onBackspace,
          borderRadius: BorderRadius.circular(16),
          child: const Center(
            child: Icon(
              Icons.backspace_outlined,
              size: 24,
              color: AppTheme.subtle,
            ),
          ),
        ),
      ],
    );
  }

  Widget _key(int d) {
    return Material(
      color: AppTheme.cream,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => onKey(d),
        borderRadius: BorderRadius.circular(16),
        child: Center(
          child: Text(
            d.toString(),
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: AppTheme.ink,
            ),
          ),
        ),
      ),
    );
  }
}

/// 0~9 의 새 셔플 순열. `math.Random.secure()` 사용으로 예측 불가능.
List<int> shuffledDigits() {
  final list = List<int>.generate(10, (i) => i);
  list.shuffle(math.Random.secure());
  return list;
}

/// 정렬된 0~9.
List<int> orderedDigits() => List<int>.generate(10, (i) => i);

/// "보안 키패드 (랜덤)" / "일반 키패드" 토글 텍스트 버튼.
class PinShuffleToggle extends StatelessWidget {
  const PinShuffleToggle({
    required this.shuffleEnabled,
    required this.onToggle,
    super.key,
  });

  final bool shuffleEnabled;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onToggle,
      icon: Icon(
        shuffleEnabled ? Icons.shuffle : Icons.grid_view_outlined,
        size: 16,
      ),
      label: Text(
        shuffleEnabled ? '보안 키패드 (랜덤)' : '일반 키패드',
        style: const TextStyle(fontSize: 13),
      ),
      style: TextButton.styleFrom(foregroundColor: AppTheme.subtle),
    );
  }
}
