import '../../../core/data/models/conflict_warning.dart';
import '../../../core/data/models/recommendation_result.dart';
import '../../../core/data/models/schedule_result.dart';
import '../../../core/data/nutrient_targets.dart';
import '../../../core/data/product_repository.dart';
import '../../../core/data/supplement_repository.dart';
import 'family_input.dart';
import 'recommendation_output.dart';

// 화면 코드는 결과 타입을 여기서 re-export 받는다 — 모델 파일 경로를 직접
// 외울 필요가 없도록.
export '../../../core/data/models/recommendation_result.dart'
    show RecommendationResult, RecommendationCategory;
export '../../../core/data/models/schedule_result.dart'
    show ScheduleResult, ScheduleSlot, ScheduleConflict, ScheduleSynergy, scheduleSlotKo;
export '../../../core/data/models/conflict_warning.dart'
    show ConflictWarning, ConflictKind, ConflictSeverity, conflictSeverityKo;
export 'recommendation_output.dart';

/// 얇은 facade — base 추천은 [SupplementRepository] 가 만들고, 엔진은 그 위에
/// 검진 결과 (LDL/혈당/헤모글로빈/간수치/비타민D/혈압) 와 아이 신호 (변/성장/식사)
/// 를 붙여 후처리한다.
///
/// 검진/아이 로직은 base 추천 결과를 직접 변형하기 때문에 base 엔진을 건드리지
/// 않고도 새 신호를 점진적으로 늘릴 수 있다.
class RecommendationEngine {
  RecommendationEngine({required this.repository, this.productRepository});

  final SupplementRepository repository;

  /// 현재 섭취량 계산을 위한 ProductRepository. null 이면 차감/영양 상태 스텝
  /// 은 건너뛰고 결과 그대로 반환 (기존 호출 호환).
  final ProductRepository? productRepository;

  List<RecommendationResult> recommend(FamilyInput input) {
    final base = repository.getRecommendations(input);
    final withCheckup = _applyCheckup(base, input);
    final withChild = _applyChildLogic(withCheckup, input);
    final withSpecial = _applySpecialCondition(withChild, input);
    final withIntake = _applyCurrentIntake(withSpecial, input);
    return withIntake;
  }

  /// 12-step 파이프라인의 풀 출력 (results + currentIntake + profile + cap).
  ///
  /// 단계:
  ///   1) Profile 매칭 (repository 가 처리)
  ///   2) 검진 결과 보정
  ///   3) 라이프스타일 부스트 (repository 가 처리)
  ///   4) 어린이 포커스
  ///   5) 증상 부스트 (repository 가 처리)
  ///   6) 임신/수유 규칙
  ///   7) 지역 보정 (repository 가 처리)
  ///   8) 현재 섭취량 차감 → alreadyTaking 강등
  ///   9) 영양소 상태 산출 (적정/부족/과다)
  ///  10) 개인화 사유 (repository 가 처리)
  ///  11) 나이대 cap (repository 가 처리)
  ///  12) 최종 정렬 (repository 가 처리)
  RecommendationOutput recommendWithOutput(FamilyInput input) {
    final base = repository.getRecommendations(input);
    final withCheckup = _applyCheckup(base, input);
    final withChild = _applyChildLogic(withCheckup, input);
    final withSpecial = _applySpecialCondition(withChild, input);
    final withIntake = _applyCurrentIntake(withSpecial, input);

    final intake = _calculateCurrentIntake(input);
    final profile = _profileKey(input);
    final cap = _capForOutput(input);

    return RecommendationOutput(
      results: withIntake,
      currentIntake: intake,
      profileMatched: profile,
      capsApplied: cap,
      fromCache: repository.isCacheLoaded && input.takingMedications != true,
    );
  }

  ScheduleResult schedule(List<String> supplementNames) =>
      repository.getSchedule(supplementNames);

  List<ConflictWarning> conflicts(
    List<String> supplementNames, {
    List<String> medicationCategories = const [],
  }) =>
      repository.checkConflicts(supplementNames, medicationCategories);

  // ──────────────────────────────────────────────────────────────────────
  // 검진 결과 기반 후처리
  // ──────────────────────────────────────────────────────────────────────

  List<RecommendationResult> _applyCheckup(
    List<RecommendationResult> base,
    FamilyInput input,
  ) {
    final c = input.lastCheckup;
    if (c == null) return base;

    final out = List<RecommendationResult>.from(base);

    void boostOrAdd(
      String name, {
      required RecommendationCategory category,
      required int priority,
      required String reason,
    }) {
      final idx = _indexOfSupplement(out, name);
      if (idx >= 0) {
        final existing = out[idx];
        // 우선순위가 더 높아질 때만 승격.
        final upgrade = _categoryRank(category) <
                _categoryRank(existing.category) ||
            (category == existing.category && priority < existing.priority);
        if (upgrade) {
          out[idx] = RecommendationResult(
            supplementName: existing.supplementName,
            supplementId: existing.supplementId,
            category: category,
            reason: existing.reason.isEmpty ? reason : existing.reason,
            priority: priority,
            condition: existing.condition ?? '검진 결과',
            notes: [...existing.notes, '검진 결과 기반'],
          );
        } else {
          out[idx] = existing.withNotes(['검진 결과 기반']);
        }
        return;
      }
      out.add(RecommendationResult(
        supplementName: name,
        category: category,
        reason: reason,
        priority: priority,
        condition: '검진 결과',
        notes: const ['검진 결과 기반'],
      ));
    }

    final isFemale = input.sex == Sex.female;

    if ((c.cholesterolLdl ?? 0) > 130) {
      boostOrAdd('오메가3',
          category: RecommendationCategory.highlyRecommended,
          priority: 70,
          reason: 'LDL이 130 mg/dL을 넘어 혈행 케어로 오메가3를 권장하는 경우가 많아요');
      boostOrAdd('홍국',
          category: RecommendationCategory.considerIf,
          priority: 200,
          reason: 'LDL이 높을 때 홍국을 함께 고려하는 경우가 있어요');
    }
    if ((c.bloodSugar ?? 0) > 100) {
      boostOrAdd('마그네슘',
          category: RecommendationCategory.highlyRecommended,
          priority: 70,
          reason: '공복혈당이 100 mg/dL을 넘어 인슐린 감수성 보조로 마그네슘을 권장하는 경우가 많아요');
      boostOrAdd('크롬',
          category: RecommendationCategory.considerIf,
          priority: 200,
          reason: '공복혈당이 높을 때 크롬을 함께 고려하는 경우가 있어요');
    }
    final hb = c.hemoglobin;
    if (hb != null) {
      final low = isFemale ? hb < 12 : hb < 13;
      if (low) {
        boostOrAdd('철분',
            category: RecommendationCategory.mustTake,
            priority: 1,
            reason: '헤모글로빈 수치가 낮아 철분 보충이 필요해 보여요');
      }
    }
    if ((c.alt ?? 0) > 40 || (c.ast ?? 0) > 40) {
      boostOrAdd('밀크씨슬',
          category: RecommendationCategory.highlyRecommended,
          priority: 60,
          reason: '간수치가 정상 범위를 넘어 간 케어로 밀크씨슬을 권장하는 경우가 많아요');
      boostOrAdd('NAC',
          category: RecommendationCategory.considerIf,
          priority: 200,
          reason: '간수치가 높을 때 NAC 항산화 보조를 고려하는 경우가 있어요');
    }
    final vd = c.vitaminD;
    if (vd != null && vd < 30) {
      boostOrAdd('비타민D',
          category: RecommendationCategory.mustTake,
          priority: 1,
          reason: '검진 비타민D가 30 ng/mL 미만으로 보충을 우선 권장해요');
    }
    if ((c.bloodPressureSystolic ?? 0) > 140) {
      boostOrAdd('오메가3',
          category: RecommendationCategory.highlyRecommended,
          priority: 60,
          reason: '수축기 혈압이 140 mmHg을 넘어 혈행 케어로 오메가3를 권장하는 경우가 많아요');
      boostOrAdd('코엔자임Q10',
          category: RecommendationCategory.considerIf,
          priority: 200,
          reason: '혈압이 높을 때 CoQ10을 함께 고려하는 경우가 있어요');
    }

    return _resort(out);
  }

  // ──────────────────────────────────────────────────────────────────────
  // 아이 (newborn / toddler / child / teen) 단순화
  //   - 핵심 3종 중심 (유산균 / 철분 / 비타민D), 나이대별 우선순위
  //   - 변/성장/식사/알레르기 신호로 부스트
  //   - visible 항목 cap 3 (영아 2 / 청소년 4)
  // ──────────────────────────────────────────────────────────────────────

  List<RecommendationResult> _applyChildLogic(
    List<RecommendationResult> base,
    FamilyInput input,
  ) {
    final group = input.ageGroup;
    if (group == null) return base;
    if (group != AgeGroup.newborn &&
        group != AgeGroup.toddler &&
        group != AgeGroup.child &&
        group != AgeGroup.teen) {
      return base;
    }

    final out = List<RecommendationResult>.from(base);

    void ensure(
      String name, {
      required RecommendationCategory category,
      required int priority,
      required String reason,
    }) {
      final idx = _indexOfSupplement(out, name);
      if (idx >= 0) {
        final existing = out[idx];
        final upgrade = _categoryRank(category) <
                _categoryRank(existing.category) ||
            (category == existing.category && priority < existing.priority);
        if (upgrade) {
          out[idx] = RecommendationResult(
            supplementName: existing.supplementName,
            supplementId: existing.supplementId,
            category: category,
            reason: existing.reason.isEmpty ? reason : existing.reason,
            priority: priority,
            condition: existing.condition,
            notes: existing.notes,
          );
        }
      } else {
        out.add(RecommendationResult(
          supplementName: name,
          category: category,
          reason: reason,
          priority: priority,
        ));
      }
    }

    // 1) 핵심 3 (나이대별) — 영아 흐름의 비타민D는 base 가 이미 must_take 로
    //    넣어줬을 가능성이 큼 (newborn boost). 여기서는 idempotent 하게 ensure.
    switch (group) {
      case AgeGroup.newborn:
        ensure('비타민D',
            category: RecommendationCategory.mustTake,
            priority: 1,
            reason: '영아는 비타민D 보충을 권장하는 경우가 많아요');
        break;
      case AgeGroup.toddler:
        ensure('유산균(프로바이오틱스)',
            category: RecommendationCategory.mustTake,
            priority: 2,
            reason: '유아 장 건강을 위해 유산균을 권장하는 경우가 많아요');
        ensure('비타민D',
            category: RecommendationCategory.mustTake,
            priority: 1,
            reason: '성장기 유아는 비타민D 보충을 권장해요');
        if (input.pickyEating == true) {
          ensure('철분',
              category: RecommendationCategory.mustTake,
              priority: 2,
              reason: '편식이 있을 때 철분 결핍 방지로 권장하는 경우가 많아요');
        }
        break;
      case AgeGroup.child:
        ensure('유산균(프로바이오틱스)',
            category: RecommendationCategory.mustTake,
            priority: 2,
            reason: '장 건강과 면역에 유산균을 권장해요');
        ensure('철분',
            category: RecommendationCategory.mustTake,
            priority: 1,
            reason: '성장기에 철분이 필요해요');
        ensure('비타민D',
            category: RecommendationCategory.mustTake,
            priority: 1,
            reason: '뼈 성장과 면역에 비타민D가 필요해요');
        break;
      case AgeGroup.teen:
        ensure('철분',
            category: RecommendationCategory.mustTake,
            priority: 1,
            reason: '청소년기 성장과 빈혈 예방에 철분이 필요해요');
        ensure('비타민D',
            category: RecommendationCategory.mustTake,
            priority: 1,
            reason: '뼈 형성기에 비타민D가 필요해요');
        if (input.digestiveIssues == true) {
          ensure('유산균(프로바이오틱스)',
              category: RecommendationCategory.highlyRecommended,
              priority: 60,
              reason: '소화 불편이 있을 때 유산균을 권장하는 경우가 많아요');
        }
        break;
      default:
        break;
    }

    // 2) 신호별 부스트
    if (input.stoolFrequency == StoolFrequency.weekly ||
        input.stoolFrequency == StoolFrequency.less ||
        input.stoolForm == StoolForm.hard) {
      ensure('유산균(프로바이오틱스)',
          category: RecommendationCategory.mustTake,
          priority: 1,
          reason: '변비 경향이 있을 때 유산균을 우선 권장해요');
      ensure('식이섬유',
          category: RecommendationCategory.considerIf,
          priority: 200,
          reason: '변비 경향이 있을 때 식이섬유를 함께 고려하는 경우가 많아요');
    }
    if (input.stoolForm == StoolForm.soft ||
        input.stoolForm == StoolForm.watery) {
      ensure('유산균(프로바이오틱스)',
          category: RecommendationCategory.mustTake,
          priority: 1,
          reason: '변이 무를 때 장 환경 정돈에 유산균을 권장해요');
    }

    // 3) 키 percentile 기반
    if (group != AgeGroup.newborn) {
      // 동적 import 회피 — growth_chart 가 percentile band 0=below p10 반환.
      // recommendation engine 자체는 dart:io 미의존이라 문제 없음.
      final age = input.age;
      final h = input.heightCm;
      if (age != null && h != null) {
        final band = _percentileBand(age, input.sex, h);
        if (band == 0) {
          ensure('칼슘',
              category: RecommendationCategory.highlyRecommended,
              priority: 50,
              reason: '또래 대비 작은 편일 때 칼슘 보충을 함께 고려해요');
          ensure('비타민D',
              category: RecommendationCategory.mustTake,
              priority: 1,
              reason: '뼈 성장 보조로 비타민D를 우선 권장해요');
        }
      }
    }

    if (input.eatsVegetables == false) {
      ensure('종합비타민',
          category: RecommendationCategory.highlyRecommended,
          priority: 60,
          reason: '채소를 잘 안 먹을 때 종합비타민을 권장하는 경우가 많아요');
    }
    if (input.eatsFish == false) {
      ensure('오메가3(DHA)',
          category: RecommendationCategory.considerIf,
          priority: 200,
          reason: '생선을 잘 안 먹을 때 DHA 보충을 고려하는 경우가 있어요');
    }
    final allergy = input.allergyItems ?? const [];
    if (allergy.contains('우유')) {
      ensure('칼슘',
          category: RecommendationCategory.highlyRecommended,
          priority: 55,
          reason: '우유 알레르기로 칼슘 보충을 권장하는 경우가 많아요');
    }

    // 4) child cap — visible 카테고리 (must_take + highly_recommended) 만 카운트.
    final cap = switch (group) {
      AgeGroup.newborn => 2,
      AgeGroup.toddler => 3,
      AgeGroup.child => 3,
      AgeGroup.teen => 4,
      _ => 4,
    };

    final sorted = _resort(out);
    final capped = <RecommendationResult>[];
    int visibleCount = 0;
    for (final r in sorted) {
      final isVisible = r.category != RecommendationCategory.considerIf &&
          r.category != RecommendationCategory.alreadyTaking;
      if (isVisible && visibleCount >= cap) {
        capped.add(RecommendationResult(
          supplementName: r.supplementName,
          supplementId: r.supplementId,
          category: RecommendationCategory.considerIf,
          reason: r.reason,
          priority: r.priority + 500,
          condition: r.condition,
          notes: r.notes,
        ));
      } else {
        capped.add(r);
        if (isVisible) visibleCount += 1;
      }
    }
    return capped;
  }

  // ──────────────────────────────────────────────────────────────────────
  // 임신/수유 규칙 (Step 6)
  //   - pregnant: 엽산/철분/DHA must_take, 비타민A/허브류 considerIf 강등 + 경고
  //   - breastfeeding: DHA/칼슘/비타민D must_take
  // ──────────────────────────────────────────────────────────────────────

  List<RecommendationResult> _applySpecialCondition(
    List<RecommendationResult> base,
    FamilyInput input,
  ) {
    if (input.specialCondition == SpecialCondition.none) return base;
    final out = List<RecommendationResult>.from(base);

    void ensure(
      String name, {
      required RecommendationCategory category,
      required int priority,
      required String reason,
    }) {
      final idx = _indexOfSupplement(out, name);
      if (idx >= 0) {
        final existing = out[idx];
        final upgrade =
            _categoryRank(category) < _categoryRank(existing.category) ||
                (category == existing.category &&
                    priority < existing.priority);
        if (upgrade) {
          out[idx] = RecommendationResult(
            supplementName: existing.supplementName,
            supplementId: existing.supplementId,
            category: category,
            reason: existing.reason.isEmpty ? reason : existing.reason,
            priority: priority,
            condition: existing.condition ?? '임신/수유',
            notes: existing.notes,
          );
        }
      } else {
        out.add(RecommendationResult(
          supplementName: name,
          category: category,
          reason: reason,
          priority: priority,
          condition: '임신/수유',
        ));
      }
    }

    void cautionIfPresent(String name, String warning) {
      final idx = _indexOfSupplement(out, name);
      if (idx < 0) return;
      final existing = out[idx];
      out[idx] = RecommendationResult(
        supplementName: existing.supplementName,
        supplementId: existing.supplementId,
        category: RecommendationCategory.considerIf,
        reason: existing.reason,
        priority: existing.priority + 500,
        condition: existing.condition,
        notes: [...existing.notes, warning],
        note: warning,
      );
    }

    if (input.specialCondition == SpecialCondition.pregnant) {
      ensure('엽산',
          category: RecommendationCategory.mustTake,
          priority: 1,
          reason: '임신 중 신경관 결손 예방을 위해 엽산을 우선 권장해요');
      ensure('철분',
          category: RecommendationCategory.mustTake,
          priority: 1,
          reason: '임신 중 빈혈 예방을 위해 철분이 필요해요');
      ensure('오메가3(DHA)',
          category: RecommendationCategory.mustTake,
          priority: 2,
          reason: '태아 두뇌·시각 발달에 DHA가 도움이 될 수 있어요');
      ensure('비타민D',
          category: RecommendationCategory.highlyRecommended,
          priority: 50,
          reason: '임신 중 비타민D 보충을 권장하는 경우가 많아요');
      cautionIfPresent('비타민A',
          '임신 중 고용량 비타민A는 기형 위험이 있어 주의가 필요해요');
      cautionIfPresent('홍국',
          '임신 중 홍국은 안전성 자료가 부족해 권장하지 않아요');
    } else if (input.specialCondition == SpecialCondition.breastfeeding) {
      ensure('오메가3(DHA)',
          category: RecommendationCategory.mustTake,
          priority: 1,
          reason: '수유 중 DHA는 모유로 전달되어 아기 발달에 도움이 될 수 있어요');
      ensure('칼슘',
          category: RecommendationCategory.mustTake,
          priority: 2,
          reason: '수유 중 칼슘 손실이 늘어 보충을 권장해요');
      ensure('비타민D',
          category: RecommendationCategory.mustTake,
          priority: 1,
          reason: '수유 중 비타민D 보충을 권장하는 경우가 많아요');
      ensure('철분',
          category: RecommendationCategory.highlyRecommended,
          priority: 50,
          reason: '수유 중 철분 보충을 권장하는 경우가 많아요');
    }

    return _resort(out);
  }

  // ──────────────────────────────────────────────────────────────────────
  // 현재 섭취량 차감 + 영양소 상태 산출 (Step 8 + 9)
  // ──────────────────────────────────────────────────────────────────────

  /// products.json + nutrient_targets 로 1일 권장량 대비 사용자 섭취 비율을
  /// 계산해 각 추천 항목에 [NutrientStatus] 와 note 를 채운다.
  /// 섭취율이 80% 이상이면 alreadyTaking 으로 강등.
  List<RecommendationResult> _applyCurrentIntake(
    List<RecommendationResult> base,
    FamilyInput input,
  ) {
    final repo = productRepository;
    if (repo == null) return base;
    final ids = input.currentProductIds;
    if (ids == null || ids.isEmpty) return base;

    final intake = <String, double>{};
    final productNames = <String, String>{};
    for (final id in ids) {
      final p = repo.getById(id);
      if (p == null) continue;
      productNames[id] = p.name;
      for (final e in p.dailyIngredients.entries) {
        intake[e.key] = (intake[e.key] ?? 0) + e.value;
      }
    }
    if (intake.isEmpty) return base;

    final firstProductName =
        productNames.values.isNotEmpty ? productNames.values.first : null;

    final out = <RecommendationResult>[];
    for (final r in base) {
      final targets = targetsForSupplements([r.supplementName]);
      if (targets.isEmpty) {
        out.add(r);
        continue;
      }

      // 가장 비중 큰 영양소 키 (권장량 대비 현재섭취율 가장 높은 것) 1개로 status 결정.
      String? bestKey;
      double bestRatio = 0;
      double? bestTarget;
      double? bestCurrent;
      String? bestUnit;
      for (final e in targets.entries) {
        final cur = intake[e.key] ?? 0;
        if (e.value <= 0) continue;
        final ratio = cur / e.value;
        if (ratio >= bestRatio) {
          bestRatio = ratio;
          bestKey = e.key;
          bestTarget = e.value;
          bestCurrent = cur;
          bestUnit = _unitFromKey(e.key);
        }
      }
      if (bestKey == null || bestTarget == null) {
        out.add(r);
        continue;
      }

      NutrientStatus status;
      String? noteText;
      RecommendationCategory nextCategory = r.category;
      int nextPriority = r.priority;

      if (bestRatio >= 1.2) {
        status = NutrientStatus.excess;
        noteText = '이미 충분해요. 추가 복용 시 주의하세요';
      } else if (bestRatio >= 0.8) {
        status = NutrientStatus.appropriate;
        if (firstProductName != null) {
          noteText = '이미 $firstProductName에 포함되어 있어요';
        } else {
          noteText = '이미 충분히 섭취 중이에요';
        }
        if (r.category != RecommendationCategory.alreadyTaking) {
          nextCategory = RecommendationCategory.alreadyTaking;
          nextPriority = r.priority + 500;
        }
      } else if (bestCurrent != null && bestCurrent > 0) {
        status = NutrientStatus.insufficient;
      } else {
        status = NutrientStatus.notCalculated;
      }

      out.add(r.copyWith(
        category: nextCategory,
        priority: nextPriority,
        note: noteText,
        nutrientStatus: status,
        targetDosage: bestTarget,
        currentDosage: bestCurrent ?? 0,
        unit: bestUnit,
      ));
    }
    return _resort(out);
  }

  Map<String, double> _calculateCurrentIntake(FamilyInput input) {
    final repo = productRepository;
    if (repo == null) return const {};
    final ids = input.currentProductIds;
    if (ids == null || ids.isEmpty) return const {};
    final out = <String, double>{};
    for (final id in ids) {
      final p = repo.getById(id);
      if (p == null) continue;
      for (final e in p.dailyIngredients.entries) {
        out[e.key] = (out[e.key] ?? 0) + e.value;
      }
    }
    return out;
  }

  String? _profileKey(FamilyInput input) {
    final age = input.age;
    final sex = input.sex;
    if (age == null || sex == null) return null;
    final group = AgeGroupX.fromAge(age);
    return '${group.name}_${sex.storage}';
  }

  int _capForOutput(FamilyInput input) {
    final age = input.age;
    if (age == null) return 4;
    int cap;
    if (age <= 1) {
      cap = 2;
    } else if (age <= 6) {
      cap = 3;
    } else if (age <= 12) {
      cap = 4;
    } else if (age <= 18) {
      cap = 5;
    } else if (age <= 59) {
      cap = 6;
    } else {
      cap = 5;
    }
    if (input.takingMedications == true && cap > 4) cap = 4;
    return cap;
  }

  /// nutrient_targets 의 키 suffix → 단위 라벨.
  String? _unitFromKey(String key) {
    if (key.endsWith('_mg')) return 'mg';
    if (key.endsWith('_mcg')) return 'mcg';
    if (key.endsWith('_iu')) return 'IU';
    if (key.endsWith('_billion')) return '억 CFU';
    return null;
  }

  // ──────────────────────────────────────────────────────────────────────
  // helpers
  // ──────────────────────────────────────────────────────────────────────

  int _indexOfSupplement(List<RecommendationResult> list, String name) {
    final n = _normalize(name);
    for (var i = 0; i < list.length; i++) {
      if (_normalize(list[i].supplementName) == n) return i;
      // 괄호 접미사 매칭 ("유산균" ↔ "유산균(프로바이오틱스)").
      final stripped = _stripParen(list[i].supplementName);
      if (_normalize(stripped) == n) return i;
      if (_normalize(_stripParen(name)) == _normalize(stripped)) return i;
    }
    return -1;
  }

  String _stripParen(String s) {
    final idx = s.indexOf('(');
    return idx < 0 ? s : s.substring(0, idx);
  }

  String _normalize(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[\s\-_()/+,.]'), '').trim();

  int _categoryRank(RecommendationCategory c) {
    switch (c) {
      case RecommendationCategory.mustTake:
        return 0;
      case RecommendationCategory.highlyRecommended:
        return 1;
      case RecommendationCategory.considerIf:
        return 2;
      case RecommendationCategory.alreadyTaking:
        return 3;
    }
  }

  List<RecommendationResult> _resort(List<RecommendationResult> list) {
    final out = List<RecommendationResult>.from(list);
    out.sort((a, b) {
      final cat = _categoryRank(a.category).compareTo(
        _categoryRank(b.category),
      );
      if (cat != 0) return cat;
      return a.priority.compareTo(b.priority);
    });
    return out;
  }

  /// 키 percentile 4구간 분류. growth_chart 와 동일 결과를 자체 매핑으로 구현.
  /// 외부 의존 회피용.
  int? _percentileBand(int age, Sex? sex, double h) {
    final list = sex == Sex.male ? _maleP : _femaleP;
    if (age < 0 || age > 18) return null;
    final band = list[age.clamp(0, 18)];
    if (h < band.$1) return 0;
    if (h < band.$2) return 1;
    if (h < band.$3) return 2;
    return 3;
  }

  /// (p10, p50, p90) — 0~18세, growth_chart.dart 와 동일.
  static const _maleP = <(double, double, double)>[
    (49.0, 49.9, 51.0),
    (73.0, 76.1, 79.0),
    (84.0, 87.1, 90.0),
    (91.0, 95.7, 100.0),
    (98.5, 103.4, 108.0),
    (105.0, 109.9, 115.0),
    (111.0, 115.9, 121.0),
    (117.0, 122.1, 127.5),
    (122.0, 127.9, 134.0),
    (127.0, 133.4, 140.0),
    (132.0, 138.8, 146.0),
    (136.0, 143.8, 152.0),
    (141.0, 149.7, 159.5),
    (148.0, 156.5, 167.0),
    (156.0, 163.1, 172.5),
    (161.5, 167.7, 175.5),
    (164.0, 170.0, 177.0),
    (165.0, 171.0, 178.0),
    (165.5, 171.4, 178.3),
  ];

  static const _femaleP = <(double, double, double)>[
    (48.5, 49.1, 50.5),
    (71.5, 74.6, 77.5),
    (83.0, 85.7, 89.0),
    (90.0, 94.2, 98.0),
    (96.5, 101.5, 106.0),
    (103.0, 108.6, 113.5),
    (109.0, 114.7, 120.0),
    (115.0, 121.0, 126.5),
    (120.0, 126.6, 133.0),
    (125.0, 132.5, 139.5),
    (131.0, 139.1, 146.5),
    (137.5, 145.8, 154.0),
    (144.0, 151.7, 159.5),
    (148.5, 155.9, 163.0),
    (151.5, 158.3, 164.5),
    (153.0, 159.5, 165.5),
    (153.7, 160.0, 166.0),
    (154.0, 160.2, 166.0),
    (154.0, 160.2, 166.0),
  ];
}

/// 추천된 멤버 input 이 어린이(영아~청소년) 인지 여부 — UI 코드가 카드 헤더
/// 색상/이모지를 변경할 때 쓸 수 있도록 헬퍼로 노출.
bool isChildAgeGroup(FamilyInput input) {
  final g = input.ageGroup;
  return g == AgeGroup.newborn ||
      g == AgeGroup.toddler ||
      g == AgeGroup.child ||
      g == AgeGroup.teen;
}
