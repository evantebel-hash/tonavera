import 'dart:io';

class AudioFileValidator {
  static const Set<String> supportedExtensions = {
    'mp3',
    'flac',
    'm4a',
    'wav',
    'ogg',
    'opus',
    'aac',
  };

  /// Check if the file extension is a supported audio format.
  static bool isSupportedAudioFile(String path) {
    if (path.trim().isEmpty) return false;
    final cleanPath = path.replaceAll('\\', '/');
    final lastDot = cleanPath.lastIndexOf('.');
    if (lastDot == -1 || lastDot == cleanPath.length - 1) return false;
    final ext = cleanPath.substring(lastDot + 1).toLowerCase();
    return supportedExtensions.contains(ext);
  }

  /// Get file extension without leading dot in lowercase.
  static String getExtension(String path) {
    final cleanPath = path.replaceAll('\\', '/');
    final lastDot = cleanPath.lastIndexOf('.');
    if (lastDot == -1 || lastDot == cleanPath.length - 1) return '';
    return cleanPath.substring(lastDot + 1).toLowerCase();
  }

  /// Safely resolve an audio file or scan recursively if it is a directory.
  static List<File> resolveAudioFiles(List<String> paths) {
    final audioFiles = <File>[];
    final seenCanonicalPaths = <String>{};

    for (final rawPath in paths) {
      if (rawPath.trim().isEmpty) continue;
      final fileType = FileSystemEntity.typeSync(rawPath);

      if (fileType == FileSystemEntityType.file) {
        if (isSupportedAudioFile(rawPath)) {
          final file = File(rawPath);
          if (file.existsSync()) {
            final key = rawPath.replaceAll('\\', '/').toLowerCase();
            if (!seenCanonicalPaths.contains(key)) {
              seenCanonicalPaths.add(key);
              audioFiles.add(file);
            }
          }
        }
      } else if (fileType == FileSystemEntityType.directory) {
        try {
          final dir = Directory(rawPath);
          if (dir.existsSync()) {
            final entries = dir.listSync(recursive: true, followLinks: false);
            for (final entry in entries) {
              if (entry is File && isSupportedAudioFile(entry.path)) {
                final key = entry.path.replaceAll('\\', '/').toLowerCase();
                if (!seenCanonicalPaths.contains(key)) {
                  seenCanonicalPaths.add(key);
                  audioFiles.add(entry);
                }
              }
            }
          }
        } catch (_) {}
      }
    }

    return audioFiles;
  }
}
