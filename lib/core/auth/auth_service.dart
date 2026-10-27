import 'dart:async';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../models/user_model.dart';
import '../../firebase_options.dart';
import 'windows_google_auth.dart';

class AuthService {
  static final AuthService instance = AuthService._internal();
  AuthService._internal();

  bool _isFirebaseInitialized = false;
  bool _isGoogleSignInInitialized = false;

  /// Initializes Firebase and Google Sign-In with safe platform checks.
  Future<void> initialize() async {
    if (_isFirebaseInitialized) return;

    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      _isFirebaseInitialized = true;
      return;
    }

    try {
      if (kIsWeb ||
          Platform.isAndroid ||
          Platform.isIOS ||
          Platform.isMacOS ||
          Platform.isWindows) {
        if (Firebase.apps.isEmpty) {
          try {
            await Firebase.initializeApp(
              options: DefaultFirebaseOptions.currentPlatform,
            );
          } catch (_) {
            await Firebase.initializeApp();
          }
        }
        _isFirebaseInitialized = true;
        debugPrint('[MyMusic][Auth] Firebase initialized successfully');
      }
    } catch (e) {
      debugPrint('[MyMusic][Auth] Firebase initialization note: $e');
    }

    try {
      if (kIsWeb || Platform.isAndroid || Platform.isIOS) {
        await GoogleSignIn.instance.initialize(
          serverClientId:
              '303373323332-f74c980pb4qjigb4k7i5lamqrd50qafe.apps.googleusercontent.com',
        );
        _isGoogleSignInInitialized = true;
        debugPrint('[MyMusic][Auth] GoogleSignIn initialized successfully');
      }
    } catch (e) {
      debugPrint('[MyMusic][Auth] GoogleSignIn initialization note: $e');
    }
  }

  /// Sign in using Google Sign-In and Firebase Authentication.
  Future<UserModel> signInWithGoogle() async {
    await initialize();

    // Windows Desktop: Firebase-hosted web helper + loopback hand-back.
    // No client_secret, no own backend. (RFC 8252 PKCE loopback is kept in
    // WindowsGoogleAuth.signIn as a fallback, but the Desktop OAuth client of
    // this project enforces a client_secret, so the web helper is the default.)
    if (!kIsWeb && Platform.isWindows) {
      final user = await WindowsGoogleAuth.signInWithWebHelper();
      if (kDebugMode) {
        debugPrint('[AuthService] Windows Google sign-in completed');
      }
      return user;
    }

    // Android / iOS / Web: use existing verified Google Sign-In flow
    try {
      if (!_isGoogleSignInInitialized) {
        try {
          await GoogleSignIn.instance.initialize(
            serverClientId:
                '303373323332-f74c980pb4qjigb4k7i5lamqrd50qafe.apps.googleusercontent.com',
          );
          _isGoogleSignInInitialized = true;
        } catch (_) {}
      }

      final GoogleSignInAccount? account;
      try {
        account = await GoogleSignIn.instance.authenticate();
      } catch (e) {
        final errStr = e.toString().toLowerCase();
        if (errStr.contains('canceled') ||
            errStr.contains('cancelled') ||
            errStr.contains('12501')) {
          throw const AuthException('Masuk dengan Google dibatalkan.');
        }
        throw AuthException(mapAuthError(e));
      }

      final authTokens = account.authentication;
      final idToken = authTokens.idToken;

      if (idToken == null || idToken.isEmpty) {
        // Fallback: if idToken is unavailable from provider, construct user from account directly
        return UserModel.fromFirebaseUser(
          uid: 'google_${account.id}',
          displayName: account.displayName,
          email: account.email,
          photoUrl: account.photoUrl,
          provider: 'google',
        );
      }

      final OAuthCredential credential = GoogleAuthProvider.credential(
        idToken: idToken,
      );

      final UserCredential userCredential = await FirebaseAuth.instance
          .signInWithCredential(credential);
      final User? fbUser = userCredential.user;

      if (fbUser == null) {
        throw const AuthException(
          'Gagal mendapatkan profil pengguna dari Google.',
        );
      }

      return UserModel.fromFirebaseUser(
        uid: fbUser.uid,
        displayName: fbUser.displayName ?? account.displayName,
        email: fbUser.email ?? account.email,
        photoUrl: fbUser.photoURL ?? account.photoUrl,
        provider: 'google',
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(mapAuthError(e));
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException(mapAuthError(e));
    }
  }

  /// Sign in with Email and Password via Firebase Authentication.
  Future<UserModel> signInWithEmail({
    required String email,
    required String password,
  }) async {
    await initialize();

    try {
      final UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
            email: email.trim(),
            password: password.trim(),
          );

      final User? fbUser = userCredential.user;
      if (fbUser == null) {
        throw const AuthException(
          'Gagal masuk. Akun pengguna tidak ditemukan.',
        );
      }

      return UserModel.fromFirebaseUser(
        uid: fbUser.uid,
        displayName: fbUser.displayName,
        email: fbUser.email,
        photoUrl: fbUser.photoURL,
        provider: 'password',
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(mapAuthError(e));
    } catch (e) {
      throw AuthException(mapAuthError(e));
    }
  }

  /// Register a new account with Name, Email, and Password via Firebase Authentication.
  Future<UserModel> registerWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    await initialize();

    try {
      final UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: email.trim(),
            password: password.trim(),
          );

      final User? fbUser = userCredential.user;
      if (fbUser == null) {
        throw const AuthException('Gagal membuat akun.');
      }

      if (name.trim().isNotEmpty) {
        try {
          await fbUser.updateDisplayName(name.trim());
        } catch (_) {}
      }

      return UserModel.fromFirebaseUser(
        uid: fbUser.uid,
        displayName: name.trim().isNotEmpty ? name.trim() : fbUser.displayName,
        email: fbUser.email,
        photoUrl: fbUser.photoURL,
        provider: 'password',
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(mapAuthError(e));
    } catch (e) {
      throw AuthException(mapAuthError(e));
    }
  }

  /// Send password reset link to user email.
  Future<void> sendPasswordReset(String email) async {
    await initialize();
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthException(mapAuthError(e));
    } catch (e) {
      throw AuthException(mapAuthError(e));
    }
  }

  /// Sign out from Firebase and Google Sign-In.
  Future<void> signOut() async {
    try {
      if (Firebase.apps.isNotEmpty) {
        await FirebaseAuth.instance.signOut();
      }
    } catch (_) {}

    try {
      if (kIsWeb || Platform.isAndroid || Platform.isIOS) {
        await GoogleSignIn.instance.signOut();
      }
    } catch (_) {}
  }

  /// Returns current Firebase user if available.
  UserModel? getCurrentUser() {
    try {
      if (Firebase.apps.isNotEmpty) {
        final fbUser = FirebaseAuth.instance.currentUser;
        if (fbUser != null) {
          final provider = fbUser.providerData.isNotEmpty
              ? (fbUser.providerData.first.providerId.contains('google')
                    ? 'google'
                    : 'password')
              : 'password';
          return UserModel.fromFirebaseUser(
            uid: fbUser.uid,
            displayName: fbUser.displayName,
            email: fbUser.email,
            photoUrl: fbUser.photoURL,
            provider: provider,
          );
        }
      }
    } catch (_) {}
    return null;
  }

  /// Stream of Firebase Auth state changes.
  Stream<User?> get authStateChanges {
    try {
      if (Firebase.apps.isNotEmpty) {
        return FirebaseAuth.instance.authStateChanges();
      }
    } catch (_) {}
    return const Stream.empty();
  }

  /// Maps Firebase exceptions and error codes into clean user-friendly messages.
  static String mapAuthError(dynamic error) {
    String rawCode = '';
    if (error is FirebaseAuthException) {
      rawCode = error.code;
    } else if (error is String) {
      rawCode = error;
    } else {
      rawCode = error.toString();
    }

    final code = eCode(rawCode);

    if (code.contains('user-not-found')) {
      return 'Akun dengan email ini tidak ditemukan.';
    }
    if (code.contains('wrong-password')) {
      return 'Password yang Anda masukkan salah.';
    }
    if (code.contains('invalid-credential')) {
      return 'Email atau password yang Anda masukkan salah.';
    }
    if (code.contains('email-already-in-use')) {
      return 'Email ini sudah terdaftar. Silakan gunakan email lain atau masuk.';
    }
    if (code.contains('invalid-email')) {
      return 'Format alamat email tidak valid.';
    }
    if (code.contains('weak-password')) {
      return 'Password terlalu lemah. Gunakan minimal 6 karakter.';
    }
    if (code.contains('user-disabled')) {
      return 'Akun ini telah dinonaktifkan oleh administrator.';
    }
    if (code.contains('network-request-failed') ||
        code.contains('network') ||
        code.contains('socket') ||
        code.contains('connection')) {
      return 'Koneksi internet bermasalah. Periksa jaringan Anda dan coba lagi.';
    }
    if (code.contains('too-many-requests')) {
      return 'Terlalu banyak percobaan gagal. Silakan tunggu beberapa saat.';
    }
    if (code.contains('operation-not-allowed')) {
      return 'Metode masuk ini belum diaktifkan di Firebase Console.';
    }
    if (code.contains('user-cancelled') ||
        code.contains('cancel') ||
        code.contains('dibatalkan') ||
        code.contains('12501')) {
      return 'Login dengan Google dibatalkan.';
    }
    if (code.contains('sign-in-failed') || code.contains('12500')) {
      return 'Gagal masuk dengan Google. Pastikan Google Play Services aktif dan SHA-1 terkonfigurasi di Firebase Console.';
    }

    if (error is FirebaseAuthException) {
      final msg = error.message?.trim();
      if (msg != null && msg.isNotEmpty && !msg.startsWith('[')) {
        return msg;
      }
    }

    return 'Terjadi kendala autentikasi. Silakan coba lagi.';
  }

  static String eCode(String code) =>
      code.toLowerCase().replaceAll('_', '-').trim();
}

class AuthException implements Exception {
  final String message;
  const AuthException(this.message);

  @override
  String toString() => message;
}
