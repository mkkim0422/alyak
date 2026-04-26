import '../../../recommendation/engine/family_input.dart';

enum ChatAuthor { bot, user }

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.author,
    required this.text,
    this.subText,
  });

  final int id;
  final ChatAuthor author;
  final String text;
  /// 봇 메시지에 한해 본문 아래 작은 회색으로 노출되는 부가 설명. 사용자
  /// 메시지에서는 무시된다.
  final String? subText;

  bool get isBot => author == ChatAuthor.bot;
}

/// 모든 가능한 챗봇 단계. 나이대에 따라 실제로 사용되는 부분집합이
/// [stepsForAge] 로 결정된다. `done`은 항상 마지막.
///
/// `currentSupplements` 는 모든 나이대 흐름의 마지막 직전(=done 직전) 에
/// 추가되는 옵션 단계. 사용자가 "있어요" 를 고르면 동적으로
/// `currentSupplementsPick` 으로 분기 (smokingAmount 와 같은 dynamic side-step).
enum ChatStep {
  name,
  age,
  sex,
  smoker,
  smokingAmount,
  drinker,
  drinkingType,
  drinkingFrequency,
  diet,
  allergies,
  feeding,
  pickyEating,
  exercise,
  sleep,
  stress,
  digestive,
  medications,
  currentSupplements,
  currentSupplementsPick,
  done,
}

/// 나이가 정해지기 전엔 나이대를 알 수 없으니 (name → age → done) 만 보여주고,
/// 나이가 들어오면 해당 나이대 흐름으로 확장한다. 흡연/음주 상세 질문은
/// 동적으로 (controller 가 답에 따라) 삽입되므로 여기서는 gate 까지만 둔다.
List<ChatStep> stepsForAge(int? age) {
  if (age == null) {
    return const [
      ChatStep.name,
      ChatStep.age,
      ChatStep.currentSupplements,
      ChatStep.done,
    ];
  }
  switch (AgeGroupX.fromAge(age)) {
    case AgeGroup.newborn:
      return const [
        ChatStep.name,
        ChatStep.age,
        ChatStep.sex,
        ChatStep.allergies,
        ChatStep.feeding,
        ChatStep.currentSupplements,
        ChatStep.done,
      ];
    case AgeGroup.toddler:
      return const [
        ChatStep.name,
        ChatStep.age,
        ChatStep.sex,
        ChatStep.pickyEating,
        ChatStep.currentSupplements,
        ChatStep.done,
      ];
    case AgeGroup.child:
      return const [
        ChatStep.name,
        ChatStep.age,
        ChatStep.sex,
        ChatStep.diet,
        ChatStep.pickyEating,
        ChatStep.exercise,
        ChatStep.currentSupplements,
        ChatStep.done,
      ];
    case AgeGroup.teen:
      return const [
        ChatStep.name,
        ChatStep.age,
        ChatStep.sex,
        ChatStep.diet,
        ChatStep.exercise,
        ChatStep.sleep,
        ChatStep.stress,
        ChatStep.currentSupplements,
        ChatStep.done,
      ];
    case AgeGroup.adult:
      return const [
        ChatStep.name,
        ChatStep.age,
        ChatStep.sex,
        ChatStep.smoker,
        ChatStep.drinker,
        ChatStep.diet,
        ChatStep.exercise,
        ChatStep.sleep,
        ChatStep.stress,
        ChatStep.currentSupplements,
        ChatStep.done,
      ];
    case AgeGroup.elderly:
      return const [
        ChatStep.name,
        ChatStep.age,
        ChatStep.sex,
        ChatStep.smoker,
        ChatStep.drinker,
        ChatStep.diet,
        ChatStep.exercise,
        ChatStep.sleep,
        ChatStep.digestive,
        ChatStep.medications,
        ChatStep.currentSupplements,
        ChatStep.done,
      ];
  }
}

ChatStep nextStepFor(int? age, ChatStep current) {
  final list = stepsForAge(age);
  final i = list.indexOf(current);
  if (i < 0 || i + 1 >= list.length) return ChatStep.done;
  return list[i + 1];
}

/// 0..1 진행도. `done` 일 때 1.0. 동적 step (smokingAmount, drinkingType,
/// drinkingFrequency) 은 base list 안에 없으므로 직전 gate (smoker / drinker) 의
/// 진행도를 유지한다.
double progressFor(int? age, ChatStep current) {
  final list = stepsForAge(age);
  final total = list.length - 1; // exclude `done` from denominator
  if (total <= 0) return 0;
  if (current == ChatStep.smokingAmount) {
    return _ratio(list, ChatStep.smoker, total);
  }
  if (current == ChatStep.drinkingType ||
      current == ChatStep.drinkingFrequency) {
    return _ratio(list, ChatStep.drinker, total);
  }
  if (current == ChatStep.currentSupplementsPick) {
    // dynamic side-step — base step (currentSupplements) 의 진행도를 유지.
    return _ratio(list, ChatStep.currentSupplements, total);
  }
  return _ratio(list, current, total);
}

double _ratio(List<ChatStep> list, ChatStep step, int total) {
  final i = list.indexOf(step);
  if (i < 0) return 0;
  return (i / total).clamp(0.0, 1.0);
}
