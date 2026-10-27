# Phase 8.2 — YouTube Public Playlist Import

## Overview
Allows users to import public YouTube playlists by providing a URL (e.g., `https://youtube.com/playlist?list=...`) or raw playlist ID.

## Workflow
1. User inputs public YouTube playlist URL or ID.
2. `YouTubeParser.extractPlaylistId` parses and validates the playlist ID.
3. `YouTubeScraper.fetchPlaylist` retrieves metadata & playlist tracks.
4. `YouTubeRepository` saves playlist and item entries into SQLite tables `youtube_playlists` and `youtube_playlist_items`.
5. Displayed as Online YouTube Playlist in MyMusic UI.
