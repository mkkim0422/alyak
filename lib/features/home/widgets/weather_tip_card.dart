import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/weather_service.dart';
import '../../../core/theme/app_theme.dart';

/// HomeScreen 의 가족 카드들 아래, AI 한마디 카드 위에 끼워 넣는 작은 팁 카드.
/// 한 줄 메시지 + 이모지 — 의도적으로 눈에 안 띄게.
final weatherTipProvider = FutureProvider<WeatherTip>((ref) async {
  return WeatherService.getTip();
});

class WeatherTipCard extends ConsumerWidget {
  const WeatherTipCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tipAsync = ref.watch(weatherTipProvider);
    return tipAsync.when(
      // 로딩/에러는 자리만 비워 둔다 (안 띄움). graceful fallback.
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (tip) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.primaryLight,
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          ),
          child: Row(
            children: [
              Text(tip.emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  tip.message,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
