import 'package:carman_app/core/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Validators', () {
    test('validates email addresses', () {
      expect(Validators.email('alex@carman.app'), isNull);
      expect(Validators.email('alex@carman'), isNotNull);
      expect(Validators.email(''), isNotNull);
    });

    test('requires strong passwords', () {
      expect(Validators.password('Carman123'), isNull);
      expect(Validators.password('abc'), isNotNull);
      expect(Validators.password('alllowercaseonly'), isNotNull);
    });

    test('checks password confirmation', () {
      expect(Validators.confirmPassword('abc123', 'abc123'), isNull);
      expect(Validators.confirmPassword('abc124', 'abc123'), isNotNull);
    });

    test('validates card numbers with Luhn', () {
      expect(Validators.cardNumber('4242 4242 4242 4242'), isNull);
      expect(Validators.cardNumber('1234 5678 9012 3456'), isNotNull);
    });

    test('rejects expired cards', () {
      expect(Validators.expiry('09/27'), isNull);
      expect(Validators.expiry('01/20'), isNotNull);
      expect(Validators.expiry('13/30'), isNotNull);
    });

    test('scores password strength', () {
      expect(assessPassword('abc').score, 0);
      expect(assessPassword('Carman123').score, greaterThanOrEqualTo(3));
      expect(assessPassword('Carman123!Segura').score, 4);
    });
  });
}
