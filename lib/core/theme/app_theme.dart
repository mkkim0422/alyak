import 'package:flutter/material.dart';

/// 디자인 토큰 단일 소스. Medisafe / Roundhealth 의 미니멀·따뜻함을 참고해
/// soft green 액센트 + warm coral 보조 + 차분한 grey 텍스트로 구성.
///
/// 기존 화면들이 참조하던 `cream` / `subtle` / `line` / `ink` / `danger`
/// 같은 이름은 신규 토큰의 alias 로 유지해 호출부 churn 을 줄였다.
class AppTheme {
  AppTheme._();

  // ─────────────────────────────────────────────────────── Brand
  static const Color primary = Color(0xFF4CAF82);
  static const Color primaryLight = Color(0xFFE8F5EE);
  static const Color primaryDark = Color(0xFF2E8B66);
  static const Color secondary = Color(0xFFFF8C69);

  // ─────────────────────────────────────────────────────── Surface / Text
  static const Color background = Color(0xFFF8F9FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B7280);

  // ─────────────────────────────────────────────────────── Status
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);

  // ─────────────────────────────────────────────────────── Border
  static const Color border = Color(0xFFE5E7EB);

  // ─────────────────────────────────────────────────────── Legacy aliases
  // 기존 화면들의 호출부 호환을 위해 옛 이름을 신규 토큰으로 매핑.
  static const Color cream = primaryLight; // soft tinted surface
  static const Color ink = textPrimary;
  static const Color subtle = textSecondary;
  static const Color line = border;
  static const Color danger = error;

  // ─────────────────────────────────────────────────────── Family colors
  // 가족 멤버 인덱스(저장 순서) 별 자동 배정 컬러. 6 명 초과 시 wrap-around.
  static const List<Color> memberColors = [
    Color(0xFFFF6B9D), // pink
    Color(0xFF4FACFE), // blue
    Color(0xFF43E97B), // green
    Color(0xFFFA8231), // orange
    Color(0xFFA29BFE), // purple
    Color(0xFFFD79A8), // rose
  ];

  static Color memberColorFor(int index) =>
      memberColors[index.abs() % memberColors.length];

  // ─────────────────────────────────────────────────────── Spacing (8dp grid)
  static const double space1 = 4;
  static const double space2 = 8;
  static const double space3 = 12;
  static const double space4 = 16;
  static const double space5 = 20;
  static const double space6 = 24;
  static const double space8 = 32;

  // ─────────────────────────────────────────────────────── Radii
  static const double radiusCard = 16;
  static const double radiusButton = 24;
  static const double radiusChip = 100;
  static const double radiusSmall = 12;

  // ─────────────────────────────────────────────────────── Shadows
  static const List<BoxShadow> softShadow = [
    BoxShadow(
      color: Color.fromRGBO(0, 0, 0, 0.08),
      offset: Offset(0, 2),
      blurRadius: 8,
    ),
  ];

  // ─────────────────────────────────────────────────────── Typography
  static const TextStyle heading1 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    height: 1.3,
  );
  static const TextStyle heading2 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    height: 1.3,
  );
  static const TextStyle heading3 = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    height: 1.35,
  );
  static const TextStyle body1 = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: textPrimary,
    height: 1.5,
  );
  static const TextStyle body2 = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: textPrimary,
    height: 1.45,
  );
  static const TextStyle caption = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: textSecondary,
    height: 1.4,
  );

  // ─────────────────────────────────────────────────────── ThemeData
  static ThemeData light() {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.light,
      ).copyWith(
        primary: primary,
        secondary: secondary,
        surface: surface,
        error: error,
      ),
      scaffoldBackgroundColor: background,
      textTheme: base.textTheme.apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusButton),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: const BorderSide(color: border),
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusButton),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          side: const BorderSide(color: border),
        ),
        margin: EdgeInsets.zero,
      ),
    );
  }
}
