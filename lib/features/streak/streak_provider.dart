import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../family/providers/family_members_provider.dart';
import 'streak_service.dart';

/// 가족 전체 streak. 가족 변동/체크 변동 시 외부에서 invalidate 해 다시 계산.
final streakProvider = FutureProvider<StreakSnapshot>((ref) async {
  final members = await ref.watch(familyMembersProvider.future);
  final ids = members.map((m) => m.id).toList();
  return StreakService.computeAndSave(ids);
});
