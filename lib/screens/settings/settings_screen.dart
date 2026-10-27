import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';

import '../../core/theme/v35_tokens.dart';
import '../../core/theme/v35_accent.dart';
import '../../providers/player_provider.dart';
import '../../providers/playlist_provider.dart';
import '../../services/desktop/desktop_integration_service.dart';
import '../../widgets/dialogs/equalizer_dialog.dart';
import '../../widgets/dialogs/sleep_timer_dialog.dart';
import '../../widgets/dialogs/playback_speed_dialog.dart';
import '../../widgets/dialogs/crossfade_dialog.dart';
import '../../widgets/dialogs/accent_color_dialog.dart';
import '../../widgets/dialogs/android_diagnostic_dialog.dart';
import '../../services/backup_restore_service.dart';
import '../../services/playlist_export_import_service.dart';
import '../../services/api/cloud_sync_provider.dart';
import '../../providers/youtube_provider.dart';
import '../library/duplicate_music_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final player = Provider.of<PlayerProvider>(context);

    return ValueListenableBuilder<V35AccentPalette>(
      valueListenable: V35Accent.notifier,
      builder: (context, activeAccent, _) {
        return Scaffold(
          backgroundColor: V35Tokens.bgVoid,
          appBar: AppBar(
            title: const Text(
              'Pengaturan & Alat',
              style: TextStyle(
                color: V35Tokens.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            backgroundColor: V35Tokens.bgVoid,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: V35Tokens.textPrimary,
              ),
              tooltip: 'Kembali',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(
              V35Tokens.space16,
              V35Tokens.space8,
              V35Tokens.space16,
              V35Tokens.space48 +
                  40, // safe bottom spacing for persistent miniplayer
            ),
            children: [
              // TAMPILAN & AKSEN (APPEARANCE)
              _buildSectionHeader('TAMPILAN & AKSEN (APPEARANCE)'),
              _buildSettingsGroup(
                children: [
                  _buildSettingTile(
                    icon: Icons.palette_rounded,
                    iconColor: activeAccent.base,
                    title: 'Warna Aksen (Accent Color)',
                    subtitle: activeAccent.mode == AccentMode.dynamicArtwork
                        ? 'Ikuti Sampul Album (Dynamic Artwork)'
                        : (activeAccent.mode == AccentMode.custom
                              ? 'Warna Kustom'
                              : 'Preset: ${activeAccent.name}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: activeAccent.base,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: activeAccent.base.withValues(alpha: 0.5),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildBadge(activeAccent.name, isActive: true),
                      ],
                    ),
                    onTap: () => AccentColorDialog.show(context),
                  ),
                  _buildDivider(),
                  // Quick Preset Swatches
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ...AccentPreset.all.map((preset) {
                            final isSel =
                                activeAccent.mode == AccentMode.preset &&
                                activeAccent.id == preset.id;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () => V35Accent.setPreset(preset),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSel
                                        ? preset.base.withValues(alpha: 0.18)
                                        : V35Tokens.bgElevated,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isSel
                                          ? preset.base
                                          : V35Tokens.borderSubtle,
                                      width: isSel ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color: preset.base,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        preset.name,
                                        style: TextStyle(
                                          color: isSel
                                              ? V35Tokens.textPrimary
                                              : V35Tokens.textSecondary,
                                          fontSize: 11,
                                          fontWeight: isSel
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                          // More / Customize button
                          InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => AccentColorDialog.show(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: V35Tokens.bgElevated,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: V35Tokens.borderSubtle,
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.tune_rounded,
                                    size: 13,
                                    color: V35Tokens.textSecondary,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Lainnya...',
                                    style: TextStyle(
                                      color: V35Tokens.textSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: V35Tokens.space24),

              // AUDIO & HARMONISASI
              _buildSectionHeader('AUDIO & HARMONISASI'),
              _buildSettingsGroup(
                children: [
                  // Equalizer
                  _buildSettingTile(
                    icon: Icons.equalizer_rounded,
                    iconColor: V35Tokens.accent,
                    title: 'Equalizer',
                    subtitle: player.equalizerEnabled
                        ? 'Aktif (${player.equalizerPreset})'
                        : 'Nonaktif',
                    trailing: _buildBadge(
                      player.equalizerEnabled ? player.equalizerPreset : 'Off',
                      isActive: player.equalizerEnabled,
                    ),
                    onTap: () => EqualizerDialog.show(context),
                  ),
                  _buildDivider(),

                  // Sleep Timer
                  _buildSettingTile(
                    icon: Icons.timer_rounded,
                    iconColor: V35Tokens.accent,
                    title: 'Sleep Timer',
                    subtitle: player.isSleepTimerActive
                        ? 'Aktif (${player.sleepTimerFormatted})'
                        : 'Matikan musik secara otomatis sesuai timer',
                    trailing: _buildBadge(
                      player.isSleepTimerActive
                          ? player.sleepTimerFormatted
                          : 'Off',
                      isActive: player.isSleepTimerActive,
                    ),
                    onTap: () => SleepTimerDialog.show(context),
                  ),
                  _buildDivider(),

                  // Playback Speed
                  _buildSettingTile(
                    icon: Icons.speed_rounded,
                    iconColor: V35Tokens.accent,
                    title: 'Kecepatan Pemutaran (Playback Speed)',
                    subtitle:
                        'Sesuaikan laju tempo audio (${player.playbackSpeed}x)',
                    trailing: _buildBadge(
                      '${player.playbackSpeed}x',
                      isActive: player.playbackSpeed != 1.0,
                    ),
                    onTap: () => PlaybackSpeedDialog.show(context),
                  ),
                  _buildDivider(),

                  // Crossfade
                  _buildSettingTile(
                    icon: Icons.shuffle_on_outlined,
                    iconColor: V35Tokens.accent,
                    title: 'Crossfade',
                    subtitle: player.crossfadeDuration > 0
                        ? '${player.crossfadeDuration} detik fade transisi'
                        : 'Nonaktif (Transisi standar)',
                    trailing: _buildBadge(
                      player.crossfadeDuration > 0
                          ? '${player.crossfadeDuration}s'
                          : 'Off',
                      isActive: player.crossfadeDuration > 0,
                    ),
                    onTap: () => CrossfadeDialog.show(context),
                  ),
                  _buildDivider(),

                  // Gapless Playback Switch
                  _buildSwitchTile(
                    icon: Icons.queue_music_rounded,
                    iconColor: V35Tokens.accent,
                    title: 'Gapless Playback',
                    subtitle:
                        'Transisi antar lagu tanpa jeda sunyi (Preload buffer)',
                    value: player.gaplessEnabled,
                    onChanged: (val) => player.setGaplessEnabled(val),
                  ),
                  _buildDivider(),

                  // Dynamic Background Switch
                  _buildSwitchTile(
                    icon: Icons.color_lens_rounded,
                    iconColor: V35Tokens.accent,
                    title: 'Dynamic Background (Latar Warna Dinding)',
                    subtitle:
                        'Ubah suasana warna layar berdasarkan cover album lagu',
                    value: player.dynamicBackgroundEnabled,
                    onChanged: (val) => player.setDynamicBackgroundEnabled(val),
                  ),
                  _buildDivider(),

                  // Waveform Seek Switch
                  _buildSwitchTile(
                    icon: Icons.graphic_eq_rounded,
                    iconColor: V35Tokens.accent,
                    title: 'Waveform Seek Bar',
                    subtitle:
                        'Gunakan waveform interaktif untuk navigasi dan penanda lagu',
                    value: player.waveformSeekEnabled,
                    onChanged: (val) => player.setWaveformSeekEnabled(val),
                  ),
                ],
              ),

              const SizedBox(height: V35Tokens.space24),

              // PUSTAKA & PEMELIHARAAN
              _buildSectionHeader('PUSTAKA & PEMELIHARAAN'),
              _buildSettingsGroup(
                children: [
                  _buildSettingTile(
                    icon: Icons.copy_rounded,
                    iconColor: Colors.orangeAccent,
                    title: 'Pembersih Lagu Duplikat (Duplicate Music)',
                    subtitle:
                        'Pindai & bersihkan file audio ganda di pustaka lokal',
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      color: V35Tokens.textMuted,
                      size: 20,
                    ),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const DuplicateMusicScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: V35Tokens.space24),

              // DATA & PENYINKRONAN
              _buildSectionHeader('DATA & PENYINKRONAN (DATA & SYNC)'),
              _buildSettingsGroup(
                children: [
                  // Backup Library
                  _buildSettingTile(
                    icon: Icons.backup_rounded,
                    iconColor: V35Tokens.accent,
                    title: 'Cadangkan Pustaka (Library Backup)',
                    subtitle:
                        'Ekspor pustaka, playlist, favorit & riwayat ke file .mymusicbackup',
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      color: V35Tokens.textMuted,
                      size: 20,
                    ),
                    onTap: () => _handleBackup(context),
                  ),
                  _buildDivider(),

                  // Restore Library
                  _buildSettingTile(
                    icon: Icons.settings_backup_restore_rounded,
                    iconColor: V35Tokens.accent,
                    title: 'Pulihkan Pustaka (Library Restore)',
                    subtitle:
                        'Impor dan pulihkan pustaka dari file .mymusicbackup',
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      color: V35Tokens.textMuted,
                      size: 20,
                    ),
                    onTap: () => _handleRestore(context),
                  ),
                  _buildDivider(),

                  // Import Playlist
                  _buildSettingTile(
                    icon: Icons.file_download_rounded,
                    iconColor: V35Tokens.accent,
                    title: 'Impor Playlist (Import Playlist)',
                    subtitle:
                        'Impor file playlist eksternal format JSON atau M3U/M3U8',
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      color: V35Tokens.textMuted,
                      size: 20,
                    ),
                    onTap: () => _handleImportPlaylist(context),
                  ),
                  _buildDivider(),

                  // Cloud Sync
                  _buildSettingTile(
                    icon: Icons.cloud_sync_rounded,
                    iconColor: V35Tokens.accent,
                    title: 'Cloud Sync (Optional Sync)',
                    subtitle:
                        'Sinkronkan playlist & favorit ke server cloud (Offline-first)',
                    trailing: _buildBadge('READY', isActive: true),
                    onTap: () => _handleCloudSync(context),
                  ),
                ],
              ),

              const SizedBox(height: V35Tokens.space24),

              // ONLINE SERVICES & YOUTUBE
              _buildSectionHeader('ONLINE SERVICES & YOUTUBE'),
              _buildSettingsGroup(
                children: [
                  // YouTube Metadata
                  _buildSettingTile(
                    icon: Icons.video_library_rounded,
                    iconColor: Colors.redAccent,
                    title: 'YouTube Public Metadata Integration',
                    subtitle:
                        'Pencarian metadata publik & cache SQLite lokal (Aktif / Offline-first)',
                    trailing: _buildBadge('ACTIVE', isActive: true),
                  ),
                  _buildDivider(),

                  // Clear YouTube Cache
                  _buildSettingTile(
                    icon: Icons.cleaning_services_rounded,
                    iconColor: Colors.orangeAccent,
                    title: 'Bersihkan Cache YouTube (Clear Cache)',
                    subtitle:
                        'Hapus cache pencarian SQLite tanpa mempengaruhi lagu lokal',
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      color: V35Tokens.textMuted,
                      size: 20,
                    ),
                    onTap: () async {
                      final ytProvider = Provider.of<YouTubeProvider>(
                        context,
                        listen: false,
                      );
                      await ytProvider.clearCache();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text(
                              'Cache SQLite YouTube berhasil dibersihkan!',
                            ),
                            backgroundColor: V35Tokens.bgElevated,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),

              // ANDROID EXPERIENCE
              if (!kIsWeb && Platform.isAndroid) ...[
                const SizedBox(height: V35Tokens.space24),
                _buildSectionHeader('ANDROID EXPERIENCE'),
                _buildSettingsGroup(
                  children: [
                    _buildSwitchTile(
                      icon: Icons.restore_rounded,
                      iconColor: V35Tokens.accent,
                      title: 'Resume Playback (Pulihkan Pemutaran)',
                      subtitle:
                          'Otomatis pulihkan lagu dan posisi saat aplikasi dibuka kembali',
                      value: player.resumePlaybackEnabled,
                      onChanged: (val) => player.setResumePlaybackEnabled(val),
                    ),
                    _buildDivider(),
                    _buildSwitchTile(
                      icon: Icons.headset_off_rounded,
                      iconColor: V35Tokens.accent,
                      title: 'Pause saat Headphone Terputus',
                      subtitle:
                          'Jeda otomatis saat koneksi headset atau Bluetooth terputus',
                      value: player.pauseOnHeadphoneDisconnect,
                      onChanged: (val) =>
                          player.setPauseOnHeadphoneDisconnect(val),
                    ),
                    _buildDivider(),
                    _buildSwitchTile(
                      icon: Icons.notifications_active_rounded,
                      iconColor: V35Tokens.accent,
                      title: 'Notification & Lock Screen Player',
                      subtitle:
                          'Tampilkan kontrol pemutar di notifikasi sistem dan layar kunci',
                      value: player.notificationPlayerEnabled,
                      onChanged: (val) =>
                          player.setNotificationPlayerEnabled(val),
                    ),
                    _buildDivider(),
                    _buildSettingTile(
                      icon: Icons.bug_report_rounded,
                      iconColor: Colors.amberAccent,
                      title: 'Diagnostik Playback Android',
                      subtitle:
                          'Pantau tahapan playback lokal & salin laporan log',
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        color: V35Tokens.textMuted,
                      ),
                      onTap: () => AndroidDiagnosticDialog.show(context),
                    ),
                  ],
                ),
              ],

              // DESKTOP & SYSTEM INTEGRATION
              if (!kIsWeb && Platform.isWindows) ...[
                const SizedBox(height: V35Tokens.space24),
                _buildSectionHeader('DESKTOP & INTEGRASI SISTEM'),
                StatefulBuilder(
                  builder: (context, setDesktopState) {
                    final desktop = DesktopIntegrationService.instance;
                    return _buildSettingsGroup(
                      children: [
                        _buildSwitchTile(
                          icon: Icons.keyboard_command_key_rounded,
                          iconColor: V35Tokens.accent,
                          title: 'Global Media Keys',
                          subtitle:
                              'Kendalikan Play/Pause, Next, dan Previous via keyboard secara global',
                          value: desktop.globalMediaKeysEnabled,
                          onChanged: (val) async {
                            await desktop.setGlobalMediaKeysEnabled(val);
                            setDesktopState(() {});
                          },
                        ),
                        _buildDivider(),
                        _buildSwitchTile(
                          icon: Icons.pin_end_rounded,
                          iconColor: V35Tokens.accent,
                          title: 'Windows System Tray',
                          subtitle:
                              'Tampilkan ikon MyMusic di area notifikasi Windows system tray',
                          value: desktop.systemTrayEnabled,
                          onChanged: (val) async {
                            await desktop.setSystemTrayEnabled(val);
                            setDesktopState(() {});
                          },
                        ),
                        _buildDivider(),
                        _buildSwitchTile(
                          icon: Icons.call_to_action_rounded,
                          iconColor: V35Tokens.accent,
                          title: 'Minimize to Tray saat Tutup',
                          subtitle:
                              'Tombol [X] menyembunyikan jendela ke tray tanpa memutus audio',
                          value: desktop.minimizeToTrayEnabled,
                          onChanged: desktop.systemTrayEnabled
                              ? (val) async {
                                  await desktop.setMinimizeToTray(val);
                                  setDesktopState(() {});
                                }
                              : null,
                        ),
                        _buildDivider(),
                        _buildSwitchTile(
                          icon: Icons.push_pin_rounded,
                          iconColor: V35Tokens.accent,
                          title: 'Always on Top (Selalu di Depan)',
                          subtitle:
                              'Pertahankan posisi jendela Mini Player di atas aplikasi lain',
                          value: desktop.alwaysOnTop,
                          onChanged: (val) async {
                            await desktop.setAlwaysOnTop(val);
                            setDesktopState(() {});
                          },
                        ),
                      ],
                    );
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // Helper widgets for V3.5 Obsidian presentation
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: V35Tokens.space8),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 12,
            decoration: BoxDecoration(
              color: V35Tokens.accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: V35Tokens.space8),
          Text(
            title,
            style: const TextStyle(
              color: V35Tokens.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsGroup({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: V35Tokens.bgSurface,
        borderRadius: V35Tokens.brMd,
        border: Border.all(color: V35Tokens.borderSubtle, width: 1),
      ),
      child: ClipRRect(
        borderRadius: V35Tokens.brMd,
        child: Column(children: children),
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(
      height: 1,
      thickness: 1,
      color: V35Tokens.borderSubtle,
      indent: 52,
      endIndent: 0,
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        hoverColor: V35Tokens.bgElevated,
        splashColor: V35Tokens.bgHighlight,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: V35Tokens.space16,
            vertical: V35Tokens.space12,
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: V35Tokens.brSm,
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: V35Tokens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: V35Tokens.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: V35Tokens.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: V35Tokens.space8),
                trailing,
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: V35Tokens.space16,
        vertical: V35Tokens.space8,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: V35Tokens.brSm,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: V35Tokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: V35Tokens.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: V35Tokens.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: V35Tokens.space8),
          Switch(
            value: value,
            activeThumbColor: V35Tokens.accent,
            activeTrackColor: V35Tokens.accent.withValues(alpha: 0.35),
            inactiveThumbColor: V35Tokens.textMuted,
            inactiveTrackColor: V35Tokens.bgElevated,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String label, {bool isActive = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isActive
            ? V35Tokens.accent.withValues(alpha: 0.15)
            : V35Tokens.bgHighlight,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isActive
              ? V35Tokens.accent.withValues(alpha: 0.4)
              : V35Tokens.borderSubtle,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isActive ? V35Tokens.accent : V35Tokens.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Future<void> _handleBackup(BuildContext context) async {
    try {
      final jsonStr = await BackupRestoreService.instance.createBackupJson();
      final bytes = Uint8List.fromList(utf8.encode(jsonStr));
      final fileName =
          'mymusic_backup_${DateTime.now().millisecondsSinceEpoch}.mymusicbackup';

      final outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Simpan File Cadangan TONAVERA',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['mymusicbackup', 'json'],
        bytes: bytes,
      );

      if (outputPath != null) {
        final file = File(outputPath);
        await file.writeAsBytes(bytes);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Pustaka berhasil dicadangkan ke: ${file.path}'),
              backgroundColor: V35Tokens.bgElevated,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membuat cadangan: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handleRestore(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Pilih File Cadangan TONAVERA',
        type: FileType.custom,
        allowedExtensions: ['mymusicbackup', 'json'],
      );

      if (result != null && result.files.isNotEmpty) {
        final path = result.files.first.path;
        if (path == null) return;
        final jsonStr = await File(path).readAsString();

        final preview = BackupRestoreService.instance.previewBackup(jsonStr);

        if (!context.mounted) return;
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: V35Tokens.bgElevated,
            title: const Text(
              'Konfirmasi Pemulihan Pustaka',
              style: TextStyle(color: V35Tokens.textPrimary),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lagu: ${preview.songsCount}',
                  style: const TextStyle(color: V35Tokens.textSecondary),
                ),
                Text(
                  'Playlist: ${preview.playlistsCount}',
                  style: const TextStyle(color: V35Tokens.textSecondary),
                ),
                Text(
                  'Favorit: ${preview.favoritesCount}',
                  style: const TextStyle(color: V35Tokens.textSecondary),
                ),
                Text(
                  'Riwayat: ${preview.historyCount}',
                  style: const TextStyle(color: V35Tokens.textSecondary),
                ),
                Text(
                  'Dibuat Pada: ${preview.createdAt}',
                  style: const TextStyle(color: V35Tokens.textSecondary),
                ),
                if (preview.missingFilesCount > 0)
                  Text(
                    'Peringatan: ${preview.missingFilesCount} lagu tidak ditemukan di lokasi file asli.',
                    style: const TextStyle(color: Colors.orangeAccent),
                  ),
                const SizedBox(height: 12),
                const Text(
                  'PERINGATAN: Pemulihan akan menggantikan pustaka saat ini. Lanjutkan?',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text(
                  'Batal',
                  style: TextStyle(color: V35Tokens.textSecondary),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                ),
                child: const Text(
                  'Pulihkan Sekarang',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        );

        if (confirm == true) {
          await BackupRestoreService.instance.restoreBackup(jsonStr);
          if (context.mounted) {
            Provider.of<PlayerProvider>(
              context,
              listen: false,
            ).restorePlayerState();
            Provider.of<PlaylistProvider>(
              context,
              listen: false,
            ).fetchPlaylists();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Pustaka berhasil dipulihkan!'),
                backgroundColor: V35Tokens.bgElevated,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memulihkan cadangan: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handleImportPlaylist(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Pilih File Playlist (JSON / M3U)',
        type: FileType.custom,
        allowedExtensions: ['json', 'm3u', 'm3u8'],
      );

      if (result != null && result.files.isNotEmpty) {
        final path = result.files.first.path;
        if (path == null) return;
        final content = await File(path).readAsString();

        final importRes = await PlaylistExportImportService.instance
            .parseAndMatchImport(content, filename: result.files.first.name);

        if (!context.mounted) return;
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: V35Tokens.bgElevated,
            title: Text(
              'Impor Playlist: ${importRes.playlistName}',
              style: const TextStyle(color: V35Tokens.textPrimary),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Lagu di File: ${importRes.totalTracks}',
                  style: const TextStyle(color: V35Tokens.textSecondary),
                ),
                Text(
                  'Lagu Cocok di Pustaka: ${importRes.matchedCount}',
                  style: const TextStyle(color: V35Tokens.textSecondary),
                ),
                Text(
                  'Lagu Tidak Ditemukan: ${importRes.missingCount}',
                  style: const TextStyle(color: V35Tokens.textSecondary),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Impor lagu yang cocok ke playlist baru?',
                  style: TextStyle(color: V35Tokens.textPrimary),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text(
                  'Batal',
                  style: TextStyle(color: V35Tokens.textSecondary),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: V35Tokens.accent,
                ),
                child: const Text(
                  'Impor Playlist',
                  style: TextStyle(
                    color: V35Tokens.bgVoid,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );

        if (confirm == true) {
          final playlistId = await PlaylistExportImportService.instance
              .commitImport(importRes);
          if (context.mounted) {
            Provider.of<PlaylistProvider>(
              context,
              listen: false,
            ).fetchPlaylists();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Playlist berhasil diimpor! (ID: $playlistId)'),
                backgroundColor: V35Tokens.bgElevated,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengimpor playlist: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handleCloudSync(BuildContext context) async {
    final provider = DefaultCloudSyncProvider();
    final isOnline = await provider.isConnected();

    if (!context.mounted) return;
    if (!isOnline) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: V35Tokens.bgElevated,
          title: const Text(
            'Cloud Sync (Opsional)',
            style: TextStyle(color: V35Tokens.textPrimary),
          ),
          content: const Text(
            'Aplikasi sedang berjalan secara Offline / Akun Lokal.\n\n'
            'Untuk menggunakan Cloud Sync, silakan login dengan akun online di menu Profil/Auth.',
            style: TextStyle(color: V35Tokens.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Tutup', style: TextStyle(color: V35Tokens.accent)),
            ),
          ],
        ),
      );
    } else {
      final synced = await provider.syncPendingOutbox();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sinkronkan Cloud selesai: $synced item terkirim.'),
            backgroundColor: V35Tokens.bgElevated,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
