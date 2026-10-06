import 'package:flutter/material.dart';
import '../screens/login_screen.dart';
import '../screens/sign_up_screen.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import 'app_shell.dart';

/// Gives screens below the gate access to sign-out (and the user's email).
/// Absent in widget tests that build a screen on its own, so UI that uses it
/// must handle `maybeOf` returning null.
class AuthScope extends InheritedWidget {
  final String? userEmail;
  final Future<void> Function() signOut;

  const AuthScope({
    super.key,
    required this.userEmail,
    required this.signOut,
    required super.child,
  });

  static AuthScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AuthScope>();

  @override
  bool updateShouldNotify(AuthScope oldWidget) =>
      userEmail != oldWidget.userEmail;
}

/// Root of the app: Login when signed out, the normal [AppShell] when signed
/// in. A saved session is checked with the server first.
class AuthGate extends StatefulWidget {
  final AuthGateway auth;

  /// The signed-in app. Defaults to [AppShell]; tests can pass a stand-in.
  final Widget? home;

  const AuthGate({
    super.key,
    this.auth = const PocketBaseAuthGateway(),
    this.home,
  });

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _checking = true;
  bool _signedIn = false;
  bool _showSignUp = false;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    var ok = false;
    if (widget.auth.isSignedIn) {
      try {
        ok = await widget.auth.restoreSession();
      } catch (_) {
        ok = false;
      }
    }
    if (!mounted) return;
    setState(() {
      _signedIn = ok;
      _checking = false;
    });
  }

  Future<void> _signOut() async {
    await widget.auth.signOut();
    if (!mounted) return;
    // Close any screens opened on top of the app before showing Login.
    Navigator.of(context).popUntil((route) => route.isFirst);
    setState(() {
      _signedIn = false;
      _showSignUp = false;
      _notice = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (!_signedIn) {
      if (_showSignUp) {
        return SignUpScreen(
          auth: widget.auth,
          onBackToLogin: () => setState(() => _showSignUp = false),
          onAccountCreated: () => setState(() {
            _showSignUp = false;
            _notice = 'Your account was created. You can now log in.';
          }),
        );
      }
      return LoginScreen(
        auth: widget.auth,
        notice: _notice,
        onCreateAccount: () => setState(() {
          _showSignUp = true;
          _notice = null;
        }),
        onSignedIn: () => setState(() {
          _signedIn = true;
          _notice = null;
        }),
      );
    }
    return AuthScope(
      userEmail: widget.auth.userEmail,
      signOut: _signOut,
      child: widget.home ?? const AppShell(),
    );
  }
}
