import 'package:flutter_test/flutter_test.dart';

import 'package:alyak/core/security/auth_service.dart';

void main() {
  group('AuthService crypto helpers', () {
    test('PBKDF2 는 같은 PIN/salt 에 같은 hash 를 돌려준다 (결정적)', () {
      final salt = List<int>.generate(32, (i) => i);
      final h1 = AuthService.deriveHashForTest('1234', salt);
      final h2 = AuthService.deriveHashForTest('1234', salt);
      expect(h1, equals(h2));
      expect(h1.length, equals(32),
          reason: 'PBKDF2 출력은 32 byte 여야 한다');
    });

    test('PBKDF2 는 다른 salt 에 다른 hash 를 돌려준다', () {
      final salt1 = List<int>.generate(32, (i) => i);
      final salt2 = List<int>.generate(32, (i) => 31 - i);
      final h1 = AuthService.deriveHashForTest('1234', salt1);
      final h2 = AuthService.deriveHashForTest('1234', salt2);
      expect(h1, isNot(equals(h2)),
          reason: '같은 PIN 이라도 salt 다르면 hash 달라야 함');
    });

    test('PBKDF2 는 다른 PIN 에 다른 hash 를 돌려준다', () {
      final salt = List<int>.generate(32, (i) => i);
      final h1 = AuthService.deriveHashForTest('1234', salt);
      final h2 = AuthService.deriveHashForTest('1235', salt);
      expect(h1, isNot(equals(h2)));
    });

    test('상수시간 비교: 같은 바이트열은 true, 다르면 false', () {
      final a = [1, 2, 3, 4, 5];
      final b = [1, 2, 3, 4, 5];
      final c = [1, 2, 3, 4, 6];
      final d = [1, 2, 3, 4]; // 길이 다름
      expect(AuthService.constantTimeEqualsForTest(a, b), isTrue);
      expect(AuthService.constantTimeEqualsForTest(a, c), isFalse);
      expect(AuthService.constantTimeEqualsForTest(a, d), isFalse,
          reason: '길이가 다르면 false');
    });

    test('상수시간 비교: 빈 리스트 동등', () {
      expect(
        AuthService.constantTimeEqualsForTest(<int>[], <int>[]),
        isTrue,
      );
    });
  });
}
