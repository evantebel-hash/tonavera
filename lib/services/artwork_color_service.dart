import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../core/theme/v35_tokens.dart';

class ArtworkColorPalette {
  final Color dominantColor;
  final Color secondaryColor;
  final Color accentColor;

  const ArtworkColorPalette({
    required this.dominantColor,
    required this.secondaryColor,
    required this.accentColor,
  });

  static ArtworkColorPalette get defaultDark => ArtworkColorPalette(
    dominantColor: V35Tokens.bgSurface,
    secondaryColor: V35Tokens.bgVoid,
    accentColor: V35Tokens.accent,
  );
}

/// Fast, offline-first extractor that extracts subtle ambient colors from artwork.
class ArtworkColorService {
  static final ArtworkColorService instance = ArtworkColorService._internal();
  ArtworkColorService._internal();

  final Map<String, ArtworkColorPalette> _cache = {};

  /// Clears in-memory palette cache.
  void clearCache() {
    _cache.clear();
  }

  /// Extracts dominant palette from an artwork image path (file path or URL).
  Future<ArtworkColorPalette> extractPalette(String? imagePath) async {
    if (imagePath == null || imagePath.trim().isEmpty) {
      return ArtworkColorPalette.defaultDark;
    }

    final key = imagePath.trim();
    if (_cache.containsKey(key)) {
      return _cache[key]!;
    }

    try {
      Uint8List? bytes;
      if (key.startsWith('http://') || key.startsWith('https://')) {
        // Online network image (rare in local-first, but handle gracefully)
        final uri = Uri.tryParse(key);
        if (uri != null) {
          final client = HttpClient();
          final request = await client
              .getUrl(uri)
              .timeout(const Duration(seconds: 3));
          final response = await request.close().timeout(
            const Duration(seconds: 3),
          );
          if (response.statusCode == 200) {
            final chunks = <List<int>>[];
            await for (final chunk in response) {
              chunks.add(chunk);
            }
            bytes = Uint8List.fromList(chunks.expand((x) => x).toList());
          }
        }
      } else {
        String cleanPath = key;
        if (cleanPath.startsWith('file://')) {
          cleanPath = cleanPath.substring(7);
        }
        final file = File(cleanPath);
        if (await file.exists()) {
          bytes = await file.readAsBytes();
        }
      }

      if (bytes == null || bytes.isEmpty) {
        final fallback = ArtworkColorPalette.defaultDark;
        _cache[key] = fallback;
        return fallback;
      }

      final palette = await _computePaletteFromBytes(bytes);
      _cache[key] = palette;
      return palette;
    } catch (e) {
      debugPrint(
        'ArtworkColorService: extraction failed ($e), using fallback.',
      );
      final fallback = ArtworkColorPalette.defaultDark;
      _cache[key] = fallback;
      return fallback;
    }
  }

  /// Decodes image downsampled to a 16x16 thumbnail to sample pixel colors efficiently without high CPU/memory cost.
  Future<ArtworkColorPalette> _computePaletteFromBytes(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 16,
        targetHeight: 16,
        allowUpscaling: false,
      );
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final byteData = await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );

      if (byteData == null) {
        return ArtworkColorPalette.defaultDark;
      }

      final pixels = byteData.buffer.asUint8List();
      int totalR = 0, totalG = 0, totalB = 0;
      int validSamples = 0;

      // Sample color averages
      for (int i = 0; i < pixels.length; i += 4) {
        final r = pixels[i];
        final g = pixels[i + 1];
        final b = pixels[i + 2];
        final a = pixels[i + 3];

        if (a < 128) continue; // Ignore transparent pixels

        // Avoid pure white / pure black extremes for richer ambience
        final brightness = (0.299 * r + 0.587 * g + 0.114 * b);
        if (brightness > 20 && brightness < 235) {
          totalR += r;
          totalG += g;
          totalB += b;
          validSamples++;
        }
      }

      if (validSamples == 0) {
        return ArtworkColorPalette.defaultDark;
      }

      final avgR = (totalR ~/ validSamples).clamp(0, 255);
      final avgG = (totalG ~/ validSamples).clamp(0, 255);
      final avgB = (totalB ~/ validSamples).clamp(0, 255);

      final dominant = Color.fromARGB(255, avgR, avgG, avgB);
      final secondary = HSLColor.fromColor(dominant)
          .withLightness(
            (HSLColor.fromColor(dominant).lightness * 0.6).clamp(0.1, 0.4),
          )
          .toColor();
      final accent = HSLColor.fromColor(dominant)
          .withSaturation(
            (HSLColor.fromColor(dominant).saturation * 1.2).clamp(0.4, 0.9),
          )
          .withLightness(0.6)
          .toColor();

      return ArtworkColorPalette(
        dominantColor: dominant,
        secondaryColor: secondary,
        accentColor: accent,
      );
    } catch (_) {
      return ArtworkColorPalette.defaultDark;
    }
  }
}
