/// Validation for the Create Account form (pure Dart, unit-tested).
/// Each validator returns an error message, or null when the value is fine.
class AccountRules {
  AccountRules._();

  /// PocketBase's `users` password field also requires at least 8.
  static const int minPasswordLength = 8;

  static final RegExp _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$');

  static String? validateName(String? value) =>
      (value == null || value.trim().isEmpty) ? 'Enter your name' : null;

  static String? validateEmail(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Enter your email';
    if (!_email.hasMatch(v)) return 'Enter a valid email address';
    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Enter a password';
    if (value.length < minPasswordLength) {
      return 'Use at least $minPasswordLength characters';
    }
    return null;
  }

  static String? validateConfirmPassword(String password, String? confirm) {
    if (confirm == null || confirm.isEmpty) return 'Confirm your password';
    if (confirm != password) return 'Passwords do not match';
    return null;
  }
}
