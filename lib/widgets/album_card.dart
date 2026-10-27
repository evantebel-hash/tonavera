import 'package:flutter/material.dart';
import '../models/album_model.dart';
import '../core/theme/v35_tokens.dart';

class AlbumCard extends StatelessWidget {
  final AlbumModel album;
  final VoidCallback? onTap;

  const AlbumCard({super.key, required this.album, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: V35Tokens.bgSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: V35Tokens.borderSubtle),
                gradient: const LinearGradient(
                  colors: [V35Tokens.bgSurface, V35Tokens.bgElevated],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Icon(
                Icons.album_rounded,
                size: 56,
                color: V35Tokens.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              album.title,
              style: const TextStyle(
                color: V35Tokens.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              album.artistName ?? 'Artist',
              style: const TextStyle(
                color: V35Tokens.textSecondary,
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
