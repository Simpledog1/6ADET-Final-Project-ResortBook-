import 'package:flutter_test/flutter_test.dart';

import 'package:final_project/logic/account_rules.dart';

void main() {
  group('name', () {
    test('required', () {
      expect(AccountRules.validateName(null), isNotNull);
      expect(AccountRules.validateName('   '), isNotNull);
      expect(AccountRules.validateName('Ana'), isNull);
    });
  });

  group('email', () {
    test('required and must look like an email', () {
      expect(AccountRules.validateEmail(''), 'Enter your email');
      expect(AccountRules.validateEmail('plain'), isNotNull);
      expect(AccountRules.validateEmail('a@b'), isNotNull);
      expect(AccountRules.validateEmail('a b@c.com'), isNotNull);
      expect(AccountRules.validateEmail(' a@b.com '), isNull);
    });
  });

  group('password', () {
    test('minimum length is 8', () {
      expect(AccountRules.validatePassword(''), isNotNull);
      expect(AccountRules.validatePassword('1234567'), isNotNull);
      expect(AccountRules.validatePassword('12345678'), isNull);
    });
  });

  group('confirm password', () {
    test('must be filled and equal', () {
      expect(AccountRules.validateConfirmPassword('abcdefgh', ''), isNotNull);
      expect(
        AccountRules.validateConfirmPassword('abcdefgh', 'abcdefgx'),
        'Passwords do not match',
      );
      expect(
        AccountRules.validateConfirmPassword('abcdefgh', 'abcdefgh'),
        isNull,
      );
    });
  });
}
