/// 가족 관리자(엄마)가 가족 전체를 관리하느냐, 본인만 관리하느냐.
enum UserRole {
  manager('manager'),
  solo('solo');

  const UserRole(this.storageValue);
  final String storageValue;

  static UserRole? fromStorage(String? value) {
    for (final role in UserRole.values) {
      if (role.storageValue == value) return role;
    }
    return null;
  }
}
