import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../repositories/local_music_repository.dart';
import '../../services/metadata/metadata_model.dart';
import '../../services/metadata/metadata_service.dart';

enum ImportStatus { idle, resolving, previewReady, importing, success, error }

class ImportMetadataProvider extends ChangeNotifier {
  final MetadataService _metadataService;
  final LocalMusicRepository _repository;

  ImportMetadataProvider({
    MetadataService? metadataService,
    LocalMusicRepository? repository,
  }) : _metadataService = metadataService ?? MetadataService.instance,
       _repository = repository ?? LocalMusicRepository();

  ImportStatus _status = ImportStatus.idle;
  ImportStatus get status => _status;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  MusicMetadataResult? _previewResult;
  MusicMetadataResult? get previewResult => _previewResult;

  Map<String, int>? _importSummary;
  Map<String, int>? get importSummary => _importSummary;

  bool _overwriteExisting = false;
  bool get overwriteExisting => _overwriteExisting;
  set overwriteExisting(bool value) {
    _overwriteExisting = value;
    notifyListeners();
  }

  void reset() {
    _status = ImportStatus.idle;
    _errorMessage = null;
    _previewResult = null;
    _importSummary = null;
    notifyListeners();
  }

  /// Resolves input URL or URI to standardized preview metadata
  Future<bool> resolveUrl(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      _errorMessage = 'Tautan tidak boleh kosong.';
      _status = ImportStatus.error;
      notifyListeners();
      return false;
    }

    _status = ImportStatus.resolving;
    _errorMessage = null;
    _previewResult = null;
    notifyListeners();

    try {
      final result = await _metadataService.fetchMetadata(trimmed);
      if (result != null) {
        _previewResult = result;
        _status = ImportStatus.previewReady;
        notifyListeners();
        return true;
      } else {
        _errorMessage =
            'Tidak dapat memuat metadata dari tautan tersebut. Pastikan tautan Spotify atau YouTube valid.';
        _status = ImportStatus.error;
        notifyListeners();
        return false;
      }
    } catch (e) {
      debugPrint('[ImportMetadataProvider] Error resolving link: $e');
      _errorMessage = 'Terjadi kesalahan saat memproses tautan: $e';
      _status = ImportStatus.error;
      notifyListeners();
      return false;
    }
  }

  /// Commits confirmed preview metadata to local SQLite database atomically
  Future<bool> commitImport() async {
    if (_previewResult == null) {
      _errorMessage = 'Tidak ada metadata pratinjau yang siap disimpan.';
      _status = ImportStatus.error;
      notifyListeners();
      return false;
    }

    _status = ImportStatus.importing;
    notifyListeners();

    try {
      final summary = await _repository.importMetadata(
        metadata: _previewResult!,
        overwriteExisting: _overwriteExisting,
      );
      _importSummary = summary;
      _status = ImportStatus.success;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[ImportMetadataProvider] Error committing metadata: $e');
      _errorMessage = 'Gagal menyimpan ke database lokal: $e';
      _status = ImportStatus.error;
      notifyListeners();
      return false;
    }
  }
}
