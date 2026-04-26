import 'secure_storage.dart';

/// Enforces a 30-day idle auto-logout. Call [touch] on any meaningful
/// user interaction; call [shouldForceLogout] on app launch / resume.
class SessionGuard {
  SessionGuard._();

  static const Duration idleLimit = Duration(days: 30);

  static Future<void> touch() async {
    await SecureStorage.write(
      SecureStorage.kLastActivityAt,
      DateTime.now().toUtc().toIso8601String(),
    );
  }

  static Future<bool> shouldForceLogout() async {
    final raw = await SecureStorage.read(SecureStorage.kLastActivityAt);
    if (raw == null) return false;
    final last = DateTime.tryParse(raw);
    if (last == null) return false;
    return DateTime.now().toUtc().difference(last) > idleLimit;
  }
}
