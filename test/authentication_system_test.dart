import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:mymusic/core/auth/auth_state.dart';
import 'package:mymusic/core/auth/auth_service.dart';
import 'package:mymusic/core/auth/auth_gate.dart';
import 'package:mymusic/models/user_model.dart';
import 'package:mymusic/providers/auth_provider.dart';
import 'package:mymusic/widgets/v35/v35_google_button.dart';
import 'package:mymusic/screens/auth/login_screen.dart';
import 'package:mymusic/screens/auth/register_screen.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Authentication System Unit Tests', () {
    test('1. AuthStatus enumeration contains all four mandatory lifecycle states', () {
      expect(AuthStatus.values, contains(AuthStatus.loading));
      expect(AuthStatus.values, contains(AuthStatus.authenticated));
      expect(AuthStatus.values, contains(AuthStatus.guest));
      expect(AuthStatus.values, contains(AuthStatus.unauthenticated));
    });

    test('2. UserModel.guest() constructs valid unauthenticated guest profile', () {
      final guest = UserModel.guest();
      expect(guest.isGuest, isTrue);
      expect(guest.username, equals('Tamu'));
      expect(guest.displayName, equals('Tamu'));
      expect(guest.email, isEmpty);
      expect(guest.provider, equals('guest'));
      expect(guest.photoURL, isNull);
    });

    test('3. UserModel JSON serialization preserves all profile fields', () {
      final user = UserModel(
        id: 42,
        uid: 'firebase_test_uid_123',
        username: 'testuser',
        displayName: 'Test User',
        email: 'test@mymusic.io',
        photoURL: 'https://lh3.googleusercontent.com/avatar.jpg',
        provider: 'google.com',
        isGuest: false,
        createdAt: '2026-10-08T12:00:00Z',
        updatedAt: '2026-10-08T12:30:00Z',
      );

      final json = user.toJson();
      expect(json['uid'], equals('firebase_test_uid_123'));
      expect(json['display_name'], equals('Test User'));
      expect(json['photo_url'], equals('https://lh3.googleusercontent.com/avatar.jpg'));
      expect(json['provider'], equals('google.com'));

      final reconstructed = UserModel.fromJson(json);
      expect(reconstructed.uid, equals('firebase_test_uid_123'));
      expect(reconstructed.displayName, equals('Test User'));
      expect(reconstructed.email, equals('test@mymusic.io'));
      expect(reconstructed.provider, equals('google.com'));
      expect(reconstructed.isGuest, isFalse);
    });

    test('4. AuthService.mapAuthError transforms raw Firebase error codes to user-friendly messages', () {
      expect(
        AuthService.mapAuthError('user-not-found'),
        contains('Akun dengan email ini tidak ditemukan'),
      );
      expect(
        AuthService.mapAuthError('wrong-password'),
        contains('Password yang Anda masukkan salah'),
      );
      expect(
        AuthService.mapAuthError('email-already-in-use'),
        contains('Email ini sudah terdaftar'),
      );
      expect(
        AuthService.mapAuthError('weak-password'),
        contains('Password terlalu lemah'),
      );
      expect(
        AuthService.mapAuthError('network-request-failed'),
        contains('Koneksi internet bermasalah'),
      );
      expect(
        AuthService.mapAuthError('user_cancelled'),
        contains('Login dengan Google dibatalkan'),
      );
    });

    test('5. AuthProvider guest mode flow sets status to guest and saves preference', () async {
      final authProvider = AuthProvider();
      expect(authProvider.isGuest, isFalse);

      await authProvider.continueAsGuest();

      expect(authProvider.status, equals(AuthStatus.guest));
      expect(authProvider.isGuest, isTrue);
      expect(authProvider.user?.isGuest, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('mymusic_is_guest_mode'), isTrue);

      // Logout should clear guest mode
      await authProvider.logout();
      expect(authProvider.status, equals(AuthStatus.unauthenticated));
      expect(authProvider.user, isNull);
      expect(prefs.getBool('mymusic_is_guest_mode') ?? false, isFalse);
    });
  });

  group('Authentication UI & Widget Tests', () {
    testWidgets('6. V35GoogleButton renders vector Google logo and label', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: V35GoogleButton(
                onPressed: () => tapped = true,
                isLoading: false,
                label: 'Lanjutkan dengan Google',
              ),
            ),
          ),
        ),
      );

      expect(find.text('Lanjutkan dengan Google'), findsOneWidget);
      expect(find.byType(GoogleLogoWidget), findsOneWidget);

      await tester.tap(find.text('Lanjutkan dengan Google'));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('7. V35GoogleButton shows loading state and ignores taps when busy', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: V35GoogleButton(
                onPressed: () => tapped = true,
                isLoading: true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Menghubungkan...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.tap(find.byType(V35GoogleButton));
      await tester.pump();
      expect(tapped, isFalse);
    });

    testWidgets('8. LoginScreen renders Obsidian branding, Google button, and Guest entry', (tester) async {
      final authProvider = AuthProvider();

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: authProvider,
          child: const MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      expect(find.text('Selamat Datang di MyMusic'), findsOneWidget);
      expect(find.text('Dengarkan musik favoritmu, kapan saja.'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Lanjutkan sebagai Tamu'), findsOneWidget);
    });

    testWidgets('9. RegisterScreen renders Name, Email, Password, Confirm Password fields', (tester) async {
      final authProvider = AuthProvider();

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: authProvider,
          child: const MaterialApp(
            home: RegisterScreen(),
          ),
        ),
      );

      expect(find.text('Buat Akun MyMusic'), findsOneWidget);
      expect(find.text('Nama Lengkap'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Konfirmasi Password'), findsOneWidget);
      expect(find.text('Buat Akun'), findsOneWidget);
      expect(find.text('Lanjutkan dengan Google'), findsOneWidget);
      expect(find.text('Masuk di sini'), findsOneWidget);
    });

    testWidgets('10. AuthGate presents LoginScreen when unauthenticated', (tester) async {
      final authProvider = AuthProvider();
      await authProvider.checkAuthStatus(); // defaults to unauthenticated in test environment

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: authProvider,
          child: const MaterialApp(
            home: AuthGate(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
    });
  });
}
