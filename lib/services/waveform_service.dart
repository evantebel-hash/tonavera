import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';

/// Lightweight local waveform cache and generator.
///
/// Generates downsampled normalized amplitude points (100–120 points)
/// based on file data or synthetic harmonic profile derived from track metadata.
/// Results are cached in-memory and keyed by song ID & duration.
class WaveformService {
  WaveformService._();
  static final WaveformService instance = WaveformService._();

  static const int defaultSampleCount = 100;
  final Map<String, List<double>> _cache = {};

  /// Returns normalized waveform amplitude samples (0.0 to 1.0).
  Future<List<double>> getWaveform({
    required String songId,
    String? filePath,
    Duration? duration,
    int sampleCount = defaultSampleCount,
  }) async {
    final cacheKey = '$songId:${duration?.inSeconds ?? 0}:$sampleCount';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    List<double>? samples;

    // Attempt fast local file sample extraction if file exists
    if (filePath != null && filePath.isNotEmpty) {
      try {
        final cleanPath = filePath.startsWith('file://')
            ? filePath.substring(7)
            : filePath;
        final file = File(cleanPath);
        if (await file.exists()) {
          samples = await _extractLightweightSamples(file, sampleCount);
        }
      } catch (e) {
        debugPrint('Waveform extraction fallback: $e');
      }
    }

    // Deterministic synthetic fallback based on song characteristics
    samples ??= _generateHarmonicWaveform(songId, duration, sampleCount);

    _cache[cacheKey] = samples;
    return samples;
  }

  Future<List<double>> _extractLightweightSamples(
    File file,
    int sampleCount,
  ) async {
    final fileSize = await file.length();
    if (fileSize < 1024)
      return _generateHarmonicWaveform(file.path, null, sampleCount);

    // Read small chunks across the file to estimate energy density without full decode
    final raf = await file.open(mode: FileMode.read);
    try {
      final samples = <double>[];
      final step = (fileSize / sampleCount).floor();
      const chunkSize = 256;

      for (int i = 0; i < sampleCount; i++) {
        final offset = (i * step).clamp(0, fileSize - chunkSize);
        await raf.setPosition(offset);
        final buffer = Uint8List(chunkSize);
        final bytesRead = await raf.readInto(buffer);

        if (bytesRead > 0) {
          double sum = 0.0;
          for (int b = 0; b < bytesRead; b++) {
            // Calculate byte delta variance
            sum += (buffer[b] - 128).abs();
          }
          final avg = (sum / bytesRead) / 128.0;
          samples.add(avg.clamp(0.08, 1.0));
        } else {
          samples.add(0.2);
        }
      }

      // Smooth samples with a simple moving window
      return _smooth(samples);
    } finally {
      await raf.close();
    }
  }

  List<double> _generateHarmonicWaveform(
    String seedStr,
    Duration? duration,
    int count,
  ) {
    final seed = seedStr.codeUnits.fold<int>(0, (prev, elem) => prev + elem);
    final random = Random(seed);
    final raw = <double>[];

    final durSec = duration?.inSeconds ?? 180;
    final tempoFactor = (durSec % 20 + 10) / 10.0;

    for (int i = 0; i < count; i++) {
      final progress = i / count;
      // Musical structure curve: intro, build-up, chorus peaks, outro
      final introOutro = sin(progress * pi);
      final harmonic =
          0.3 * sin(progress * pi * tempoFactor) +
          0.2 * cos(progress * pi * 4 * tempoFactor) +
          0.15 * sin(progress * pi * 8 * tempoFactor);
      final jitter = (random.nextDouble() - 0.5) * 0.2;

      final val = (0.2 + (introOutro * (0.5 + harmonic + jitter))).clamp(
        0.1,
        0.95,
      );
      raw.add(val);
    }

    return _smooth(raw);
  }

  List<double> _smooth(List<double> input) {
    if (input.length < 3) return input;
    final smoothed = <double>[];
    for (int i = 0; i < input.length; i++) {
      if (i == 0) {
        smoothed.add((input[0] * 2 + input[1]) / 3);
      } else if (i == input.length - 1) {
        smoothed.add((input[i] * 2 + input[i - 1]) / 3);
      } else {
        smoothed.add((input[i - 1] + input[i] * 2 + input[i + 1]) / 4);
      }
    }
    return smoothed;
  }

  void clearCache() {
    _cache.clear();
  }
}
