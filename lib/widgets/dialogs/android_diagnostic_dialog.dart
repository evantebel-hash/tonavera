import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/v35_tokens.dart';
import '../../core/theme/v35_accent.dart';
import '../../providers/player_provider.dart';
import '../../services/audio/android_diagnostic_logger.dart';
import '../dialogs/settings_detail_dialog.dart';

/// Modal dialog for viewing and copying Android playback diagnostic logs on release builds.
class AndroidDiagnosticDialog extends StatefulWidget {
  const AndroidDiagnosticDialog({super.key});

  static Future<void> show(BuildContext context) {
    if (!kIsWeb && !Platform.isAndroid) return Future.value();
    return SettingsDetailDialog.show(
      context: context,
      icon: Icons.bug_report_rounded,
      title: 'Diagnostik Playback Android',
      subtitle: 'Pantau tahapan playback lokal & salin log ke clipboard',
      maxWidth: 580,
      maxHeight: 680,
      child: const AndroidDiagnosticDialog(),
    );
  }

  @override
  State<AndroidDiagnosticDialog> createState() =>
      _AndroidDiagnosticDialogState();
}

class _AndroidDiagnosticDialogState extends State<AndroidDiagnosticDialog> {
  final ScrollController _scrollController = ScrollController();
  bool _copied = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _gatherPlayerStatus(PlayerProvider player) {
    return {
      'CurrentSong': player.currentSong?.title ?? 'null',
      'CurrentSongSource': player.currentSong?.source ?? 'null',
      'IsPlaying': player.isPlaying,
      'IsLoadingAudio': player.isLoadingAudio,
      'IsLoadingSource': player.isLoadingSource,
      'ActiveSessionId': player.activeSessionId,
      'PlaybackConfirmedSessionId': player.playbackConfirmedSessionId,
      'PositionMs': player.position.inMilliseconds,
      'DurationMs': player.duration.inMilliseconds,
      'NotificationPlayerEnabled': player.notificationPlayerEnabled,
      'EqualizerEnabled': player.equalizerEnabled,
    };
  }

  Future<void> _copyReport(PlayerProvider player) async {
    final status = _gatherPlayerStatus(player);
    final success = await AndroidDiagnosticLogger.instance
        .copyReportToClipboard(playerStatus: status);
    if (!mounted) return;
    if (success) {
      setState(() => _copied = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Laporan Diagnostik berhasil disalin ke Clipboard!'),
          backgroundColor: Color(0xFF1DB954),
          duration: Duration(seconds: 3),
        ),
      );
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _copied = false);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal menyalin laporan diagnostik.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = Provider.of<PlayerProvider>(context);
    final diag = AndroidDiagnosticLogger.instance;
    final logs = diag.logs;
    final accent = V35Accent.current;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Status Overview Card
        Container(
          padding: const EdgeInsets.all(V35Tokens.space12),
          decoration: BoxDecoration(
            color: V35Tokens.bgSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: V35Tokens.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: player.isLoadingAudio
                              ? Colors.amberAccent
                              : (player.isPlaying
                                    ? accent.base
                                    : V35Tokens.textMuted),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        player.isLoadingAudio
                            ? 'Status: LOADING / BUFFERING'
                            : (player.isPlaying
                                  ? 'Status: PLAYING'
                                  : 'Status: IDLE / PAUSED'),
                        style: const TextStyle(
                          color: V35Tokens.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Sesi: #${player.activeSessionId}',
                    style: const TextStyle(
                      color: V35Tokens.textMuted,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Tahap Terakhir: ${diag.lastStage}',
                style: TextStyle(
                  color: accent.base,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (diag.lastError != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Error: ${diag.lastError}',
                  style: const TextStyle(color: Colors.redAccent, fontSize: 11),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: V35Tokens.space12),

        // Action Buttons Row
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: Icon(
                  _copied ? Icons.check_rounded : Icons.copy_all_rounded,
                  size: 18,
                  color: Colors.black,
                ),
                label: Text(
                  _copied
                      ? 'Tersalin ke Clipboard!'
                      : 'Salin Laporan Diagnostik',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent.base,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => _copyReport(player),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(
                Icons.delete_sweep_rounded,
                color: V35Tokens.textMuted,
              ),
              tooltip: 'Bersihkan Log Buffer',
              onPressed: () {
                setState(() {
                  diag.clearLogs();
                });
              },
            ),
          ],
        ),
        const SizedBox(height: V35Tokens.space12),

        // Live Log Viewer Box
        Container(
          constraints: const BoxConstraints(minHeight: 180, maxHeight: 320),
          decoration: BoxDecoration(
            color: const Color(0xFF0F1115),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: V35Tokens.borderSubtle),
          ),
          padding: const EdgeInsets.all(V35Tokens.space8),
          child: logs.isEmpty
              ? const Center(
                  child: Text(
                    'Belum ada log tercatat.\nPutar salah satu lagu lokal untuk memulai pencatatan.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: V35Tokens.textMuted, fontSize: 12),
                  ),
                )
              : Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: true,
                  child: ListView.builder(
                    controller: _scrollController,
                    shrinkWrap: true,
                    itemCount: logs.length,
                    itemBuilder: (context, idx) {
                      final line = logs[idx];
                      final isError =
                          line.contains('[ERROR]') ||
                          line.contains('Error') ||
                          line.contains('failed');
                      final isOk =
                          line.contains('[STAGE_OK]') ||
                          line.contains('Success');
                      final isWarn =
                          line.contains('[STAGE_WARN]') ||
                          line.contains('Warning');

                      Color textColor = const Color(0xFFD4D4D4);
                      if (isError) {
                        textColor = const Color(0xFFFF6B6B);
                      } else if (isOk) {
                        textColor = const Color(0xFF51CF66);
                      } else if (isWarn) {
                        textColor = const Color(0xFFFCC419);
                      }

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2.0),
                        child: Text(
                          line,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 10.5,
                            color: textColor,
                            height: 1.3,
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}
