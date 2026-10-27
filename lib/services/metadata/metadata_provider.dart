import 'metadata_model.dart';

/// Abstract contract for music metadata providers.
/// Enables future extensibility (e.g., MusicBrainz, Discogs, local tags)
/// while maintaining strict isolation between providers.
abstract class MetadataProvider {
  /// Unique name identifying this metadata provider.
  String get name;

  /// Returns true if this provider is able to handle the given query/URL.
  bool canHandle(String input);

  /// Fetches metadata from this provider.
  /// Returns null or throws nothing on failure, adhering to non-crashing contracts.
  Future<MusicMetadataResult?> fetchMetadata(String input);
}
