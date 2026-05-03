import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/models/recommendation_result.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/security/secure_storage.dart';
import '../../../core/theme/app_theme.dart';
import '../../family/models/family_member.dart';
import '../../family/providers/family_members_provider.dart';
import '../../family/screens/recommendation_detail_screen.dart';
import '../../family/services/family_service.dart';
import '../../health_checkup/screens/health_checkup_input_screen.dart';
import '../../onboarding/family_chat/family_chat_screen.dart';
import '../../recommendation/engine/family_input.dart';
import '../../settings/settings_screen.dart';
import '../../streak/streak_provider.dart';
import '../../streak/streak_service.dart';
import '../data/checkin_service.dart';
import '../providers/home_feed_provider.dart';
import '../widgets/ai_comment_card.dart';
import '../widgets/weather_tip_card.dart';

/// 홈 = 한 번에 한 명. 상단 가족 아바타 strip 에서 누가 보일지 고르고,
/// 그 아래엔 선택된 멤버의 오늘 가이드 카드 한 장만 큼직하게.
///
/// 1차 redesign 의 핵심: 리스트 → 단일 포커스. Medisafe / Roundhealth 의
/// "오늘 한 사람" 흐름을 차용.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  static const routeName = '/home';

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  /// SecureStorage 에서 읽어 둔 가족 정렬 순서. 드래그로 갱신될 때마다 저장.
  List<String>? _order;
  bool _orderLoaded = false;

  /// 카드 키 — 향후 reorder UX 로 복귀 시 사용 가능. 현재는 미사용.
  final Map<String, GlobalKey> _cardKeys = {};

  GlobalKey _keyFor(String id) =>
      _cardKeys.putIfAbsent(id, () => GlobalKey());

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  Future<void> _loadOrder() async {
    final raw = await SecureStorage.read(SecureStorage.kFamilyOrder);
    if (!mounted) return;
    if (raw == null || raw.isEmpty) {
      setState(() => _orderLoaded = true);
      return;
    }
    try {
      final list = (jsonDecode(raw) as List).map((e) => e.toString()).toList();
      setState(() {
        _order = list;
        _orderLoaded = true;
      });
    } catch (_) {
      setState(() => _orderLoaded = true);
    }
  }

  /// 저장된 [_order] 와 실제 entries 를 합쳐 화면에 노출할 정렬을 만든다.
  /// 저장된 순서를 우선 따라가되 거기 없는 새 멤버는 끝에 붙이고,
  /// 저장된 id 중 사라진 건 무시.
  List<HomeFeedEntry> _applyOrder(List<HomeFeedEntry> entries) {
    final saved = _order;
    if (saved == null || saved.isEmpty) return entries;
    final byId = {for (final e in entries) e.member.id: e};
    final result = <HomeFeedEntry>[];
    for (final id in saved) {
      final e = byId.remove(id);
      if (e != null) result.add(e);
    }
    result.addAll(byId.values);
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final feedAsync = ref.watch(homeFeedProvider);
    final today = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        toolbarHeight: 72,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              AppStrings.homeGreeting,
              style: AppTheme.heading2,
            ),
            const SizedBox(height: 2),
            Text(
              AppStrings.homeTodayDateLong(today),
              style: AppTheme.caption.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: AppStrings.homeMenuFamilyAdd,
            onPressed: () => context.push(FamilyChatScreen.routeName),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: AppStrings.homeMenuSettings,
            onPressed: () => context.push(SettingsScreen.routeName),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: feedAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => const _ErrorState(),
        data: (rawEntries) {
          if (rawEntries.isEmpty) return const _EmptyState();
          if (!_orderLoaded) {
            return const Center(child: CircularProgressIndicator());
          }
          final entries = _applyOrder(rawEntries);

          final streakAsync = ref.watch(streakProvider);
          final streak = streakAsync.hasValue
              ? streakAsync.requireValue
              : StreakSnapshot.empty;

          // 더 이상 활성 카드 1개 개념이 없으므로, AI 코멘트와 streak 축하
          // 카드는 첫 번째 가족(=대표 멤버) 기준으로 노출.
          final headEntry = entries.first;

          return ListView(
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
            children: [
              if (streak.count >= 1)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: _StreakPill(snapshot: streak),
                ),
              // 사용자 요청으로 상단 아바타 strip 제거 — 첫 화면에서 가족 카드를
              // 바로 보여줘 모든 가족의 영양제 섭취 현황·필요 영양제를 한눈에
              // 확인할 수 있도록 한다.
              const SizedBox(height: 4),
              for (var i = 0; i < entries.length; i++) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: _FamilyCard(
                    key: _keyFor(entries[i].member.id),
                    entry: entries[i],
                    memberIndex: i,
                    onMarkChecked: (names) async {
                      await CheckinService.markChecked(
                        entries[i].member.id,
                        names,
                      );
                      ref.invalidate(homeFeedProvider);
                      ref.invalidate(streakProvider);
                    },
                  ),
                ),
              ],
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: WeatherTipCard(),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: streak.allTodayChecked && streak.count >= 1
                    ? _StreakCelebrationCard(count: streak.count)
                    : AiCommentCard(entry: headEntry),
              ),
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  AppStrings.homeDisclaimer,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// 추천 정확도 pill — 데일리 카드 내부, 미입력 라이프스타일 필드를
// "smoker / drinker / diet / exercise / sleep / stress" 6 종 기준으로 측정.
// 100% 면 숨김, 그 외엔 색상 단계 (warning < 50%, secondary 50-79%,
// primary >= 80%) 와 현재 % 노출. 탭 시 bottom sheet 가 한 번에 한 질문씩.
// ════════════════════════════════════════════════════════════════════

/// 추천 정확도 pill — 미응답 라이프스타일 필드 비율을 노출하고, 탭 시 한 번에
/// 한 질문씩 채우는 bottom sheet 를 띄운다. 상세 페이지 헤더에서도 동일하게 사용.
class AccuracyPill extends ConsumerWidget {
  const AccuracyPill({super.key, required this.member});
  final FamilyMember member;

  /// 현재 기획상 적용 대상은 성인/노인. 어린이/청소년/유아/영아는 온보딩
  /// 챗에서 이미 전부 묻고 있어 accuracy 개념 자체가 무의미.
  bool _appliesTo(FamilyInput input) {
    final g = input.ageGroup;
    return g == AgeGroup.adult || g == AgeGroup.elderly;
  }

  /// 6종 라이프스타일 필드 중 채워진 비율 (%) 0~100.
  int _accuracy(FamilyInput input) {
    var filled = 0;
    if (input.smoker != null) filled++;
    if (input.drinker != null) filled++;
    if (input.diet != null) filled++;
    if (input.exercise != null) filled++;
    if (input.sleep != null) filled++;
    if (input.stress != null) filled++;
    return ((filled / 6) * 100).round();
  }

  Color _colorFor(int pct) {
    if (pct >= 80) return AppTheme.primary;
    if (pct >= 50) return AppTheme.secondary;
    return AppTheme.warning;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final input = member.input;
    if (!_appliesTo(input)) return const SizedBox.shrink();
    final pct = _accuracy(input);
    if (pct >= 100) return const SizedBox.shrink();

    final color = _colorFor(pct);
    return Align(
      alignment: Alignment.centerLeft,
      child: InkWell(
        onTap: () => _open(context, ref),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Text(
            AppStrings.accuracyPill(pct),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AccuracySheet(memberId: member.id),
    );
  }
}

class _AccuracySheet extends ConsumerWidget {
  const _AccuracySheet({required this.memberId});
  final String memberId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final familyAsync = ref.watch(familyMembersProvider);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: familyAsync.when(
        loading: () => const SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => const SizedBox(
          height: 200,
          child: Center(child: Text(AppStrings.familyLoadFailed)),
        ),
        data: (members) {
          final member = members.firstWhere(
            (m) => m.id == memberId,
            orElse: () => members.first,
          );
          final input = member.input;
          final question = _nextQuestion(input);
          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.line,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const Text(
                  AppStrings.accuracySheetTitle,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.ink,
                  ),
                ),
                const SizedBox(height: 16),
                if (question == null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Row(
                      children: [
                        const Text('💚', style: TextStyle(fontSize: 22)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            AppStrings.accuracySheetDone,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.ink,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  Text(
                    question.text,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.ink,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final opt in question.options)
                        OutlinedButton(
                          onPressed: () async {
                            final updated = opt.apply(input);
                            await FamilyService.updateMember(
                              member.id,
                              updated,
                            );
                            ref.invalidate(familyMembersProvider);
                            ref.invalidate(homeFeedProvider);
                            ref.invalidate(streakProvider);
                          },
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 44),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side:
                                const BorderSide(color: AppTheme.primary),
                            foregroundColor: AppTheme.primary,
                          ),
                          child: Text(
                            opt.label,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 18),
                if (input.lastCheckup == null)
                  _CheckupBannerInSheet(memberId: member.id),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      question == null ? '닫기' : '나중에 할게요',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.subtle,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 미응답 필드를 우선순위(smoker → drinker → diet → exercise → sleep
  /// → stress) 로 찾아 다음 질문 묶음 반환. 다 채워지면 null.
  _AccuracyQuestion? _nextQuestion(FamilyInput i) {
    if (i.smoker == null) {
      return _AccuracyQuestion(
        text: AppStrings.qSmoker,
        options: [
          _AccuracyOption(AppStrings.yes, (x) => x.copyWith(smoker: true)),
          _AccuracyOption(AppStrings.no, (x) => x.copyWith(smoker: false)),
        ],
      );
    }
    if (i.drinker == null) {
      return _AccuracyQuestion(
        text: AppStrings.qDrinker,
        options: [
          _AccuracyOption(AppStrings.yes, (x) => x.copyWith(drinker: true)),
          _AccuracyOption(AppStrings.no, (x) => x.copyWith(drinker: false)),
        ],
      );
    }
    if (i.diet == null) {
      return _AccuracyQuestion(
        text: AppStrings.qDiet,
        options: [
          _AccuracyOption(AppStrings.choiceDietMeat,
              (x) => x.copyWith(diet: DietHabit.meat)),
          _AccuracyOption(AppStrings.choiceDietBalanced,
              (x) => x.copyWith(diet: DietHabit.balanced)),
          _AccuracyOption(AppStrings.choiceDietVegetarian,
              (x) => x.copyWith(diet: DietHabit.vegetarian)),
        ],
      );
    }
    if (i.exercise == null) {
      return _AccuracyQuestion(
        text: AppStrings.qExercise,
        options: [
          _AccuracyOption(AppStrings.choiceLevelNone,
              (x) => x.copyWith(exercise: ExerciseLevel.none)),
          _AccuracyOption(AppStrings.choiceLevelSometimes,
              (x) => x.copyWith(exercise: ExerciseLevel.sometimes)),
          _AccuracyOption(AppStrings.choiceLevelOften,
              (x) => x.copyWith(exercise: ExerciseLevel.often)),
        ],
      );
    }
    if (i.sleep == null) {
      return _AccuracyQuestion(
        text: AppStrings.qSleep,
        options: [
          _AccuracyOption(AppStrings.choiceSleepLess,
              (x) => x.copyWith(sleep: SleepHours.lessSix)),
          _AccuracyOption(AppStrings.choiceSleep78,
              (x) => x.copyWith(sleep: SleepHours.sevenEight)),
          _AccuracyOption(AppStrings.choiceSleep9,
              (x) => x.copyWith(sleep: SleepHours.nineOrMore)),
        ],
      );
    }
    if (i.stress == null) {
      return _AccuracyQuestion(
        text: AppStrings.qStress,
        options: [
          _AccuracyOption(AppStrings.choiceStressLow,
              (x) => x.copyWith(stress: StressLevel.low)),
          _AccuracyOption(AppStrings.choiceStressMedium,
              (x) => x.copyWith(stress: StressLevel.medium)),
          _AccuracyOption(AppStrings.choiceStressHigh,
              (x) => x.copyWith(stress: StressLevel.high)),
        ],
      );
    }
    return null;
  }
}

class _AccuracyQuestion {
  _AccuracyQuestion({required this.text, required this.options});
  final String text;
  final List<_AccuracyOption> options;
}

class _AccuracyOption {
  _AccuracyOption(this.label, this.apply);
  final String label;
  final FamilyInput Function(FamilyInput) apply;
}

/// 정확도 시트 안에 들어가는 검진 입력 권유 카드. 검진 데이터가 없을 때만 노출.
class _CheckupBannerInSheet extends StatelessWidget {
  const _CheckupBannerInSheet({required this.memberId});
  final String memberId;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.of(context).pop();
          context.push(HealthCheckupInputScreen.pathFor(memberId));
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.cream,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Text('📋', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '건강검진 결과 입력',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.ink,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '입력하면 추천이 훨씬 정확해져요',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.subtle,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: AppTheme.subtle,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// Streak (가족 전체 연속 챙김 일수)
// ════════════════════════════════════════════════════════════════════

class _StreakPill extends StatelessWidget {
  const _StreakPill({required this.snapshot});
  final StreakSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: AppTheme.primaryLight,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () => _showHistory(context),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text(
              AppStrings.streakPill(snapshot.count),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryDark,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showHistory(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppStrings.streakHistoryDialog(snapshot.count, snapshot.best),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _StreakCelebrationCard extends StatelessWidget {
  const _StreakCelebrationCard({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryLight,
            Color(0xFFFFF1EC),
          ],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🎉', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              AppStrings.streakCelebration(count),
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.ink,
                height: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// Avatar strip (horizontal, drag-to-reorder)
// ════════════════════════════════════════════════════════════════════

class _AvatarStrip extends StatefulWidget {
  const _AvatarStrip({
    required this.entries,
    required this.activeIndex,
    required this.onSelect,
    required this.onReorder,
  });

  final List<HomeFeedEntry> entries;
  final int activeIndex;
  final ValueChanged<String> onSelect;
  final void Function(int oldIndex, int newIndex) onReorder;

  @override
  State<_AvatarStrip> createState() => _AvatarStripState();
}

class _AvatarStripState extends State<_AvatarStrip>
    with SingleTickerProviderStateMixin {
  /// iOS 편집 모드처럼 흔들리는 회전 애니메이션. 드래그가 시작되면 repeat,
  /// 드래그가 끝나면 stop + 0 으로 리셋.
  late final AnimationController _wiggleCtrl;

  /// 활성 아바타가 화면 중앙에 오도록 자동 스크롤할 때 쓰는 컨트롤러.
  final ScrollController _scrollCtrl = ScrollController();

  bool _wiggling = false;
  bool _isDragging = false;

  /// 활성 long-press preview 수. 동시에 여러 손가락이 누를 수도 있어 카운트.
  /// 0 으로 떨어지고 드래그도 끝나면 wiggle 정리.
  int _activePresses = 0;

  /// 한 아바타가 차지하는 가로 폭 추정값 (52dp + 좌우 패딩 5dp). active 시 60dp
  /// 가 되어도 평균은 비슷해 자동 스크롤 계산엔 충분.
  static const double _itemWidth = 62;

  /// 어떤 타일이 350ms 길게 눌리면 호출 — wiggle 즉시 시작 (drag 시작과 무관).
  void _startPreview() {
    _activePresses += 1;
    if (!_wiggling) {
      _wiggleCtrl.repeat();
      setState(() => _wiggling = true);
    }
  }

  /// 그 타일이 손을 뗐거나 드래그가 시작되지 않은 채 끝났을 때 호출.
  void _cancelPreview() {
    _activePresses = (_activePresses - 1).clamp(0, 1 << 30);
    if (_activePresses == 0 && !_isDragging) {
      _wiggleCtrl.stop();
      _wiggleCtrl.value = 0;
      setState(() => _wiggling = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _wiggleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void didUpdateWidget(_AvatarStrip old) {
    super.didUpdateWidget(old);
    if (old.activeIndex != widget.activeIndex) {
      _scrollToActive();
    }
  }

  /// 첫 frame 이전에 controller 가 attach 안 돼 있을 수 있어 post-frame 으로 한 번 더 시도.
  void _scrollToActive() {
    if (!_scrollCtrl.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scrollCtrl.hasClients) _scrollToActive();
      });
      return;
    }
    final viewport = _scrollCtrl.position.viewportDimension;
    final target =
        (widget.activeIndex * _itemWidth) - viewport / 2 + _itemWidth / 2;
    final clamped = target.clamp(
      _scrollCtrl.position.minScrollExtent,
      _scrollCtrl.position.maxScrollExtent,
    );
    _scrollCtrl.animateTo(
      clamped,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _wiggleCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: ReorderableListView.builder(
        scrollController: _scrollCtrl,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        buildDefaultDragHandles: false,
        proxyDecorator: (child, _, _) => Material(
          color: Colors.transparent,
          child: child,
        ),
        itemCount: widget.entries.length,
        onReorderStart: (_) {
          _isDragging = true;
          // long-press preview 가 이미 wiggle 을 켰을 가능성이 큼 — 안 켜져
          // 있으면 여기서 켠다 (e.g. delayed listener 자체 timer 가 우리보다 빨랐을 때).
          if (!_wiggling) {
            _wiggleCtrl.repeat();
            setState(() => _wiggling = true);
          }
        },
        onReorderEnd: (_) {
          _isDragging = false;
          if (_activePresses == 0) {
            _wiggleCtrl.stop();
            _wiggleCtrl.value = 0;
            setState(() => _wiggling = false);
          }
        },
        onReorder: widget.onReorder,
        itemBuilder: (context, i) {
          final e = widget.entries[i];
          // ReorderableDelayedDragStartListener 는 ~500ms 길게 눌러야 drag 가
          // 시작되는데, 우리는 그보다 빠른 350ms 시점에 wiggle preview 를 켠다.
          // → 손가락이 머무는 동안 먼저 흔들리고, 조금 더 머무르면 drag 가
          //   잡혀 자리 이동이 가능. 평소 짧은 탭은 onTap 으로만 흘러간다.
          return ReorderableDelayedDragStartListener(
            key: ValueKey(e.member.id),
            index: i,
            child: _AvatarTile(
              entry: e,
              memberIndex: i,
              isActive: i == widget.activeIndex,
              wiggling: _wiggling,
              wiggleCtrl: _wiggleCtrl,
              onTap: () => widget.onSelect(e.member.id),
              onPreviewStart: _startPreview,
              onPreviewCancel: _cancelPreview,
            ),
          );
        },
      ),
    );
  }
}

class _AvatarTile extends StatefulWidget {
  const _AvatarTile({
    required this.entry,
    required this.memberIndex,
    required this.isActive,
    required this.onTap,
    required this.wiggling,
    required this.wiggleCtrl,
    required this.onPreviewStart,
    required this.onPreviewCancel,
  });

  final HomeFeedEntry entry;
  final int memberIndex;
  final bool isActive;
  final VoidCallback onTap;
  final bool wiggling;
  final AnimationController wiggleCtrl;

  /// 350ms 동안 손가락이 머물면 호출 — strip 단위 wiggle 시작 신호.
  final VoidCallback onPreviewStart;

  /// preview 가 켜진 상태에서 손을 떼거나 cancel 됐을 때 호출. drag 가 시작되면
  /// preview 는 켠 채로 두고 strip 의 onReorderEnd 에서 정리.
  final VoidCallback onPreviewCancel;

  @override
  State<_AvatarTile> createState() => _AvatarTileState();
}

class _AvatarTileState extends State<_AvatarTile> {
  Timer? _previewTimer;
  bool _previewActive = false;

  /// drag 가 시작되면 더 이상 preview cancel 을 호출하지 않는다 (drag 가 이어서
  /// reorderEnd 에서 wiggle 을 정리).
  bool _committedToDrag = false;

  /// 상태별 테두리 색.
  /// - green: 모든 추천 체크 완료 → primary (초록)
  /// - yellow: 일부만 체크됨 → warning (주황)
  /// - red(아무것도 안 챙김) / none(추천 없음) → line (회색) — 의미가 같으니
  ///   동일 색으로 합침.
  Color get _statusColor {
    switch (widget.entry.statusDot) {
      case StatusDot.green:
        return AppTheme.primary;
      case StatusDot.yellow:
        return AppTheme.warning;
      case StatusDot.red:
      case StatusDot.none:
        return AppTheme.line;
    }
  }

  /// 아바타 아래 작은 상태 라벨. 회색(red/none) 일 땐 표시하지 않음.
  String? get _statusLabel {
    switch (widget.entry.statusDot) {
      case StatusDot.green:
        return AppStrings.avatarStatusDone;
      case StatusDot.yellow:
        return AppStrings.avatarStatusInProgress;
      case StatusDot.red:
      case StatusDot.none:
        return null;
    }
  }

  void _onPointerDown(PointerDownEvent _) {
    _previewTimer?.cancel();
    _committedToDrag = false;
    _previewTimer = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      _previewActive = true;
      setState(() {}); // scale-down 즉시 반영
      widget.onPreviewStart();
    });
  }

  void _onPointerUp(PointerEvent _) {
    _previewTimer?.cancel();
    if (_previewActive && !_committedToDrag) {
      _previewActive = false;
      widget.onPreviewCancel();
      if (mounted) setState(() {});
    }
  }

  @override
  void didUpdateWidget(_AvatarTile old) {
    super.didUpdateWidget(old);
    // 부모 strip 이 wiggle 을 끄면 (drag 종료) 우리 쪽 preview 카운터도 정리.
    if (old.wiggling && !widget.wiggling) {
      if (_previewActive) {
        _previewActive = false;
        // strip 쪽에서는 이미 _activePresses 를 우리 cancel 호출 없이 줄였으므로
        // 여기서 widget.onPreviewCancel() 을 다시 부르지 않는다 — 단지 로컬 플래그만 정리.
      }
      _committedToDrag = false;
    }
  }

  @override
  void dispose() {
    _previewTimer?.cancel();
    if (_previewActive && !_committedToDrag) {
      widget.onPreviewCancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 부모 strip 의 wiggle 이 켜졌고 우리가 preview 시작점이었다면 drag 가
    // 시작된 것으로 간주 (long-press → drag 자동 전이). 이 경우 cancel 안 함.
    if (widget.wiggling && _previewActive) {
      _committedToDrag = true;
    }

    final size = widget.isActive ? 60.0 : 52.0;
    final color = AppTheme.memberColorFor(widget.memberIndex);
    final initial = widget.entry.member.name.isEmpty
        ? '?'
        : widget.entry.member.name.characters.first;

    Widget circle = AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: _statusColor,
          width: widget.isActive ? 3 : 2,
        ),
        boxShadow: widget.isActive ? AppTheme.softShadow : null,
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontSize: widget.isActive ? 22 : 20,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    // iOS 편집 모드 흔들림 (±2°). 멤버 인덱스에 따라 위상을 살짝 어긋나게
    // 두면 모든 아바타가 동시에 같은 방향으로 흔들리지 않아 자연스럽다.
    if (widget.wiggling) {
      final phase = (widget.memberIndex % 5) * 0.7;
      circle = AnimatedBuilder(
        animation: widget.wiggleCtrl,
        builder: (_, child) {
          final t = widget.wiggleCtrl.value * 2 * math.pi;
          final angle = math.sin(t + phase) * 0.035; // ≈ ±2°
          return Transform.rotate(angle: angle, child: child);
        },
        child: circle,
      );
    }

    // preview 가 활성된 (= 350ms 길게 눌린) 타일은 살짝 줄어들어 "내가 잡혔다"
    // 라는 시각 신호를 준다.
    final pressedScale = _previewActive ? 0.95 : 1.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Listener(
        onPointerDown: _onPointerDown,
        onPointerUp: _onPointerUp,
        onPointerCancel: _onPointerUp,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                scale: pressedScale,
                duration: const Duration(milliseconds: 140),
                curve: Curves.easeOut,
                child: circle,
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: 64,
                child: Text(
                  widget.entry.member.name,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight:
                        widget.isActive ? FontWeight.w700 : FontWeight.w500,
                    color: widget.isActive
                        ? AppTheme.textPrimary
                        : AppTheme.textSecondary,
                  ),
                ),
              ),
              if (_statusLabel != null) ...[
                const SizedBox(height: 2),
                Text(
                  _statusLabel!,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _statusColor,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// Selected-member daily card
// ════════════════════════════════════════════════════════════════════

/// 가족 한 명을 한 장의 컴팩트 카드로 보여주는 새 홈 카드.
///
/// - 헤더: 작은 아바타 + 이름 + 나이/성별 + 상태 dot
/// - 시간 슬롯: 아침 / 점심 / 저녁 / 취침 (있는 슬롯만 노출)
/// - 각 영양제는 💊 아이콘 + 12sp 이름 (8자 초과 시 truncate)
/// - 하단 버튼: [먹었어요 👍] [자세히 보기 →]
/// - 카드 본문 탭(=버튼 영역 외) → 상세 페이지로 push
class _FamilyCard extends StatelessWidget {
  const _FamilyCard({
    super.key,
    required this.entry,
    required this.memberIndex,
    required this.onMarkChecked,
  });

  final HomeFeedEntry entry;
  final int memberIndex;
  final Future<void> Function(Iterable<String> names) onMarkChecked;

  void _openDetail(BuildContext context) {
    context.push(RecommendationDetailScreen.pathFor(entry.member.id));
  }

  @override
  Widget build(BuildContext context) {
    final taking = entry.alreadyTakingSupplements;
    final needed = entry.visibleSupplements;
    final neededNames = needed.map((r) => r.supplementName).toList();
    final allChecked = neededNames.isNotEmpty &&
        neededNames.every(entry.checkedToday.contains);
    final memberColor = AppTheme.memberColorFor(memberIndex);

    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(AppTheme.radiusCard),
      child: Ink(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          boxShadow: AppTheme.softShadow,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          onTap: () => _openDetail(context),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CardHeader(
                  member: entry.member,
                  color: memberColor,
                  statusDot: entry.statusDot,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1, color: AppTheme.border),
                ),
                _NowTakingSection(items: taking),
                const SizedBox(height: 14),
                _NeededSection(
                  items: needed,
                  checkedToday: entry.checkedToday,
                ),
                const SizedBox(height: 14),
                // 카드 본문 InkWell 의 탭이 버튼까지 새지 않도록 별도 GestureDetector
                // 로 감싸 버튼 영역의 탭은 InkWell 로 흘려보내지 않는다.
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {},
                  child: Row(
                    children: [
                      Expanded(
                        child: _CheckButton(
                          alreadyDone: allChecked,
                          onTap: allChecked || neededNames.isEmpty
                              ? null
                              : () => onMarkChecked(neededNames),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _openDetail(context),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            side: const BorderSide(color: AppTheme.border),
                            foregroundColor: AppTheme.primary,
                          ),
                          child: const Text(
                            '자세히 보기 →',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "지금 드시는 것" — 사용자가 등록한 currentSupplements 만 칩으로 노출.
/// 비어 있으면 등록 안내 문구.
class _NowTakingSection extends StatelessWidget {
  const _NowTakingSection({required this.items});
  final List<RecommendationResult> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '💊 지금 드시는 것',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        if (items.isEmpty)
          const Text(
            '아직 등록된 영양제가 없어요. 자세히 보기에서 추가하세요',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
          )
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final r in items)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.cream,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    r.supplementName,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

/// "더 필요한 것" — must_take + highly_recommended 항목을 bullet 으로 노출.
/// 각 항목: 이름 / reason 한 줄 / 체크된 경우 옅은 색 + 취소선.
class _NeededSection extends StatelessWidget {
  const _NeededSection({
    required this.items,
    required this.checkedToday,
  });

  final List<RecommendationResult> items;
  final Set<String> checkedToday;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Text(
        '✅ 추가로 필요한 영양제가 없어요',
        style: TextStyle(
          fontSize: 13,
          color: AppTheme.textSecondary,
          fontWeight: FontWeight.w600,
          height: 1.5,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '⚠️ 더 필요한 것',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        for (final r in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _NeededRow(
              result: r,
              checked: checkedToday.contains(r.supplementName),
            ),
          ),
      ],
    );
  }
}

class _NeededRow extends StatelessWidget {
  const _NeededRow({required this.result, required this.checked});
  final RecommendationResult result;
  final bool checked;

  @override
  Widget build(BuildContext context) {
    final nameColor = checked ? AppTheme.textSecondary : AppTheme.textPrimary;
    final decoration =
        checked ? TextDecoration.lineThrough : TextDecoration.none;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4, right: 8),
          child: Text(
            checked ? '✅' : '•',
            style: TextStyle(
              fontSize: checked ? 12 : 16,
              color: AppTheme.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                result.supplementName,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: nameColor,
                  decoration: decoration,
                ),
              ),
              if (result.reason.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    result.reason,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({
    required this.member,
    required this.color,
    required this.statusDot,
  });

  final FamilyMember member;
  final Color color;
  final StatusDot statusDot;

  Color get _statusColor {
    switch (statusDot) {
      case StatusDot.green:
        return AppTheme.primary;
      case StatusDot.yellow:
        return AppTheme.warning;
      case StatusDot.red:
      case StatusDot.none:
        return AppTheme.border;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sex = member.sex;
    final ageLabel = [
      if (sex != null) sex.ko,
      if (member.age > 0) '${member.age}세',
    ].join(' ');

    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.18),
            border: Border.all(color: color, width: 2),
          ),
          alignment: Alignment.center,
          child: Text(
            member.name.isEmpty ? '?' : member.name[0],
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                member.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              if (ageLabel.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  ageLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _statusColor,
          ),
        ),
      ],
    );
  }
}

/// 탭 시 살짝 줄어들었다 돌아오는 bounce 애니메이션이 들어간 "먹었어요" 버튼.
class _CheckButton extends StatefulWidget {
  const _CheckButton({required this.alreadyDone, required this.onTap});
  final bool alreadyDone;
  final VoidCallback? onTap;

  @override
  State<_CheckButton> createState() => _CheckButtonState();
}

class _CheckButtonState extends State<_CheckButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
      lowerBound: 0.0,
      upperBound: 0.06,
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    if (widget.onTap == null) return;
    await _ctrl.forward();
    await _ctrl.reverse();
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final scale = 1 - _ctrl.value;
        return Transform.scale(scale: scale, child: child);
      },
      child: FilledButton(
        onPressed: widget.onTap == null ? null : _handleTap,
        style: FilledButton.styleFrom(
          backgroundColor: widget.alreadyDone
              ? AppTheme.primaryLight
              : AppTheme.primary,
          foregroundColor: widget.alreadyDone
              ? AppTheme.primary
              : Colors.white,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusButton),
          ),
        ),
        child: Text(
          widget.alreadyDone
              ? AppStrings.homeAllDone
              : AppStrings.homeAlreadyTaken,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// Empty / Error
// ════════════════════════════════════════════════════════════════════

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('👨‍👩‍👧‍👦', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 14),
            const Text(
              AppStrings.homeEmptyHeading,
              style: AppTheme.heading3,
            ),
            const SizedBox(height: 6),
            const Text(
              AppStrings.homeEmptyBody,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => context.push(FamilyChatScreen.routeName),
              child: const Text(AppStrings.homeAddFamily),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          AppStrings.homeLoadFailed,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
