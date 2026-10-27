import 'lyric_line.dart';

enum LyricsSource { embedded, cache, lrclib, localAi, unknown }

class LyricsModel {
  final int? id;
  final int songId;
  final LyricsSource source;
  final String? plainLyrics;
  final String? syncedLyrics;
  final String? language;
  final DateTime fetchedAt;
  final DateTime? updatedAt;
  final bool isSynced;
  final List<LyricLine> parsedLines;

  LyricsModel({
    this.id,
    required this.songId,
    required this.source,
    this.plainLyrics,
    this.syncedLyrics,
    this.language,
    required this.fetchedAt,
    this.updatedAt,
    required this.isSynced,
    this.parsedLines = const [],
  });

  bool get hasContent =>
      (syncedLyrics != null && syncedLyrics!.trim().isNotEmpty) ||
      (plainLyrics != null && plainLyrics!.trim().isNotEmpty);

  bool get hasSyncedLyrics =>
      isSynced && (syncedLyrics != null && syncedLyrics!.trim().isNotEmpty);

  factory LyricsModel.fromEmbedded({
    required int songId,
    required String rawLyrics,
  }) {
    final clean = rawLyrics.trim();
    final isSynced =
        clean.isNotEmpty &&
        RegExp(r'\[(?:(\d{1,2}):)?(\d{1,2}):(\d{2})').hasMatch(clean);
    return LyricsModel(
      songId: songId,
      source: LyricsSource.embedded,
      plainLyrics: isSynced ? null : clean,
      syncedLyrics: isSynced ? clean : null,
      fetchedAt: DateTime.now(),
      isSynced: isSynced,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'song_id': songId,
      'source': source.name,
      'plain_lyrics': plainLyrics,
      'synced_lyrics': syncedLyrics,
      'language': language,
      'fetched_at': fetchedAt.toIso8601String(),
      'updated_at': (updatedAt ?? fetchedAt).toIso8601String(),
      'is_synced': isSynced ? 1 : 0,
    };
  }

  factory LyricsModel.fromMap(
    Map<String, dynamic> map, {
    List<LyricLine> parsedLines = const [],
  }) {
    final sourceStr = map['source']?.toString() ?? 'unknown';
    final src = LyricsSource.values.firstWhere(
      (e) => e.name.toLowerCase() == sourceStr.toLowerCase(),
      orElse: () => LyricsSource.unknown,
    );

    final isSyn = map['is_synced'] == 1 || map['is_synced'] == true;

    return LyricsModel(
      id: map['id'] != null ? int.tryParse(map['id'].toString()) : null,
      songId: int.parse(map['song_id'].toString()),
      source: src,
      plainLyrics: map['plain_lyrics'],
      syncedLyrics: map['synced_lyrics'],
      language: map['language'],
      fetchedAt: map['fetched_at'] != null
          ? DateTime.tryParse(map['fetched_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'].toString())
          : null,
      isSynced: isSyn,
      parsedLines: parsedLines,
    );
  }

  LyricsModel copyWith({
    int? id,
    int? songId,
    LyricsSource? source,
    String? plainLyrics,
    String? syncedLyrics,
    String? language,
    DateTime? fetchedAt,
    DateTime? updatedAt,
    bool? isSynced,
    List<LyricLine>? parsedLines,
  }) {
    return LyricsModel(
      id: id ?? this.id,
      songId: songId ?? this.songId,
      source: source ?? this.source,
      plainLyrics: plainLyrics ?? this.plainLyrics,
      syncedLyrics: syncedLyrics ?? this.syncedLyrics,
      language: language ?? this.language,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
      parsedLines: parsedLines ?? this.parsedLines,
    );
  }
}
