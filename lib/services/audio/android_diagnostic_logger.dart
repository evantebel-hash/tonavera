import 'dart:collection';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Ring buffer in-memory logger for Android local playback diagnostics.
///
/// Designed to capture exact step-by-step playback events on release builds
/// without requiring ADB or external logging tools.
class AndroidDiagnosticLogger {
  AndroidDiagnosticLogger._();
  static final AndroidDiagnosticLogger instance = AndroidDiagnosticLogger._();

  static const int _maxLogs = 250;
  final ListQueue<String> _logs = ListQueue<String>(_maxLogs);

  String _lastStage = 'None';
  DateTime? _lastStageTime;
  String? _lastError;
  String? _currentTrackTitle;
  String? _currentLocalPath;

  // Timestamps of major playback lifecycle checkpoints
  final Map<String, DateTime> _stageStartTimes = {};
  final Map<String, DateTime> _stageEndTimes = {};
  final Map<String, int> _stageDurationsMs = {};

  String get lastStage => _lastStage;
  String? get lastError => _lastError;
  String? get currentTrackTitle => _currentTrackTitle;
  String? get currentLocalPath => _currentLocalPath;
  List<String> get logs => List.unmodifiable(_logs.toList());

  /// Records an event to the ring buffer and also forwards to debugPrint.
  void log(String tag, String message) {
    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}.${now.millisecond.toString().padLeft(3, '0')}';
    final entry = '[$timeStr][$tag] $message';

    if (_logs.length >= _maxLogs) {
      _logs.removeFirst();
    }
    _logs.addLast(entry);

    // Forward to console output as well
    debugPrint(entry);
  }

  void startStage(String stageName, {String? details}) {
    _lastStage = stageName;
    _lastStageTime = DateTime.now();
    _stageStartTimes[stageName] = _lastStageTime!;
    log('STAGE_START', '$stageName${details != null ? ' | $details' : ''}');
  }

  void endStage(String stageName, {String? details, bool success = true}) {
    final end = DateTime.now();
    _stageEndTimes[stageName] = end;
    final start = _stageStartTimes[stageName];
    if (start != null) {
      final dur = end.difference(start).inMilliseconds;
      _stageDurationsMs[stageName] = dur;
      log(
        success ? 'STAGE_OK' : 'STAGE_WARN',
        '$stageName took ${dur}ms${details != null ? ' | $details' : ''}',
      );
    } else {
      log(
        success ? 'STAGE_OK' : 'STAGE_WARN',
        '$stageName finished${details != null ? ' | $details' : ''}',
      );
    }
  }

  void recordError(String stageName, dynamic error, [StackTrace? stackTrace]) {
    _lastError = '$error';
    final stFirstLine = stackTrace != null
        ? stackTrace.toString().split('\n').take(3).join(' | ')
        : '';
    log(
      'ERROR',
      '$stageName: $error${stFirstLine.isNotEmpty ? ' [$stFirstLine]' : ''}',
    );
  }

  void setCurrentTrack({required String title, required String path}) {
    _currentTrackTitle = title;
    _currentLocalPath = path;
    log('TRACK_SELECT', 'title="$title", path="$path"');
  }

  void clearLogs() {
    _logs.clear();
    _lastStage = 'None';
    _lastStageTime = null;
    _lastError = null;
    _currentTrackTitle = null;
    _currentLocalPath = null;
    _stageStartTimes.clear();
    _stageEndTimes.clear();
    _stageDurationsMs.clear();
    log('DIAG_RESET', 'Diagnostic log buffer cleared.');
  }

  /// Formats the complete diagnostics report for easy clipboard copying.
  String buildDiagnosticReport({required Map<String, dynamic> playerStatus}) {
    final sb = StringBuffer();
    sb.writeln('=== TONAVERA ANDROID PLAYBACK DIAGNOSTIC REPORT ===');
    sb.writeln('GeneratedAt: ${DateTime.now().toIso8601String()}');
    sb.writeln('Platform: Android (${Platform.operatingSystemVersion})');
    sb.writeln('AppVersion: 1.0.0+1 (Obsidian V3.5)');
    sb.writeln('');
    sb.writeln('--- CURRENT TRACK CONTEXT ---');
    sb.writeln('TrackTitle: ${_currentTrackTitle ?? 'Unknown / None'}');
    sb.writeln('LocalFilePath: ${_currentLocalPath ?? 'None'}');
    sb.writeln('');
    sb.writeln('--- PLAYER STATUS ---');
    playerStatus.forEach((k, v) {
      sb.writeln('$k: $v');
    });
    sb.writeln('');
    sb.writeln('--- STAGES & DURATIONS ---');
    sb.writeln(
      'LastStage: $_lastStage (${_lastStageTime?.toIso8601String() ?? 'N/A'})',
    );
    sb.writeln('LastError: ${_lastError ?? 'None'}');
    for (final entry in _stageDurationsMs.entries) {
      sb.writeln('Stage [${entry.key}]: ${entry.value}ms');
    }
    sb.writeln('');
    sb.writeln('--- LOG TRACE (Newest Last) ---');
    for (final line in _logs) {
      sb.writeln(line);
    }
    sb.writeln('=== END DIAGNOSTIC REPORT ===');
    return sb.toString();
  }

  /// Copies the generated report to the clipboard.
  Future<bool> copyReportToClipboard({
    required Map<String, dynamic> playerStatus,
  }) async {
    try {
      final report = buildDiagnosticReport(playerStatus: playerStatus);
      await Clipboard.setData(ClipboardData(text: report));
      return true;
    } catch (e) {
      log('CLIPBOARD_ERROR', 'Failed to copy report: $e');
      return false;
    }
  }
}
