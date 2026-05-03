import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/growth_chart.dart';
import '../../../core/data/nutrient_targets.dart';
import '../../../core/data/product_repository.dart';
import '../../../core/data/supplement_repository.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../core/security/encryption_service.dart';
import '../../../core/security/secure_storage.dart';
import '../../../core/theme/app_theme.dart';
import '../../family/providers/family_members_provider.dart';
import '../../home/providers/home_feed_provider.dart';
import '../../notifications/providers/notification_settings_provider.dart';
import '../../notifications/screens/notification_settings_screen.dart';
import '../../recommendation/engine/family_input.dart';
import '../../recommendation/engine/recommendation_engine.dart';
import '../screens/family_select_screen.dart';
import 'family_chat_controller.dart';
import 'models/chat_message.dart';
import 'widgets/chat_bubble.dart';

/// 가족 추가 채팅 진입 모드. 저장 직후 동작이 달라진다.
/// - own: 본인 등록 (웰컴 → "나부터 등록할게요"). 저장 후 가족 추가 권유 메시지.
/// - onboarding: 온보딩 가족 추가 (가족 선택 → 카드). 저장 후 다음 가족/완료 선택.
/// - manage: 홈/가족 관리에서 push. 저장 후 곧장 pop.
enum FamilyChatMode { own, onboarding, manage }

class FamilyChatScreen extends ConsumerWidget {
  const FamilyChatScreen({
    super.key,
    this.mode = FamilyChatMode.manage,
    this.relation,
  });

  static const routeName = '/onboarding/family-add';

  final FamilyChatMode mode;
  final String? relation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repoAsync = ref.watch(supplementRepositoryProvider);
    final productRepoAsync = ref.watch(productRepositoryProvider);

    if (repoAsync.isLoading || productRepoAsync.isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (repoAsync.hasError || productRepoAsync.hasError) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              AppStrings.onboardingLoadFailed,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final engine = RecommendationEngine(repository: repoAsync.value!);
    final productRepo = productRepoAsync.value!;

    return ProviderScope(
      overrides: [
        familyChatControllerProvider.overrideWith(
          () => FamilyChatController(
            engine,
            isOwn: mode == FamilyChatMode.own,
            productRepository: productRepo,
          ),
        ),
      ],
      child: _FamilyChatBody(mode: mode, relation: relation),
    );
  }
}

class _FamilyChatBody extends ConsumerStatefulWidget {
  const _FamilyChatBody({required this.mode, required this.relation});

  final FamilyChatMode mode;
  final String? relation;

  @override
  ConsumerState<_FamilyChatBody> createState() => _FamilyChatBodyState();
}

class _FamilyChatBodyState extends ConsumerState<_FamilyChatBody> {
  final _scrollCtrl = ScrollController();

  /// 단일 관계 → (이름, 성별) 자동 채움 매핑.
  /// family_select 에서 '남편'/'아내'/'엄마'/'아빠' 카드를 누르면 relation 으로
  /// 라벨이 그대로 들어와 여기서 매칭. 그 외는 일반 흐름.
  static const Map<String, (String name, Sex sex)> _singularRelations = {
    AppStrings.relationHusband: ('남편', Sex.male),
    AppStrings.relationWife: ('아내', Sex.female),
    AppStrings.relationMom: ('엄마', Sex.female),
    AppStrings.relationDad: ('아빠', Sex.male),
  };

  @override
  void initState() {
    super.initState();
    final prefill = _singularRelations[widget.relation];
    if (prefill != null) {
      // controller build() 가 이미 첫 봇 메시지를 만든 직후, 첫 frame 그리기 전에
      // shortcut 을 적용해 이름·성별 질문을 건너뛴다.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(familyChatControllerProvider.notifier)
            .applyRelationShortcut(name: prefill.$1, sex: prefill.$2);
      });
    }
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!_scrollCtrl.hasClients) return;
    _scrollCtrl.animateTo(
      _scrollCtrl.position.maxScrollExtent,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(familyChatControllerProvider);

    ref.listen(familyChatControllerProvider, (prev, next) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _scrollToBottom());
    });

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: Column(
            children: [
              _ProgressBar(
                progress: progressFor(state.input.age, state.step),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // 메시지가 적을 땐 첫 메시지가 화면 ~35% 지점에 떠 있도록
                    // 상단 패딩을 둔다. 메시지가 쌓일수록 패딩이 줄어들어
                    // 결국 0 이 되고, 그 다음엔 자연스럽게 위로 스크롤된다.
                    // 메시지 평균 높이는 100dp 로 근사 (subText/wrap 고려해 보수적).
                    final estimated = state.messages.length * 100.0 +
                        (state.botTyping ? 40.0 : 0.0);
                    final topPad = math.max(
                      0.0,
                      constraints.maxHeight * 0.35 - estimated,
                    );
                    return SingleChildScrollView(
                      controller: _scrollCtrl,
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      child: Padding(
                        padding:
                            const EdgeInsets.fromLTRB(20, 0, 20, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(height: topPad),
                            for (final msg in state.messages)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: ChatBubble(message: msg),
                              ),
                            if (state.botTyping) const _TypingIndicator(),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              _InputArea(
                state: state,
                mode: widget.mode,
                relation: widget.relation,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: progress),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOut,
      builder: (context, value, _) {
        return LinearProgressIndicator(
          value: value,
          minHeight: 3,
          backgroundColor: AppTheme.line,
          valueColor: const AlwaysStoppedAnimation(AppTheme.primary),
        );
      },
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 10, left: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Dot(delay: 0),
            SizedBox(width: 5),
            _Dot(delay: 150),
            SizedBox(width: 5),
            _Dot(delay: 300),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatefulWidget {
  const _Dot({required this.delay});
  final int delay;

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.3, end: 1.0).animate(_ctrl),
      child: Container(
        width: 7,
        height: 7,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.subtle,
        ),
      ),
    );
  }
}

class _InputArea extends ConsumerStatefulWidget {
  const _InputArea({
    required this.state,
    required this.mode,
    required this.relation,
  });

  final FamilyChatState state;
  final FamilyChatMode mode;
  final String? relation;

  @override
  ConsumerState<_InputArea> createState() => _InputAreaState();
}

class _InputAreaState extends ConsumerState<_InputArea> {
  final _textCtrl = TextEditingController();
  bool _saving = false;
  bool _completionShown = false;

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  String get _nameHint {
    if (widget.mode == FamilyChatMode.own) return AppStrings.ownNameHint;
    return AppStrings.onboardingNameHint;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppTheme.line)),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 240),
        transitionBuilder: (child, anim) =>
            FadeTransition(opacity: anim, child: child),
        child: KeyedSubtree(
          key: ValueKey(
            _completionShown ? '__completion__' : widget.state.step.name,
          ),
          child: _completionShown
              ? _completionChoices()
              : _buildForStep(widget.state.step),
        ),
      ),
    );
  }

  Widget _buildForStep(ChatStep step) {
    switch (step) {
      case ChatStep.name:
        return _textInput(hint: _nameHint, subHint: AppStrings.nameSubHint);
      case ChatStep.age:
        return _textInput(
          hint: AppStrings.onboardingAgeHint,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        );
      case ChatStep.sex:
        return _choices([
          _Choice(AppStrings.choiceMale, () => ref
              .read(familyChatControllerProvider.notifier)
              .submitSex(Sex.male)),
          _Choice(AppStrings.choiceFemale, () => ref
              .read(familyChatControllerProvider.notifier)
              .submitSex(Sex.female)),
        ]);
      case ChatStep.smoker:
        return _choices([
          _Choice(AppStrings.yes, () => ref
              .read(familyChatControllerProvider.notifier)
              .submitSmoker(true)),
          _Choice(AppStrings.no, () => ref
              .read(familyChatControllerProvider.notifier)
              .submitSmoker(false)),
        ]);
      case ChatStep.smokingAmount:
        return _choices([
          _Choice(AppStrings.choiceSmokeLight, () => ref
              .read(familyChatControllerProvider.notifier)
              .submitSmokingAmount(SmokingAmount.light)),
          _Choice(AppStrings.choiceSmokeModerate, () => ref
              .read(familyChatControllerProvider.notifier)
              .submitSmokingAmount(SmokingAmount.moderate)),
          _Choice(AppStrings.choiceSmokeHeavy, () => ref
              .read(familyChatControllerProvider.notifier)
              .submitSmokingAmount(SmokingAmount.heavy)),
          _Choice(AppStrings.choiceSmokeVeryHeavy, () => ref
              .read(familyChatControllerProvider.notifier)
              .submitSmokingAmount(SmokingAmount.veryHeavy)),
        ]);
      case ChatStep.drinker:
        return _choices([
          _Choice(AppStrings.yes, () => ref
              .read(familyChatControllerProvider.notifier)
              .submitDrinker(true)),
          _Choice(AppStrings.no, () => ref
              .read(familyChatControllerProvider.notifier)
              .submitDrinker(false)),
        ]);
      case ChatStep.drinkingType:
        return _choices([
          _Choice(AppStrings.choiceDrinkSoju, () => ref
              .read(familyChatControllerProvider.notifier)
              .submitDrinkingType(DrinkingType.soju)),
          _Choice(AppStrings.choiceDrinkBeer, () => ref
              .read(familyChatControllerProvider.notifier)
              .submitDrinkingType(DrinkingType.beer)),
          _Choice(AppStrings.choiceDrinkWine, () => ref
              .read(familyChatControllerProvider.notifier)
              .submitDrinkingType(DrinkingType.wine)),
          _Choice(AppStrings.choiceDrinkLiquor, () => ref
              .read(familyChatControllerProvider.notifier)
              .submitDrinkingType(DrinkingType.liquor)),
          _Choice(AppStrings.choiceDrinkMixed, () => ref
              .read(familyChatControllerProvider.notifier)
              .submitDrinkingType(DrinkingType.mixed)),
        ]);
      case ChatStep.drinkingFrequency:
        return _choices([
          _Choice(AppStrings.choiceFreqMonthly, () => ref
              .read(familyChatControllerProvider.notifier)
              .submitDrinkingFrequency(DrinkingFrequency.monthly)),
          _Choice(AppStrings.choiceFreqWeekly, () => ref
              .read(familyChatControllerProvider.notifier)
              .submitDrinkingFrequency(DrinkingFrequency.weekly)),
          _Choice(AppStrings.choiceFreqFrequent, () => ref
              .read(familyChatControllerProvider.notifier)
              .submitDrinkingFrequency(DrinkingFrequency.frequent)),
        ]);
      case ChatStep.diet:
        return _choices([
          _Choice(AppStrings.choiceDietMeat, () => ref
              .read(familyChatControllerProvider.notifier)
              .submitDiet(DietHabit.meat)),
          _Choice(AppStrings.choiceDietBalanced, () => ref
              .read(familyChatControllerProvider.notifier)
              .submitDiet(DietHabit.balanced)),
          _Choice(AppStrings.choiceDietVegetarian, () => ref
              .read(familyChatControllerProvider.notifier)
              .submitDiet(DietHabit.vegetarian)),
        ]);
      case ChatStep.allergies:
        return _choices([
          _Choice(AppStrings.yes, () => ref
              .read(familyChatControllerProvider.notifier)
              .submitAllergies(true)),
          _Choice(AppStrings.no, () => ref
              .read(familyChatControllerProvider.notifier)
              .submitAllergies(false)),
        ]);
      case ChatStep.feeding:
        return _choices([
          _Choice(AppStrings.choiceFeedingBreast, () => ref
              .read(familyChatControllerProvider.notifier)
              .submitFeeding(FeedingType.breastMilk)),
          _Choice(AppStrings.choiceFeedingFormula, () => ref
              .read(familyChatControllerProvider.notifier)
              .submitFeeding(FeedingType.formula)),
          _Choice(AppStrings.choiceFeedingSolid, () => ref
              .read(familyChatControllerProvider.notifier)
              .submitFeeding(FeedingType.solidFood)),
        ]);
      case ChatStep.pickyEating:
        return _choices([
          _Choice(AppStrings.yes, () => ref
              .read(familyChatControllerProvider.notifier)
              .submitPickyEating(true)),
          _Choice(AppStrings.no, () => ref
              .read(familyChatControllerProvider.notifier)
              .submitPickyEating(false)),
        ]);
      case ChatStep.exercise:
        return _choices([
          _Choice(AppStrings.choiceLevelNone, () => ref
              .read(familyChatControllerProvider.notifier)
              .submitExercise(ExerciseLevel.none)),
          _Choice(AppStrings.choiceLevelSometimes, () => ref
              .read(familyChatControllerProvider.notifier)
              .submitExercise(ExerciseLevel.sometimes)),
          _Choice(AppStrings.choiceLevelOften, () => ref
              .read(familyChatControllerProvider.notifier)
              .submitExercise(ExerciseLevel.often)),
        ]);
      case ChatStep.sleep:
        return _choices([
          _Choice(AppStrings.choiceSleepLess, () => ref
              .read(familyChatControllerProvider.notifier)
              .submitSleep(SleepHours.lessSix)),
          _Choice(AppStrings.choiceSleep78, () => ref
              .read(familyChatControllerProvider.notifier)
              .submitSleep(SleepHours.sevenEight)),
          _Choice(AppStrings.choiceSleep9, () => ref
              .read(familyChatControllerProvider.notifier)
              .submitSleep(SleepHours.nineOrMore)),
        ]);
      case ChatStep.stress:
        return _choices([
          _Choice(AppStrings.choiceStressLow, () => ref
              .read(familyChatControllerProvider.notifier)
              .submitStress(StressLevel.low)),
          _Choice(AppStrings.choiceStressMedium, () => ref
              .read(familyChatControllerProvider.notifier)
              .submitStress(StressLevel.medium)),
          _Choice(AppStrings.choiceStressHigh, () => ref
              .read(familyChatControllerProvider.notifier)
              .submitStress(StressLevel.high)),
        ]);
      case ChatStep.digestive:
        return _choices([
          _Choice(AppStrings.yes, () => ref
              .read(familyChatControllerProvider.notifier)
              .submitDigestive(true)),
          _Choice(AppStrings.no, () => ref
              .read(familyChatControllerProvider.notifier)
              .submitDigestive(false)),
        ]);
      case ChatStep.medications:
        return _choices([
          _Choice(AppStrings.yes, () => ref
              .read(familyChatControllerProvider.notifier)
              .submitMedications(true)),
          _Choice(AppStrings.no, () => ref
              .read(familyChatControllerProvider.notifier)
              .submitMedications(false)),
        ]);
      case ChatStep.currentSupplements:
        return _choices([
          _Choice(
            AppStrings.currentSupplementsHasYes,
            () => ref
                .read(familyChatControllerProvider.notifier)
                .submitHasSupplements(true),
          ),
          _Choice(
            AppStrings.currentSupplementsHasNo,
            () => ref
                .read(familyChatControllerProvider.notifier)
                .submitHasSupplements(false),
          ),
        ]);
      case ChatStep.currentSupplementsPick:
        return _ProductsPicker(
          products: _productsList(),
          onDone: (picked) => ref
              .read(familyChatControllerProvider.notifier)
              .submitCurrentSupplementsList(picked),
          onAddManual: () async {
            // 온보딩 단계에서는 아직 memberId 가 없으므로 빈 문자열을 넘긴다.
            // ManualSupplementInputScreen 은 멤버를 못 찾으면 멤버 업데이트를
            // 스킵하고 repo 에만 저장한다.
            await context.push<String>(
              '/supplement/manual-input?member_id=',
            );
            // repo invalidate → 다시 watch 시 사용자 추가 항목까지 포함된 목록 노출.
            ref.invalidate(productRepositoryProvider);
          },
        );
      case ChatStep.heightWeight:
        return _HeightWeightInput(
          input: widget.state.input,
          onSubmit: (h, w) => ref
              .read(familyChatControllerProvider.notifier)
              .submitHeightWeight(h, w),
        );
      case ChatStep.stoolFrequency:
        return _choices([
          _Choice(AppStrings.stoolDaily, () => ref
              .read(familyChatControllerProvider.notifier)
              .submitStoolFrequency(StoolFrequency.daily)),
          _Choice(AppStrings.stoolTwoToThree, () => ref
              .read(familyChatControllerProvider.notifier)
              .submitStoolFrequency(StoolFrequency.twoToThreeDays)),
          _Choice(AppStrings.stoolWeekly, () => ref
              .read(familyChatControllerProvider.notifier)
              .submitStoolFrequency(StoolFrequency.weekly)),
          _Choice(AppStrings.stoolLess, () => ref
              .read(familyChatControllerProvider.notifier)
              .submitStoolFrequency(StoolFrequency.less)),
        ]);
      case ChatStep.stoolForm:
        return _choices([
          _Choice(AppStrings.stoolHard, () => ref
              .read(familyChatControllerProvider.notifier)
              .submitStoolForm(StoolForm.hard)),
          _Choice(AppStrings.stoolNormal, () => ref
              .read(familyChatControllerProvider.notifier)
              .submitStoolForm(StoolForm.normal)),
          _Choice(AppStrings.stoolSoft, () => ref
              .read(familyChatControllerProvider.notifier)
              .submitStoolForm(StoolForm.soft)),
          _Choice(AppStrings.stoolWatery, () => ref
              .read(familyChatControllerProvider.notifier)
              .submitStoolForm(StoolForm.watery)),
        ]);
      case ChatStep.allergyItems:
        return _AllergyPicker(
          onDone: (items) => ref
              .read(familyChatControllerProvider.notifier)
              .submitAllergyItems(items),
        );
      case ChatStep.eatsVegetables:
        return _choices([
          _Choice(AppStrings.yes, () => ref
              .read(familyChatControllerProvider.notifier)
              .submitEatsVegetables(true)),
          _Choice(AppStrings.no, () => ref
              .read(familyChatControllerProvider.notifier)
              .submitEatsVegetables(false)),
        ]);
      case ChatStep.eatsFish:
        return _choices([
          _Choice(AppStrings.yes, () => ref
              .read(familyChatControllerProvider.notifier)
              .submitEatsFish(true)),
          _Choice(AppStrings.no, () => ref
              .read(familyChatControllerProvider.notifier)
              .submitEatsFish(false)),
        ]);
      case ChatStep.done:
        return FilledButton(
          onPressed: _saving ? null : _finish,
          child: _saving
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Colors.white,
                  ),
                )
              : const Text(AppStrings.onboardingSubmit),
        );
    }
  }

  Widget _completionChoices() {
    final isOwn = widget.mode == FamilyChatMode.own;
    final options = isOwn
        ? [
            _Choice(AppStrings.completionOwnYes, _onCompletionAddFamily),
            _Choice(AppStrings.completionOwnLater, _onCompletionLater),
          ]
        : [
            _Choice(AppStrings.completionFamilyMore, _onCompletionAddFamily),
            _Choice(AppStrings.completionFamilyDone, _onCompletionStart),
          ];
    return _choices(options);
  }

  void _onCompletionAddFamily() {
    context.go(FamilySelectScreen.routeName);
  }

  void _onCompletionLater() {
    context.go(NotificationSettingsScreen.onboardingRoute);
  }

  Future<void> _onCompletionStart() async {
    final notif =
        await SecureStorage.read(SecureStorage.kNotificationSettings);
    if (!mounted) return;
    if (notif != null) {
      context.go('/home');
    } else {
      context.go(NotificationSettingsScreen.onboardingRoute);
    }
  }

  Widget _textInput({
    required String hint,
    String? subHint,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _textCtrl,
                // step 이 바뀌면 KeyedSubtree key 가 갱신돼 TextField 가 새로
                // 만들어진다 → autofocus 가 매번 발동 → 사용자가 입력창을 다시
                // 탭할 필요 없이 키보드가 즉시 떠오른다.
                autofocus: true,
                keyboardType: keyboardType,
                textInputAction: TextInputAction.send,
                inputFormatters: inputFormatters,
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: TextStyle(
                    color: AppTheme.textSecondary
                        .withValues(alpha: 0.5),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  filled: true,
                  fillColor: AppTheme.background,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppTheme.primary,
                      width: 2,
                    ),
                  ),
                ),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.ink,
                ),
                onSubmitted: (_) => _sendText(),
              ),
            ),
            const SizedBox(width: 12),
            IconButton.filled(
              onPressed: _sendText,
              icon: const Icon(Icons.arrow_upward),
              style: IconButton.styleFrom(
                backgroundColor: AppTheme.primary,
                minimumSize: const Size(48, 48),
              ),
            ),
          ],
        ),
        if (subHint != null) ...[
          const SizedBox(height: 6),
          Text(
            subHint,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.subtle,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }

  Widget _choices(List<_Choice> options) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options
          .map(
            (c) => OutlinedButton(
              onPressed: c.onTap,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 48),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                side: const BorderSide(color: AppTheme.primary),
                foregroundColor: AppTheme.primary,
              ),
              child: Text(
                c.label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          )
          .toList(),
    );
  }

  /// 제품 picker 가 사용할 제품 목록. 부모 화면이 repo 로드를 기다린 뒤에만
  /// 본문을 렌더하므로 여기서는 항상 hasValue.
  List<Product> _productsList() {
    final repoAsync = ref.read(productRepositoryProvider);
    if (!repoAsync.hasValue) return const [];
    return repoAsync.requireValue.products;
  }

  Future<void> _sendText() async {
    final text = _textCtrl.text;
    if (text.trim().isEmpty) return;
    _textCtrl.clear();
    FocusManager.instance.primaryFocus?.unfocus();
    await ref.read(familyChatControllerProvider.notifier).submitText(text);
  }

  Future<void> _finish() async {
    final input = widget.state.input;
    if (!input.isComplete) {
      // silent return 대신 사용자에게 안내 — 어떤 필드가 빠졌는지 모르면 버튼이
      // 죽은 것처럼 보임. 이전에 child/newborn 흐름에서 이 silent return 이
      // 모든 단계 입력 후에도 발생해서 디버그가 어려웠음.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('아직 답변하지 않은 항목이 있어요. 위로 올라가서 확인해주세요'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      // 1. 평문은 메모리 밖으로 나가지 않음. 디스크 저장 시 AES-256.
      final cipher = EncryptionService.instance.encryptJson(input.toJson());

      // 2. 인덱스에 ID 추가, 페이로드는 별도 키로.
      final id = DateTime.now().millisecondsSinceEpoch.toString();
      final indexRaw =
          await SecureStorage.read(SecureStorage.kFamilyDraftsIndex);
      final List<String> ids = indexRaw == null
          ? <String>[]
          : (jsonDecode(indexRaw) as List).map((e) => e.toString()).toList();
      ids.add(id);
      await SecureStorage.write(
        SecureStorage.kFamilyDraftsIndex,
        jsonEncode(ids),
      );
      await SecureStorage.write(SecureStorage.familyDraftKey(id), cipher);

      // 새 멤버가 가진 모든 currentProductIds 에 대해 재구매 알림을 자동 예약.
      // (manual 입력 항목 포함 — 통 사이즈 / 1일 복용량만 있으면 알림 가능)
      await _scheduleReordersForNewMember(id, input);

      // 검진 결과가 함께 입력됐으면 1년 뒤 검진 알림도 예약.
      final checkup = input.lastCheckup;
      if (checkup != null) {
        final notif = ref.read(notificationSettingsProvider);
        if (notif.checkupEnabled) {
          await NotificationService.scheduleCheckupReminder(
            memberId: id,
            lastCheckupDate: checkup.checkupDate,
          );
        }
      }

      // TODO(supabase): user 인증 후 supabase의 family_members 테이블에 upsert.
      ref.invalidate(familyMembersProvider);
      ref.invalidate(homeFeedProvider);

      // 가족이 추가되면 통합 알림 본문(이름 목록) 도 stale — 알림이 이미 설정된
      // 상태라면 새 가족 이름이 반영되도록 재예약. 첫 온보딩(아직 설정 전) 에선
      // 호출해도 default 로 스케줄돼버려 의도와 어긋나므로 가드.
      final notifRaw =
          await SecureStorage.read(SecureStorage.kNotificationSettings);
      if (notifRaw != null) {
        await ref
            .read(notificationSettingsProvider.notifier)
            .persistAndSchedule();
      }

      if (!mounted) return;

      // (a) manage 모드 = 가족 관리/홈에서 push 진입 → 이전 화면으로 pop.
      if (widget.mode == FamilyChatMode.manage) {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/home');
        }
        return;
      }

      // (b) own / onboarding 모드 → 채팅에 완료 메시지 이어 붙이고 옵션 노출.
      await ref
          .read(familyChatControllerProvider.notifier)
          .pushCompletion(isOwn: widget.mode == FamilyChatMode.own);
      if (!mounted) return;
      setState(() => _completionShown = true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// 새로 저장된 멤버 [id] 의 currentProductIds 각각에 대해 재구매 알림을
  /// 예약한다. 사용자가 설정 화면에서 reorder 토글을 끄면 예약을 스킵한다.
  /// started_date 는 토글과 무관하게 항상 기록 — 나중에 켜졌을 때 재계산용.
  Future<void> _scheduleReordersForNewMember(
    String memberId,
    FamilyInput input,
  ) async {
    final productIds = input.currentProductIds ?? const <String>[];
    if (productIds.isEmpty) return;
    final repoAsync = ref.read(productRepositoryProvider);
    if (!repoAsync.hasValue) return;
    final repo = repoAsync.requireValue;
    final notif = ref.read(notificationSettingsProvider);
    final now = DateTime.now();
    for (final pid in productIds) {
      final p = repo.getById(pid);
      if (p == null) continue;
      if (p.packageSize <= 0 || p.dailyDose <= 0) continue;
      await SecureStorage.write(
        'started.$memberId.$pid',
        now.toIso8601String(),
      );
      if (!notif.reorderEnabled) continue;
      await NotificationService.scheduleProductReorderReminder(
        memberId: memberId,
        productId: pid,
        productName: p.name,
        startedDate: now,
        packageSize: p.packageSize,
        dailyDose: p.dailyDose,
        daysBefore: notif.reorderDaysBefore,
      );
    }
  }
}

class _Choice {
  _Choice(this.label, this.onTap);
  final String label;
  final VoidCallback onTap;
}

/// "지금 드시는 영양제" 인라인 picker — 제품(products.json) 기반.
/// - 위쪽: 선택된 제품 chip
/// - 카테고리 필터 chip (가로 스크롤)
/// - 검색 필드 (선택)
/// - 카테고리 선택 시 그 카테고리 제품 카드 리스트 (세로 스크롤, max 280)
/// - 맨 아래: 완료 버튼 — 빈 리스트도 허용.
class _ProductsPicker extends StatefulWidget {
  const _ProductsPicker({
    required this.products,
    required this.onDone,
    this.onAddManual,
  });

  final List<Product> products;
  final ValueChanged<List<String>> onDone;

  /// "위에 없는 영양제" 직접 추가 진입점. null 이면 버튼이 노출되지 않는다.
  final Future<void> Function()? onAddManual;

  @override
  State<_ProductsPicker> createState() => _ProductsPickerState();
}

class _ProductsPickerState extends State<_ProductsPicker> {
  final TextEditingController _query = TextEditingController();
  final Set<String> _selectedIds = <String>{};
  String? _activeCategory;

  static const _categoryOrder = <String>[
    'multivitamin',
    'vitamin_d_complex',
    'omega3',
    'magnesium_complex',
    'calcium_complex',
    'b_complex',
    'probiotics',
  ];

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  /// 검색 + 카테고리 + 미선택 필터를 모두 적용한 후보.
  /// 검색어가 있으면 카테고리 무시 (전체 검색). 없으면 활성 카테고리 안에서.
  ///
  /// 검색 매칭 대상 (느슨한 contains):
  ///   - product.name (브랜드/상품명)
  ///   - product.category (예: 'probiotics')
  ///   - 카테고리 한글 라벨 (예: '유산균') — 사용자가 "유산균" 으로 검색해도
  ///     락토핏 등이 나오도록 (이전에는 이름에 '유산균' 글자 없으면 누락됐음)
  ///   - product.goodFor 항목 (예: '면역', '장 건강')
  List<Product> _matches() {
    final q = _query.text.trim().toLowerCase();
    final source = q.isEmpty
        ? (_activeCategory == null
            ? const <Product>[]
            : widget.products.where((p) => p.category == _activeCategory))
        : widget.products.where((p) {
            if (p.name.toLowerCase().contains(q)) return true;
            if (p.category.toLowerCase().contains(q)) return true;
            final koLabel = productCategoryDisplayName[p.category];
            if (koLabel != null && koLabel.toLowerCase().contains(q)) {
              return true;
            }
            for (final g in p.goodFor) {
              if (g.toLowerCase().contains(q)) return true;
            }
            return false;
          });
    return [for (final p in source) if (!_selectedIds.contains(p.id)) p];
  }

  void _toggle(Product p) {
    setState(() {
      if (_selectedIds.contains(p.id)) {
        _selectedIds.remove(p.id);
      } else {
        _selectedIds.add(p.id);
      }
    });
  }

  void _remove(String id) {
    setState(() => _selectedIds.remove(id));
  }

  Product? _byId(String id) {
    for (final p in widget.products) {
      if (p.id == id) return p;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final matches = _matches();
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 420),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_selectedIds.isNotEmpty) ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final id in _selectedIds)
                  if (_byId(id) != null)
                    _SelectedChip(
                      name: _byId(id)!.name,
                      onRemove: () => _remove(id),
                    ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          // 카테고리 필터.
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _categoryOrder.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final cat = _categoryOrder[i];
                final label = productCategoryDisplayName[cat] ?? cat;
                final active = _activeCategory == cat;
                return _CategoryChip(
                  label: label,
                  active: active,
                  onTap: () => setState(() {
                    _activeCategory = active ? null : cat;
                  }),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _query,
            textInputAction: TextInputAction.search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: AppStrings.productPickerSearchHint,
              hintStyle: TextStyle(
                color: AppTheme.textSecondary.withValues(alpha: 0.5),
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
              filled: true,
              fillColor: AppTheme.background,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              prefixIcon: const Icon(Icons.search, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppTheme.primary,
                  width: 2,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: matches.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      AppStrings.productPickerEmpty,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.subtle,
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: matches.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (_, i) {
                      final p = matches[i];
                      return _ProductCard(
                        product: p,
                        selected: _selectedIds.contains(p.id),
                        onTap: () => _toggle(p),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 12),
          if (widget.onAddManual != null) ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await widget.onAddManual!.call();
                  if (mounted) setState(() {});
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text(
                  '+ 위에 없으면 직접 추가하기',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  side: BorderSide(
                    color: AppTheme.primary.withValues(alpha: 0.4),
                  ),
                  foregroundColor: AppTheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => widget.onDone(_selectedIds.toList()),
              child: const Text(AppStrings.currentSupplementsDone),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? AppTheme.primary : AppTheme.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active
                ? AppTheme.primary
                : AppTheme.primary.withValues(alpha: 0.25),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : AppTheme.primary,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.selected,
    required this.onTap,
  });

  final Product product;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brand = productBrandTypeLabel[product.brandType] ?? product.brandType;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? AppTheme.cream : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppTheme.primary : AppTheme.line,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          product.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.background,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          brand,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppTheme.subtle,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppStrings.productCardPackage(
                      product.packageSize,
                      product.unit,
                      product.packagePriceKrw,
                    ),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    AppStrings.productCardDailyNoCost(
                      product.dailyDose,
                      product.unit,
                    ),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.subtle,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.check_circle
                  : Icons.radio_button_unchecked,
              color: selected ? AppTheme.primary : AppTheme.subtle,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectedChip extends StatelessWidget {
  const _SelectedChip({required this.name, required this.onRemove});
  final String name;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: const Padding(
              padding: EdgeInsets.all(2),
              child: Icon(Icons.close, color: Colors.white, size: 16),
            ),
          ),
        ],
      ),
    );
  }
}

/// 키 + 몸무게 동시 입력 위젯. 둘 다 비울 수도 있음 (전부 모르면 그냥 다음).
/// 입력값에 따라 또래 대비 라벨을 그 자리에서 보여 준다.
class _HeightWeightInput extends StatefulWidget {
  const _HeightWeightInput({required this.input, required this.onSubmit});

  final FamilyInput input;
  final void Function(double? heightCm, double? weightKg) onSubmit;

  @override
  State<_HeightWeightInput> createState() => _HeightWeightInputState();
}

class _HeightWeightInputState extends State<_HeightWeightInput> {
  final _heightCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final h = widget.input.heightCm;
    final w = widget.input.weightKg;
    if (h != null) _heightCtrl.text = h.toStringAsFixed(1);
    if (w != null) _weightCtrl.text = w.toStringAsFixed(1);
  }

  @override
  void dispose() {
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final h = double.tryParse(_heightCtrl.text.trim());
    final w = double.tryParse(_weightCtrl.text.trim());
    widget.onSubmit(h, w);
  }

  @override
  Widget build(BuildContext context) {
    final h = double.tryParse(_heightCtrl.text.trim());
    final peerLabel = heightPeerLabel(
      ageYears: widget.input.age,
      sexStorage: widget.input.sex?.storage,
      heightCm: h,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _heightCtrl,
                // 키몸무게 단계 진입 시 첫 칸(키) 에 자동 focus → 숫자 키패드 즉시 표시.
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (_) => setState(() {}),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: _hwDecoration(AppStrings.childHeightHint),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _weightCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (_) => setState(() {}),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: _hwDecoration(AppStrings.childWeightHint),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        if (peerLabel != null) ...[
          const SizedBox(height: 8),
          Text(
            peerLabel,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _submit,
            child: const Text(AppStrings.checkupNext),
          ),
        ),
      ],
    );
  }

  InputDecoration _hwDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: AppTheme.textSecondary.withValues(alpha: 0.5),
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        filled: true,
        fillColor: AppTheme.background,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primary, width: 2),
        ),
      );
}

/// 알레르기 항목 다중 선택. "없어요" 누르면 빈 리스트로 제출.
class _AllergyPicker extends StatefulWidget {
  const _AllergyPicker({required this.onDone});
  final ValueChanged<List<String>> onDone;

  @override
  State<_AllergyPicker> createState() => _AllergyPickerState();
}

class _AllergyPickerState extends State<_AllergyPicker> {
  static const _items = <String>[
    AppStrings.allergyMilk,
    AppStrings.allergyEgg,
    AppStrings.allergyNuts,
    AppStrings.allergyWheat,
    AppStrings.allergyShrimp,
    AppStrings.allergyFish,
    AppStrings.allergySoy,
  ];

  final Set<String> _picked = <String>{};

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in _items)
              _AllergyChip(
                label: item,
                selected: _picked.contains(item),
                onTap: () => setState(() {
                  if (_picked.contains(item)) {
                    _picked.remove(item);
                  } else {
                    _picked.add(item);
                  }
                }),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => widget.onDone(const []),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  side: const BorderSide(color: AppTheme.line),
                  foregroundColor: AppTheme.subtle,
                ),
                child: const Text(AppStrings.allergyNone),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: () => widget.onDone(_picked.toList()),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                ),
                child: const Text(AppStrings.checkupNext),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AllergyChip extends StatelessWidget {
  const _AllergyChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary : AppTheme.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? AppTheme.primary
                : AppTheme.primary.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppTheme.primary,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

