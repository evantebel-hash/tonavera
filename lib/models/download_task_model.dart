import '../models/song_model.dart';

enum DownloadStatus {
  queued,
  downloading,
  paused,
  completed,
  failed,
  cancelled,
}

class DownloadTask {
  final String id;
  final SongModel song;
  final String downloadUrl;
  DownloadStatus status;
  double progress; // 0.0 to 1.0
  int bytesDownloaded;
  int totalBytes;
  String? error;
  final DateTime createdAt;
  DateTime? completedAt;
  String? localPath;

  DownloadTask({
    required this.id,
    required this.song,
    required this.downloadUrl,
    this.status = DownloadStatus.queued,
    this.progress = 0.0,
    this.bytesDownloaded = 0,
    this.totalBytes = 0,
    this.error,
    DateTime? createdAt,
    this.completedAt,
    this.localPath,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'song': song.toJson(),
      'download_url': downloadUrl,
      'status': status.name,
      'progress': progress,
      'bytes_downloaded': bytesDownloaded,
      'total_bytes': totalBytes,
      'error': error,
      'created_at': createdAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'local_path': localPath,
    };
  }

  factory DownloadTask.fromJson(Map<String, dynamic> json) {
    return DownloadTask(
      id: json['id'],
      song: SongModel.fromJson(json['song']),
      downloadUrl: json['download_url'] ?? '',
      status: DownloadStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => DownloadStatus.failed,
      ),
      progress: (json['progress'] ?? 0.0).toDouble(),
      bytesDownloaded: json['bytes_downloaded'] ?? 0,
      totalBytes: json['total_bytes'] ?? 0,
      error: json['error'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'])
          : null,
      localPath: json['local_path'],
    );
  }
}
