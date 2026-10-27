import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/auth/auth_service.dart';
import '../core/auth/auth_state.dart';
import '../models/user_model.dart';
import '../repositories/local_music_repository.dart';
import '../services/api/api_service.dart';

class AuthProvider with ChangeNotifier {
  static const String _kGuestKey = 'mymusic_is_guest_mode';

  final AuthService _authService = AuthService.instance;
  StreamSubscription<dynamic>? _authSubscription;

  UserModel? _user;
  AuthStatus _status = AuthStatus.loading;
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _isEmailLoading = false;
  String? _errorMessage;

  UserModel? get user => _user;
  AuthStatus get status => _status;
  bool get isAuthenticated =>
      _status == AuthStatus.authenticated && _user != null && !_user!.isGuest;
  bool get isGuest => _status == AuthStatus.guest || (_user?.isGuest ?? false);
  bool get isUnauthenticated => _status == AuthStatus.unauthenticated;
  bool get isLoading => _isLoading;
  bool get isGoogleLoading => _isGoogleLoading;
  bool get isEmailLoading => _isEmailLoading;
  String? get errorMessage => _errorMessage;

  void clearErrorMessage() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  void _setupAuthListener() {
    _authSubscription?.cancel();
    _authSubscription = _authService.authStateChanges.listen((fbUser) {
      if (fbUser != null) {
        final currentModel = _authService.getCurrentUser();
        if (currentModel != null &&
            (_status != AuthStatus.authenticated || _user == null)) {
          _user = currentModel;
          _status = AuthStatus.authenticated;
          notifyListeners();
        }
      } else {
        if (_status == AuthStatus.authenticated) {
          _user = null;
          _status = AuthStatus.unauthenticated;
          notifyListeners();
        }
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  /// Check persisted session on application startup.
  Future<void> checkAuthStatus() async {
    _status = AuthStatus.loading;
    notifyListeners();

    try {
      await _authService.initialize();
      _setupAuthListener();

      // 1. Check if Firebase current user exists
      final fbUser = _authService.getCurrentUser();
      if (fbUser != null) {
        _user = fbUser;
        _status = AuthStatus.authenticated;
        await _persistSession(_user!);
        notifyListeners();
        return;
      }

      // 2. Check if user explicitly selected Guest mode previously
      final prefs = await SharedPreferences.getInstance();
      final isGuestMode = prefs.getBool(_kGuestKey) ?? false;
      if (isGuestMode) {
        _user = UserModel.guest();
        _status = AuthStatus.guest;
        notifyListeners();
        return;
      }

      // 3. Otherwise, user is unauthenticated -> show Login Screen
      _user = null;
      _status = AuthStatus.unauthenticated;
    } catch (e) {
      debugPrint('[MyMusic][Auth] checkAuthStatus error: $e');
      _user = null;
      _status = AuthStatus.unauthenticated;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Continue as Guest without creating or requiring an account.
  Future<void> continueAsGuest() async {
    _isLoading = false;
    _isGoogleLoading = false;
    _isEmailLoading = false;
    _errorMessage = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kGuestKey, true);

    _user = UserModel.guest();
    _status = AuthStatus.guest;
    notifyListeners();
  }

  /// Sign In with Google via Firebase Authentication.
  Future<bool> signInWithGoogle() async {
    if (_isLoading) return false;
    _setGoogleLoading(true);
    _errorMessage = null;

    try {
      final loggedInUser = await _authService.signInWithGoogle();
      _user = loggedInUser;
      _status = AuthStatus.authenticated;

      await _persistSession(loggedInUser);
      _setGoogleLoading(false);
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _errorMessage = e.message;
      _setGoogleLoading(false);
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = AuthService.mapAuthError(e);
      _setGoogleLoading(false);
      notifyListeners();
      return false;
    }
  }

  /// Sign In with Email and Password.
  Future<bool> login(String emailOrUsername, String password) async {
    if (_isLoading) return false;
    _setEmailLoading(true);
    _errorMessage = null;

    final email = emailOrUsername.trim();

    // 1. Try Firebase Authentication if input looks like an email
    if (email.contains('@')) {
      try {
        final loggedInUser = await _authService.signInWithEmail(
          email: email,
          password: password,
        );
        _user = loggedInUser;
        _status = AuthStatus.authenticated;

        await _persistSession(loggedInUser);
        _setEmailLoading(false);
        notifyListeners();
        return true;
      } on AuthException catch (e) {
        // If Firebase error is not network error, or if network available, report cleanly
        if (!e.message.contains('Koneksi') && !e.message.contains('network')) {
          _errorMessage = e.message;
          _setEmailLoading(false);
          notifyListeners();
          return false;
        }
      } catch (e) {
        _errorMessage = AuthService.mapAuthError(e);
      }
    }

    // 2. Fallback to API Service (XAMPP / backend server if running)
    try {
      final response = await ApiService.post('login', {
        'username': emailOrUsername,
        'password': password,
      });

      if (response['status'] == true && response['data'] != null) {
        final data = response['data'];
        final token = data['token'];
        if (token != null) {
          await ApiService.saveToken(token);
        }
        if (data['user'] != null) {
          _user = UserModel.fromJson(data['user']);
          await _persistSession(_user!);
        }
        _status = AuthStatus.authenticated;
        _setEmailLoading(false);
        notifyListeners();
        return true;
      }
    } catch (_) {}

    // 3. Fallback: Local Account in SQLite
    try {
      final emailFallback = email.contains('@') ? email : '$email@local.com';
      final localUserMap = await LocalMusicRepository().getOrCreateLocalUser(
        emailOrUsername,
        emailFallback,
      );
      _user = UserModel.fromJson(localUserMap);
      _status = AuthStatus.authenticated;
      await _persistSession(_user!);
      _setEmailLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      _setEmailLoading(false);
      _errorMessage = _errorMessage ?? 'Gagal masuk akun: $e';
      notifyListeners();
      return false;
    }
  }

  /// Register a new account with Name, Email, and Password.
  Future<bool> register(String name, String email, String password) async {
    if (_isLoading) return false;
    _setEmailLoading(true);
    _errorMessage = null;

    final trimmedEmail = email.trim();
    final trimmedName = name.trim();

    // 1. Register with Firebase Authentication
    try {
      final registeredUser = await _authService.registerWithEmail(
        name: trimmedName,
        email: trimmedEmail,
        password: password,
      );
      _user = registeredUser;
      _status = AuthStatus.authenticated;

      await _persistSession(registeredUser);
      _setEmailLoading(false);
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      if (!e.message.contains('Koneksi') && !e.message.contains('network')) {
        _errorMessage = e.message;
        _setEmailLoading(false);
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = AuthService.mapAuthError(e);
    }

    // 2. Fallback to API Service
    try {
      final response = await ApiService.post('register', {
        'username': trimmedName,
        'email': trimmedEmail,
        'password': password,
      });

      if (response['status'] == true && response['data'] != null) {
        final data = response['data'];
        final token = data['token'];
        if (token != null) {
          await ApiService.saveToken(token);
        }
        if (data['user'] != null) {
          _user = UserModel.fromJson(data['user']);
          await _persistSession(_user!);
        }
        _status = AuthStatus.authenticated;
        _setEmailLoading(false);
        notifyListeners();
        return true;
      }
    } catch (_) {}

    // 3. Fallback: Local Account in SQLite
    try {
      final localUserMap = await LocalMusicRepository().getOrCreateLocalUser(
        trimmedName,
        trimmedEmail,
      );
      _user = UserModel.fromJson(localUserMap);
      _status = AuthStatus.authenticated;
      await _persistSession(_user!);
      _setEmailLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      _setEmailLoading(false);
      _errorMessage = _errorMessage ?? 'Gagal membuat akun: $e';
      notifyListeners();
      return false;
    }
  }

  /// Send password reset email.
  Future<bool> sendPasswordReset(String email) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authService.sendPasswordReset(email);
      _isLoading = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = AuthService.mapAuthError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Sign out from Firebase, Google Sign-In, and local session.
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authService.signOut();
    } catch (_) {}

    try {
      await ApiService.post('logout', {});
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kGuestKey);
    await ApiService.clearToken();
    await ApiService.clearCachedUser();

    _user = null;
    _status = AuthStatus.unauthenticated;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _persistSession(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kGuestKey, false);
    await ApiService.saveToken('token_${user.uid}');
    await ApiService.saveCachedUser(user.toJson());

    // Also link with SQLite local database
    try {
      await LocalMusicRepository().getOrCreateLocalUser(
        user.username,
        user.email,
      );
    } catch (_) {}
  }

  void _setGoogleLoading(bool value) {
    _isGoogleLoading = value;
    _isLoading = value;
    notifyListeners();
  }

  void _setEmailLoading(bool value) {
    _isEmailLoading = value;
    _isLoading = value;
    notifyListeners();
  }
}
