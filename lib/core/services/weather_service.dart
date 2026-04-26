import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../l10n/app_strings.dart';
import '../security/secure_storage.dart';

/// 계절은 디바이스 시각 기준, 날씨는 wttr.in (key 불필요) 1회 호출 후
/// 6시간 캐시. 네트워크 실패 시 계절 정보만으로 fallback.
class WeatherService {
  WeatherService._();

  static const _endpoint = 'https://wttr.in/Seoul?format=j1';
  static const _ttl = Duration(hours: 6);

  /// 메인 entry. 항상 [WeatherTip] 을 돌려준다 (절대 throw 하지 않음).
  static Future<WeatherTip> getTip({
    DateTime? now,
    http.Client? client,
  }) async {
    final at = now ?? DateTime.now();
    final season = _seasonFor(at);

    // 1. 캐시.
    final cached = await _readCache(at);
    if (cached != null) {
      return _composeTip(season, cached);
    }

    // 2. fetch (단축 timeout). 실패해도 계절 fallback.
    final fresh = await _fetch(client, at);
    if (fresh != null) {
      await _writeCache(fresh, at);
      return _composeTip(season, fresh);
    }
    return WeatherTip.seasonOnly(season);
  }

  static Future<_WeatherCache?> _fetch(
    http.Client? client,
    DateTime at,
  ) async {
    final cli = client ?? http.Client();
    try {
      final resp = await cli
          .get(Uri.parse(_endpoint))
          .timeout(const Duration(seconds: 4));
      if (resp.statusCode != 200) return null;
      final data = json.decode(resp.body) as Map<String, dynamic>;
      final current =
          (data['current_condition'] as List?)?.cast<Map<String, dynamic>>() ??
              const [];
      if (current.isEmpty) return null;
      final c = current.first;
      final desc = ((c['weatherDesc'] as List?)?.cast<Map<String, dynamic>>() ??
              const [])
          .map((e) => e['value']?.toString() ?? '')
          .join(',');
      // PM2.5 / PM10 둘 중 큰 값 (없으면 0).
      double pm = 0;
      final pm25 = num.tryParse(c['pm2.5']?.toString() ?? '');
      final pm10 = num.tryParse(c['pm10']?.toString() ?? '');
      if (pm25 != null && pm25 > pm) pm = pm25.toDouble();
      if (pm10 != null && pm10 > pm) pm = pm10.toDouble();
      return _WeatherCache(
        descLower: desc.toLowerCase(),
        pm: pm,
        fetchedAt: at,
      );
    } catch (_) {
      return null;
    } finally {
      if (client == null) cli.close();
    }
  }

  static WeatherTip _composeTip(Season season, _WeatherCache w) {
    // 우선순위: 미세먼지 > 흐림/비 > 계절 fallback.
    if (w.pm >= 35) {
      return const WeatherTip(
        message: AppStrings.weatherTipDust,
        emoji: AppStrings.weatherTipDustEmoji,
      );
    }
    final d = w.descLower;
    final rainy = d.contains('rain') ||
        d.contains('drizzle') ||
        d.contains('shower');
    final cloudy = d.contains('overcast') || d.contains('cloud');
    if (rainy || cloudy) {
      return const WeatherTip(
        message: AppStrings.weatherTipCloudy,
        emoji: AppStrings.weatherTipCloudyEmoji,
      );
    }
    return WeatherTip.seasonOnly(season);
  }

  static Season _seasonFor(DateTime now) {
    final m = now.month;
    if (m >= 3 && m <= 5) return Season.spring;
    if (m >= 6 && m <= 8) return Season.summer;
    if (m >= 9 && m <= 11) return Season.autumn;
    return Season.winter;
  }

  // ── cache ─────────────────────────────────────────────────────────────

  static Future<_WeatherCache?> _readCache(DateTime now) async {
    final raw = await SecureStorage.read(SecureStorage.kWeatherCache);
    if (raw == null) return null;
    try {
      final m = json.decode(raw) as Map<String, dynamic>;
      final ts = DateTime.tryParse(m['fetched_at'] as String? ?? '');
      if (ts == null) return null;
      if (now.difference(ts) > _ttl) return null;
      return _WeatherCache(
        descLower: (m['desc'] as String? ?? '').toLowerCase(),
        pm: (m['pm'] as num? ?? 0).toDouble(),
        fetchedAt: ts,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> _writeCache(_WeatherCache w, DateTime now) async {
    final payload = json.encode(<String, dynamic>{
      'desc': w.descLower,
      'pm': w.pm,
      'fetched_at': now.toIso8601String(),
    });
    await SecureStorage.write(SecureStorage.kWeatherCache, payload);
  }
}

class _WeatherCache {
  const _WeatherCache({
    required this.descLower,
    required this.pm,
    required this.fetchedAt,
  });
  final String descLower;
  final double pm;
  final DateTime fetchedAt;
}

enum Season { spring, summer, autumn, winter }

extension SeasonX on Season {
  String get message {
    switch (this) {
      case Season.spring:
        return AppStrings.seasonSpring;
      case Season.summer:
        return AppStrings.seasonSummer;
      case Season.autumn:
        return AppStrings.seasonAutumn;
      case Season.winter:
        return AppStrings.seasonWinter;
    }
  }

  String get emoji {
    switch (this) {
      case Season.spring:
        return AppStrings.seasonSpringEmoji;
      case Season.summer:
        return AppStrings.seasonSummerEmoji;
      case Season.autumn:
        return AppStrings.seasonAutumnEmoji;
      case Season.winter:
        return AppStrings.seasonWinterEmoji;
    }
  }
}

/// UI에 보여 줄 한 줄 + 이모지. 계절 fallback / 날씨 우선 둘 다 같은 모양.
class WeatherTip {
  const WeatherTip({required this.message, required this.emoji});

  factory WeatherTip.seasonOnly(Season season) =>
      WeatherTip(message: season.message, emoji: season.emoji);

  final String message;
  final String emoji;
}
