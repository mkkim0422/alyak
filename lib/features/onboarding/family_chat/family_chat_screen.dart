import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/models/supplement_guide_model.dart';
import '../../../core/data/supplement_repository.dart';
import '../../../core/l10n/app_strings.dart';
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

    if (repoAsync.isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (repoAsync.hasError) {
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

    return ProviderScope(
      overrides: [
        familyChatControllerProvider.overrideWith(
          () => FamilyChatController(
            engine,
            isOwn: mode == FamilyChatMode.own,
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
        return _SupplementsPicker(
          supplements: _supplementsList(),
          onDone: (picked) => ref
              .read(familyChatControllerProvider.notifier)
              .submitCurrentSupplementsList(picked),
        );
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

  /// 영양제 picker 가 사용할 supplement 후보 목록. 부모 화면이 repo 로드를
  /// 기다린 뒤에만 본문을 렌더하므로 여기서는 항상 hasValue.
  List<SupplementGuide> _supplementsList() {
    final repoAsync = ref.read(supplementRepositoryProvider);
    if (!repoAsync.hasValue) return const [];
    return repoAsync.requireValue.supplements;
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
    if (!input.isComplete) return;
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
}

class _Choice {
  _Choice(this.label, this.onTap);
  final String label;
  final VoidCallback onTap;
}

/// "지금 드시는 영양제" 인라인 picker.
/// - 위쪽: 선택된 영양제 (초록 chip + X)
/// - 가운데: 검색 텍스트 필드
/// - 아래: 매칭 영양제 (탭하면 선택)
/// - 맨 아래: 완료 버튼 — 빈 리스트도 허용 (사용자가 안 골랐을 때).
class _SupplementsPicker extends StatefulWidget {
  const _SupplementsPicker({
    required this.supplements,
    required this.onDone,
  });

  final List<SupplementGuide> supplements;
  final ValueChanged<List<String>> onDone;

  @override
  State<_SupplementsPicker> createState() => _SupplementsPickerState();
}

class _SupplementsPickerState extends State<_SupplementsPicker> {
  final TextEditingController _query = TextEditingController();
  final Set<String> _selected = <String>{};

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  /// 입력어 기준 부분 매칭. 입력 없으면 빈 리스트 (초기 노이즈 방지).
  /// 이미 선택된 항목은 제안에서 제외.
  List<SupplementGuide> _matches() {
    final q = _query.text.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final out = <SupplementGuide>[];
    for (final s in widget.supplements) {
      if (_selected.contains(s.nameKorean)) continue;
      final ko = s.nameKorean.toLowerCase();
      final en = s.nameEnglish.toLowerCase();
      if (ko.contains(q) || en.contains(q)) {
        out.add(s);
        if (out.length >= 6) break;
      }
    }
    return out;
  }

  void _add(String name) {
    setState(() {
      _selected.add(name);
      _query.clear();
    });
  }

  void _remove(String name) {
    setState(() => _selected.remove(name));
  }

  @override
  Widget build(BuildContext context) {
    final matches = _matches();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_selected.isNotEmpty) ...[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final name in _selected)
                _SelectedChip(name: name, onRemove: () => _remove(name)),
            ],
          ),
          const SizedBox(height: 10),
        ],
        TextField(
          controller: _query,
          textInputAction: TextInputAction.search,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: AppStrings.currentSupplementsSearchHint,
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
        if (matches.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final m in matches)
                _SuggestionChip(
                  name: m.nameKorean,
                  onTap: () => _add(m.nameKorean),
                ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => widget.onDone(_selected.toList()),
            child: const Text(AppStrings.currentSupplementsDone),
          ),
        ),
      ],
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

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({required this.name, required this.onTap});
  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppTheme.cream,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
        ),
        child: Text(
          '+ $name',
          style: const TextStyle(
            color: AppTheme.primary,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
