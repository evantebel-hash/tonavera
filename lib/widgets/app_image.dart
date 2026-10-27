import 'dart:io';
import 'package:flutter/material.dart';
import '../core/theme/v35_tokens.dart';

class AppImage extends StatelessWidget {
  final String? imagePath;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? fallback;
  final IconData defaultIcon;
  final int? cacheWidth;
  final int? cacheHeight;

  const AppImage({
    super.key,
    required this.imagePath,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.fallback,
    this.defaultIcon = Icons.music_note_rounded,
    this.cacheWidth,
    this.cacheHeight,
  });

  @override
  Widget build(BuildContext context) {
    final path = imagePath?.trim();

    if (path == null || path.isEmpty) {
      return _buildFallback();
    }

    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Image.network(
        path,
        width: width,
        height: height,
        fit: fit,
        cacheWidth: cacheWidth,
        cacheHeight: cacheHeight,
        errorBuilder: (ctx, err, stack) => _buildFallback(),
      );
    }

    String cleanPath = path;
    if (cleanPath.startsWith('file://')) {
      cleanPath = cleanPath.substring(7);
    }

    final localFile = File(cleanPath);
    if (localFile.existsSync()) {
      return Image.file(
        localFile,
        width: width,
        height: height,
        fit: fit,
        cacheWidth: cacheWidth,
        cacheHeight: cacheHeight,
        errorBuilder: (ctx, err, stack) => _buildFallback(),
      );
    }

    return _buildFallback();
  }

  Widget _buildFallback() {
    if (fallback != null) return fallback!;
    return Container(
      width: width,
      height: height,
      color: V35Tokens.bgSurface,
      child: Center(
        child: Icon(
          defaultIcon,
          size: (width != null && height != null) ? (width! * 0.4) : 24,
          color: V35Tokens.textMuted,
        ),
      ),
    );
  }
}
