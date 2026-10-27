# Phase 7.5 — Optional Cloud Sync Documentation

## Architecture & Principles
- **Local-First & Offline-First**: Local library is 100% functional without internet or backend login.
- **Outbox Pattern**: Changes to playlists, favorites, and history are enqueued in SQLite table `sync_outbox`.
- **SyncProvider Abstraction**: Abstract `CloudSyncProvider` interface implemented by `DefaultCloudSyncProvider` which syncs outbox payloads to the PHP/XAMPP ApiService when an active online session is detected.
- **Data Privacy**: No audio binaries or sensitive credentials are ever transmitted.
