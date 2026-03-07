import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../constants/constants.dart';
import '../../../../log.dart';

enum AuthStatus {
  uninitialized,
  authenticating,
  authenticated,
  authenticateError,
  authenticateCanceled,
  unauthenticated,
}

class DosukAuthProvider extends ChangeNotifier {
  final FirebaseAuth firebaseAuth;
  final GoogleSignIn googleSignIn;
  final SharedPreferences prefs;

  AuthStatus _status = AuthStatus.uninitialized;

  AuthStatus get status => _status;

  DosukAuthProvider({
    required this.firebaseAuth,
    required this.googleSignIn,
    required this.prefs,
  });

  String? getUserId() => prefs.getString(FirestoreConstants.userId);

  Future<bool> isLoggedIn() async {
    try {
      await firebaseAuth.currentUser?.getIdToken();
      final bool firebaseLoggedIn = firebaseAuth.currentUser != null;
      final bool hasUserId =
          prefs.getString(FirestoreConstants.userId)?.isNotEmpty == true;
      return firebaseLoggedIn && hasUserId;
    } catch (e) {
      logger.e(e);
      return false;
    }
  }

  /// Googleサインイン
  Future<bool> signInWithGoogle() async {
    _updateStatus(AuthStatus.authenticating);
    try {
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        _updateStatus(AuthStatus.authenticateCanceled);
        return false;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential =
          await firebaseAuth.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user == null) {
        _updateStatus(AuthStatus.authenticateError);
        return false;
      }

      await _saveUserToPrefs(user);
      _updateStatus(AuthStatus.authenticated);
      return true;
    } catch (e, stackTrace) {
      logger.e(e, stackTrace: stackTrace);
      _updateStatus(AuthStatus.authenticateError);
      return false;
    }
  }

  /// Email/Passwordサインイン
  Future<bool> signInWithEmail(String email, String password) async {
    _updateStatus(AuthStatus.authenticating);
    try {
      final UserCredential userCredential =
          await firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final User? user = userCredential.user;

      if (user == null) {
        _updateStatus(AuthStatus.authenticateError);
        return false;
      }

      if (!user.emailVerified) {
        _updateStatus(AuthStatus.unauthenticated);
        return false;
      }

      await _saveUserToPrefs(user);
      _updateStatus(AuthStatus.authenticated);
      return true;
    } on FirebaseAuthException catch (e) {
      logger.w('Email sign-in failed: ${e.code}');
      _updateStatus(AuthStatus.authenticateError);
      return false;
    } catch (e, stackTrace) {
      logger.e(e, stackTrace: stackTrace);
      _updateStatus(AuthStatus.authenticateError);
      return false;
    }
  }

  /// ログアウト
  Future<void> signOut() async {
    _status = AuthStatus.uninitialized;
    await firebaseAuth.signOut();
    try {
      await googleSignIn.signOut();
    } catch (e) {
      logger.w('Google sign-out failed: $e');
    }
    await prefs.clear();
    notifyListeners();
  }

  /// Firebaseトークンを取得 (API呼び出し時に使用)
  Future<String?> getIdToken() async {
    try {
      return await firebaseAuth.currentUser?.getIdToken();
    } catch (e) {
      logger.e(e);
      return null;
    }
  }

  Future<void> _saveUserToPrefs(User user) async {
    await prefs.setString(FirestoreConstants.userId, user.uid);
    await prefs.setString(FirestoreConstants.name, user.displayName ?? '');
    await prefs.setString(FirestoreConstants.email, user.email ?? '');
    await prefs.setString(FirestoreConstants.photoUrl, user.photoURL ?? '');
  }

  void _updateStatus(AuthStatus status) {
    _status = status;
    notifyListeners();
  }
}
