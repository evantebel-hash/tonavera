# Phase 7.1 — Library Backup Documentation

## Architecture & Overview
The Library Backup feature in MyMusic provides a portable, versioned, and local-first backup solution for user music library metadata.

## Format Specification (.mymusicbackup)
- **Manifest**: Includes app version (`1.0.0+1`), schema version (`6`), backup version (`1`), platform signature, creation timestamp, and integer hash checksum.
- **Payload**: Contains JSON objects of all SQLite tables: `songs`, `artists`, `albums`, `genres`, `playlists`, `playlist_songs`, `favorites`, `listening_histories`, `player_states`, `player_queues`.
- **Integrity**: Non-blocking atomic JSON file export created via background thread avoiding UI thread freezes.

## Data Safety
- Audio binary files are **not** bundled into database backup packages to ensure fast, compact backup sizes.
- Missing audio files are tagged cleanly during restore without deleting metadata.
