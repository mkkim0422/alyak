import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/ai_comment_service.dart';
import '../providers/home_feed_provider.dart';

/// 하단 "AI 한마디" 카드. 멤버가 바뀌면 다시 로드.
/// 첫 표시 때 캐시 또는 fallback이 즉시 보이고, Claude 응답이 도착하면 갱신.
class AiCommentCard extends StatefulWidget {
  const AiCommentCard({required this.entry, super.key});

  final HomeFeedEntry entry;

  @override
  State<AiCommentCard> createState() => _AiCommentCardState();
}

class _AiCommentCardState extends State<AiCommentCard> {
  String? _comment;
  String? _loadedForMemberId;

  @override
  void initState() {
    super.initState();
    _maybeLoad();
  }

  @override
  void didUpdateWidget(AiCommentCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entry.member.id != widget.entry.member.id) {
      setState(() => _comment = null);
      _maybeLoad();
    }
  }

  void _maybeLoad() {
    final id = widget.entry.member.id;
    if (_loadedForMemberId == id) return;
    _loadedForMemberId = id;
    AiCommentService.getDailyComment(
      member: widget.entry.member,
      recommendations: widget.entry.recommendations,
    ).then((value) {
      if (!mounted) return;
      if (_loadedForMemberId != id) return; // 사용자가 다른 멤버로 옮겼다.
      setState(() => _comment = value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = _comment;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryLight,
            Color(0xFFFFF1EC), // soft coral wash to pair with secondary
          ],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.auto_awesome, size: 18, color: AppTheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              child: text == null
                  ? const _LoadingShimmer(key: ValueKey('loading'))
                  : Text(
                      text,
                      key: ValueKey(text),
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingShimmer extends StatelessWidget {
  const _LoadingShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 12,
          decoration: BoxDecoration(
            color: AppTheme.line,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 12,
          width: 180,
          decoration: BoxDecoration(
            color: AppTheme.line,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ],
    );
  }
}
