import 'dart:convert';

import '../../../core/security/encryption_service.dart';
import '../../../core/security/secure_storage.dart';
import '../../recommendation/engine/family_input.dart';

class FamilyService {
  FamilyService._();

  /// 인덱스에서 ID 제거 + 드래프트 키 + 모든 날짜의 체크인 / AI 캐시 삭제.
  /// 멤버 삭제 후에는 어떤 잔여 건강 데이터도 디스크에 남기지 않는다.
  static Future<void> deleteMember(String id) async {
    final indexRaw = await SecureStorage.read(SecureStorage.kFamilyDraftsIndex);
    if (indexRaw != null) {
      final ids =
          (jsonDecode(indexRaw) as List).map((e) => e.toString()).toList();
      ids.remove(id);
      await SecureStorage.write(
        SecureStorage.kFamilyDraftsIndex,
        jsonEncode(ids),
      );
    }
    await SecureStorage.delete(SecureStorage.familyDraftKey(id));

    // 과거 날짜를 포함한 모든 체크인/AI 캐시 키를 정리한다.
    final all = await SecureStorage.readAll();
    final checkinPrefix = 'checkin.$id.';
    final aiPrefix = 'ai_comment.$id.';
    for (final key in all.keys) {
      if (key.startsWith(checkinPrefix) || key.startsWith(aiPrefix)) {
        await SecureStorage.delete(key);
      }
    }
  }

  /// 같은 ID에 새 FamilyInput을 암호화해서 덮어쓴다.
  static Future<void> updateMember(String id, FamilyInput input) async {
    final cipher = EncryptionService.instance.encryptJson(input.toJson());
    await SecureStorage.write(SecureStorage.familyDraftKey(id), cipher);
  }
}
