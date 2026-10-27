enum StatisticsTimeRange { today, last7Days, last30Days, thisYear, allTime }

extension StatisticsTimeRangeExt on StatisticsTimeRange {
  String get label {
    switch (this) {
      case StatisticsTimeRange.today:
        return 'Hari Ini';
      case StatisticsTimeRange.last7Days:
        return '7 Hari';
      case StatisticsTimeRange.last30Days:
        return '30 Hari';
      case StatisticsTimeRange.thisYear:
        return 'Tahun Ini';
      case StatisticsTimeRange.allTime:
        return 'Semua';
    }
  }

  DateTime? get startDate {
    final now = DateTime.now();
    switch (this) {
      case StatisticsTimeRange.today:
        return DateTime(now.year, now.month, now.day);
      case StatisticsTimeRange.last7Days:
        return DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(const Duration(days: 6));
      case StatisticsTimeRange.last30Days:
        return DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(const Duration(days: 29));
      case StatisticsTimeRange.thisYear:
        return DateTime(now.year, 1, 1);
      case StatisticsTimeRange.allTime:
        return null;
    }
  }

  DateTime? get endDate {
    final now = DateTime.now();
    switch (this) {
      case StatisticsTimeRange.today:
      case StatisticsTimeRange.last7Days:
      case StatisticsTimeRange.last30Days:
      case StatisticsTimeRange.thisYear:
        return DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
      case StatisticsTimeRange.allTime:
        return null;
    }
  }
}

class ListeningStatisticsModel {
  final int totalListeningTimeSeconds;
  final int totalPlays;
  final int uniqueSongs;
  final int uniqueArtists;
  final int uniqueAlbums;
  final int completedPlays;
  final int skippedPlays;
  final double completionRate;
  final int averageDurationSeconds;

  ListeningStatisticsModel({
    this.totalListeningTimeSeconds = 0,
    this.totalPlays = 0,
    this.uniqueSongs = 0,
    this.uniqueArtists = 0,
    this.uniqueAlbums = 0,
    this.completedPlays = 0,
    this.skippedPlays = 0,
    this.completionRate = 0.0,
    this.averageDurationSeconds = 0,
  });

  factory ListeningStatisticsModel.fromMap(Map<String, dynamic> map) {
    final totalPlays = int.tryParse(map['total_plays']?.toString() ?? '0') ?? 0;
    final completedPlays =
        int.tryParse(map['completed_plays']?.toString() ?? '0') ?? 0;
    final totalSeconds =
        int.tryParse(map['total_time_seconds']?.toString() ?? '0') ?? 0;

    return ListeningStatisticsModel(
      totalListeningTimeSeconds: totalSeconds,
      totalPlays: totalPlays,
      uniqueSongs: int.tryParse(map['unique_songs']?.toString() ?? '0') ?? 0,
      uniqueArtists:
          int.tryParse(map['unique_artists']?.toString() ?? '0') ?? 0,
      uniqueAlbums: int.tryParse(map['unique_albums']?.toString() ?? '0') ?? 0,
      completedPlays: completedPlays,
      skippedPlays: int.tryParse(map['skipped_plays']?.toString() ?? '0') ?? 0,
      completionRate: totalPlays > 0
          ? (completedPlays / totalPlays) * 100.0
          : 0.0,
      averageDurationSeconds: totalPlays > 0 ? (totalSeconds ~/ totalPlays) : 0,
    );
  }
}

class TopMusicItemModel {
  final int id;
  final String title;
  final String? subtitle;
  final String? cover;
  final int playCount;
  final int totalDurationSeconds;
  final int? artistId;
  final int? albumId;
  final String? audioPath;
  final String? filePath;

  TopMusicItemModel({
    required this.id,
    required this.title,
    this.subtitle,
    this.cover,
    required this.playCount,
    required this.totalDurationSeconds,
    this.artistId,
    this.albumId,
    this.audioPath,
    this.filePath,
  });
}

class DailyListeningActivityModel {
  final DateTime date;
  final int totalSeconds;
  final int totalPlays;
  final int uniqueSongs;

  DailyListeningActivityModel({
    required this.date,
    required this.totalSeconds,
    required this.totalPlays,
    required this.uniqueSongs,
  });
}
