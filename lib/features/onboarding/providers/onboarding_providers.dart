import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/security/secure_storage.dart';
import '../models/user_role.dart';

/// Tracks which role the user has chosen on screen 1. Persisted to
/// SecureStorage (not SharedPreferences) so it survives reinstalls
/// only via OS-level secure storage rules.
class UserRoleController extends Notifier<UserRole?> {
  @override
  UserRole? build() {
    _hydrate();
    return null;
  }

  Future<void> _hydrate() async {
    final raw = await SecureStorage.read(SecureStorage.kUserRole);
    state = UserRole.fromStorage(raw);
  }

  Future<void> select(UserRole role) async {
    await SecureStorage.write(SecureStorage.kUserRole, role.storageValue);
    state = role;
  }
}

final userRoleControllerProvider =
    NotifierProvider<UserRoleController, UserRole?>(UserRoleController.new);

/// 동기 ref가 필요한 곳(설정 화면 등)에서 한 번에 읽기 위한 Future 버전.
final userRoleFutureProvider = FutureProvider<UserRole?>((ref) async {
  final raw = await SecureStorage.read(SecureStorage.kUserRole);
  return UserRole.fromStorage(raw);
});
