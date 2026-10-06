// Login / logout / session tests. A fake AuthGateway stands in for PocketBase,
// and a small stand-in replaces the signed-in app, so no server is needed.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:final_project/screens/login_screen.dart';
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

  @override
  bool get isSignedIn => signedIn;

  @override
  String? get userEmail => signedIn ? 'demo@resortbook.test' : null;

  @override
  Future<void> signIn(String email, String password) async {
    signInCalls++;
    if (hold != null) await hold!.future;
    if (signInError != null) throw signInError!;
    if (email.trim() == 'demo@resortbook.test' &&
        password == 'correct-password') {
      signedIn = true;
      return;
    }
    throw const AuthException('Incorrect email or password.');
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
}
