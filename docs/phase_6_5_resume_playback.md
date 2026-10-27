# Phase 6.5 — Resume Playback Documentation

## Overview
Phase 6.5 delivers automatic, reliable player state and queue restoration upon application launch.

## State Persistence Architecture
- **SQLite Storage**: Uses existing `player_states` and `player_queues` tables in `mymusic_local.db`.
- **Persisted Attributes**:
  - `current_song_id`
  - `position_seconds`
  - `is_shuffle`
  - `repeat_mode`
  - `volume`
  - `player_queues` (ordered list of song IDs)
- **Safe Recovery**:
  - Validates candidate song and local file existence.
  - Clamps playback position if saved position exceeds song duration.
  - Filters out missing/deleted files from restored queue.
- **Settings Toggle**: Added `Resume Playback` setting tile in `SettingsScreen` (Default: `ON`).

## Lifecycle Integration
- Triggered on app startup via `PlayerProvider()..restorePlayerState()` in `lib/main.dart`.
