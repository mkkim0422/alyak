import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Pill + heart 모티프 앱 아이콘. 한 곳에서 정의해서 (1) 인앱 스플래시,
/// (2) 플랫폼 아이콘 PNG 생성 (`tool/generate_app_icon.dart`) 양쪽에서 같이
/// 쓴다.
class AppIconPainter extends CustomPainter {
  AppIconPainter({
    this.background = AppTheme.primary,
    this.pillColor = Colors.white,
    this.heartColor = AppTheme.primaryDark,
  });

  final Color background;
  final Color pillColor;
  final Color heartColor;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;

    // 1. 배경
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = background,
    );

    // 2. 알약 (살짝 기운 캡슐)
    canvas.save();
    canvas.translate(w * 0.42, w * 0.58);
    canvas.rotate(-math.pi / 6);
    final pillW = w * 0.62;
    final pillH = w * 0.26;
    final pillRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: pillW, height: pillH),
      Radius.circular(pillH / 2),
    );
    canvas.drawRRect(pillRect, Paint()..color = pillColor);
    // 알약 가운데 분리선
    canvas.drawLine(
      Offset(-pillW * 0.42, 0),
      Offset(pillW * 0.42, 0),
      Paint()
        ..color = background.withValues(alpha: 0.22)
        ..strokeWidth = w * 0.012,
    );
    canvas.restore();

    // 3. 하트 (알약 위 오른쪽, 살짝 떠 있는 느낌)
    final heartSize = w * 0.42;
    canvas.save();
    canvas.translate(w * 0.5 - heartSize / 2, w * 0.18);
    _drawHeart(canvas, heartSize, heartColor);
    canvas.restore();
  }

  /// 두 cubic 베지어로 그리는 단순 하트. 좌상단(0,0) ~ 우하단(s,s) 박스
  /// 안에 들어간다.
  void _drawHeart(Canvas canvas, double s, Color color) {
    final paint = Paint()..color = color;
    final w = s;
    final h = s;
    final path = Path()
      ..moveTo(w * 0.5, h * 0.32)
      ..cubicTo(
        w * 0.5,
        h * 0.05,
        w * 0.0,
        h * 0.05,
        w * 0.0,
        h * 0.42,
      )
      ..cubicTo(
        w * 0.0,
        h * 0.65,
        w * 0.42,
        h * 0.85,
        w * 0.5,
        h * 1.00,
      )
      ..cubicTo(
        w * 0.58,
        h * 0.85,
        w * 1.0,
        h * 0.65,
        w * 1.0,
        h * 0.42,
      )
      ..cubicTo(
        w * 1.0,
        h * 0.05,
        w * 0.5,
        h * 0.05,
        w * 0.5,
        h * 0.32,
      )
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(AppIconPainter old) =>
      old.background != background ||
      old.pillColor != pillColor ||
      old.heartColor != heartColor;
}

/// 인앱에서 가볍게 갖다 쓸 수 있는 위젯.
class BrandIcon extends StatelessWidget {
  const BrandIcon({this.size = 96, this.rounded = true, super.key});

  final double size;
  final bool rounded;

  @override
  Widget build(BuildContext context) {
    final child = CustomPaint(
      size: Size.square(size),
      painter: AppIconPainter(),
    );
    if (!rounded) return child;
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.22),
      child: child,
    );
  }
}
