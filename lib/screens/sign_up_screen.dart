import 'package:flutter/material.dart';
import '../logic/account_rules.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_layout.dart';

/// Create Account page: name, email, password and confirmation. On success
/// it calls [onAccountCreated]; the user then signs in from the Login page.
class SignUpScreen extends StatefulWidget {
  final AuthGateway auth;
  final VoidCallback onAccountCreated;
  final VoidCallback onBackToLogin;

  const SignUpScreen({
    super.key,
    required this.auth,
    required this.onAccountCreated,
    required this.onBackToLogin,
  });

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  bool _hidePassword = true;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading || !_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.auth.signUp(
        name: _name.text.trim(),
        email: _email.text.trim(),
        password: _password.text,
      );
      if (!mounted) return;
      widget.onAccountCreated();
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Something went wrong. Please try again.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Create account', style: AppText.sectionTitle),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _name,
              enabled: !_loading,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
              autofillHints: const [AutofillHints.name],
              decoration: const InputDecoration(labelText: 'Name'),
              validator: AccountRules.validateName,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _email,
              enabled: !_loading,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(labelText: 'Email'),
              validator: AccountRules.validateEmail,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _password,
              enabled: !_loading,
              obscureText: _hidePassword,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newPassword],
              decoration: InputDecoration(
                labelText: 'Password',
                helperText:
                    'At least ${AccountRules.minPasswordLength} characters',
                suffixIcon: IconButton(
                  tooltip: _hidePassword ? 'Show password' : 'Hide password',
                  icon: Icon(
                    _hidePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () =>
                      setState(() => _hidePassword = !_hidePassword),
                ),
              ),
              validator: AccountRules.validatePassword,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _confirm,
              enabled: !_loading,
              obscureText: _hidePassword,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              decoration: const InputDecoration(labelText: 'Confirm password'),
              validator: (v) =>
                  AccountRules.validateConfirmPassword(_password.text, v),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              AuthMessage(text: _error!),
            ],
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              height: AppSpacing.buttonHeight,
              child: FilledButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const AuthButtonSpinner()
                    : const Text('Create Account'),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Center(
              child: Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text(
                    'Already have an account?',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  TextButton(
                    onPressed: _loading ? null : widget.onBackToLogin,
                    child: const Text('Log in'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
