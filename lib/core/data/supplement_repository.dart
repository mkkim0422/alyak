import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/recommendation/engine/family_input.dart';
import '../config/region_config.dart';
import 'models/conflict_warning.dart';
import 'models/recommendation_result.dart';
import 'models/schedule_result.dart';
import 'models/supplement_guide_model.dart';
import 'models/symptom_result.dart';

/// Loads the four data assets in `assets/data/` and exposes the queries
/// the app needs against them. Old `supplements.json`, `recommendation_rules.json`,
/// and `interactions.json` are intentionally NOT touched here.
class SupplementRepository {
  static const _supplementGuideAsset = 'assets/data/supplement_guide.json';
  static const _symptomGuideAsset = 'assets/data/symptom_guide.json';
  static const _combinationOptimizerAsset =
      'assets/data/combination_optimizer.json';
  static const _ageGroupAsset = 'assets/data/age_group_recommendations.json';

  // Cached parsed data.
  List<SupplementGuide> _supplements = const [];
  List<SymptomResult> _symptoms = const [];
  List<_ComboRule> _rules = const [];
  _TimeSlots _timeSlots = const _TimeSlots(
    morning: [],
    lunch: [],
    evening: [],
    beforeSleep: [],
    emptyStomachOk: [],
    mustTakeWithFood: [],
  );
  List<_OverdoseWarning> _overdoseWarnings = const [];
  List<_AgeProfile> _ageProfiles = const [];
  bool _loaded = false;

  // Pre-built recommendation cache. See scripts/generate_cache.dart.
  // 키 형식:
  //   • newborn_{sex}_{feeding}
  //   • toddler_{sex}_picky_{yes|no}
  //   • child_{sex}_picky_{yes|no}
  //   • teen_{sex}_stress_{low|medium|high}
  //   • {twenties|thirties|forties|fifties|elderly}_{sex}_{archetypeId}
  Map<String, _CachedEntry> _cache = const {};
  List<_CacheArchetype> _cacheArchetypes = const [];
  bool _cacheLoaded = false;

  bool get isLoaded => _loaded;
  bool get isCacheLoaded => _cacheLoaded;
  List<SupplementGuide> get supplements => List.unmodifiable(_supplements);

  Future<void> load({AssetBundle? bundle}) async {
    if (_loaded) return;
    final assetBundle = bundle ?? rootBundle;

    final results = await Future.wait([
      assetBundle.loadString(_supplementGuideAsset),
      assetBundle.loadString(_symptomGuideAsset),
      assetBundle.loadString(_combinationOptimizerAsset),
      assetBundle.loadString(_ageGroupAsset),
    ]);

    final supplementJson = json.decode(results[0]) as Map<String, dynamic>;
    final symptomJson = json.decode(results[1]) as Map<String, dynamic>;
    final comboJson = json.decode(results[2]) as Map<String, dynamic>;
    final ageJson = json.decode(results[3]) as Map<String, dynamic>;

    _supplements = (supplementJson['supplements'] as List<dynamic>)
        .map((e) => SupplementGuide.fromJson(e as Map<String, dynamic>))
        .toList();

    _symptoms = (symptomJson['symptoms'] as List<dynamic>)
        .map((e) => SymptomResult.fromJson(e as Map<String, dynamic>))
        .toList();

    _rules = (comboJson['rules'] as List<dynamic>)
        .map((e) => _ComboRule.fromJson(e as Map<String, dynamic>))
        .toList();

    _timeSlots = _TimeSlots.fromJson(
      (comboJson['time_slot_optimization'] as Map?)?.cast<String, dynamic>() ??
          const {},
    );

    _overdoseWarnings = (comboJson['overdose_warnings'] as List<dynamic>)
        .map((e) => _OverdoseWarning.fromJson(e as Map<String, dynamic>))
        .toList();

    _ageProfiles = (ageJson['profiles'] as List<dynamic>)
        .map((e) => _AgeProfile.fromJson(e as Map<String, dynamic>))
        .toList();

    _loaded = true;
  }

  /// 사전 생성된 추천 캐시(`assets/data/recommendation_cache.json`)를 로드한다.
  /// 파일이 없거나 파싱 실패 시 조용히 무시 — 캐시 미스 시 일반 계산으로 fallback.
  Future<void> loadCache({AssetBundle? bundle}) async {
    if (_cacheLoaded) return;
    final assetBundle = bundle ?? rootBundle;
    try {
      final raw =
          await assetBundle.loadString('assets/data/recommendation_cache.json');
      final j = json.decode(raw) as Map<String, dynamic>;
      final entries = j['entries'] as Map<String, dynamic>? ?? const {};
      _cache = {
        for (final entry in entries.entries)
          entry.key: _CachedEntry.fromJson(entry.value as Map<String, dynamic>),
      };
      _cacheArchetypes =
          (j['archetypes'] as List<dynamic>? ?? const <dynamic>[])
              .map((e) =>
                  _CacheArchetype.fromJson(e as Map<String, dynamic>))
              .toList();
    } catch (_) {
      _cache = const {};
      _cacheArchetypes = const [];
    }
    _cacheLoaded = true;
  }

  // ────────────────────────────────────────────────────────────────────
  // 1. getRecommendations
  // ────────────────────────────────────────────────────────────────────

  /// 추천 정책 (2026-04 reset): "줄 수 있는 모든 것" → "지금 가장 중요한 2~3개".
  ///
  /// 노출(visible) 기준:
  ///   • must_take 중 priority ≤ 2
  ///   • highly_recommended 중 사용자가 답한 condition / 등록 증상에 직접
  ///     연결되는 항목 (max 2)
  ///   • 사용자 입력 condition flag 가 활성화돼 트리거된 boost
  /// 그 외 (priority 3+ must_take, 매칭 안 된 highly_recommended, synergy 확장) 은
  /// 모두 considerIf 로 보내서 화면 기본 collapsed 섹션에서만 노출.
  ///
  /// 노출 항목 수는 나이대별 hard cap 으로 더 줄인다 (infant 3 / child 4 /
  /// teen 5 / adult 6 / elderly 5). takingMedications=true 면 추가로 4 까지.
  List<RecommendationResult> getRecommendations(FamilyInput input) {
    _ensureLoaded();

    // 사전 캐시 체크. takingMedications=true 는 4-cap 분기가 들어가므로 캐시
    // 우회 (캐시는 takingMedications=false 가정). 불일치 가능성이 작은
    // 부분만 캐시로 처리하고 나머지는 정상 계산 경로로 보낸다.
    if (_cacheLoaded && input.takingMedications != true) {
      final key = _buildCacheKey(input);
      if (key != null) {
        final hit = _cache[key];
        if (kDebugMode) {
          // ignore: avoid_print
          print('[Cache] $key: ${hit != null ? "HIT" : "MISS"}');
        }
        if (hit != null) {
          return _markAlreadyTaking(
            _applyPersonalizedReasons(
              hit.toResults(_findSupplementByName),
              input,
            ),
            input.currentSupplements,
          );
        }
      } else if (kDebugMode) {
        // ignore: avoid_print
        print('[Cache] (no key — partial input or weak archetype match): MISS');
      }
    }

    final ageGroupKey = _ageGroupKey(input.age);
    final genderKey = input.sex?.storage;
    if (ageGroupKey == null || genderKey == null) return const [];

    final profile = _findAgeProfile(ageGroupKey, genderKey);
    if (profile == null) return const [];

    final avoidSet = <String>{
      for (final a in profile.avoidOrCaution)
        _normalize(_stripParenSuffix(a.supplement)),
    };

    /// 사용자가 명시적으로 입력한 condition / 등록한 증상으로부터 도출되는
    /// "직접 관련 영양제" 정규화 이름 집합. highly_recommended 매칭에 사용.
    final concernKeys = _concernSupplementKeys(input);

    final picked = <String, RecommendationResult>{};
    final order = <String>[];

    void add(
      String name, {
      required RecommendationCategory category,
      required String reason,
      required int priority,
      String? condition,
    }) {
      final key = _normalize(_stripParenSuffix(name));
      if (key.isEmpty) return;
      // must_take 만 avoid 무시. 나머지는 avoid 들어 있으면 스킵.
      if (category != RecommendationCategory.mustTake &&
          avoidSet.contains(key)) {
        return;
      }
      if (picked.containsKey(key)) return;
      final guide = _findSupplementByName(name);
      picked[key] = RecommendationResult(
        supplementName: name,
        supplementId: guide?.id,
        category: category,
        reason: reason,
        priority: priority,
        condition: condition,
      );
      order.add(key);
    }

    // 1) must_take — priority 1~2 만 visible, 3+ 는 considerIf 로 강등.
    for (final m in profile.mustTake) {
      final isCore = m.priority <= 2;
      add(
        m.supplement,
        category: isCore
            ? RecommendationCategory.mustTake
            : RecommendationCategory.considerIf,
        reason: m.reason,
        priority: m.priority,
      );
    }

    // 2) highly_recommended — 사용자 concern 과 매칭되는 항목만 visible (max 2).
    int matchedHighly = 0;
    for (final h in profile.highlyRecommended) {
      final key = _normalize(_stripParenSuffix(h.supplement));
      final matches = concernKeys.contains(key);
      RecommendationCategory cat;
      if (matches && matchedHighly < 2) {
        cat = RecommendationCategory.highlyRecommended;
        matchedHighly += 1;
      } else {
        cat = RecommendationCategory.considerIf;
      }
      add(
        h.supplement,
        category: cat,
        reason: h.reason,
        priority: 100,
      );
    }

    // 3) Condition boosts — 사용자가 직접 답한 신호 → visible (highlyRecommended).
    //    이 경로는 사용자 의도가 가장 명확하므로 항상 노출.
    void boost(String name, String reason) {
      add(
        name,
        category: RecommendationCategory.highlyRecommended,
        reason: reason,
        priority: 90,
        condition: reason,
      );
    }

    if (input.stress == StressLevel.high || input.sleep == SleepHours.lessSix) {
      boost('마그네슘', '스트레스가 높거나 수면이 부족할 때 도움이 될 수 있어요');
      boost('비타민B군', '스트레스가 높을 때 비타민B군 소모가 늘어요');
    }
    if (input.digestiveIssues == true) {
      boost('유산균(프로바이오틱스)', '소화 불편이 있을 때 장 환경 개선에 도움이 될 수 있어요');
    }
    if (input.pickyEating == true) {
      boost('종합비타민', '편식 보완으로 종합비타민을 권장하는 경우가 많아요');
    }
    if (input.feeding == FeedingType.formula ||
        input.feeding == FeedingType.solidFood) {
      boost('비타민D', '모유 외 수유·이유식 영아는 비타민D 보충을 권장하는 경우가 많아요');
    }
    if (input.smoker == true) {
      boost('비타민C', '흡연자는 비타민C 소모가 빨라 보충을 권장하는 경우가 많아요');
    }
    // 흡연량이 많을수록 항산화 부담이 커지니 NAC 추가 + 비타민C 우선순위 끌어올림.
    if (input.smokingAmount == SmokingAmount.heavy ||
        input.smokingAmount == SmokingAmount.veryHeavy) {
      boost('비타민C', '흡연량이 많을 때 비타민C 보충이 특히 중요해요');
      boost('NAC', '흡연량이 많을 때 항산화/호흡기 케어로 NAC를 권장하는 경우가 있어요');
    }
    // 음주 빈도별 boost.
    if (input.drinkingFrequency == DrinkingFrequency.weekly) {
      boost('밀크씨슬', '주 1-2회 음주 시 간 케어를 함께 권장하는 경우가 많아요');
    }
    if (input.drinkingFrequency == DrinkingFrequency.frequent) {
      boost('밀크씨슬', '잦은 음주 시 간 케어를 함께 권장하는 경우가 많아요');
      boost('비타민B군', '잦은 음주 시 B군 결핍이 흔해요');
      boost('비타민B1(티아민)', '잦은 음주 시 비타민B1 결핍이 흔해 보충을 권장하는 경우가 많아요');
    }

    // 영아 (0-1세) — 비타민D 필수 + DHA. allergies/feeding 신호와 별개로 always.
    if (input.ageGroup == AgeGroup.newborn) {
      boost('비타민D', '영아는 모유·분유만으로는 비타민D가 부족하기 쉬워 보충을 권장해요');
      boost('오메가3(DHA)', '두뇌·시각 발달 시기에 DHA 보충을 고려할 수 있어요');
    }

    // 유아 (2-6세) — 성장기 핵심 미네랄 3종. picky 여부와 무관하게 visible.
    if (input.ageGroup == AgeGroup.toddler) {
      boost('비타민D', '성장기 유아는 비타민D 보충을 권장하는 경우가 많아요');
      boost('칼슘', '뼈 성장기에 칼슘 섭취가 중요해요');
      boost('아연', '면역·성장 발달에 아연이 필요해요');
    }

    // 4) Symptom-driven boost — input.symptomIds 의 primary 영양제도 visible.
    final ids = input.symptomIds;
    if (ids != null) {
      for (final id in ids) {
        final sym = getSymptomById(id);
        if (sym == null || sym.isMedical) continue;
        for (final s in sym.relatedSupplements) {
          if (s.relevance != 'primary') continue;
          add(
            s.supplementName,
            category: RecommendationCategory.highlyRecommended,
            reason: s.safeExpression,
            priority: 80,
            condition: '${sym.symptom} 관련',
          );
        }
      }
    }

    // 5) Synergy 확장 — picked 안에 한 쪽이 있고 나머지가 없으면 considerIf 로만.
    final pickedKeys = picked.keys.toSet();
    for (final rule in _rules.where((r) => r.type == 'synergy')) {
      if (rule.supplements.length < 2) continue;
      final aKey = _normalize(_stripParenSuffix(rule.supplements[0]));
      final bKey = _normalize(_stripParenSuffix(rule.supplements[1]));
      if (pickedKeys.contains(aKey) && !pickedKeys.contains(bKey)) {
        add(
          rule.supplements[1],
          category: RecommendationCategory.considerIf,
          reason: rule.benefit ?? '함께 복용 시 시너지가 있어요',
          priority: 300,
        );
      } else if (pickedKeys.contains(bKey) && !pickedKeys.contains(aKey)) {
        add(
          rule.supplements[0],
          category: RecommendationCategory.considerIf,
          reason: rule.benefit ?? '함께 복용 시 시너지가 있어요',
          priority: 300,
        );
      }
    }

    // 6) 지역 보정 — RegionConfig.adjustment 기반으로 비타민D / 오메가3 / 철분 /
    //    항산화제 우선순위를 조정. 사용자 condition 보다 약한 신호이므로 마지막에.
    _applyRegionAdjustments(picked, order);

    // 정렬: visible(must_take → highly_recommended) 먼저, 그 안에서 priority 오름차순.
    final results = order.map((k) => picked[k]!).toList();
    results.sort((a, b) {
      final cat = _categoryRank(a.category).compareTo(
        _categoryRank(b.category),
      );
      if (cat != 0) return cat;
      return a.priority.compareTo(b.priority);
    });

    // 나이대별 hard cap. visible (must_take + highly_recommended) 만 카운트.
    final cap = _ageVisibleCap(input.age);
    final capped = <RecommendationResult>[];
    int visibleCount = 0;
    for (final r in results) {
      final isVisible = r.category != RecommendationCategory.considerIf;
      if (isVisible && visibleCount >= cap) {
        // 초과분은 considerIf 로 다운그레이드해서 collapsed 섹션에 보이게.
        capped.add(_demote(r));
      } else {
        capped.add(r);
        if (isVisible) visibleCount += 1;
      }
    }

    // takingMedications=true → visible 추가 캡 (4개) + 첫 항목에 안내 노트.
    if (input.takingMedications == true) {
      var seenVisible = 0;
      final clipped = <RecommendationResult>[];
      for (final r in capped) {
        final isVisible = r.category != RecommendationCategory.considerIf;
        if (isVisible) {
          if (seenVisible >= 4) {
            clipped.add(_demote(r));
            continue;
          }
          seenVisible += 1;
        }
        clipped.add(r);
      }
      const note = '복용 중인 약이 있어 추천을 4개 이내로 제한했어요. 반드시 의사/약사와 상담 후 복용하세요';
      for (var i = 0; i < clipped.length; i++) {
        if (clipped[i].category != RecommendationCategory.considerIf) {
          clipped[i] = clipped[i].withNotes([note]);
          break;
        }
      }
      return _markAlreadyTaking(
        _applyPersonalizedReasons(clipped, input),
        input.currentSupplements,
      );
    }

    return _markAlreadyTaking(
      _applyPersonalizedReasons(capped, input),
      input.currentSupplements,
    );
  }

  /// supplement_guide 의 `personalized_reasons` 맵에서 사용자 프로필과 가장
  /// 잘 맞는 키를 골라 reason 후보로 반환. 매칭 우선순위:
  /// smoker → heavy_drinker → elderly → child(=child/teen) → female_30s →
  /// vegetarian. 매칭 없거나 데이터 부재면 null.
  String? _resolvePersonalizedReason(
    SupplementGuide? guide,
    FamilyInput input,
  ) {
    if (guide == null) return null;
    final pr = guide.personalizedReasons;
    if (pr.isEmpty) return null;
    String? pick(String key) {
      final v = pr[key];
      if (v == null || v.trim().isEmpty) return null;
      return v;
    }

    if (input.smoker == true) {
      final v = pick('smoker');
      if (v != null) return v;
    }
    if (input.drinkingFrequency == DrinkingFrequency.frequent) {
      final v = pick('heavy_drinker');
      if (v != null) return v;
    }
    if (input.ageGroup == AgeGroup.elderly) {
      final v = pick('elderly');
      if (v != null) return v;
    }
    if (input.ageGroup == AgeGroup.child ||
        input.ageGroup == AgeGroup.teen) {
      final v = pick('child');
      if (v != null) return v;
    }
    final age = input.age;
    if (input.sex == Sex.female &&
        age != null &&
        age >= 30 &&
        age <= 39) {
      final v = pick('female_30s');
      if (v != null) return v;
    }
    if (input.diet == DietHabit.vegetarian) {
      final v = pick('vegetarian');
      if (v != null) return v;
    }
    return null;
  }

  /// 모든 추천 항목의 reason 을 우선순위 규칙으로 재계산:
  ///   1) personalized_reasons 매칭 → 덮어쓰기
  ///   2) 기존 reason 이 비어있지 않으면 그대로 유지
  ///   3) supplement_guide.main_benefits[0] 폴백
  ///   4) 그래도 없으면 빈 문자열
  List<RecommendationResult> _applyPersonalizedReasons(
    List<RecommendationResult> input,
    FamilyInput profile,
  ) {
    return [
      for (final r in input) _withResolvedReason(r, profile),
    ];
  }

  RecommendationResult _withResolvedReason(
    RecommendationResult r,
    FamilyInput profile,
  ) {
    final guide = _findSupplementByName(r.supplementName);
    final personalized = _resolvePersonalizedReason(guide, profile);
    String? next;
    if (personalized != null && personalized.trim().isNotEmpty) {
      next = personalized;
    } else if (r.reason.trim().isNotEmpty) {
      // 이미 의미 있는 reason 이 들어 있으면 (boost / condition / synergy) 유지.
      return r;
    } else if (guide != null && guide.mainBenefits.isNotEmpty) {
      next = guide.mainBenefits.first;
    }
    if (next == null) return r;
    return RecommendationResult(
      supplementName: r.supplementName,
      supplementId: r.supplementId,
      category: r.category,
      reason: next,
      priority: r.priority,
      condition: r.condition,
      notes: r.notes,
    );
  }

  /// `currentSupplements` 에 들어 있는 영양제는 추천 카테고리를
  /// `alreadyTaking` 으로 강등시켜 별도 섹션에서만 보이게 한다.
  List<RecommendationResult> _markAlreadyTaking(
    List<RecommendationResult> input,
    List<String>? currentSupplements,
  ) {
    if (currentSupplements == null || currentSupplements.isEmpty) {
      return input;
    }
    final keys = <String>{
      for (final n in currentSupplements) _normalize(_stripParenSuffix(n)),
    }..removeWhere((k) => k.isEmpty);
    if (keys.isEmpty) return input;
    return [
      for (final r in input)
        if (keys.contains(_normalize(_stripParenSuffix(r.supplementName))))
          RecommendationResult(
            supplementName: r.supplementName,
            supplementId: r.supplementId,
            category: RecommendationCategory.alreadyTaking,
            reason: r.reason,
            priority: r.priority,
            condition: r.condition,
            notes: r.notes,
          )
        else
          r,
    ];
  }

  RecommendationResult _demote(RecommendationResult r) {
    return RecommendationResult(
      supplementName: r.supplementName,
      supplementId: r.supplementId,
      category: RecommendationCategory.considerIf,
      reason: r.reason,
      priority: r.priority + 500, // 정렬 시 considerIf 안에서 뒤로 밀리도록.
      condition: r.condition,
      notes: r.notes,
    );
  }

  /// RegionConfig 기반 추천 후처리. KR 만 활성, 다른 region 값은 구조만 준비됨.
  /// - vitaminDPriority high  → 비타민D 를 must_take priority 1 로 승격
  /// - vitaminDPriority low   → 비타민D 강등 (considerIf)
  /// - omega3Priority   low   → 오메가3 강등 (considerIf)
  /// - ironCaution     true   → 철분 항목에 식단성 과다 주의 노트 추가
  /// - highSunlight    true   → 비타민D 강등 + 항산화제(C/E/아스타잔틴) 승격
  void _applyRegionAdjustments(
    Map<String, RecommendationResult> picked,
    List<String> order,
  ) {
    final adj = RegionConfig.adjustment;

    void promoteOrInsert(
      String name, {
      required RecommendationCategory category,
      required int priority,
      required String reason,
    }) {
      final key = _normalize(_stripParenSuffix(name));
      if (key.isEmpty) return;
      final existing = picked[key];
      if (existing == null) {
        final guide = _findSupplementByName(name);
        picked[key] = RecommendationResult(
          supplementName: name,
          supplementId: guide?.id,
          category: category,
          reason: reason,
          priority: priority,
        );
        order.add(key);
        return;
      }
      // 이미 더 높은 우선순위면 그대로 둔다.
      final shouldUpgrade = _categoryRank(category) <
              _categoryRank(existing.category) ||
          (category == existing.category && priority < existing.priority);
      if (!shouldUpgrade) return;
      picked[key] = RecommendationResult(
        supplementName: existing.supplementName,
        supplementId: existing.supplementId,
        category: category,
        reason: existing.reason,
        priority: priority,
        condition: existing.condition,
        notes: existing.notes,
      );
    }

    void demoteIfPresent(String name) {
      final key = _normalize(_stripParenSuffix(name));
      final existing = picked[key];
      if (existing == null) return;
      if (existing.category == RecommendationCategory.considerIf) return;
      picked[key] = _demote(existing);
    }

    void addNoteIfPresent(String name, String note) {
      final key = _normalize(_stripParenSuffix(name));
      final existing = picked[key];
      if (existing == null) return;
      picked[key] = existing.withNotes([note]);
    }

    // Vitamin D
    final demoteVitaminD =
        adj.vitaminDPriority == 'low' || adj.highSunlight;
    if (demoteVitaminD) {
      demoteIfPresent('비타민D');
    } else if (adj.vitaminDPriority == 'high') {
      promoteOrInsert(
        '비타민D',
        category: RecommendationCategory.mustTake,
        priority: 1,
        reason: '${adj.note} → 비타민D 보충을 우선 권장하는 경우가 많아요',
      );
    }

    // Omega-3
    if (adj.omega3Priority == 'low') {
      demoteIfPresent('오메가3');
    }

    // Iron caution note (recommendation 자체는 그대로 두고 안내만 추가)
    if (adj.ironCaution) {
      addNoteIfPresent(
        '철분',
        '${adj.note} → 철분 보충은 결핍 확인 후 결정하시는 게 안전해요',
      );
    }

    // High sunlight → 항산화제 승격
    if (adj.highSunlight) {
      const antioxidants = ['비타민C', '비타민E', '아스타잔틴'];
      for (final name in antioxidants) {
        promoteOrInsert(
          name,
          category: RecommendationCategory.highlyRecommended,
          priority: 50,
          reason: '${adj.note} → 일조량이 많을 때 항산화 보충을 권장하는 경우가 많아요',
        );
      }
    }
  }

  int _ageVisibleCap(int? age) {
    if (age == null) return 4;
    if (age <= 1) return 2; // newborn — 비타민D + 오메가3 정도만
    if (age <= 6) return 3; // toddler
    if (age <= 12) return 4; // child
    if (age <= 18) return 5; // teen
    if (age <= 59) return 6; // adult
    return 5; // elderly
  }

  /// FamilyInput → recommendation_cache.json 의 entry 키 (없으면 null).
  ///
  /// pre-adult 는 결정적 매핑(필수 필드 다 있을 때만), adult 는 가장 가까운
  /// archetype 을 점수로 골라 `{ageKey}_{sex}_{archetypeId}` 를 돌려준다.
  String? _buildCacheKey(FamilyInput input) {
    final age = input.age;
    final sex = input.sex?.storage;
    if (age == null || sex == null) return null;

    if (age <= 1) {
      final feeding = input.feeding?.storage;
      if (feeding == null) return null;
      return 'newborn_${sex}_$feeding';
    }
    if (age <= 6) {
      final picky = input.pickyEating;
      if (picky == null) return null;
      return 'toddler_${sex}_picky_${picky ? 'yes' : 'no'}';
    }
    if (age <= 12) {
      final picky = input.pickyEating;
      if (picky == null) return null;
      return 'child_${sex}_picky_${picky ? 'yes' : 'no'}';
    }
    if (age <= 18) {
      final stress = input.stress?.storage;
      if (stress == null) return null;
      return 'teen_${sex}_stress_$stress';
    }

    String ageKey;
    if (age <= 29) {
      ageKey = 'twenties';
    } else if (age <= 39) {
      ageKey = 'thirties';
    } else if (age <= 49) {
      ageKey = 'forties';
    } else if (age <= 59) {
      ageKey = 'fifties';
    } else {
      ageKey = 'elderly';
    }

    if (_cacheArchetypes.isEmpty) return null;
    final archetypeId = _bestArchetypeId(input);
    if (archetypeId == null) return null;
    return '${ageKey}_${sex}_$archetypeId';
  }

  int? _bestArchetypeId(FamilyInput input) {
    int bestScore = -1;
    int? bestId;
    for (final a in _cacheArchetypes) {
      int score = 0;
      if (a.smoker == (input.smoker == true)) score += 2;
      if (a.drinker == (input.drinker == true)) score += 2;
      if (input.diet != null && a.diet == input.diet!.storage) score += 2;
      final symptomIds = input.symptomIds;
      if (a.symptomId != null &&
          symptomIds != null &&
          symptomIds.contains(a.symptomId)) {
        score += 4;
      }
      if (score > bestScore) {
        bestScore = score;
        bestId = a.id;
      }
    }
    // 3점 미만이면 너무 약한 매칭이라 캐시 미스 처리.
    // (4점 → 3점으로 완화: 너무 엄격하면 cache miss 가 늘어 캐시 의의 약화)
    return bestScore >= 3 ? bestId : null;
  }

  /// 사용자가 직접 답하거나 등록한 신호로부터 "이 영양제는 사용자가 관심 가질
  /// 만하다"라고 매핑되는 한국어 영양제 이름 집합 (정규화된 키).
  Set<String> _concernSupplementKeys(FamilyInput input) {
    final names = <String>{};
    if (input.stress == StressLevel.high || input.sleep == SleepHours.lessSix) {
      names.addAll(['마그네슘', '비타민B군']);
    }
    if (input.digestiveIssues == true) {
      names.addAll(['유산균(프로바이오틱스)', '유산균', '프로바이오틱스']);
    }
    if (input.pickyEating == true) names.add('종합비타민');
    if (input.feeding == FeedingType.formula ||
        input.feeding == FeedingType.solidFood) {
      names.add('비타민D');
    }
    if (input.smoker == true) names.add('비타민C');
    if (input.smokingAmount == SmokingAmount.heavy ||
        input.smokingAmount == SmokingAmount.veryHeavy) {
      names.addAll(['비타민C', 'NAC']);
    }
    if (input.drinkingFrequency == DrinkingFrequency.weekly) {
      names.add('밀크씨슬');
    }
    if (input.drinkingFrequency == DrinkingFrequency.frequent) {
      names.addAll(['밀크씨슬', '비타민B군', '비타민B1(티아민)']);
    }
    if (input.ageGroup == AgeGroup.newborn) {
      names.addAll(['비타민D', '오메가3', 'DHA']);
    }
    if (input.ageGroup == AgeGroup.toddler) {
      names.addAll(['비타민D', '칼슘', '아연']);
    }
    final ids = input.symptomIds;
    if (ids != null) {
      for (final id in ids) {
        final sym = getSymptomById(id);
        if (sym == null) continue;
        for (final s in sym.relatedSupplements) {
          names.add(s.supplementName);
        }
      }
    }
    return {
      for (final n in names) _normalize(_stripParenSuffix(n)),
    };
  }

  int _categoryRank(RecommendationCategory c) {
    switch (c) {
      case RecommendationCategory.mustTake:
        return 0;
      case RecommendationCategory.highlyRecommended:
        return 1;
      case RecommendationCategory.considerIf:
        return 2;
      case RecommendationCategory.alreadyTaking:
        // 별도 섹션이라 visible 정렬에 영향 없도록 가장 뒤로.
        return 3;
    }
  }

  // ────────────────────────────────────────────────────────────────────
  // 2. getSchedule
  // ────────────────────────────────────────────────────────────────────

  ScheduleResult getSchedule(List<String> supplementNames) {
    _ensureLoaded();

    final morning = <String>[];
    final lunch = <String>[];
    final evening = <String>[];
    final beforeSleep = <String>[];

    final names = supplementNames.where((n) => n.trim().isNotEmpty).toList();

    for (final name in names) {
      final slot = _preferredSlot(name);
      switch (slot) {
        case ScheduleSlot.morning:
          morning.add(name);
          break;
        case ScheduleSlot.lunch:
          lunch.add(name);
          break;
        case ScheduleSlot.evening:
          evening.add(name);
          break;
        case ScheduleSlot.beforeSleep:
          beforeSleep.add(name);
          break;
      }
    }

    final conflicts = <ScheduleConflict>[];
    final synergies = <ScheduleSynergy>[];
    final selectedKeys = names.map(_normalize).toSet();

    for (final rule in _rules) {
      if (rule.supplements.length < 2) continue;
      final aRaw = rule.supplements[0];
      final bRaw = rule.supplements[1];
      final aKey = _normalize(_stripParenSuffix(aRaw));
      final bKey = _normalize(_stripParenSuffix(bRaw));
      // Both must be present in the user's list (fuzzy via prefix/contains).
      final aPresent = selectedKeys.any((k) => k.contains(aKey) || aKey.contains(k));
      final bPresent = selectedKeys.any((k) => k.contains(bKey) || bKey.contains(k));
      if (!(aPresent && bPresent)) continue;

      if (rule.type == 'separation_required' || rule.type == 'caution') {
        // Move B to evening if both currently share a slot, only when both were
        // picked — keeps the constraint visible to the user as a conflict too.
        _separateIfSameSlot(aKey, bKey, morning, lunch, evening, beforeSleep);
        conflicts.add(ScheduleConflict(
          supplementA: _resolveDisplayName(aRaw),
          supplementB: _resolveDisplayName(bRaw),
          type: rule.type,
          reason: rule.reason ?? '',
          solution: rule.solution ?? '복용 시간을 분리해 주세요',
        ));
      } else if (rule.type == 'synergy') {
        // Co-locate B with A's slot for an obvious "함께 드세요" hint.
        _alignToSameSlot(aKey, bKey, morning, lunch, evening, beforeSleep);
        synergies.add(ScheduleSynergy(
          supplementA: _resolveDisplayName(aRaw),
          supplementB: _resolveDisplayName(bRaw),
          benefit: rule.benefit ?? '함께 복용 시 시너지가 있어요',
          recommendation: rule.recommendation ?? '같은 시간에 함께 드세요',
        ));
      }
    }

    return ScheduleResult(
      morning: morning,
      lunch: lunch,
      evening: evening,
      beforeSleep: beforeSleep,
      conflicts: conflicts,
      synergies: synergies,
    );
  }

  ScheduleSlot _preferredSlot(String name) {
    final key = _normalize(_stripParenSuffix(name));

    bool inList(List<String> list) {
      for (final entry in list) {
        final ek = _normalize(_stripParenSuffix(entry));
        if (ek.isEmpty) continue;
        if (ek == key || ek.contains(key) || key.contains(ek)) return true;
      }
      return false;
    }

    if (inList(_timeSlots.beforeSleep)) return ScheduleSlot.beforeSleep;
    if (inList(_timeSlots.evening)) return ScheduleSlot.evening;
    if (inList(_timeSlots.lunch)) return ScheduleSlot.lunch;
    if (inList(_timeSlots.morning)) return ScheduleSlot.morning;

    // Fall back to the supplement guide's best_time hint, if any.
    final guide = _findSupplementByName(name);
    if (guide != null) {
      for (final t in guide.timing.bestTime) {
        switch (t) {
          case 'before_sleep':
            return ScheduleSlot.beforeSleep;
          case 'evening':
            return ScheduleSlot.evening;
          case 'lunch':
            return ScheduleSlot.lunch;
          case 'morning':
            return ScheduleSlot.morning;
        }
      }
    }
    return ScheduleSlot.morning;
  }

  void _separateIfSameSlot(
    String aKey,
    String bKey,
    List<String> morning,
    List<String> lunch,
    List<String> evening,
    List<String> beforeSleep,
  ) {
    for (final bucket in [morning, lunch, evening, beforeSleep]) {
      final aHere = bucket.any(
          (n) => _normalize(_stripParenSuffix(n)).contains(aKey));
      final bHere = bucket.any(
          (n) => _normalize(_stripParenSuffix(n)).contains(bKey));
      if (aHere && bHere) {
        // Move B out of the shared slot to evening (or morning if already evening).
        final destination = identical(bucket, evening) ? morning : evening;
        bucket.removeWhere((n) {
          final key = _normalize(_stripParenSuffix(n));
          if (key.contains(bKey)) {
            destination.add(n);
            return true;
          }
          return false;
        });
        return;
      }
    }
  }

  void _alignToSameSlot(
    String aKey,
    String bKey,
    List<String> morning,
    List<String> lunch,
    List<String> evening,
    List<String> beforeSleep,
  ) {
    final allBuckets = <List<String>>[morning, lunch, evening, beforeSleep];
    List<String>? bucketWithA;
    for (final b in allBuckets) {
      if (b.any((n) => _normalize(_stripParenSuffix(n)).contains(aKey))) {
        bucketWithA = b;
        break;
      }
    }
    if (bucketWithA == null) return;
    if (bucketWithA.any((n) => _normalize(_stripParenSuffix(n)).contains(bKey))) {
      return; // already aligned
    }
    String? bName;
    for (final b in allBuckets) {
      if (identical(b, bucketWithA)) continue;
      final removed = <String>[];
      b.removeWhere((n) {
        final key = _normalize(_stripParenSuffix(n));
        if (key.contains(bKey)) {
          removed.add(n);
          return true;
        }
        return false;
      });
      if (removed.isNotEmpty) {
        bName = removed.first;
        break;
      }
    }
    if (bName != null) bucketWithA.add(bName);
  }

  // ────────────────────────────────────────────────────────────────────
  // 3. checkConflicts
  // ────────────────────────────────────────────────────────────────────

  List<ConflictWarning> checkConflicts(
    List<String> supplementNames,
    List<String> medicationCategories,
  ) {
    _ensureLoaded();

    final warnings = <ConflictWarning>[];
    final names = supplementNames.where((n) => n.trim().isNotEmpty).toList();
    final guides = names
        .map((n) => MapEntry(n, _findSupplementByName(n)))
        .where((e) => e.value != null)
        .toList();

    // (a) Pairwise bad_combinations
    for (var i = 0; i < guides.length; i++) {
      final aName = guides[i].key;
      final aGuide = guides[i].value!;
      for (var j = 0; j < guides.length; j++) {
        if (i == j) continue;
        final bName = guides[j].key;
        final bGuide = guides[j].value!;
        for (final bad in aGuide.badCombinations) {
          if (_namesMatch(bad.supplement, bGuide.nameKorean) ||
              _namesMatch(bad.supplement, bGuide.nameEnglish)) {
            warnings.add(ConflictWarning(
              kind: ConflictKind.supplementSupplement,
              severity: conflictSeverityFromKo(bad.severity),
              supplementA: aName,
              supplementB: bName,
              message:
                  '$aName 와(과) $bName: ${bad.reason ?? '함께 복용 시 흡수율이 떨어질 수 있어요'}',
              recommendation: bad.solution ?? '복용 시간을 분리해 주세요',
            ));
          }
        }
      }
    }

    // (b) Drug interactions for the user's medication categories
    if (medicationCategories.isNotEmpty) {
      for (final entry in guides) {
        final supName = entry.key;
        final guide = entry.value!;
        for (final inter in guide.drugInteractions) {
          for (final med in medicationCategories) {
            if (_namesMatch(inter.drugCategory, med) ||
                _namesMatch(med, inter.drugCategory)) {
              warnings.add(ConflictWarning(
                kind: ConflictKind.supplementMedication,
                severity: conflictSeverityFromKo(inter.severity),
                supplementA: supName,
                medicationCategory: med,
                message: '$supName ↔ $med: ${inter.reason}',
                recommendation: inter.recommendation,
              ));
            }
          }
        }
      }
    }

    // (c) Overdose risk: if two or more selected supplements share a nutrient
    // that has an overdose warning entry, surface it once per nutrient.
    for (final ow in _overdoseWarnings) {
      final overlapHits = <String>[];
      for (final overlap in ow.commonOverlap) {
        for (final entry in guides) {
          if (_namesMatch(overlap, entry.key) ||
              _namesMatch(overlap, entry.value!.nameKorean) ||
              _namesMatch(overlap, entry.value!.nameEnglish)) {
            overlapHits.add(entry.key);
            break;
          }
        }
      }
      if (overlapHits.length >= 2) {
        warnings.add(ConflictWarning(
          kind: ConflictKind.overdoseRisk,
          severity: ConflictSeverity.caution,
          supplementA: overlapHits.first,
          supplementB: overlapHits[1],
          nutrient: ow.nutrient,
          message: '${ow.nutrient} 중복 가능성: ${ow.warningMessage}',
          recommendation: '제품 성분표를 확인해 ${ow.nutrient} 합산 용량을 점검해 주세요. ${ow.risk}',
        ));
      }
    }

    return warnings;
  }

  // ────────────────────────────────────────────────────────────────────
  // 4. getSupplementGuide
  // ────────────────────────────────────────────────────────────────────

  SupplementGuide? getSupplementGuide(String supplementName) {
    _ensureLoaded();
    return _findSupplementByName(supplementName);
  }

  // ────────────────────────────────────────────────────────────────────
  // 5. getSymptomsInfo
  // ────────────────────────────────────────────────────────────────────

  SymptomResult? getSymptomsInfo(String symptomQuery) {
    _ensureLoaded();
    final q = _normalize(symptomQuery);
    if (q.isEmpty) return null;

    SymptomResult? best;
    int bestScore = 0;
    for (final s in _symptoms) {
      int score = 0;
      final ns = _normalize(s.symptom);
      if (ns == q) {
        score = 100;
      } else if (ns.contains(q)) {
        score = 80;
      } else if (q.contains(ns)) {
        score = 70;
      }

      for (final kw in s.keywords) {
        final nk = _normalize(kw);
        if (nk == q) {
          score = score < 95 ? 95 : score;
        } else if (nk.contains(q) && q.length >= 2) {
          score = score < 75 ? 75 : score;
        } else if (q.contains(nk) && nk.length >= 2) {
          score = score < 65 ? 65 : score;
        }
      }
      if (score > bestScore) {
        bestScore = score;
        best = s;
      }
    }
    return bestScore > 0 ? best : null;
  }

  // ────────────────────────────────────────────────────────────────────
  // 6. getTopSymptoms
  // ────────────────────────────────────────────────────────────────────

  List<String> getTopSymptoms() {
    _ensureLoaded();
    return _symptoms
        .where((s) => s.type == SymptomType.typeA)
        .map((s) => s.symptom)
        .toList(growable: false);
  }

  // ────────────────────────────────────────────────────────────────────
  // Helpers
  // ────────────────────────────────────────────────────────────────────

  SupplementGuide? _findSupplementByName(String name) {
    final n = _normalize(_stripParenSuffix(name));
    if (n.isEmpty) return null;
    // Pass 1: exact match on normalized Korean/English/id.
    for (final s in _supplements) {
      if (_normalize(s.nameKorean) == n ||
          _normalize(s.nameEnglish) == n ||
          s.id == n) {
        return s;
      }
    }
    // Pass 2: contains (handles "오메가" → "오메가3", "vitamin d" → "Vitamin D").
    for (final s in _supplements) {
      final ko = _normalize(s.nameKorean);
      final en = _normalize(s.nameEnglish);
      if (ko.startsWith(n) || en.startsWith(n)) return s;
    }
    for (final s in _supplements) {
      final ko = _normalize(s.nameKorean);
      final en = _normalize(s.nameEnglish);
      if (ko.contains(n) || en.contains(n)) return s;
    }
    return null;
  }

  String _resolveDisplayName(String raw) {
    final guide = _findSupplementByName(raw);
    if (guide != null) return guide.nameKorean;
    return raw;
  }

  bool _namesMatch(String a, String b) {
    final na = _normalize(_stripParenSuffix(a));
    final nb = _normalize(_stripParenSuffix(b));
    if (na.isEmpty || nb.isEmpty) return false;
    if (na == nb) return true;
    if (na.length >= 2 && nb.contains(na)) return true;
    if (nb.length >= 2 && na.contains(nb)) return true;
    return false;
  }

  String _normalize(String s) {
    return s
        .toLowerCase()
        .replaceAll(RegExp(r'[\s\-_()/+,.]'), '')
        .trim();
  }

  String _stripParenSuffix(String s) {
    final idx = s.indexOf('(');
    return idx < 0 ? s.trim() : s.substring(0, idx).trim();
  }

  String? _ageGroupKey(int? age) {
    if (age == null) return null;
    if (age <= 6) return 'infant';
    if (age <= 12) return 'child';
    if (age <= 18) return 'teen';
    if (age <= 29) return 'twenties';
    if (age <= 39) return 'thirties';
    if (age <= 49) return 'forties';
    if (age <= 59) return 'fifties';
    return 'elderly';
  }

  _AgeProfile? _findAgeProfile(String ageGroup, String gender) {
    for (final p in _ageProfiles) {
      if (p.ageGroup == ageGroup && p.gender == gender) return p;
    }
    return null;
  }

  void _ensureLoaded() {
    if (!_loaded) {
      throw StateError(
          'SupplementRepository.load() must be called before use.');
    }
  }

  /// 증상 한 개를 id로 조회. 결과 카드에서 캐싱·정렬용.
  SymptomResult? getSymptomById(String symptomId) {
    _ensureLoaded();
    for (final s in _symptoms) {
      if (s.symptomId == symptomId) return s;
    }
    return null;
  }

  /// 영양제 가이드 한 개를 id (예: "s001") 로 조회. 가이드 화면 진입 시 쓰임.
  SupplementGuide? getSupplementById(String id) {
    _ensureLoaded();
    for (final s in _supplements) {
      if (s.id == id) return s;
    }
    // id가 안 맞으면 한국어/영문 이름으로도 시도해서 callers 가 둘 다 던져도 작동.
    return _findSupplementByName(id);
  }
}

/// 앱 전역에서 single-instance 로 쓰는 Repository. main()에서 미리 load 하지
/// 않아도 첫 watch 시 자동으로 비동기 로드 → 화면이 알아서 loading 처리.
///
/// load() 직후에 loadCache() 도 호출해서 사전 생성된 추천 캐시를 메모리에
/// 올린다. 캐시 파일이 없거나 손상돼도 loadCache() 가 silent fallback 처리
/// 하므로 첫 빌드/CI 환경에서도 깨지지 않는다.
final supplementRepositoryProvider =
    FutureProvider<SupplementRepository>((ref) async {
  final repo = SupplementRepository();
  await repo.load();
  await repo.loadCache();
  return repo;
});

// ──────────────────────────────────────────────────────────────────────
// Internal data classes (kept private — public API uses the model files).
// ──────────────────────────────────────────────────────────────────────

class _ComboRule {
  final String ruleId;
  final String type; // separation_required | synergy | caution
  final List<String> supplements;
  final num? minimumGapHours;
  final String? reason;
  final String? solution;
  final String? benefit;
  final String? recommendation;

  const _ComboRule({
    required this.ruleId,
    required this.type,
    required this.supplements,
    this.minimumGapHours,
    this.reason,
    this.solution,
    this.benefit,
    this.recommendation,
  });

  factory _ComboRule.fromJson(Map<String, dynamic> json) {
    return _ComboRule(
      ruleId: json['rule_id'] as String? ?? '',
      type: json['type'] as String? ?? '',
      supplements: (json['supplements'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      minimumGapHours: json['minimum_gap_hours'] as num?,
      reason: json['reason'] as String?,
      solution: json['solution'] as String?,
      benefit: json['benefit'] as String?,
      recommendation: json['recommendation'] as String?,
    );
  }
}

class _TimeSlots {
  final List<String> morning;
  final List<String> lunch;
  final List<String> evening;
  final List<String> beforeSleep;
  final List<String> emptyStomachOk;
  final List<String> mustTakeWithFood;

  const _TimeSlots({
    required this.morning,
    required this.lunch,
    required this.evening,
    required this.beforeSleep,
    required this.emptyStomachOk,
    required this.mustTakeWithFood,
  });

  factory _TimeSlots.fromJson(Map<String, dynamic> json) {
    List<String> list(String k) {
      final v = json[k];
      if (v is List) return v.map((e) => e.toString()).toList();
      return const [];
    }

    return _TimeSlots(
      morning: list('morning_preferred'),
      lunch: list('lunch_preferred'),
      evening: list('evening_preferred'),
      beforeSleep: list('before_sleep_preferred'),
      emptyStomachOk: list('empty_stomach_ok'),
      mustTakeWithFood: list('must_take_with_food'),
    );
  }
}

class _OverdoseWarning {
  final String nutrient;
  final String risk;
  final List<String> commonOverlap;
  final String warningMessage;

  const _OverdoseWarning({
    required this.nutrient,
    required this.risk,
    required this.commonOverlap,
    required this.warningMessage,
  });

  factory _OverdoseWarning.fromJson(Map<String, dynamic> json) {
    return _OverdoseWarning(
      nutrient: json['nutrient'] as String? ?? '',
      risk: json['risk'] as String? ?? '',
      commonOverlap: (json['common_overlap'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      warningMessage: json['warning_message'] as String? ?? '',
    );
  }
}

class _AgeProfileItem {
  final String supplement;
  final String reason;
  final int priority;
  final String? condition;
  final String? severity;

  const _AgeProfileItem({
    required this.supplement,
    required this.reason,
    required this.priority,
    this.condition,
    this.severity,
  });

  factory _AgeProfileItem.fromJson(Map<String, dynamic> json) {
    return _AgeProfileItem(
      supplement: json['supplement'] as String? ?? '',
      reason: json['reason'] as String? ?? '',
      priority: json['priority'] as int? ?? 99,
      condition: json['condition'] as String?,
      severity: json['severity'] as String?,
    );
  }
}

class _AgeProfile {
  final String ageGroup;
  final String gender;
  final String label;
  final List<_AgeProfileItem> mustTake;
  final List<_AgeProfileItem> highlyRecommended;
  final List<_AgeProfileItem> considerIf;
  final List<_AgeProfileItem> avoidOrCaution;
  final String specialNotes;

  const _AgeProfile({
    required this.ageGroup,
    required this.gender,
    required this.label,
    required this.mustTake,
    required this.highlyRecommended,
    required this.considerIf,
    required this.avoidOrCaution,
    required this.specialNotes,
  });

  factory _AgeProfile.fromJson(Map<String, dynamic> json) {
    List<_AgeProfileItem> list(String key) {
      return (json[key] as List<dynamic>? ?? const [])
          .map((e) => _AgeProfileItem.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return _AgeProfile(
      ageGroup: json['age_group'] as String? ?? '',
      gender: json['gender'] as String? ?? '',
      label: json['label'] as String? ?? '',
      mustTake: list('must_take'),
      highlyRecommended: list('highly_recommended'),
      considerIf: list('consider_if'),
      avoidOrCaution: list('avoid_or_caution'),
      specialNotes: json['special_notes'] as String? ?? '',
    );
  }
}

class _CachedEntry {
  final List<String> mustTake;
  final List<String> highlyRecommended;
  final List<String> consider;

  const _CachedEntry({
    required this.mustTake,
    required this.highlyRecommended,
    required this.consider,
  });

  factory _CachedEntry.fromJson(Map<String, dynamic> json) {
    List<String> list(String key) =>
        (json[key] as List<dynamic>? ?? const [])
            .map((e) => e.toString())
            .toList();
    return _CachedEntry(
      mustTake: list('must_take'),
      highlyRecommended: list('highly_recommended'),
      consider: list('consider'),
    );
  }

  /// 캐시는 영양제 이름만 저장하므로 reason 은 supplement_guide 의
  /// `main_benefits` 첫 항목으로 채운다. 데이터가 비어 있으면 빈 문자열.
  /// 화면 단(home/detail) 에서 빈 reason 은 노출하지 않도록 가드.
  List<RecommendationResult> toResults(
    SupplementGuide? Function(String) lookup,
  ) {
    final out = <RecommendationResult>[];
    void add(String name, RecommendationCategory cat, int priority) {
      final guide = lookup(name);
      final reason = (guide != null && guide.mainBenefits.isNotEmpty)
          ? guide.mainBenefits.first
          : '';
      out.add(RecommendationResult(
        supplementName: name,
        supplementId: guide?.id,
        category: cat,
        reason: reason,
        priority: priority,
      ));
    }

    var p = 1;
    for (final n in mustTake) {
      add(n, RecommendationCategory.mustTake, p++);
    }
    p = 100;
    for (final n in highlyRecommended) {
      add(n, RecommendationCategory.highlyRecommended, p++);
    }
    p = 300;
    for (final n in consider) {
      add(n, RecommendationCategory.considerIf, p++);
    }
    return out;
  }
}

class _CacheArchetype {
  final int id;
  final bool smoker;
  final bool drinker;
  final String diet; // matches DietHabit.storage
  final String? symptomId;

  const _CacheArchetype({
    required this.id,
    required this.smoker,
    required this.drinker,
    required this.diet,
    this.symptomId,
  });

  factory _CacheArchetype.fromJson(Map<String, dynamic> json) {
    return _CacheArchetype(
      id: json['id'] as int,
      smoker: json['smoker'] as bool? ?? false,
      drinker: json['drinker'] as bool? ?? false,
      diet: json['diet'] as String? ?? 'balanced',
      symptomId: json['symptom_id'] as String?,
    );
  }
}

