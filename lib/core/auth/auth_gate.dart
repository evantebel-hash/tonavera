import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../theme/v35_tokens.dart';
import '../../providers/auth_provider.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/main_navigation_screen.dart';
import 'auth_state.dart';

/// Centralized AuthGate for MyMusic.
///
/// Reactively handles the four root authentication states:
/// - [AuthStatus.loading]: Sleek obsidian branding & loading state
/// - [AuthStatus.authenticated]: Main MyMusic application
/// - [AuthStatus.guest]: Main MyMusic application with guest privileges
/// - [AuthStatus.unauthenticated]: MyMusic Login screen
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    if (kDebugMode && auth.status == AuthStatus.authenticated) {
      debugPrint('[AuthGate] Firebase user detected');
    }

    switch (auth.status) {
      case AuthStatus.loading:
        return Scaffold(
          backgroundColor: V35Tokens.bgVoid,
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: V35Tokens.accentDeep.withValues(alpha: 0.25),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: V35Tokens.accent.withValues(alpha: 0.6),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Image.asset(
                      'assets/images/tonavera_symbol_white.png',
                      width: 36,
                      height: 36,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: AlwaysStoppedAnimation<Color>(V35Tokens.accent),
                  ),
                ),
              ],
            ),
          ),
        );

      case AuthStatus.authenticated:
      case AuthStatus.guest:
        return const MainNavigationScreen();

      case AuthStatus.unauthenticated:
        return const LoginScreen();
    }
  }
}
