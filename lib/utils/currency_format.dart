/// Philippine peso formatting without the intl package.
class CurrencyFormat {
  CurrencyFormat._();

  /// 2500 → "₱2,500"   ·   1234.5 → "₱1,234.50"
  static String peso(double amount) {
    final negative = amount < 0;
    final fixed = amount.abs().toStringAsFixed(2);
    final parts = fixed.split('.');
    final whole = parts[0];
    final cents = parts[1];

    final buffer = StringBuffer();
    for (var i = 0; i < whole.length; i++) {
      final fromEnd = whole.length - i;
      buffer.write(whole[i]);
      if (fromEnd > 1 && fromEnd % 3 == 1) buffer.write(',');
    }

    final sign = negative ? '-' : '';
    return cents == '00' ? '$sign₱$buffer' : '$sign₱$buffer.$cents';
  }
}
