import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_strings.dart';
import '../../recommendation/engine/family_input.dart';
import '../../recommendation/engine/recommendation_engine.dart';
import 'models/chat_message.dart';

class FamilyChatState {
  FamilyChatState({
    required this.messages,
    required this.step,
    required this.input,
    required this.preview,
    this.botTyping = false,
  });

  final List<ChatMessage> messages;
  final ChatStep step;
  final FamilyInput input;
  final List<RecommendationResult> preview;
  final bool botTyping;

  FamilyChatState copyWith({
    List<ChatMessage>? messages,
    ChatStep? step,
    FamilyInput? input,
    List<RecommendationResult>? preview,
    bool? botTyping,
  }) {
    return FamilyChatState(
      messages: messages ?? this.messages,
      step: step ?? this.step,
      input: input ?? this.input,
      preview: preview ?? this.preview,
      botTyping: botTyping ?? this.botTyping,
    );
  }

  static FamilyChatState initial() {
    return FamilyChatState(
      messages: const [],
      step: ChatStep.name,
      input: const FamilyInput(),
      preview: const [],
    );
  }
}

class FamilyChatController extends Notifier<FamilyChatState> {
  FamilyChatController(this._engine, {this.isOwn = false});

  final RecommendationEngine _engine;
  /// 본인 등록 모드면 첫 질문에 `qNameOwn` 사용. 그 외엔 일반 `qName`.
  final bool isOwn;
  int _msgCounter = 0;

  @override
  FamilyChatState build() {
    final initial = FamilyChatState.initial();
    final firstBot = ChatMessage(
      id: _nextId(),
      author: ChatAuthor.bot,
      text: isOwn ? AppStrings.qNameOwn : AppStrings.qName,
      // 본인 모드는 부가 설명 생략 — own copy 자체가 "이름이나 별명".
      subText: isOwn ? null : AppStrings.qNameSubText,
    );
    return initial.copyWith(messages: [firstBot]);
  }

  int _nextId() => ++_msgCounter;

  /// 봇 메시지 본문 아래 작은 회색으로 노출되는 부가 안내. 해당 step 에
  /// 보조 설명이 없으면 null.
  static String? _subTextFor(ChatStep step) {
    switch (step) {
      case ChatStep.currentSupplements:
        return AppStrings.qCurrentSupplementsSub;
      default:
        return null;
    }
  }

  static String _questionFor(ChatStep step) {
    switch (step) {
      case ChatStep.name:
        return AppStrings.qName;
      case ChatStep.age:
        return AppStrings.qAge;
      case ChatStep.sex:
        return AppStrings.qSex;
      case ChatStep.smoker:
        return AppStrings.qSmoker;
      case ChatStep.smokingAmount:
        return AppStrings.qSmokingAmount;
      case ChatStep.drinker:
        return AppStrings.qDrinker;
      case ChatStep.drinkingType:
        return AppStrings.qDrinkingType;
      case ChatStep.drinkingFrequency:
        return AppStrings.qDrinkingFrequency;
      case ChatStep.diet:
        return AppStrings.qDiet;
      case ChatStep.allergies:
        return AppStrings.qAllergies;
      case ChatStep.feeding:
        return AppStrings.qFeeding;
      case ChatStep.pickyEating:
        return AppStrings.qPickyEating;
      case ChatStep.exercise:
        return AppStrings.qExercise;
      case ChatStep.sleep:
        return AppStrings.qSleep;
      case ChatStep.stress:
        return AppStrings.qStress;
      case ChatStep.digestive:
        return AppStrings.qDigestive;
      case ChatStep.medications:
        return AppStrings.qMedications;
      case ChatStep.currentSupplements:
        return AppStrings.qCurrentSupplements;
      case ChatStep.currentSupplementsPick:
        return AppStrings.qCurrentSupplementsPick;
      case ChatStep.done:
        return AppStrings.qDone;
    }
  }

  /// 이름 / 나이 자유입력. 잘못된 입력은 거부하고 봇이 다시 묻는다.
  Future<void> submitText(String raw) async {
    final text = raw.trim();
    if (text.isEmpty) return;

    switch (state.step) {
      case ChatStep.name:
        if (text.length > 20) {
          await _addBot(AppStrings.onboardingTooLongName);
          return;
        }
        await _commit(
          userText: text,
          updated: state.input.copyWith(name: text),
        );
        break;
      case ChatStep.age:
        final age = int.tryParse(text);
        if (age == null || age < 1 || age > 120) {
          await _addBot(AppStrings.onboardingAgeRange);
          return;
        }
        await _commit(
          userText: '$age세',
          updated: state.input.copyWith(age: age),
        );
        break;
      default:
        // 다른 단계에서는 텍스트 입력을 받지 않음.
        break;
    }
  }

  Future<void> submitSex(Sex sex) async {
    if (state.step != ChatStep.sex) return;
    await _commit(userText: sex.ko, updated: state.input.copyWith(sex: sex));
  }

  Future<void> submitSmoker(bool smoker) async {
    if (state.step != ChatStep.smoker) return;
    await _commit(
      userText: smoker ? AppStrings.yes : AppStrings.no,
      updated: state.input.copyWith(smoker: smoker),
      // 흡연 시 상세량 질문 삽입; 비흡연은 base 흐름으로.
      overrideNext: smoker ? ChatStep.smokingAmount : null,
    );
  }

  Future<void> submitSmokingAmount(SmokingAmount amount) async {
    if (state.step != ChatStep.smokingAmount) return;
    await _commit(
      userText: amount.ko,
      updated: state.input.copyWith(smokingAmount: amount),
      // smokingAmount 다음은 smoker 의 base 다음 step.
      overrideNext: nextStepFor(state.input.age, ChatStep.smoker),
    );
  }

  Future<void> submitDrinker(bool drinker) async {
    if (state.step != ChatStep.drinker) return;
    await _commit(
      userText: drinker ? AppStrings.yes : AppStrings.no,
      updated: state.input.copyWith(drinker: drinker),
      overrideNext: drinker ? ChatStep.drinkingType : null,
    );
  }

  Future<void> submitDrinkingType(DrinkingType type) async {
    if (state.step != ChatStep.drinkingType) return;
    await _commit(
      userText: type.ko,
      updated: state.input.copyWith(drinkingType: type),
      overrideNext: ChatStep.drinkingFrequency,
    );
  }

  Future<void> submitDrinkingFrequency(DrinkingFrequency freq) async {
    if (state.step != ChatStep.drinkingFrequency) return;
    await _commit(
      userText: freq.ko,
      updated: state.input.copyWith(drinkingFrequency: freq),
      // drinkingFrequency 다음은 drinker 의 base 다음 step.
      overrideNext: nextStepFor(state.input.age, ChatStep.drinker),
    );
  }

  Future<void> submitDiet(DietHabit diet) async {
    if (state.step != ChatStep.diet) return;
    await _commit(
      userText: diet.ko,
      updated: state.input.copyWith(diet: diet),
    );
  }

  Future<void> submitAllergies(bool hasAllergies) async {
    if (state.step != ChatStep.allergies) return;
    await _commit(
      userText: hasAllergies ? AppStrings.yes : AppStrings.no,
      updated: state.input.copyWith(allergies: hasAllergies),
    );
  }

  Future<void> submitFeeding(FeedingType feeding) async {
    if (state.step != ChatStep.feeding) return;
    await _commit(
      userText: feeding.ko,
      updated: state.input.copyWith(feeding: feeding),
    );
  }

  Future<void> submitPickyEating(bool picky) async {
    if (state.step != ChatStep.pickyEating) return;
    await _commit(
      userText: picky ? AppStrings.yes : AppStrings.no,
      updated: state.input.copyWith(pickyEating: picky),
    );
  }

  Future<void> submitExercise(ExerciseLevel level) async {
    if (state.step != ChatStep.exercise) return;
    await _commit(
      userText: level.ko,
      updated: state.input.copyWith(exercise: level),
    );
  }

  Future<void> submitSleep(SleepHours hours) async {
    if (state.step != ChatStep.sleep) return;
    await _commit(
      userText: hours.ko,
      updated: state.input.copyWith(sleep: hours),
    );
  }

  Future<void> submitStress(StressLevel level) async {
    if (state.step != ChatStep.stress) return;
    await _commit(
      userText: level.ko,
      updated: state.input.copyWith(stress: level),
    );
  }

  Future<void> submitDigestive(bool hasIssues) async {
    if (state.step != ChatStep.digestive) return;
    await _commit(
      userText: hasIssues ? AppStrings.yes : AppStrings.no,
      updated: state.input.copyWith(digestiveIssues: hasIssues),
    );
  }

  Future<void> submitMedications(bool taking) async {
    if (state.step != ChatStep.medications) return;
    await _commit(
      userText: taking ? AppStrings.yes : AppStrings.no,
      updated: state.input.copyWith(takingMedications: taking),
    );
  }

  /// "지금 드시는 영양제 있으세요?" 응답.
  /// `true` → currentSupplementsPick 으로 분기 (sub-step), `false` → 빈 리스트로
  /// done 직행.
  Future<void> submitHasSupplements(bool has) async {
    if (state.step != ChatStep.currentSupplements) return;
    if (has) {
      await _commit(
        userText: AppStrings.currentSupplementsHasYes,
        updated: state.input,
        overrideNext: ChatStep.currentSupplementsPick,
      );
    } else {
      await _commit(
        userText: AppStrings.currentSupplementsHasNo,
        updated: state.input.copyWith(currentSupplements: const []),
        overrideNext: ChatStep.done,
      );
    }
  }

  /// 검색-선택 picker 의 [완료] 결과 처리. 빈 리스트도 허용 (사용자가 안 골랐을 때).
  Future<void> submitCurrentSupplementsList(List<String> picked) async {
    if (state.step != ChatStep.currentSupplementsPick) return;
    await _commit(
      userText: picked.isEmpty
          ? AppStrings.currentSupplementsAnswerNone
          : picked.join(', '),
      updated: state.input.copyWith(currentSupplements: picked),
      overrideNext: ChatStep.done,
    );
  }

  Future<void> _commit({
    required String userText,
    required FamilyInput updated,
    ChatStep? overrideNext,
  }) async {
    // 1. user bubble
    final userMsg = ChatMessage(
      id: _nextId(),
      author: ChatAuthor.user,
      text: userText,
    );
    final preview = _engine.recommend(updated);
    state = state.copyWith(
      messages: [...state.messages, userMsg],
      input: updated,
      preview: preview,
      botTyping: true,
    );

    // 2. small thinking delay
    await Future<void>.delayed(const Duration(milliseconds: 380));

    // 3. advance step (age-aware) + bot bubble.
    //    overrideNext 가 있으면 dynamic flow (흡연/음주 상세) 로 분기.
    final next = overrideNext ?? nextStepFor(updated.age, state.step);
    final botMsg = ChatMessage(
      id: _nextId(),
      author: ChatAuthor.bot,
      text: _questionFor(next),
      subText: _subTextFor(next),
    );
    state = state.copyWith(
      messages: [...state.messages, botMsg],
      step: next,
      botTyping: false,
    );
  }

  Future<void> _addBot(String text) async {
    state = state.copyWith(botTyping: true);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final msg = ChatMessage(
      id: _nextId(),
      author: ChatAuthor.bot,
      text: text,
    );
    state = state.copyWith(
      messages: [...state.messages, msg],
      botTyping: false,
    );
  }

  /// 저장 직후 채팅 흐름에 완료 메시지를 이어 붙인다.
  /// `isOwn=true` 이면 본인 등록 완료 + "가족 등록할까요?" 라인까지,
  /// `false` 이면 가족 등록 완료 한 줄만.
  Future<void> pushCompletion({required bool isOwn}) async {
    if (isOwn) {
      await _addBot(AppStrings.completionOwnMsg1);
      await Future<void>.delayed(const Duration(milliseconds: 280));
      await _addBot(AppStrings.completionOwnMsg2);
    } else {
      await _addBot(AppStrings.completionFamilyMsg);
    }
  }
}

/// Lazily wired in [FamilyChatScreen] once the engine is loaded.
final familyChatControllerProvider =
    NotifierProvider.autoDispose<FamilyChatController, FamilyChatState>(
  () => throw UnimplementedError(
    'familyChatControllerProvider must be overridden with a configured '
    'controller via ProviderScope.overrides',
  ),
);
