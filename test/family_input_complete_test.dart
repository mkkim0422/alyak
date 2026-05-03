import 'package:flutter_test/flutter_test.dart';

import 'package:alyak/features/recommendation/engine/family_input.dart';

void main() {
  group('FamilyInput.isComplete — 흐름과 일치 검증', () {
    test('어린이 (10세) 흐름: pickyEating 없이도 완료', () {
      // child 흐름은 pickyEating 을 묻지 않으므로 isComplete 도 요구하면 안 됨.
      // 이 테스트가 통과해야 child 등록 후 완료 버튼이 정상 동작한다.
      final input = FamilyInput(
        name: '아이',
        age: 10,
        sex: Sex.female,
        diet: DietHabit.balanced,
        exercise: ExerciseLevel.sometimes,
        // pickyEating 의도적으로 null.
      );
      expect(input.isComplete, isTrue,
          reason: '어린이는 diet + exercise 만 있으면 완료 가능해야 한다');
    });

    test('영아 (0세) 흐름: allergyItems 만 있어도 완료 (allergies 필요 없음)', () {
      // newborn 흐름은 allergies (bool) 가 아니라 allergyItems (List) 만 묻는다.
      // legacy allergies 필드 요구는 제거돼야 함.
      final input = FamilyInput(
        name: '영아',
        age: 0,
        sex: Sex.male,
        feeding: FeedingType.breastMilk,
        allergyItems: const ['우유'],
      );
      expect(input.isComplete, isTrue,
          reason: '영아는 feeding 만 있으면 완료 가능해야 한다');
    });

    test('어린이: diet 빠지면 isComplete=false', () {
      final input = FamilyInput(
        name: '아이',
        age: 10,
        sex: Sex.female,
        exercise: ExerciseLevel.sometimes,
      );
      expect(input.isComplete, isFalse);
    });

    test('성인: smoker/drinker/diet/exercise/sleep/stress 모두 필요', () {
      final input = FamilyInput(
        name: '성인',
        age: 30,
        sex: Sex.male,
        smoker: false,
        drinker: false,
        diet: DietHabit.balanced,
        exercise: ExerciseLevel.sometimes,
        sleep: SleepHours.sevenEight,
        stress: StressLevel.medium,
      );
      expect(input.isComplete, isTrue);
    });

    test('성인: stress 빠지면 isComplete=false', () {
      final input = FamilyInput(
        name: '성인',
        age: 30,
        sex: Sex.male,
        smoker: false,
        drinker: false,
        diet: DietHabit.balanced,
        exercise: ExerciseLevel.sometimes,
        sleep: SleepHours.sevenEight,
      );
      expect(input.isComplete, isFalse);
    });
  });
}
