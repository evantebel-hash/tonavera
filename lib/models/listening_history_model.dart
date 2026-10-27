class ListeningHistoryModel {
  final int id;
  final int songId;
  final String title;
  final String artistName;
  final String? albumTitle;
  final String? cover;
  final String? audioPath;
  final String? filePath;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int durationPlayed; // in seconds
  final bool completed;
  final bool skipped;

  ListeningHistoryModel({
    required this.id,
    required this.songId,
    required this.title,
    required this.artistName,
    this.albumTitle,
    this.cover,
    this.audioPath,
    this.filePath,
    required this.startedAt,
    this.endedAt,
    this.durationPlayed = 0,
    this.completed = false,
    this.skipped = false,
  });

  factory ListeningHistoryModel.fromMap(Map<String, dynamic> map) {
    return ListeningHistoryModel(
      id: map['id'] is int ? map['id'] : int.parse(map['id'].toString()),
      songId: map['song_id'] is int
          ? map['song_id']
          : int.parse(map['song_id'].toString()),
      title: map['title']?.toString() ?? 'Lagu Tidak Dikenal',
      artistName: map['artist_name']?.toString() ?? 'Artis Tidak Dikenal',
      albumTitle: map['album_title']?.toString(),
      cover: map['cover']?.toString(),
      audioPath: map['audio_path']?.toString(),
      filePath: map['file_path']?.toString(),
      startedAt:
          DateTime.tryParse(map['started_at']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
      endedAt: map['ended_at'] != null
          ? DateTime.tryParse(map['ended_at'].toString())?.toLocal()
          : null,
      durationPlayed: map['duration_played'] is int
          ? map['duration_played']
          : int.tryParse(map['duration_played']?.toString() ?? '0') ?? 0,
      completed: (map['completed'] == 1 || map['completed'] == true),
      skipped: (map['skipped'] == 1 || map['skipped'] == true),
    );
  }
}
