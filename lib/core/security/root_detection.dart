import 'package:flutter/foundation.dart';
import 'package:flutter_jailbreak_detection/flutter_jailbreak_detection.dart';

/// Checks whether the device appears rooted (Android) or jailbroken (iOS).
/// We never *block* the app — we surface a soft warning, because the
/// detection has false positives and locking real users out is worse
/// than the marginal extra risk on a rooted device.
class RootDetection {
  RootDetection._();

  static Future<RootStatus> check() async {
    if (kDebugMode) {
      // Debug builds frequently report jailbroken on simulators.
      return RootStatus.unknown;
    }
    try {
      final jailbroken = await FlutterJailbreakDetection.jailbroken;
      final developerMode =
          await FlutterJailbreakDetection.developerMode.catchError((_) => false);
      if (jailbroken) return RootStatus.compromised;
      if (developerMode) return RootStatus.developerMode;
      return RootStatus.clean;
    } catch (_) {
      return RootStatus.unknown;
    }
  }
}

enum RootStatus { clean, developerMode, compromised, unknown }
