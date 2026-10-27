import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/v35_tokens.dart';
import '../../models/song_model.dart';
import '../../providers/player_provider.dart';
import '../../widgets/lyrics/lyrics_view.dart';
import '../../widgets/now_playing/dynamic_background.dart';

/// Fullscreen standalone lyrics screen (Phase 3.5 / V3.5).
class LyricsScreen extends StatelessWidget {
  final SongModel song;

  const LyricsScreen({super.key, required this.song});

  @override
  Widget build(BuildContext context) {
    final player = Provider.of<PlayerProvider>(context);

    return Scaffold(
      backgroundColor: V35Tokens.bgVoid,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 28,
            color: V35Tokens.textPrimary,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          children: [
            Text(
              song.title,
              style: V35Tokens.title.copyWith(
                fontWeight: FontWeight.w700,
                color: V35Tokens.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              song.artistName ?? 'Unknown Artist',
              style: V35Tokens.secondary.copyWith(
                fontSize: 12.0,
                color: V35Tokens.textMuted,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: DynamicBackground(
        song: song,
        enabled: player.dynamicBackgroundEnabled,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: V35Tokens.space16,
              vertical: V35Tokens.space8,
            ),
            child: LyricsView(song: song),
          ),
        ),
      ),
    );
  }
}
