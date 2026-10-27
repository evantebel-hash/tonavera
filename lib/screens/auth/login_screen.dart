import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/v35_tokens.dart';
import '../../core/theme/v35_accent.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/custom_snack_bar.dart';
import '../../widgets/v35/v35_google_button.dart';
import 'register_screen.dart';

/// MyMusic V3.5 Obsidian Design Language Login Screen.
///
/// Serves as the primary authentication gateway when user is unauthenticated.
/// Features:
/// - Brand logo and welcoming typography
/// - Primary "Continue with Google" action
/// - Clean loading, error, and cancel states
/// - Secondary email login & guest mode access
class LoginScreen extends StatefulWidget {
  final bool isModal;

  const LoginScreen({super.key, this.isModal = false});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _showEmailFields = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submitGoogleLogin() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.isGoogleLoading || auth.isLoading) return;

    auth.clearErrorMessage();
    final success = await auth.signInWithGoogle();

    if (!mounted) return;

    if (success) {
      if (widget.isModal && Navigator.of(context).canPop()) {
        Navigator.of(context).pop(true);
      }
    } else if (auth.errorMessage != null) {
      CustomSnackBar.showError(context, auth.errorMessage!);
    }
  }

  void _submitEmailLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      CustomSnackBar.showError(context, 'Email dan password wajib diisi.');
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.isEmailLoading || auth.isLoading) return;

    auth.clearErrorMessage();
    final success = await auth.login(email, password);

    if (!mounted) return;

    if (success) {
      if (widget.isModal && Navigator.of(context).canPop()) {
        Navigator.of(context).pop(true);
      }
    } else if (auth.errorMessage != null) {
      CustomSnackBar.showError(context, auth.errorMessage!);
    }
  }

  void _submitGuestMode() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    auth.clearErrorMessage();
    await auth.continueAsGuest();

    if (!mounted) return;

    if (widget.isModal && Navigator.of(context).canPop()) {
      Navigator.of(context).pop(true);
    }
  }

  void _showForgotPasswordDialog() {
    final resetEmailController = TextEditingController(
      text: _emailController.text.trim(),
    );

    showDialog(
      context: context,
      builder: (ctx) {
        bool isSubmitting = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: V35Tokens.bgSurface,
              shape: const RoundedRectangleBorder(borderRadius: V35Tokens.brXl),
              title: Text(
                'Lupa Password?',
                style: V35Tokens.heading.copyWith(
                  fontSize: 18,
                  color: V35Tokens.textPrimary,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Masukkan alamat email Anda untuk menerima instruksi pemulihan kata sandi.',
                    style: V35Tokens.secondary.copyWith(
                      color: V35Tokens.textSecondary,
                    ),
                  ),
                  const SizedBox(height: V35Tokens.space16),
                  TextField(
                    controller: resetEmailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: V35Tokens.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Alamat Email',
                      labelStyle: const TextStyle(color: V35Tokens.textMuted),
                      prefixIcon: Icon(
                        Icons.email_outlined,
                        color: V35Tokens.accent,
                        size: 20,
                      ),
                      filled: true,
                      fillColor: V35Tokens.bgBase,
                      border: OutlineInputBorder(
                        borderRadius: V35Tokens.brMd,
                        borderSide: const BorderSide(
                          color: V35Tokens.borderSubtle,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: V35Tokens.brMd,
                        borderSide: BorderSide(
                          color: V35Tokens.accent,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () => Navigator.of(ctx).pop(),
                  child: const Text(
                    'Batal',
                    style: TextStyle(color: V35Tokens.textMuted),
                  ),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final email = resetEmailController.text.trim();
                          if (email.isEmpty) {
                            CustomSnackBar.showError(
                              context,
                              'Silakan masukkan alamat email.',
                            );
                            return;
                          }
                          setDialogState(() => isSubmitting = true);
                          final auth = Provider.of<AuthProvider>(
                            context,
                            listen: false,
                          );
                          final success = await auth.sendPasswordReset(email);
                          setDialogState(() => isSubmitting = false);
                          if (!ctx.mounted) return;
                          Navigator.of(ctx).pop();
                          if (success) {
                            CustomSnackBar.showSuccess(
                              context,
                              'Tautan reset kata sandi telah dikirim ke email Anda.',
                            );
                          } else if (auth.errorMessage != null) {
                            CustomSnackBar.showError(
                              context,
                              auth.errorMessage!,
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: V35Tokens.accent,
                    foregroundColor: Colors.black,
                    shape: const RoundedRectangleBorder(
                      borderRadius: V35Tokens.brMd,
                    ),
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Text(
                          'Kirim Email',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final bool isBusy =
        auth.isLoading || auth.isGoogleLoading || auth.isEmailLoading;

    return ValueListenableBuilder<V35AccentPalette>(
      valueListenable: V35Accent.notifier,
      builder: (context, accentPalette, _) {
        return Scaffold(
          backgroundColor: V35Tokens.bgVoid,
          appBar: widget.isModal && Navigator.of(context).canPop()
              ? AppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  leading: IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: V35Tokens.textPrimary,
                      size: 20,
                    ),
                    onPressed: isBusy
                        ? null
                        : () => Navigator.of(context).pop(),
                  ),
                )
              : null,
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: V35Tokens.space24,
                  vertical: V35Tokens.space20,
                ),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 420),
                  padding: const EdgeInsets.all(V35Tokens.space24),
                  decoration: BoxDecoration(
                    color: V35Tokens.bgSurface,
                    borderRadius: V35Tokens.brLg,
                    border: Border.all(color: V35Tokens.borderSubtle),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // --- LOGO / ICON TONAVERA ---
                      Center(
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: V35Tokens.accentDeep.withValues(alpha: 0.25),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: V35Tokens.accent.withValues(alpha: 0.6),
                              width: 1.8,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: V35Tokens.accent.withValues(alpha: 0.15),
                                blurRadius: 16,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Image.asset(
                              'assets/images/tonavera_symbol_white.png',
                              width: 38,
                              height: 38,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: V35Tokens.space20),

                      // --- JUDUL BESAR ---
                      Text(
                        'Selamat Datang di TONAVERA',
                        style: V35Tokens.display.copyWith(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: V35Tokens.textPrimary,
                          letterSpacing: -0.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: V35Tokens.space8),

                      // --- SUBTITLE ---
                      Text(
                        'Dengarkan musik favoritmu, kapan saja.',
                        style: V35Tokens.secondary.copyWith(
                          color: V35Tokens.textMuted,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: V35Tokens.space24),

                      // --- STATUS / ERROR BANNER ---
                      if (auth.errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: V35Tokens.bgElevated,
                            borderRadius: V35Tokens.brMd,
                            border: Border.all(
                              color: auth.errorMessage!.contains('dibatalkan')
                                  ? V35Tokens.accent.withValues(alpha: 0.5)
                                  : Colors.redAccent.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                auth.errorMessage!.contains('dibatalkan')
                                    ? Icons.info_outline_rounded
                                    : Icons.warning_amber_rounded,
                                size: 18,
                                color: auth.errorMessage!.contains('dibatalkan')
                                    ? V35Tokens.accentBright
                                    : Colors.redAccent,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  auth.errorMessage!,
                                  style: V35Tokens.caption.copyWith(
                                    color: V35Tokens.textPrimary,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: () => auth.clearErrorMessage(),
                                child: const Icon(
                                  Icons.close_rounded,
                                  size: 16,
                                  color: V35Tokens.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: V35Tokens.space20),
                      ],

                      // --- TOMBOL UTAMA: CONTINUE WITH GOOGLE ---
                      V35GoogleButton(
                        onPressed: isBusy ? null : _submitGoogleLogin,
                        isLoading: auth.isGoogleLoading,
                        label: 'Continue with Google',
                      ),
                      const SizedBox(height: V35Tokens.space20),

                      // --- DIVIDER OR ---
                      Row(
                        children: [
                          const Expanded(
                            child: Divider(
                              color: V35Tokens.borderSubtle,
                              thickness: 1,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: V35Tokens.space12,
                            ),
                            child: Text(
                              'ATAU',
                              style: V35Tokens.caption.copyWith(
                                color: V35Tokens.textMuted,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          const Expanded(
                            child: Divider(
                              color: V35Tokens.borderSubtle,
                              thickness: 1,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: V35Tokens.space16),

                      // --- GUEST BUTTON ---
                      OutlinedButton.icon(
                        onPressed: isBusy ? null : _submitGuestMode,
                        icon: const Icon(
                          Icons.person_outline_rounded,
                          size: 18,
                          color: V35Tokens.textSecondary,
                        ),
                        label: Text(
                          'Lanjutkan sebagai Tamu',
                          style: V35Tokens.title.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: V35Tokens.textSecondary,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                            color: V35Tokens.borderSubtle,
                            width: 1.2,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: const RoundedRectangleBorder(
                            borderRadius: V35Tokens.brMd,
                          ),
                        ),
                      ),
                      const SizedBox(height: V35Tokens.space16),

                      // --- EMAIL COLLAPSIBLE SECTION ---
                      if (!_showEmailFields)
                        TextButton(
                          onPressed: isBusy
                              ? null
                              : () => setState(() => _showEmailFields = true),
                          child: Text(
                            'Masuk dengan Email & Password',
                            style: V35Tokens.caption.copyWith(
                              color: V35Tokens.accentBright,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      else ...[
                        const SizedBox(height: V35Tokens.space8),
                        TextField(
                          controller: _emailController,
                          enabled: !isBusy,
                          keyboardType: TextInputType.emailAddress,
                          style: const TextStyle(color: V35Tokens.textPrimary),
                          decoration: InputDecoration(
                            labelText: 'Email',
                            labelStyle: const TextStyle(
                              color: V35Tokens.textMuted,
                            ),
                            prefixIcon: Icon(
                              Icons.email_outlined,
                              color: V35Tokens.accent,
                              size: 20,
                            ),
                            filled: true,
                            fillColor: V35Tokens.bgBase,
                            border: OutlineInputBorder(
                              borderRadius: V35Tokens.brMd,
                              borderSide: const BorderSide(
                                color: V35Tokens.borderSubtle,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: V35Tokens.brMd,
                              borderSide: const BorderSide(
                                color: V35Tokens.borderSubtle,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: V35Tokens.brMd,
                              borderSide: BorderSide(
                                color: V35Tokens.accent,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: V35Tokens.space12),
                        TextField(
                          controller: _passwordController,
                          enabled: !isBusy,
                          obscureText: _obscurePassword,
                          style: const TextStyle(color: V35Tokens.textPrimary),
                          decoration: InputDecoration(
                            labelText: 'Password',
                            labelStyle: const TextStyle(
                              color: V35Tokens.textMuted,
                            ),
                            prefixIcon: Icon(
                              Icons.lock_outline_rounded,
                              color: V35Tokens.accent,
                              size: 20,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: V35Tokens.textMuted,
                                size: 20,
                              ),
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                            ),
                            filled: true,
                            fillColor: V35Tokens.bgBase,
                            border: OutlineInputBorder(
                              borderRadius: V35Tokens.brMd,
                              borderSide: const BorderSide(
                                color: V35Tokens.borderSubtle,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: V35Tokens.brMd,
                              borderSide: const BorderSide(
                                color: V35Tokens.borderSubtle,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: V35Tokens.brMd,
                              borderSide: BorderSide(
                                color: V35Tokens.accent,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: isBusy
                                ? null
                                : _showForgotPasswordDialog,
                            child: Text(
                              'Lupa password?',
                              style: V35Tokens.caption.copyWith(
                                color: V35Tokens.accentBright,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: isBusy ? null : _submitEmailLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: V35Tokens.accent,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: const RoundedRectangleBorder(
                              borderRadius: V35Tokens.brMd,
                            ),
                          ),
                          child: auth.isEmailLoading
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    color: Colors.black,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Masuk dengan Email',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                        ),
                        const SizedBox(height: V35Tokens.space8),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    RegisterScreen(isModal: widget.isModal),
                              ),
                            );
                          },
                          child: Text(
                            'Belum punya akun? Buat akun',
                            style: V35Tokens.caption.copyWith(
                              color: V35Tokens.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
