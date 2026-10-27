import 'dart:collection';
import 'metadata_model.dart';

/// In-memory metadata cache with LRU eviction to prevent memory bloat.
class MetadataCache {
  static const int defaultCapacity = 100;
  final int capacity;
  final LinkedHashMap<String, MusicMetadataResult> _cache = LinkedHashMap();

  MetadataCache({this.capacity = defaultCapacity});

  /// Retrieves cached metadata by key, returning null if not found.
  MusicMetadataResult? get(String key) {
    if (!_cache.containsKey(key)) return null;
    // Move to end for LRU order
    final value = _cache.remove(key)!;
    _cache[key] = value;
    return value;
  }

  /// Stores metadata under the given key.
  void put(String key, MusicMetadataResult value) {
    if (_cache.containsKey(key)) {
      _cache.remove(key);
    } else if (_cache.length >= capacity) {
      // Evict least recently used item (the first key in LinkedHashMap)
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = value;
  }

  /// Checks if key is present in cache.
  bool contains(String key) => _cache.containsKey(key);

  /// Removes an entry from cache.
  void remove(String key) => _cache.remove(key);

  /// Clears all entries.
  void clear() => _cache.clear();

  /// Current number of items in cache.
  int get length => _cache.length;
}
