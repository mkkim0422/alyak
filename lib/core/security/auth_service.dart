import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:pointycastle/digests/sha256.dart';
import 'package:pointycastle/key_derivators/api.dart';
import 'package:pointycastle/key_derivators/pbkdf2.dart';
import 'package:pointycastle/macs/hmac.dart';

import 'secure_storage.dart';

/// 4자리 PIN + 생체 인증을 통합 관리하는 보안 서비스.
///
/// PIN 저장 방식:
/// - 평문 절대 저장 안 함.
/// - 기기별 32바이트 random salt 를 secure storage 에 별도 저장.
/// - PBKDF2-HMAC-SHA256, 100,000 iterations, 32 byte 출력.
/// - 검증은 상수시간 비교 (timing attack 방지).
///
/// 잠금 정책:
/// - 5회 실패: 5분 잠금 (분 단위 카운트다운).
/// - 10회 실패 + auto-wipe ON: SecureStorage.wipe() 후 동의 화면으로.
/// - 10회 실패 + auto-wipe OFF: 30분 잠금.
///
/// 세션 정책:
/// - 인증 성공 시 [_LastAuth] 갱신.
/// - 백그라운드 ≥ 5분 후 복귀하면 재인증 필요.
class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  // ─────────── 상수 ───────────
  static const int pinLength = 4;
  static const int maxFailedAttempts = 5;
  static const int wipeOnFailedAttempts = 10;
  static const Duration lockoutDuration = Duration(minutes: 5);
  static const Duration extendedLockoutDuration = Duration(minutes: 30);
  static const Duration sessionTimeout = Duration(minutes: 5);
  static const int _pbkdf2Iterations = 100000;
  static const int _saltLength = 32;
  static const int _hashLength = 32;

  final LocalAuthentication _localAuth = LocalAuthentication();

  // ───────────────────────────────────────────── PIN management

  Future<bool> isPinSet() async {
    final hash = await SecureStorage.read(SecureStorage.kAuthPinHash);
    final salt = await SecureStorage.read(SecureStorage.kAuthPinSalt);
    return hash != null && salt != null && hash.isNotEmpty && salt.isNotEmpty;
  }

  /// 새 PIN 을 설정. 기존 hash/salt 가 있어도 덮어쓴다 (변경 흐름은 [changePin]).
  Future<void> setPin(String pin) async {
    _assertPinShape(pin);
    final salt = _randomBytes(_saltLength);
    final hash = _deriveHash(pin, salt);
    await SecureStorage.write(SecureStorage.kAuthPinSalt, base64Encode(salt));
    await SecureStorage.write(SecureStorage.kAuthPinHash, base64Encode(hash));
    // 새 PIN 설정 시 실패 카운터/잠금 리셋.
    await resetFailedAttempts();
  }

  /// PIN 검증. 일치하면 true 반환 + 세션 시작 + 실패 카운터 리셋.
  /// 불일치면 false + 실패 카운터 +1 (호출 측에서 잠금 처리).
  Future<bool> verifyPin(String pin) async {
    _assertPinShape(pin);
    if (await isLockedOut()) return false;

    final hashB64 = await SecureStorage.read(SecureStorage.kAuthPinHash);
    final saltB64 = await SecureStorage.read(SecureStorage.kAuthPinSalt);
    if (hashB64 == null || saltB64 == null) return false;

    final stored = base64Decode(hashB64);
    final salt = base64Decode(saltB64);
    final candidate = _deriveHash(pin, salt);

    final ok = _constantTimeEquals(stored, candidate);
    if (ok) {
      await resetFailedAttempts();
      await startSession();
      return true;
    }
    await incrementFailedAttempts();
    return false;
  }

  /// 기존 PIN 확인 후 새 PIN 으로 교체. 잘못된 oldPin 이면 false.
  Future<bool> changePin(String oldPin, String newPin) async {
    final ok = await verifyPin(oldPin);
    if (!ok) return false;
    await setPin(newPin);
    return true;
  }

  // ───────────────────────────────────────────── biometric

  Future<bool> isBiometricAvailable() async {
    try {
      final supported = await _localAuth.isDeviceSupported();
      if (!supported) return false;
      final canCheck = await _localAuth.canCheckBiometrics;
      return canCheck;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isBiometricEnabled() async {
    final v = await SecureStorage.read(SecureStorage.kAuthBiometricEnabled);
    return v == 'true';
  }

  /// 생체 인증을 켜기 위해서는 (1) 현재 PIN 확인 (2) 한 번 생체로 인증 성공.
  /// 둘 중 하나라도 실패하면 토글 ON 안 됨. 반환값: 켜졌는지.
  Future<bool> enableBiometric(String currentPin) async {
    if (!await verifyPin(currentPin)) return false;
    final available = await isBiometricAvailable();
    if (!available) return false;
    final ok = await authenticateWithBiometric();
    if (!ok) return false;
    await SecureStorage.write(SecureStorage.kAuthBiometricEnabled, 'true');
    return true;
  }

  Future<void> disableBiometric() async {
    await SecureStorage.write(SecureStorage.kAuthBiometricEnabled, 'false');
  }

  /// 생체 인증 시도. 성공하면 세션 시작.
  Future<bool> authenticateWithBiometric() async {
    if (await isLockedOut()) return false;
    if (!await isBiometricEnabled() && !await isBiometricAvailable()) {
      return false;
    }
    try {
      final ok = await _localAuth.authenticate(
        localizedReason: '잠금 해제를 위해 생체 인증이 필요해요',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      if (ok) {
        await resetFailedAttempts();
        await startSession();
      }
      return ok;
    } catch (_) {
      return false;
    }
  }

  // ───────────────────────────────────────────── lockout

  Future<int> getFailedAttempts() async {
    final raw = await SecureStorage.read(SecureStorage.kAuthFailedAttempts);
    return int.tryParse(raw ?? '0') ?? 0;
  }

  Future<void> incrementFailedAttempts() async {
    final cur = await getFailedAttempts();
    final next = cur + 1;
    await SecureStorage.write(
      SecureStorage.kAuthFailedAttempts,
      next.toString(),
    );

    if (next >= wipeOnFailedAttempts) {
      // 10회: 호출 측에서 handleMaxFailures() 로 분기 (auto-wipe ON 시 즉시 삭제).
      await SecureStorage.write(
        SecureStorage.kAuthLockoutUntil,
        DateTime.now().toUtc().add(extendedLockoutDuration).toIso8601String(),
      );
    } else if (next >= maxFailedAttempts) {
      // 5회: 5분 잠금.
      await SecureStorage.write(
        SecureStorage.kAuthLockoutUntil,
        DateTime.now().toUtc().add(lockoutDuration).toIso8601String(),
      );
    }
  }

  Future<void> resetFailedAttempts() async {
    await SecureStorage.delete(SecureStorage.kAuthFailedAttempts);
    await SecureStorage.delete(SecureStorage.kAuthLockoutUntil);
  }

  Future<bool> isLockedOut() async {
    final until = await getLockoutUntil();
    if (until == null) return false;
    return DateTime.now().toUtc().isBefore(until);
  }

  Future<DateTime?> getLockoutUntil() async {
    final raw = await SecureStorage.read(SecureStorage.kAuthLockoutUntil);
    if (raw == null) return null;
    return DateTime.tryParse(raw)?.toUtc();
  }

  // ───────────────────────────────────────────── auto-wipe

  Future<bool> isAutoWipeEnabled() async {
    final v = await SecureStorage.read(SecureStorage.kAuthAutoWipeEnabled);
    return v == 'true';
  }

  Future<void> setAutoWipeEnabled(bool enabled) async {
    await SecureStorage.write(
      SecureStorage.kAuthAutoWipeEnabled,
      enabled.toString(),
    );
  }

  /// 10회 실패 도달 시 호출. auto-wipe ON 이면 SecureStorage 전부 비우고 true,
  /// 아니면 false (호출 측은 30분 잠금 안내만 표시).
  Future<bool> handleMaxFailures() async {
    if (await isAutoWipeEnabled()) {
      await SecureStorage.wipe();
      return true;
    }
    return false;
  }

  // ───────────────────────────────────────────── session

  Future<void> startSession() async {
    await SecureStorage.write(
      SecureStorage.kAuthLastAuth,
      DateTime.now().toUtc().toIso8601String(),
    );
  }

  Future<void> endSession() async {
    await SecureStorage.delete(SecureStorage.kAuthLastAuth);
  }

  Future<bool> isSessionActive() async {
    final last = await getLastAuthTime();
    if (last == null) return false;
    return DateTime.now().toUtc().difference(last) < sessionTimeout;
  }

  Future<DateTime?> getLastAuthTime() async {
    final raw = await SecureStorage.read(SecureStorage.kAuthLastAuth);
    if (raw == null) return null;
    return DateTime.tryParse(raw)?.toUtc();
  }

  // ───────────────────────────────────────────── crypto helpers

  @visibleForTesting
  static Uint8List deriveHashForTest(String pin, List<int> salt) =>
      _deriveHash(pin, salt);

  @visibleForTesting
  static bool constantTimeEqualsForTest(List<int> a, List<int> b) =>
      _constantTimeEquals(a, b);

  /// PBKDF2-HMAC-SHA256, 100k iterations. 32 byte 출력.
  static Uint8List _deriveHash(String pin, List<int> salt) {
    final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(
        Uint8List.fromList(salt),
        _pbkdf2Iterations,
        _hashLength,
      ));
    return pbkdf2.process(Uint8List.fromList(utf8.encode(pin)));
  }

  /// 상수시간 비교 — 길이가 같으면 모든 바이트를 끝까지 비교한 뒤 결과 반환.
  /// timing attack 으로 PIN 추측을 못 하도록.
  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    int diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  static Uint8List _randomBytes(int length) {
    final rnd = math.Random.secure();
    final out = Uint8List(length);
    for (var i = 0; i < length; i++) {
      out[i] = rnd.nextInt(256);
    }
    return out;
  }

  static void _assertPinShape(String pin) {
    if (pin.length != pinLength) {
      throw ArgumentError('PIN must be $pinLength digits');
    }
    if (!RegExp(r'^\d+$').hasMatch(pin)) {
      throw ArgumentError('PIN must be digits only');
    }
  }
}
