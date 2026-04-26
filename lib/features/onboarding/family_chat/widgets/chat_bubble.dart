import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../models/chat_message.dart';

/// Toss 스타일 채팅 버블.
/// - 봇 메시지: 배경 없음, 부드러운 회색 텍스트, 큰 폰트 (대화처럼).
/// - 사용자 답변: primary 컬러 알약, 우측 정렬.
class ChatBubble extends StatelessWidget {
  const ChatBubble({required this.message, super.key});

  final ChatMessage message;

  /// 봇 메시지의 톤다운된 텍스트 색상. ink 보다 살짝 옅게.
  static const Color _botText = Color(0xFF374151);

  @override
  Widget build(BuildContext context) {
    final isBot = message.isBot;
    return TweenAnimationBuilder<double>(
      key: ValueKey(message.id),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 8),
            child: child,
          ),
        );
      },
      child: Align(
        alignment: isBot ? Alignment.centerLeft : Alignment.centerRight,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.82,
          ),
          child: isBot ? _bot() : _user(),
        ),
      ),
    );
  }

  Widget _bot() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message.text,
            style: const TextStyle(
              fontSize: 18,
              height: 1.5,
              color: _botText,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (message.subText != null) ...[
            const SizedBox(height: 6),
            Text(
              message.subText!,
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                color: AppTheme.subtle,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _user() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: const BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(6),
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Text(
        message.text,
        style: const TextStyle(
          fontSize: 15,
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
