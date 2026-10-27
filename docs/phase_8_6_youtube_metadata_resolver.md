# Phase 8.6 — YouTube Metadata Resolver

## Overview
Higher-level resolver API (`YouTubeService`) providing unified typed model resolution for UI components.

## Interface Methods
- `search(query, {forceRefresh})`
- `resolveVideo(videoId)`
- `resolvePlaylist(playlistId)`
- `matchLocalSong(video, localSongs)`
- `importPlaylistUrl(urlOrId)`
- `clearCache()`
