// Renders [AppIconPainter] at every platform-required size and writes
// PNG files into Android mipmap folders + iOS appiconset folder.
//
// Run with:
//   flutter test tool/generate_app_icon.dart
//
// Produced files are committed alongside the rest of the project. Re-run
// this script whenever the painter changes.

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:alyak/core/branding/app_icon_painter.dart';

void main() {
  testWidgets('generate app icons', (WidgetTester tester) async {
    await tester.runAsync(() async {
      final androidSizes = <String, int>{
        'mdpi': 48,
        'hdpi': 72,
        'xhdpi': 96,
        'xxhdpi': 144,
        'xxxhdpi': 192,
      };
      for (final entry in androidSizes.entries) {
        final bytes = await _renderPainterToPng(tester, entry.value.toDouble());
        final dir =
            Directory('android/app/src/main/res/mipmap-${entry.key}');
        await dir.create(recursive: true);
        File('${dir.path}/ic_launcher.png').writeAsBytesSync(bytes);
      }

      final iosFiles = <String, double>{
        'Icon-App-1024x1024@1x.png': 1024,
        'Icon-App-20x20@1x.png': 20,
        'Icon-App-20x20@2x.png': 40,
        'Icon-App-20x20@3x.png': 60,
        'Icon-App-29x29@1x.png': 29,
        'Icon-App-29x29@2x.png': 58,
        'Icon-App-29x29@3x.png': 87,
        'Icon-App-40x40@1x.png': 40,
        'Icon-App-40x40@2x.png': 80,
        'Icon-App-40x40@3x.png': 120,
        'Icon-App-60x60@2x.png': 120,
        'Icon-App-60x60@3x.png': 180,
        'Icon-App-76x76@1x.png': 76,
        'Icon-App-76x76@2x.png': 152,
        'Icon-App-83.5x83.5@2x.png': 167,
      };
      const iosDir = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
      await Directory(iosDir).create(recursive: true);
      for (final entry in iosFiles.entries) {
        final bytes = await _renderPainterToPng(tester, entry.value);
        File('$iosDir/${entry.key}').writeAsBytesSync(bytes);
      }

      // iOS LaunchScreen이 참조하는 LaunchImage 자산.
      const launchDir = 'ios/Runner/Assets.xcassets/LaunchImage.imageset';
      await Directory(launchDir).create(recursive: true);
      final launch1x = await _renderPainterToPng(tester, 120);
      final launch2x = await _renderPainterToPng(tester, 240);
      final launch3x = await _renderPainterToPng(tester, 360);
      File('$launchDir/LaunchImage.png').writeAsBytesSync(launch1x);
      File('$launchDir/LaunchImage@2x.png').writeAsBytesSync(launch2x);
      File('$launchDir/LaunchImage@3x.png').writeAsBytesSync(launch3x);

      // 인앱에서 splash 등에 직접 쓰기 위한 1024 마스터.
      const brandingDir = 'assets/branding';
      await Directory(brandingDir).create(recursive: true);
      final master = await _renderPainterToPng(tester, 1024);
      File('$brandingDir/app_icon.png').writeAsBytesSync(master);
    });
  });
}

Future<Uint8List> _renderPainterToPng(
  WidgetTester tester,
  double size,
) async {
  final boundaryKey = GlobalKey();
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: RepaintBoundary(
          key: boundaryKey,
          child: SizedBox(
            width: size,
            height: size,
            child: CustomPaint(
              size: Size.square(size),
              painter: AppIconPainter(),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();

  final boundary = boundaryKey.currentContext!.findRenderObject()
      as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 1.0);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  return byteData!.buffer.asUint8List();
}
