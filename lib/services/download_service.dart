import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/song_model.dart';
import '../models/download_task_model.dart';
import '../repositories/local_music_repository.dart';

class DownloadService extends ChangeNotifier {
  static final DownloadService instance = DownloadService._internal();

  final http.Client _client;
  final LocalMusicRepository _localRepo;

  final List<DownloadTask> _tasks = [];
  int _maxConcurrentDownloads = 2;
  final Map<String, http.StreamedResponse> _activeStreamResponses = {};
  final Map<String, IOSink> _activeFileSinks = {};

  DownloadService({http.Client? client, LocalMusicRepository? localRepo})
    : _client = client ?? http.Client(),
      _localRepo = localRepo ?? LocalMusicRepository();

  DownloadService._internal()
    : _client = http.Client(),
      _localRepo = LocalMusicRepository();

  List<DownloadTask> get tasks => List.unmodifiable(_tasks);
  int get maxConcurrentDownloads => _maxConcurrentDownloads;

  set maxConcurrentDownloads(int val) {
    if (val > 0) {
      _maxConcurrentDownloads = val;
      _processQueue();
      notifyListeners();
    }
  }

  /// Checks if a song source is an authorized downloadable direct HTTP/HTTPS URL
  static bool isDownloadableSource(SongModel song) {
    final path = song.audioPath.trim().toLowerCase();
    if (song.source == 'youtube') return false;
    return path.startsWith('http://') || path.startsWith('https://');
  }

  /// Resolves target directory for local downloaded music
  Future<Directory> getDownloadDirectory() async {
    Directory baseDir;
    if (Platform.isWindows) {
      final userProfile =
          Platform.environment['USERPROFILE'] ?? 'C:\\Users\\Public';
      baseDir = Directory(p.join(userProfile, 'Music', 'MyMusicDownloads'));
    } else {
      try {
        baseDir = await getApplicationDocumentsDirectory();
        baseDir = Directory(p.join(baseDir.path, 'MyMusicDownloads'));
      } catch (_) {
        baseDir = Directory(
          p.join(Directory.systemTemp.path, 'MyMusicDownloads'),
        );
      }
    }
    if (!await baseDir.exists()) {
      await baseDir.create(recursive: true);
    }
    return baseDir;
  }

  /// Checks if song already exists locally in repository
  Future<bool> isSongAlreadyDownloaded(SongModel song) async {
    try {
      final existingSongs = await _localRepo.getSongs(query: song.title);
      for (final s in existingSongs) {
        if (s.trackHash == song.trackHash || s.audioPath == song.audioPath) {
          return true;
        }
      }
    } catch (_) {}
    return false;
  }

  /// Enqueues a new download task
  Future<DownloadTask?> enqueueDownload(
    SongModel song, {
    String? customUrl,
    bool replaceExisting = false,
  }) async {
    final url = customUrl ?? song.audioPath;

    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      debugPrint('[DownloadService] Cannot download non-HTTP source: $url');
      return null;
    }

    if (!replaceExisting && await isSongAlreadyDownloaded(song)) {
      debugPrint(
        '[DownloadService] Song already exists locally: ${song.title}',
      );
    }

    // Prevent duplicate active queue entry
    final existingTask = _tasks.firstWhere(
      (t) =>
          t.song.trackHash == song.trackHash &&
          t.status != DownloadStatus.cancelled &&
          t.status != DownloadStatus.failed,
      orElse: () => DownloadTask(id: '', song: song, downloadUrl: url),
    );
    if (existingTask.id.isNotEmpty) {
      return existingTask;
    }

    final taskId = DateTime.now().millisecondsSinceEpoch.toString();
    final task = DownloadTask(
      id: taskId,
      song: song,
      downloadUrl: url,
      status: DownloadStatus.queued,
    );

    _tasks.add(task);
    notifyListeners();

    _processQueue();
    return task;
  }

  /// Process queue with max concurrency limit
  void _processQueue() {
    final activeCount = _tasks
        .where((t) => t.status == DownloadStatus.downloading)
        .length;
    if (activeCount >= _maxConcurrentDownloads) return;

    final queuedTasks = _tasks
        .where((t) => t.status == DownloadStatus.queued)
        .toList();
    final availableSlots = _maxConcurrentDownloads - activeCount;

    for (int i = 0; i < availableSlots && i < queuedTasks.length; i++) {
      _startDownload(queuedTasks[i]);
    }
  }

  Future<void> _startDownload(DownloadTask task) async {
    task.status = DownloadStatus.downloading;
    task.error = null;
    notifyListeners();

    IOSink? sink;
    try {
      final dir = await getDownloadDirectory();

      // Check free disk space if supported on Windows
      if (Platform.isWindows) {
        try {
          final stat = await dir.stat();
          if (stat.type == FileSystemEntityType.notFound) {
            await dir.create(recursive: true);
          }
        } catch (_) {}
      }

      final sanitizeName = task.song.title.replaceAll(
        RegExp(r'[\\/:*?"<>|]'),
        '_',
      );
      final ext = p.extension(task.downloadUrl).split('?').first;
      final fileExtension = ext.isNotEmpty && ext.length <= 5 ? ext : '.mp3';

      final finalFileName = '${sanitizeName}_${task.id}$fileExtension';
      final finalPath = p.join(dir.path, finalFileName);
      final tempPath = '$finalPath.tmp';

      final tempFile = File(tempPath);
      int startBytes = 0;

      final request = http.Request('GET', Uri.parse(task.downloadUrl));
      if (await tempFile.exists() && task.bytesDownloaded > 0) {
        startBytes = await tempFile.length();
        request.headers['Range'] = 'bytes=$startBytes-';
      }

      final response = await _client.send(request);

      if (response.statusCode != 200 && response.statusCode != 206) {
        throw Exception('Server returned HTTP ${response.statusCode}');
      }

      final contentLengthHeader = response.headers['content-length'];
      if (contentLengthHeader != null) {
        final totalLength = int.tryParse(contentLengthHeader) ?? 0;
        task.totalBytes = startBytes + totalLength;
      }

      _activeStreamResponses[task.id] = response;
      sink = tempFile.openWrite(
        mode: startBytes > 0 ? FileMode.append : FileMode.write,
      );
      _activeFileSinks[task.id] = sink;

      int downloaded = startBytes;

      await response.stream.forEach((chunk) {
        if (task.status != DownloadStatus.downloading) {
          throw Exception('Download interrupted by user action');
        }
        sink!.add(chunk);
        downloaded += chunk.length;
        task.bytesDownloaded = downloaded;
        if (task.totalBytes > 0) {
          task.progress = (downloaded / task.totalBytes).clamp(0.0, 1.0);
        }
        notifyListeners();
      });

      await sink.flush();
      await sink.close();
      _activeFileSinks.remove(task.id);
      _activeStreamResponses.remove(task.id);

      // Verify and atomic rename temp file to final file
      if (await tempFile.exists()) {
        final finalFile = await tempFile.rename(finalPath);
        task.localPath = finalFile.path;
        task.status = DownloadStatus.completed;
        task.completedAt = DateTime.now();
        task.progress = 1.0;

        // Register completed download into LocalMusicRepository
        final localSong = task.song.copyWith(
          source: 'local',
          audioPath: finalFile.path,
          filePath: finalFile.path,
        );

        await _localRepo.insertOrUpdateSong(localSong);
        debugPrint(
          '[DownloadService] Download completed and registered in LocalMusicRepository: ${finalFile.path}',
        );
      } else {
        throw Exception(
          'Temporary download file missing after stream finished',
        );
      }
    } catch (e) {
      _activeStreamResponses.remove(task.id);
      if (_activeFileSinks.containsKey(task.id)) {
        await _activeFileSinks[task.id]?.close();
        _activeFileSinks.remove(task.id);
      }

      if (task.status == DownloadStatus.cancelled) {
        _cleanupTempFile(task);
      } else if (task.status == DownloadStatus.paused) {
        // Retain temporary file for resume
      } else {
        task.status = DownloadStatus.failed;
        task.error = e.toString().replaceAll('Exception: ', '');
      }
    } finally {
      notifyListeners();
      _processQueue();
    }
  }

  Future<void> pauseDownload(String taskId) async {
    final task = _tasks.firstWhere(
      (t) => t.id == taskId,
      orElse: () => DownloadTask(
        id: '',
        song: SongModel(
          id: 0,
          artistId: 0,
          title: '',
          duration: 0,
          audioPath: '',
        ),
        downloadUrl: '',
      ),
    );
    if (task.id.isEmpty || task.status != DownloadStatus.downloading) return;

    task.status = DownloadStatus.paused;
    _activeFileSinks[taskId]?.close();
    _activeFileSinks.remove(taskId);
    _activeStreamResponses.remove(taskId);

    notifyListeners();
    _processQueue();
  }

  Future<void> resumeDownload(String taskId) async {
    final task = _tasks.firstWhere(
      (t) => t.id == taskId,
      orElse: () => DownloadTask(
        id: '',
        song: SongModel(
          id: 0,
          artistId: 0,
          title: '',
          duration: 0,
          audioPath: '',
        ),
        downloadUrl: '',
      ),
    );
    if (task.id.isEmpty ||
        (task.status != DownloadStatus.paused &&
            task.status != DownloadStatus.failed))
      return;

    task.status = DownloadStatus.queued;
    notifyListeners();
    _processQueue();
  }

  Future<void> cancelDownload(String taskId) async {
    final task = _tasks.firstWhere(
      (t) => t.id == taskId,
      orElse: () => DownloadTask(
        id: '',
        song: SongModel(
          id: 0,
          artistId: 0,
          title: '',
          duration: 0,
          audioPath: '',
        ),
        downloadUrl: '',
      ),
    );
    if (task.id.isEmpty) return;

    task.status = DownloadStatus.cancelled;
    _activeFileSinks[taskId]?.close();
    _activeFileSinks.remove(taskId);
    _activeStreamResponses.remove(taskId);

    await _cleanupTempFile(task);
    notifyListeners();
    _processQueue();
  }

  Future<void> _cleanupTempFile(DownloadTask task) async {
    try {
      final dir = await getDownloadDirectory();
      final sanitizeName = task.song.title.replaceAll(
        RegExp(r'[\\/:*?"<>|]'),
        '_',
      );
      final ext = p.extension(task.downloadUrl).split('?').first;
      final fileExtension = ext.isNotEmpty && ext.length <= 5 ? ext : '.mp3';
      final tempPath = p.join(
        dir.path,
        '${sanitizeName}_${task.id}$fileExtension.tmp',
      );

      final tempFile = File(tempPath);
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    } catch (_) {}
  }

  void removeTask(String taskId) {
    _tasks.removeWhere((t) => t.id == taskId);
    notifyListeners();
  }

  void clearCompletedTasks() {
    _tasks.removeWhere((t) => t.status == DownloadStatus.completed);
    notifyListeners();
  }
}
