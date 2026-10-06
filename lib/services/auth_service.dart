import 'package:pocketbase/pocketbase.dart';
import 'pocketbase_service.dart';

/// Sign-in operations the app needs. Screens take one as an optional
/// parameter so widget tests can pass a fake instead of a PocketBase server.
abstract class AuthGateway {
  /// Whether a signed-in session currently exists.
  bool get isSignedIn;

  /// Email of the signed-in user, if any.
  String? get userEmail;

  /// Signs in with email + password. Throws [AuthException] when the
  /// credentials are wrong or the server can't be reached.
  Future<void> signIn(String email, String password);

  /// Ends the session (clears the stored login).
  Future<void> signOut();

  /// Checks a restored session with the server and clears it when it is no
  /// longer valid. Returns whether the user is still signed in.
  Future<bool> restoreSession();
}

/// Sign-in failed. [message] is safe to show to the user.
class AuthException implements Exception {
  final String message;
  const AuthException(this.message);

  @override
  String toString() => message;
}

/// PocketBase implementation: users live in the built-in `users` auth
/// collection. Accounts are created by a PocketBase superuser only; there is
/// no sign-up in the app (and the API's create rule is closed).
class PocketBaseAuthGateway implements AuthGateway {
  const PocketBaseAuthGateway();

  @override
  bool get isSignedIn => PocketBaseService.pb.authStore.isValid;

  @override
  String? get userEmail =>
      PocketBaseService.pb.authStore.record?.getStringValue('email');

  @override
  Future<void> signIn(String email, String password) async {
    try {
      await PocketBaseService.pb
          .collection('users')
          .authWithPassword(email.trim(), password);
    } on ClientException catch (e) {
      if (e.statusCode == 400 || e.statusCode == 401 || e.statusCode == 403) {
        throw const AuthException('Incorrect email or password.');
      }
      throw const AuthException(
        'Cannot reach the ResortBook server. Check your connection and try again.',
      );
    }
  }

  @override
  Future<void> signOut() async => PocketBaseService.pb.authStore.clear();

  @override
  Future<bool> restoreSession() async {
    final store = PocketBaseService.pb.authStore;
    if (!store.isValid) {
      store.clear();
      return false;
    }
    try {
      await PocketBaseService.pb.collection('users').authRefresh();
      return true;
    } on ClientException catch (e) {
      // Rejected by the server (user removed, password changed): sign out.
      if (e.statusCode == 400 ||
          e.statusCode == 401 ||
          e.statusCode == 403 ||
          e.statusCode == 404) {
        store.clear();
        return false;
      }
      // Server unreachable: keep the session; screens show their own errors.
      return true;
    }
  }
}
