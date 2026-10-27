import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/v35_tokens.dart';
import '../../core/theme/v35_accent.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/v35/v35_google_button.dart';
import '../auth/login_screen.dart';
import '../settings/settings_screen.dart';

/// V3.5 Obsidian Emerald Profile Screen.
///
/// Features:
/// - Clean account status card (Authenticated / Guest / Unauthenticated)
/// - User profile display with Google / Email provider details & avatar
/// - Direct routing to Audio & Playback Settings
/// - Secure authentication state handling.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return ValueListenableBuilder<V35AccentPalette>(
      valueListenable: V35Accent.notifier,
      builder: (context, accentPalette, _) {
        return Scaffold(
          backgroundColor: V35Tokens.bgVoid,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: V35Tokens.space20,
                vertical: V35Tokens.space16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- HEADER ---
                  Text(
                    'Profil Saya',
                    style: V35Tokens.display.copyWith(
                      fontSize: 26.0,
                      fontWeight: FontWeight.w700,
                      color: V35Tokens.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Kelola akun dan pengaturan aplikasi MyMusic',
                    style: V35Tokens.secondary.copyWith(
                      color: V35Tokens.textMuted,
                    ),
                  ),
                  const SizedBox(height: V35Tokens.space24),

                  // --- AUTH STATE CARDS ---
                  if (auth.isGuest) ...[
                    // Guest Account Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(V35Tokens.space20),
                      decoration: BoxDecoration(
                        color: V35Tokens.bgSurface,
                        borderRadius: V35Tokens.brLg,
                        border: Border.all(color: V35Tokens.borderSubtle),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: V35Tokens.bgElevated,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: V35Tokens.borderSubtle,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.person_outline_rounded,
                                  size: 28,
                                  color: V35Tokens.textSecondary,
                                ),
                              ),
                              const SizedBox(width: V35Tokens.space16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          'Mode Tamu',
                                          style: V35Tokens.title.copyWith(
                                            fontSize: 17.0,
                                            fontWeight: FontWeight.w700,
                                            color: V35Tokens.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(width: V35Tokens.space8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: V35Tokens.bgHighlight,
                                            borderRadius: V35Tokens.brSm,
                                          ),
                                          child: Text(
                                            'GUEST',
                                            style: V35Tokens.caption.copyWith(
                                              color: V35Tokens.textSecondary,
                                              fontSize: 10.0,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Akun lokal tanpa sinkronisasi cloud',
                                      style: V35Tokens.secondary.copyWith(
                                        color: V35Tokens.textMuted,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: V35Tokens.space16),
                          Text(
                            'Masuk atau hubungkan akun Google untuk menyimpan playlist, lagu favorit, dan riwayat mendengarkan secara permanen.',
                            style: V35Tokens.secondary.copyWith(
                              color: V35Tokens.textSecondary,
                              fontSize: 13.0,
                            ),
                          ),
                          const SizedBox(height: V35Tokens.space16),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const LoginScreen(isModal: true),
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: V35Tokens.accent,
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: const RoundedRectangleBorder(
                                      borderRadius: V35Tokens.brMd,
                                    ),
                                  ),
                                  child: Text(
                                    'Hubungkan Akun / Masuk',
                                    style: V35Tokens.mono.copyWith(
                                      color: Colors.black,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13.0,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: V35Tokens.space12),
                              OutlinedButton(
                                onPressed: () => auth.logout(),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(
                                    color: V35Tokens.borderSubtle,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: V35Tokens.brMd,
                                  ),
                                ),
                                child: const Text(
                                  'Keluar',
                                  style: TextStyle(color: V35Tokens.textMuted),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ] else if (!auth.isAuthenticated) ...[
                    // Unauthenticated Card
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(V35Tokens.space24),
                        decoration: BoxDecoration(
                          color: V35Tokens.bgSurface,
                          borderRadius: V35Tokens.brLg,
                          border: Border.all(color: V35Tokens.borderSubtle),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: V35Tokens.bgElevated,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: V35Tokens.borderSubtle,
                                ),
                              ),
                              child: const Icon(
                                Icons.person_outline_rounded,
                                size: 40,
                                color: V35Tokens.textMuted,
                              ),
                            ),
                            const SizedBox(height: V35Tokens.space16),
                            Text(
                              'Anda Belum Masuk',
                              style: V35Tokens.title.copyWith(
                                fontSize: 18.0,
                                fontWeight: FontWeight.w700,
                                color: V35Tokens.textPrimary,
                              ),
                            ),
                            const SizedBox(height: V35Tokens.space8),
                            Text(
                              'Masuk atau buat akun MyMusic untuk sinkronisasi playlist dan riwayat musik Anda.',
                              style: V35Tokens.secondary.copyWith(
                                color: V35Tokens.textMuted,
                                fontSize: 13.0,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: V35Tokens.space20),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const LoginScreen(),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: V35Tokens.accent,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: V35Tokens.space32,
                                  vertical: V35Tokens.space12,
                                ),
                                shape: const RoundedRectangleBorder(
                                  borderRadius: V35Tokens.brMd,
                                ),
                              ),
                              child: Text(
                                'Masuk / Register',
                                style: V35Tokens.mono.copyWith(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.0,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    // Authenticated Profile Card
                    Container(
                      padding: const EdgeInsets.all(V35Tokens.space20),
                      decoration: BoxDecoration(
                        color: V35Tokens.bgSurface,
                        borderRadius: V35Tokens.brLg,
                        border: Border.all(color: V35Tokens.borderSubtle),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              // Avatar / Photo
                              if (auth.user?.photoURL != null &&
                                  auth.user!.photoURL!.isNotEmpty)
                                Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: V35Tokens.accent.withValues(
                                        alpha: 0.6,
                                      ),
                                      width: 2.0,
                                    ),
                                    image: DecorationImage(
                                      image: NetworkImage(auth.user!.photoURL!),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                )
                              else
                                Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    color: V35Tokens.accentDeep.withValues(
                                      alpha: 0.35,
                                    ),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: V35Tokens.accent.withValues(
                                        alpha: 0.5,
                                      ),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      auth.user?.displayName.isNotEmpty == true
                                          ? auth.user!.displayName
                                                .substring(0, 1)
                                                .toUpperCase()
                                          : (auth.user?.username.isNotEmpty ==
                                                    true
                                                ? auth.user!.username
                                                      .substring(0, 1)
                                                      .toUpperCase()
                                                : 'U'),
                                      style: V35Tokens.heading.copyWith(
                                        color: V35Tokens.accent,
                                        fontSize: 26.0,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              const SizedBox(width: V35Tokens.space16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      auth.user?.displayName.isNotEmpty == true
                                          ? auth.user!.displayName
                                          : (auth.user?.username ??
                                                'Pengguna MyMusic'),
                                      style: V35Tokens.title.copyWith(
                                        fontSize: 18.0,
                                        fontWeight: FontWeight.w700,
                                        color: V35Tokens.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      auth.user?.email ?? '',
                                      style: V35Tokens.secondary.copyWith(
                                        color: V35Tokens.textMuted,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    // Provider badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: V35Tokens.bgElevated,
                                        borderRadius: V35Tokens.brSm,
                                        border: Border.all(
                                          color: V35Tokens.borderSubtle,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (auth.user?.provider == 'google' ||
                                              auth.user?.provider ==
                                                  'google.com') ...[
                                            const GoogleLogoWidget(size: 13),
                                            const SizedBox(width: 5),
                                            Text(
                                              'Google Account',
                                              style: V35Tokens.caption.copyWith(
                                                color: V35Tokens.textPrimary,
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ] else ...[
                                            Icon(
                                              Icons.email_outlined,
                                              size: 12,
                                              color: V35Tokens.accent,
                                            ),
                                            const SizedBox(width: 5),
                                            Text(
                                              'Email Account',
                                              style: V35Tokens.caption.copyWith(
                                                color: V35Tokens.textPrimary,
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: V35Tokens.space16),

                  // Audio & Playback Settings Navigation
                  Container(
                    decoration: BoxDecoration(
                      color: V35Tokens.bgSurface,
                      borderRadius: V35Tokens.brMd,
                      border: Border.all(color: V35Tokens.borderSubtle),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: V35Tokens.space16,
                        vertical: 4.0,
                      ),
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: V35Tokens.accentDeep.withValues(alpha: 0.2),
                          borderRadius: V35Tokens.brSm,
                        ),
                        child: Icon(
                          Icons.settings_rounded,
                          color: V35Tokens.accent,
                          size: 22,
                        ),
                      ),
                      title: Text(
                        'Pengaturan Audio & Playback',
                        style: V35Tokens.title.copyWith(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: V35Tokens.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        'Equalizer, Sleep Timer, Crossfade & Gapless',
                        style: V35Tokens.secondary.copyWith(
                          fontSize: 12.0,
                          color: V35Tokens.textMuted,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        color: V35Tokens.textMuted,
                        size: 20,
                      ),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SettingsScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: V35Tokens.space20),

                  // Logout Button (Only if authenticated)
                  if (auth.isAuthenticated)
                    OutlinedButton.icon(
                      onPressed: () => auth.logout(),
                      icon: const Icon(
                        Icons.logout_rounded,
                        color: Colors.redAccent,
                        size: 18,
                      ),
                      label: const Text(
                        'Keluar dari Akun',
                        style: TextStyle(color: Colors.redAccent),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: Colors.redAccent.withValues(alpha: 0.5),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: const RoundedRectangleBorder(
                          borderRadius: V35Tokens.brMd,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
