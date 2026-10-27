import 'dart:convert';

enum SmartRuleField {
  title,
  artist,
  album,
  genre,
  year,
  duration,
  format,
  favorite,
  playCount,
  dateAdded,
  lastPlayed,
  albumArtist,
}

enum SmartRuleOperator {
  equals,
  notEquals,
  contains,
  startsWith,
  endsWith,
  greaterThan,
  greaterThanOrEqual,
  lessThan,
  lessThanOrEqual,
  isTrue,
  isFalse,
  withinLastNDays,
}

enum SmartRuleLogic {
  all, // AND
  any, // OR
}

enum SmartSortOption {
  titleAsc,
  titleDesc,
  artistAsc,
  albumAsc,
  dateAddedDesc,
  dateAddedAsc,
  playCountDesc,
  playCountAsc,
  lastPlayedDesc,
  durationDesc,
  durationAsc,
  random,
}

class SmartPlaylistRule {
  final SmartRuleField field;
  final SmartRuleOperator operator;
  final String value;

  SmartPlaylistRule({
    required this.field,
    required this.operator,
    required this.value,
  });

  Map<String, dynamic> toJson() => {
    'field': field.name,
    'operator': operator.name,
    'value': value,
  };

  factory SmartPlaylistRule.fromJson(Map<String, dynamic> json) {
    return SmartPlaylistRule(
      field: SmartRuleField.values.firstWhere(
        (e) => e.name == json['field'],
        orElse: () => SmartRuleField.title,
      ),
      operator: SmartRuleOperator.values.firstWhere(
        (e) => e.name == json['operator'],
        orElse: () => SmartRuleOperator.contains,
      ),
      value: json['value']?.toString() ?? '',
    );
  }

  String get humanReadableDescription {
    final fieldLabel = _formatField(field);
    final opLabel = _formatOp(operator);
    if (operator == SmartRuleOperator.isTrue)
      return '$fieldLabel bernilai Benar';
    if (operator == SmartRuleOperator.isFalse)
      return '$fieldLabel bernilai Salah';
    if (operator == SmartRuleOperator.withinLastNDays)
      return '$fieldLabel dalam $value hari terakhir';
    return '$fieldLabel $opLabel "$value"';
  }

  static String _formatField(SmartRuleField f) {
    switch (f) {
      case SmartRuleField.title:
        return 'Judul';
      case SmartRuleField.artist:
        return 'Artis';
      case SmartRuleField.album:
        return 'Album';
      case SmartRuleField.genre:
        return 'Genre';
      case SmartRuleField.year:
        return 'Tahun';
      case SmartRuleField.duration:
        return 'Durasi (detik)';
      case SmartRuleField.format:
        return 'Format Audio';
      case SmartRuleField.favorite:
        return 'Favorit';
      case SmartRuleField.playCount:
        return 'Jumlah Putar';
      case SmartRuleField.dateAdded:
        return 'Tanggal Ditambahkan';
      case SmartRuleField.lastPlayed:
        return 'Terakhir Diputar';
      case SmartRuleField.albumArtist:
        return 'Artis Album';
    }
  }

  static String _formatOp(SmartRuleOperator op) {
    switch (op) {
      case SmartRuleOperator.equals:
        return 'sama dengan';
      case SmartRuleOperator.notEquals:
        return 'tidak sama dengan';
      case SmartRuleOperator.contains:
        return 'mengandung';
      case SmartRuleOperator.startsWith:
        return 'dimulai dengan';
      case SmartRuleOperator.endsWith:
        return 'diakhiri dengan';
      case SmartRuleOperator.greaterThan:
        return '>';
      case SmartRuleOperator.greaterThanOrEqual:
        return '>=';
      case SmartRuleOperator.lessThan:
        return '<';
      case SmartRuleOperator.lessThanOrEqual:
        return '<=';
      case SmartRuleOperator.isTrue:
        return 'adalah ya';
      case SmartRuleOperator.isFalse:
        return 'adalah tidak';
      case SmartRuleOperator.withinLastNDays:
        return 'dalam N hari';
    }
  }
}

class SmartPlaylistConfig {
  final SmartRuleLogic logic;
  final List<SmartPlaylistRule> rules;
  final SmartSortOption sort;
  final int? limit;

  SmartPlaylistConfig({
    this.logic = SmartRuleLogic.all,
    this.rules = const [],
    this.sort = SmartSortOption.titleAsc,
    this.limit,
  });

  Map<String, dynamic> toJson() => {
    'logic': logic.name,
    'rules': rules.map((r) => r.toJson()).toList(),
    'sort': sort.name,
    'limit': limit,
  };

  factory SmartPlaylistConfig.fromJson(Map<String, dynamic> json) {
    return SmartPlaylistConfig(
      logic: SmartRuleLogic.values.firstWhere(
        (e) => e.name == json['logic'],
        orElse: () => SmartRuleLogic.all,
      ),
      rules: (json['rules'] as List<dynamic>? ?? [])
          .map((r) => SmartPlaylistRule.fromJson(r as Map<String, dynamic>))
          .toList(),
      sort: SmartSortOption.values.firstWhere(
        (e) => e.name == json['sort'],
        orElse: () => SmartSortOption.titleAsc,
      ),
      limit: json['limit'] != null
          ? int.tryParse(json['limit'].toString())
          : null,
    );
  }

  String toJsonString() => json.encode(toJson());

  factory SmartPlaylistConfig.fromJsonString(String raw) {
    try {
      final decoded = json.decode(raw);
      if (decoded is Map<String, dynamic>) {
        return SmartPlaylistConfig.fromJson(decoded);
      }
    } catch (_) {}
    return SmartPlaylistConfig();
  }
}
