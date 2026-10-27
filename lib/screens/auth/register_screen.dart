import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/v35_tokens.dart';
import '../../core/theme/v35_accent.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/custom_snack_bar.dart';
import '../../widgets/v35/v35_google_button.dart';
import 'login_screen.dart';

/// MyMusic V3.5 Obsidian Design Language Register Screen.
///
/// Supports Name, Email, Password, Confirm Password registration,
/// Google Sign-In, and instant navigation back to Login.
class RegisterScreen extends StatefulWidget {
  final bool isModal;

  const RegisterScreen({super.key, this.isModal = false});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _submitRegistration() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (name.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      CustomSnackBar.showError(context, 'Semua data wajib diisi.');
      return;
    }

    if (!email.contains('@') || !email.contains('.')) {
      CustomSnackBar.showError(context, 'Format email tidak valid.');
      return;
    }

    if (password.length < 6) {
      CustomSnackBar.showError(context, 'Password minimal 6 karakter.');
      return;
    }

    if (password != confirmPassword) {
      CustomSnackBar.showError(context, 'Konfirmasi password tidak cocok.');
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.register(name, email, password);

    if (!mounted) return;

    if (success) {
      CustomSnackBar.showSuccess(
        context,
        'Akun berhasil dibuat! Selamat datang di TONAVERA.',
      );
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(true);
      }
    } else if (auth.errorMessage != null) {
      CustomSnackBar.showError(context, auth.errorMessage!);
    }
  }

  void _submitGoogleLogin() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.signInWithGoogle();

    if (!mounted) return;

    if (success) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(true);
      }
    } else if (auth.errorMessage != null) {
      CustomSnackBar.showError(context, auth.errorMessage!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final bool isBusy = auth.isLoading || auth.isGoogleLoading;

    return ValueListenableBuilder<V35AccentPalette>(
      valueListenable: V35Accent.notifier,
      builder: (context, accentPalette, _) {
        return Scaffold(
          backgroundColor: V35Tokens.bgVoid,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: V35Tokens.textPrimary,
                size: 20,
              ),
              onPressed: isBusy ? null : () => Navigator.of(context).pop(),
            ),
          ),
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: V35Tokens.space24,
                  vertical: V35Tokens.space16,
                ),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 440),
                  padding: const EdgeInsets.all(V35Tokens.space24),
                  decoration: BoxDecoration(
                    color: V35Tokens.bgSurface,
                    borderRadius: V35Tokens.brLg,
                    border: Border.all(color: V35Tokens.borderSubtle),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // --- BRANDING & HEADER ---
                      Center(
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: V35Tokens.accentDeep.withValues(alpha: 0.25),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: V35Tokens.accent.withValues(alpha: 0.6),
                              width: 1.5,
                            ),
                          ),
                          child: Icon(
                            Icons.person_add_rounded,
                            size: 30,
                            color: V35Tokens.accent,
                          ),
                        ),
                      ),
                      const SizedBox(height: V35Tokens.space16),
                      Text(
                        'Buat Akun TONAVERA',
                        style: V35Tokens.display.copyWith(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: V35Tokens.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: V35Tokens.space4),
                      Text(
                        'Mulai petualangan musik Anda dengan sinkronisasi multi-perangkat',
                        style: V35Tokens.secondary.copyWith(
                          color: V35Tokens.textMuted,
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: V35Tokens.space24),

                      // --- FULL NAME FIELD ---
                      TextField(
                        controller: _nameController,
                        enabled: !isBusy,
                        style: const TextStyle(color: V35Tokens.textPrimary),
                        decoration: InputDecoration(
                          labelText: 'Nama Lengkap',
                          labelStyle: const TextStyle(
                            color: V35Tokens.textMuted,
                          ),
                          prefixIcon: Icon(
                            Icons.person_outline_rounded,
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
                      const SizedBox(height: V35Tokens.space16),

                      // --- EMAIL FIELD ---
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
                      const SizedBox(height: V35Tokens.space16),

                      // --- PASSWORD FIELD ---
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
                      const SizedBox(height: V35Tokens.space16),

                      // --- CONFIRM PASSWORD FIELD ---
                      TextField(
                        controller: _confirmPasswordController,
                        enabled: !isBusy,
                        obscureText: _obscureConfirmPassword,
                        style: const TextStyle(color: V35Tokens.textPrimary),
                        decoration: InputDecoration(
                          labelText: 'Konfirmasi Password',
                          labelStyle: const TextStyle(
                            color: V35Tokens.textMuted,
                          ),
                          prefixIcon: Icon(
                            Icons.lock_reset_rounded,
                            color: V35Tokens.accent,
                            size: 20,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: V35Tokens.textMuted,
                              size: 20,
                            ),
                            onPressed: () => setState(
                              () => _obscureConfirmPassword =
                                  !_obscureConfirmPassword,
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
                      const SizedBox(height: V35Tokens.space24),

                      // --- SUBMIT BUTTON ---
                      ElevatedButton(
                        onPressed: isBusy ? null : _submitRegistration,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: V35Tokens.accent,
                          foregroundColor: Colors.black,
                          disabledBackgroundColor: V35Tokens.bgElevated,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: const RoundedRectangleBorder(
                            borderRadius: V35Tokens.brMd,
                          ),
                          elevation: 0,
                        ),
                        child: auth.isLoading
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      color: Colors.black,
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Mendaftarkan...',
                                    style: V35Tokens.title.copyWith(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black,
                                    ),
                                  ),
                                ],
                              )
                            : Text(
                                'Buat Akun',
                                style: V35Tokens.title.copyWith(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black,
                                ),
                              ),
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
                      const SizedBox(height: V35Tokens.space20),

                      // --- GOOGLE SIGN IN BUTTON ---
                      V35GoogleButton(
                        onPressed: isBusy ? null : _submitGoogleLogin,
                        isLoading: auth.isGoogleLoading,
                        label: 'Lanjutkan dengan Google',
                      ),
                      const SizedBox(height: V35Tokens.space24),

                      // --- BACK TO LOGIN ---
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Sudah punya akun? ',
                            style: V35Tokens.secondary.copyWith(
                              color: V35Tokens.textSecondary,
                            ),
                          ),
                          GestureDetector(
                            onTap: isBusy
                                ? null
                                : () {
                                    Navigator.of(context).pushReplacement(
                                      MaterialPageRoute(
                                        builder: (_) => LoginScreen(
                                          isModal: widget.isModal,
                                        ),
                                      ),
                                    );
                                  },
                            child: Text(
                              'Masuk di sini',
                              style: V35Tokens.secondary.copyWith(
                                color: V35Tokens.accentBright,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
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
