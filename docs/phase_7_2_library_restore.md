# Phase 7.2 — Library Restore Documentation

## Restore Workflow
1. File Selection via native `file_picker` (.mymusicbackup or .json format).
2. Schema & Checksum Verification.
3. Interactive Preview Dialog displaying counts for songs, playlists, favorites, history, and missing audio files.
4. User Confirmation.
5. Transactional SQLite database wipe & rebuild with automatic foreign key integrity checks.
6. Player state & UI repository provider cache refresh.

## Path Remapping & Missing File Behavior
- If audio file path differs from source machine (e.g., `C:\Music` vs `D:\Music`), MyMusic preserves the track metadata and missing status.
- Songs are never forcibly removed due to missing audio files.
