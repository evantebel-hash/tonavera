# Phase 8.5 — Local + YouTube Playlist Merge

## Overview
Supports mixed hybrid playlist models combining local audio files and YouTube video references.

## Hybrid Item Model (`HybridPlaylistItem`)
- `sourceType`: `local` or `youtube`.
- `localSong`: References `SongModel` for offline audio engine playback.
- `youtubeVideo`: References `YouTubeVideo` for external browser opening and metadata display.
- Keeps YouTube metadata strictly separated from local audio paths (`songs.file_path`).
