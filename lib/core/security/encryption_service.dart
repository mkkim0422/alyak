import 'dart:convert';

import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/foundation.dart';

import '../config/env_config.dart';
import 'secure_storage.dart';

/// AES-256 GCM symmetric encryption used to protect sensitive payloads
/// (health profile, lifestyle answers) before they leave the device.
///
/// 키 출처 우선순위:
///   1) Keystore/Keychain에 저장된 device-bound 256-bit 키 — 첫 실행 때
///      `SecureRandom`으로 생성해서 저장. 기기 외부로 절대 빠지지 않는다.
///   2) (`kDebugMode` only) `.env`의 `APP_ENCRYPTION_KEY` — 위 단계가 실패할
///      때만 폴백. 프로덕션 빌드에서는 폴백을 쓰지 않고 에러를 던진다.
///
/// IV는 매 encrypt 마다 12바이트씩 새로 생성해서 ciphertext 앞에 붙인다.
class EncryptionService {
  EncryptionService._(this._key);

  final enc.Key _key;
  static EncryptionService? _instance;

  /// `main()`에서 한 번 호출. 기기 키를 읽거나 새로 만든 뒤 캐싱한다.
  /// 호출 후부터 [instance]를 동기 접근으로 쓸 수 있다.
  static Future<EncryptionService> initialize() async {
    if (_instance != null) return _instance!;

    // 1. 이미 생성된 device-bound 키가 있으면 그대로 사용.
    final existing = await SecureStorage.read(SecureStorage.kCryptoMasterKey);
    if (existing != null && existing.isNotEmpty) {
      try {
        final raw = base64Decode(existing);
        if (raw.length == 32) {
          return _instance =
              EncryptionService._(enc.Key(Uint8List.fromList(raw)));
        }
      } catch (_) {
        // 손상된 값. 아래 fresh-key 단계로 진행.
      }
    }

    // 2. 첫 실행: 256-bit 랜덤 키 생성 → SecureStorage에 저장.
    try {
      final fresh = enc.Key.fromSecureRandom(32);
      await SecureStorage.write(
        SecureStorage.kCryptoMasterKey,
        base64Encode(fresh.bytes),
      );
      return _instance = EncryptionService._(fresh);
    } catch (_) {
      // 3. 디버그 빌드에서만 .env 키로 폴백 (테스트/시뮬레이터에서
      //    Keychain 접근 실패하는 케이스 대비). 프로덕션에선 그냥 fail.
      if (kDebugMode) {
        final raw = base64Decode(EnvConfig.appEncryptionKey);
        if (raw.length == 32) {
          return _instance =
              EncryptionService._(enc.Key(Uint8List.fromList(raw)));
        }
      }
      rethrow;
    }
  }

  static EncryptionService get instance {
    final i = _instance;
    if (i == null) {
      throw StateError(
        'EncryptionService not initialised. Call initialize() in main() '
        'before any encrypt/decrypt usage.',
      );
    }
    return i;
  }

  enc.Encrypter get _encrypter =>
      enc.Encrypter(enc.AES(_key, mode: enc.AESMode.gcm, padding: null));

  /// Encrypts a plain UTF-8 string. Returns base64(IV || ciphertext || tag).
  String encryptString(String plaintext) {
    final iv = enc.IV.fromSecureRandom(12);
    final encrypted = _encrypter.encryptBytes(
      utf8.encode(plaintext),
      iv: iv,
    );
    final out = Uint8List(iv.bytes.length + encrypted.bytes.length)
      ..setRange(0, iv.bytes.length, iv.bytes)
      ..setRange(iv.bytes.length, iv.bytes.length + encrypted.bytes.length,
          encrypted.bytes);
    return base64Encode(out);
  }

  /// Decrypts a value produced by [encryptString].
  String decryptString(String payload) {
    final raw = base64Decode(payload);
    if (raw.length < 13) {
      throw const FormatException('encrypted payload too short');
    }
    final iv = enc.IV(Uint8List.fromList(raw.sublist(0, 12)));
    final cipher = enc.Encrypted(Uint8List.fromList(raw.sublist(12)));
    final bytes = _encrypter.decryptBytes(cipher, iv: iv);
    return utf8.decode(bytes);
  }

  /// Encrypts a JSON-serializable map.
  String encryptJson(Map<String, dynamic> json) =>
      encryptString(jsonEncode(json));

  Map<String, dynamic> decryptJson(String payload) =>
      jsonDecode(decryptString(payload)) as Map<String, dynamic>;

  @visibleForTesting
  static void resetForTest() => _instance = null;
}
