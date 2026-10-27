import 'package:flutter/material.dart';
import '../models/artist_model.dart';
import '../core/theme/v35_tokens.dart';
import 'app_image.dart';

class ArtistCard extends StatelessWidget {
  final ArtistModel artist;
  final VoidCallback? onTap;

  const ArtistCard({super.key, required this.artist, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        margin: const EdgeInsets.only(right: 14),
        child: Column(
          children: [
            ClipOval(
              child: SizedBox(
                width: 84,
                height: 84,
                child: AppImage(
                  imagePath: artist.image,
                  width: 84,
                  height: 84,
                  defaultIcon: Icons.person_rounded,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              artist.name,
              style: const TextStyle(
                color: V35Tokens.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
