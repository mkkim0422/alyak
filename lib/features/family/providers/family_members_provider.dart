import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/security/encryption_service.dart';
import '../../../core/security/secure_storage.dart';
import '../models/family_member.dart';

/// SecureStorage에 저장된 암호화 드래프트를 복호화해서 리스트로 반환.
/// 비어 있으면 빈 리스트.
final familyMembersProvider = FutureProvider<List<FamilyMember>>((ref) async {
  final indexRaw = await SecureStorage.read(SecureStorage.kFamilyDraftsIndex);
  if (indexRaw == null) return const [];
  final ids =
      (jsonDecode(indexRaw) as List).map((e) => e.toString()).toList();

  final out = <FamilyMember>[];
  for (final id in ids) {
    final cipher = await SecureStorage.read(SecureStorage.familyDraftKey(id));
    if (cipher == null) continue;
    try {
      final json = EncryptionService.instance.decryptJson(cipher);
      out.add(FamilyMember.fromDraft(id: id, draft: json));
    } catch (_) {
      // 복호화 실패는 조용히 스킵 — 키가 바뀌었거나 손상된 데이터.
    }
  }
  return out;
});
