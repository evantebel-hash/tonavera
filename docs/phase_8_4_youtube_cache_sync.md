# Phase 8.4 — YouTube Local Cache & Sync

## Cache Policy & TTL Rules
- **Search Cache TTL**: 1 Hour (`Duration(hours: 1)`).
- **Playlist & Items Cache TTL**: 24 Hours (`Duration(hours: 24)`).
- **Offline Fallback**: Serves stale cache when internet is disconnected.

## Database Tables (SQLite Schema v7)
- `youtube_videos`
- `youtube_playlists`
- `youtube_playlist_items`
- `youtube_search_cache`
- `hybrid_playlist_items`
