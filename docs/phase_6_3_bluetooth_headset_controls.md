# Phase 6.3 — Bluetooth / Headset Controls Documentation

## Overview
Phase 6.3 handles hardware media buttons and headset state changes for wired headsets, Bluetooth earbuds, and car audio systems.

## Key Behaviors
- **Media Button Events**:
  - `ACTION_MEDIA_PLAY` / `ACTION_MEDIA_PAUSE` / `ACTION_MEDIA_PLAY_PAUSE`: Toggles play/pause state in `PlayerProvider`.
  - `ACTION_MEDIA_NEXT`: Advances to next track in queue.
  - `ACTION_MEDIA_PREVIOUS`: Restarts track or goes to previous track.
- **Headphone Disconnection**:
  - Automatically pauses audio playback when headphones/Bluetooth headsets are disconnected (governed by the `pauseOnHeadphoneDisconnect` setting, default: `ON`).

## Settings Integration
- Added switch tile in Settings: `Pause when Headphones Disconnected` (Default: ON).
