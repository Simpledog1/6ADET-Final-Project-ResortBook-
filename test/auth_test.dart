// Login / logout / session tests. A fake AuthGateway stands in for PocketBase,
// and a small stand-in replaces the signed-in app, so no server is needed.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:final_project/screens/login_screen.dart';
import 'package:final_project/screens/sign_up_screen.dart';
import 'package:final_project/services/auth_service.dart';
import 'package:final_project/theme/app_theme.dart';
import 'package:final_project/widgets/app_header.dart';
import 'package:final_project/widgets/auth_gate.dart';

class FakeAuth implements AuthGateway {
  FakeAuth({this.signedIn = false, this.sessionStillValid = true});

  bool signedIn;
  final bool sessionStillValid;
  Object? signInError;
  Completer<void>? hold;
  int signInCalls = 0;
  int restoreCalls = 0;
  int signOutCalls = 0;
  int signUpCalls = 0;
  Completer<void>? signUpHold;
  Object? signUpError;

  /// Registered accounts: email -> password (the demo account exists).
  final Map<String, String> accounts = {
    'demo@resortbook.test': 'correct-password',
  };
  String? lastEmail;

  @override
  bool get isSignedIn => signedIn;

  @override
  String? get userEmail =>
      signedIn ? (lastEmail ?? 'demo@resortbook.test') : null;

  @override
  Future<void> signIn(String email, String password) async {
    signInCalls++;
    if (hold != null) await hold!.future;
    if (signInError != null) throw signInError!;
    if (accounts[email.trim()] == password) {
      signedIn = true;
      lastEmail = email.trim();
      return;
    }
    throw const AuthException('Incorrect email or password.');
  }

  @override
  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    signUpCalls++;
    if (signUpHold != null) await signUpHold!.future;
    if (signUpError != null) throw signUpError!;
    if (accounts.containsKey(email)) {
      throw const AuthException('An account with this email already exists.');
    }
    accounts[email] = password;
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    signedIn = false;
  }

  @override
  Future<bool> restoreSession() async {
    restoreCalls++;
    if (!sessionStillValid) signedIn = false;
    return sessionStillValid;
  }
}

/// Stand-in for the signed-in app; has a sign-out button like the real one.
class _Home extends StatelessWidget {
  const _Home();

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.maybeOf(context)!;
    return Scaffold(
      body: Column(
        children: [
          const Text('APP HOME'),
          Text(auth.userEmail ?? ''),
          TextButton(onPressed: auth.signOut, child: const Text('Sign out')),
        ],
      ),
    );
  }
}

Widget _app(FakeAuth auth) => MaterialApp(
  theme: AppTheme.lightTheme,
  home: AuthGate(auth: auth, home: const _Home()),
);

Future<void> _fill(WidgetTester tester, String email, String password) async {
  await tester.enterText(find.widgetWithText(TextFormField, 'Email'), email);
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Password'),
    password,
  );
}

void main() {
  testWidgets('signed out: shows Login, not the app', (tester) async {
    await tester.pumpWidget(_app(FakeAuth()));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('APP HOME'), findsNothing);
    // No public registration or password reset in the UI.
    expect(find.textContaining('Sign up'), findsNothing);
    expect(find.textContaining('Register'), findsNothing);
    expect(find.textContaining('Forgot'), findsNothing);
  });

  testWidgets('empty fields are rejected without calling the server', (
    tester,
  ) async {
    final auth = FakeAuth();
    await tester.pumpWidget(_app(auth));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    expect(find.text('Enter your email'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);
    expect(auth.signInCalls, 0);
  });

  testWidgets('invalid credentials show an error and stay on Login', (
    tester,
  ) async {
    final auth = FakeAuth();
    await tester.pumpWidget(_app(auth));
    await tester.pumpAndSettle();

    await _fill(tester, 'demo@resortbook.test', 'wrong');
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    expect(find.text('Incorrect email or password.'), findsOneWidget);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('APP HOME'), findsNothing);
    // Button usable again.
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets('server unreachable shows the message from the service', (
    tester,
  ) async {
    final auth = FakeAuth()
      ..signInError = const AuthException(
        'Cannot reach the ResortBook server.',
      );
    await tester.pumpWidget(_app(auth));
    await tester.pumpAndSettle();

    await _fill(tester, 'demo@resortbook.test', 'correct-password');
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    expect(find.text('Cannot reach the ResortBook server.'), findsOneWidget);
  });

  testWidgets('shows a loading state while signing in', (tester) async {
    final auth = FakeAuth()..hold = Completer<void>();
    await tester.pumpWidget(_app(auth));
    await tester.pumpAndSettle();

    await _fill(tester, 'demo@resortbook.test', 'correct-password');
    await tester.tap(find.text('Sign In'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Sign In'), findsNothing);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );

    auth.hold!.complete();
    await tester.pumpAndSettle();
    expect(find.text('APP HOME'), findsOneWidget);
  });

  testWidgets(
    'successful sign-in opens the app, then logout returns to Login',
    (tester) async {
      final auth = FakeAuth();
      await tester.pumpWidget(_app(auth));
      await tester.pumpAndSettle();

      await _fill(tester, '  demo@resortbook.test ', 'correct-password');
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('APP HOME'), findsOneWidget);
      expect(find.text('demo@resortbook.test'), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);

      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();

      expect(auth.signOutCalls, 1);
      expect(auth.isSignedIn, isFalse);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('APP HOME'), findsNothing);
    },
  );

  testWidgets('a valid saved session skips Login (session restoration)', (
    tester,
  ) async {
    final auth = FakeAuth(signedIn: true);
    await tester.pumpWidget(_app(auth));
    await tester.pumpAndSettle();

    expect(auth.restoreCalls, 1);
    expect(find.text('APP HOME'), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets('a saved session the server rejects shows Login', (tester) async {
    final auth = FakeAuth(signedIn: true, sessionStillValid: false);
    await tester.pumpWidget(_app(auth));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('APP HOME'), findsNothing);
  });

  testWidgets('phone header shows Sign out only inside a signed-in app', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(appBar: AppHeader.home()),
      ),
    );
    expect(find.byTooltip('Sign out'), findsNothing);

    var signedOut = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: AuthScope(
          userEmail: 'demo@resortbook.test',
          signOut: () async => signedOut = true,
          child: const Scaffold(appBar: AppHeader.home()),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Sign out'));
    expect(signedOut, isTrue);
  });

  // ---- Create account ----

  Future<void> openSignUp(WidgetTester tester) async {
    await tester.tap(find.text('Create one'));
    await tester.pumpAndSettle();
  }

  Future<void> fillSignUp(
    WidgetTester tester, {
    String name = 'New Guest',
    String email = 'new@resortbook.test',
    String password = 'new-password-1',
    String? confirm,
  }) async {
    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), name);
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), email);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      password,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirm password'),
      confirm ?? password,
    );
  }

  testWidgets('Login links to Create account and back', (tester) async {
    await tester.pumpWidget(_app(FakeAuth()));
    await tester.pumpAndSettle();

    expect(find.text("Don't have an account?"), findsOneWidget);
    await openSignUp(tester);
    expect(find.byType(SignUpScreen), findsOneWidget);
    expect(find.text('Already have an account?'), findsOneWidget);

    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('sign-up validation: required fields, email, length, match', (
    tester,
  ) async {
    final auth = FakeAuth();
    await tester.pumpWidget(_app(auth));
    await tester.pumpAndSettle();
    await openSignUp(tester);

    await tester.tap(find.text('Create Account'));
    await tester.pumpAndSettle();
    expect(find.text('Enter your name'), findsOneWidget);
    expect(find.text('Enter your email'), findsOneWidget);
    expect(find.text('Enter a password'), findsOneWidget);
    expect(find.text('Confirm your password'), findsOneWidget);

    await fillSignUp(
      tester,
      email: 'not-an-email',
      password: 'short',
      confirm: 'different',
    );
    await tester.tap(find.text('Create Account'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid email address'), findsOneWidget);
    expect(find.text('Use at least 8 characters'), findsOneWidget);
    expect(find.text('Passwords do not match'), findsOneWidget);
    expect(auth.signUpCalls, 0);
  });

  testWidgets('password confirmation must match', (tester) async {
    final auth = FakeAuth();
    await tester.pumpWidget(_app(auth));
    await tester.pumpAndSettle();
    await openSignUp(tester);

    await fillSignUp(
      tester,
      password: 'new-password-1',
      confirm: 'new-password-2',
    );
    await tester.tap(find.text('Create Account'));
    await tester.pumpAndSettle();

    expect(find.text('Passwords do not match'), findsOneWidget);
    expect(auth.signUpCalls, 0);
  });

  testWidgets('sign-up shows loading and blocks a second submit', (
    tester,
  ) async {
    final auth = FakeAuth()..signUpHold = Completer<void>();
    await tester.pumpWidget(_app(auth));
    await tester.pumpAndSettle();
    await openSignUp(tester);

    await fillSignUp(tester);
    await tester.tap(find.text('Create Account'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(auth.signUpCalls, 1);

    auth.signUpHold!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('server error on sign-up is shown and the form stays', (
    tester,
  ) async {
    final auth = FakeAuth();
    await tester.pumpWidget(_app(auth));
    await tester.pumpAndSettle();
    await openSignUp(tester);

    await fillSignUp(tester, email: 'demo@resortbook.test');
    await tester.tap(find.text('Create Account'));
    await tester.pumpAndSettle();

    expect(
      find.text('An account with this email already exists.'),
      findsOneWidget,
    );
    expect(find.byType(SignUpScreen), findsOneWidget);
  });

  testWidgets('register, see the success message, log in, then log out', (
    tester,
  ) async {
    final auth = FakeAuth();
    await tester.pumpWidget(_app(auth));
    await tester.pumpAndSettle();
    await openSignUp(tester);

    await fillSignUp(tester);
    await tester.tap(find.text('Create Account'));
    await tester.pumpAndSettle();

    // Back on Login with a success message; not signed in yet.
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(
      find.text('Your account was created. You can now log in.'),
      findsOneWidget,
    );
    expect(auth.isSignedIn, isFalse);
    expect(find.text('APP HOME'), findsNothing);

    // The new account can log in.
    await _fill(tester, 'new@resortbook.test', 'new-password-1');
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();
    expect(find.text('APP HOME'), findsOneWidget);
    expect(find.text('new@resortbook.test'), findsOneWidget);

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(
      find.text('Your account was created. You can now log in.'),
      findsNothing,
    );
  });

  testWidgets('an existing user can still log in', (tester) async {
    final auth = FakeAuth();
    await tester.pumpWidget(_app(auth));
    await tester.pumpAndSettle();
    await _fill(tester, 'demo@resortbook.test', 'correct-password');
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();
    expect(find.text('APP HOME'), findsOneWidget);
  });

  for (final size in const [Size(375, 812), Size(1280, 800)]) {
    testWidgets('Login and Create account fit at ${size.width.toInt()} px', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_app(FakeAuth()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await openSignUp(tester);
      expect(find.text('Create Account'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
