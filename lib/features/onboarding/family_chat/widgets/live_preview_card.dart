import 'package:flutter/material.dart';

import '../../../../core/data/models/recommendation_result.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/theme/app_theme.dart';

/// 채팅 위에 sticky로 붙는 추천 미리보기 카드.
///
/// 답이 쌓일 때마다 추천 라인업이 갱신된다. controller 가 들고 있는
/// preview 는 [RecommendationResult] 의 리스트 (must_take + highly + boost).
class LivePreviewCard extends StatelessWidget {
  const LivePreviewCard({
    required this.preview,
    this.profileLabel,
    super.key,
  });

  final List<RecommendationResult> preview;
  final String? profileLabel;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: preview.isEmpty
          ? const _EmptyHint()
          : _Filled(preview: preview, profileLabel: profileLabel),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cream,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.line),
      ),
      child: const Row(
        children: [
          Icon(Icons.auto_awesome, size: 18, color: AppTheme.subtle),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              AppStrings.livePreviewEmpty,
              style: TextStyle(fontSize: 13, color: AppTheme.subtle),
            ),
          ),
        ],
      ),
    );
  }
}

class _Filled extends StatelessWidget {
  const _Filled({required this.preview, required this.profileLabel});
  final List<RecommendationResult> preview;
  final String? profileLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.auto_awesome, size: 18, color: AppTheme.primary),
              SizedBox(width: 6),
              Text(
                AppStrings.livePreviewTitle,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
          if (profileLabel != null) ...[
            const SizedBox(height: 4),
            Text(
              profileLabel!,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.subtle,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: preview
                .map((r) => _Chip(name: r.supplementName, category: r.category))
                .toList(),
          ),
          const SizedBox(height: 6),
          const Text(
            AppStrings.previewDisclaimer,
            style: TextStyle(fontSize: 11, color: AppTheme.subtle),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.name, required this.category});
  final String name;
  final RecommendationCategory category;

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    switch (category) {
      case RecommendationCategory.mustTake:
        icon = Icons.star;
        break;
      case RecommendationCategory.highlyRecommended:
        icon = Icons.thumb_up_alt_outlined;
        break;
      case RecommendationCategory.considerIf:
        icon = Icons.add_circle_outline;
        break;
      case RecommendationCategory.alreadyTaking:
        icon = Icons.check_circle;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.cream,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.primary),
          const SizedBox(width: 4),
          Text(
            name,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
