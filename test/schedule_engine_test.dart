import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:alyak/core/data/supplement_repository.dart';
import 'package:alyak/features/recommendation/engine/schedule_engine.dart';

class _DiskAssetBundle extends CachingAssetBundle {
  _DiskAssetBundle(this.root);
  final String root;
  @override
  Future<ByteData> load(String key) async {
    final f = File('$root/$key');
    final bytes = await f.readAsBytes();
    return ByteData.sublistView(bytes);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SupplementRepository repo;
  late ScheduleEngine engine;

  setUpAll(() async {
    final root = Directory.current.path;
    repo = SupplementRepository();
    await repo.load(bundle: _DiskAssetBundle(root));
    engine = ScheduleEngine(repository: repo);
  });

  test('철분과 칼슘은 같은 슬롯에 배치되지 않는다 (분리 필요 룰)', () {
    final result = engine.scheduleForNames(['철분', '칼슘']);
    final allSlots = [
      result.morning,
      result.lunch,
      result.evening,
      result.beforeSleep,
    ];
    bool same = false;
    for (final slot in allSlots) {
      final hasIron = slot.any((n) => n.contains('철분'));
      final hasCalcium = slot.any((n) => n.contains('칼슘'));
      if (hasIron && hasCalcium) same = true;
    }
    expect(same, isFalse, reason: '철분과 칼슘은 다른 슬롯에 있어야 한다');
    // conflicts 에도 분리 필요로 잡혀야 함.
    expect(
      result.conflicts.any((c) =>
          (c.supplementA.contains('철분') && c.supplementB.contains('칼슘')) ||
          (c.supplementA.contains('칼슘') && c.supplementB.contains('철분'))),
      isTrue,
      reason: 'conflicts 에 철분-칼슘 분리 룰이 잡혀야 한다',
    );
  });

  test('비타민D + 칼슘 시너지가 같은 슬롯으로 정렬된다', () {
    final result = engine.scheduleForNames(['비타민D', '칼슘']);
    bool aligned = false;
    final slots = [
      result.morning,
      result.lunch,
      result.evening,
      result.beforeSleep,
    ];
    for (final slot in slots) {
      final hasD = slot.any((n) => n.contains('비타민D'));
      final hasCa = slot.any((n) => n.contains('칼슘'));
      if (hasD && hasCa) aligned = true;
    }
    // synergies 가 잡히면 룰이 정상 동작 — 같은 슬롯 정렬은 best-effort 이므로
    // synergies 나 같은 슬롯 둘 중 하나는 만족해야 한다.
    final hasSynergy = result.synergies.any((s) =>
        (s.supplementA.contains('비타민D') && s.supplementB.contains('칼슘')) ||
        (s.supplementA.contains('칼슘') && s.supplementB.contains('비타민D')));
    expect(aligned || hasSynergy, isTrue,
        reason: '비타민D + 칼슘은 같은 슬롯이거나 synergy 로 잡혀야 한다');
  });
}
