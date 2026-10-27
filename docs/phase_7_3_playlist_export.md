# Phase 7.3 — Playlist Export Documentation

## Formats Supported
1. **MyMusic Playlist JSON** (`mymusic-playlist`): Preserves name, description, timestamp, track metadata, and stable track hashes (`title|artist|album|duration`).
2. **M3U / M3U8 Playlist**: Standard cross-platform format featuring `#EXTINF` metadata tags and file paths.

## Multi-Select Export Support
- Integrated with `MultiSelectController` for batch selecting playlists on Android (long-press) and Desktop (Ctrl/Shift + Click).
