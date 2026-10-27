# PHASE 3.1 — AUTO LYRICS & LYRICS ENGINE DOCUMENTATION

**MyMusic Flutter Application**  
**Version / Phase:** Phase 3.1  
**Status:** Completed & Verified  

---

## 1. Architecture Overview

Phase 3.1 introduces a modular, local-first lyrics subsystem built directly above the application's domain and repository layers without altering or interfering with the audio playback pipeline.

```
┌─────────────────────────────────────────────────────────────┐
│                       Audio File                             │
└──────────────────────────────┬──────────────────────────────┘
                               │ (Import Time)
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                    Embedded Tag Lyrics                      │
└──────────────────────────────┬──────────────────────────────┘
                               │ (Cached)
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                  SQLite Lyrics Cache Table                  │
│                     (`lyrics_cache`)                        │
└──────────────────────────────┬──────────────────────────────┘
                               │ (On-Demand Lookup if missing)
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                     LRCLIB Public API                       │
│     (Anonymous HTTPS GET / API Search with Duration Match)  │
└──────────────────────────────┬──────────────────────────────┘
                               │ (Fallback)
                               ▼
┌─────────────────────────────────────────────────────────────┐
│               Local AI Fallback Architecture                │
│    (`LocalAiLyricsProvider` stub for future transcription)   │
└──────────────────────────────┬──────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│               Now Playing & Lyrics UI View                  │
│           (Synced Timestamps / Plain Text View)             │
└─────────────────────────────────────────────────────────────┘
```

---

## 2. Lyrics Source Priority

When a user views a song or opens the Lyrics view, the `LyricsService` evaluates sources in strict order:
1. **Embedded Lyrics**: Read from audio metadata tags during import and cached into SQLite.
2. **SQLite Lyrics Cache**: Persistent device-local storage in `lyrics_cache`.
3. **LRCLIB Online Lookup**: On-demand query over HTTPS if no local lyrics exist.
4. **Future Local AI Provider**: Extensible fallback provider interface (`LyricsFallbackProvider`).
5. **Not Found / Offline State**: Graceful UI representation without affecting audio playback.

---

## 3. Embedded Metadata Extraction

- Integrated seamlessly into `MusicImportService`.
- Uses `audiotags` tag reader to extract `tag.lyrics` (supporting ID3 USLT/lyrics, Vorbis comment `LYRICS`, and MP4/M4A lyrics).
- Automatically normalizes line endings and writes directly into SQLite `lyrics_cache` during library import.
- Non-blocking: If no embedded lyrics exist, import completes instantly without initiating network requests.

---

## 4. SQLite Schema & Migration

- **Database Version Upgraded**: **Version 4 → Version 5**
- **Table Definition**:
```sql
CREATE TABLE IF NOT EXISTS lyrics_cache (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  song_id INTEGER NOT NULL UNIQUE,
  source TEXT NOT NULL,
  plain_lyrics TEXT,
  synced_lyrics TEXT,
  language TEXT,
  fetched_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  is_synced INTEGER NOT NULL DEFAULT 0,
  FOREIGN KEY (song_id) REFERENCES songs(id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_lyrics_song_id ON lyrics_cache(song_id);
```
- **Integrity**: `ON DELETE CASCADE` ensures that deleting a song cleans up associated cached lyrics automatically.

---

## 5. LRCLIB Online Integration & Privacy

- **Endpoint**: `https://lrclib.net/api/get` with fallback to `https://lrclib.net/api/search`.
- **Query Parameters**: Anonymous metadata only:
  - `track_name` (song title)
  - `artist_name` (song artist)
  - `album_name` (album title)
  - `duration` (song duration in seconds)
- **Security & Privacy Guarantee**:
  - Only HTTPS protocol is permitted.
  - Zero transmission of user audio files, local paths, authentication tokens, emails, or listening history.
  - 8-second network timeout.
  - Maximum payload size enforcement (256 KB) to prevent memory ballooning.
  - Duration difference tolerance ($\le 15$ seconds) prevents false-positive lyrics matches.

---

## 6. LRC Parser & Precision Timestamps

`LrcParser` handles all industry LRC formats:
- Standard: `[mm:ss.xx]` (e.g. `[01:23.45]`)
- Extended: `[mm:ss.xxx]` (e.g. `[01:23.456]`)
- Long track: `[hh:mm:ss.xx]` (e.g. `[01:02:03.45]`)
- Multiple timestamp tags on single line: `[00:10.00][00:20.00]Chorus line`
- Header metadata tags (`[ar:...]`, `[ti:...]`, etc.) are ignored safely.
- Normalizes CRLF (`\r\n`) to LF (`\n`) and preserves full multilingual Unicode (Indonesian, Japanese, Korean, Chinese, Arabic, Cyrillic, Latin).

---

## 7. Playback Synchronization & Active Line Algorithm

- **Source of Truth**: `PlayerProvider.position`.
- **Algorithm**: Binary Search $O(\log N)$ in `LrcParser.findActiveLineIndex` to compute the current active line in sub-millisecond time.
- **Scroll Modes**:
  - **Auto-Scroll**: Smoothly tracks the active lyric as the song plays.
  - **Manual Scroll Release**: When the user manually scrolls up/down to browse, auto-scrolling yields for 4 seconds or until the user taps the floating **"Lirik Aktif"** (Jump to Active) action button.
- **Tap to Seek**: Tapping any line in the synced lyrics list triggers `player.seek(line.startTime)`.

---

## 8. Desktop & Android Responsive UX

- **Desktop (Width $\ge 800$px)**:
  - Side-by-side layout in Now Playing: Album Art & Controls on the left (flex: 5), Live Lyrics View on the right (flex: 6).
- **Android & Compact Screens**:
  - Toggle between Rotating Album Cover and Lyrics View via the header action button.
  - Dedicated full-screen lyrics screen accessible via popup menu or playlist cards.
  - Touch-friendly tap targets with subtle source badges (`Embedded`, `Cache`, `LRCLIB`).

---

## 9. Request Cancellation & Concurrency Safety

- `LyricsService` manages a generation counter (`_currentRequestToken`).
- If a user rapidly skips through songs (Song A $\rightarrow$ Song B $\rightarrow$ Song C), any slow asynchronous network response for Song A or B is discarded and will never overwrite Song C's UI or cache.

---

## 10. Local AI Fallback Architecture Readiness

- Extensible abstraction via `LyricsFallbackProvider`.
- Includes `LocalAiLyricsProvider` registered as a placeholder for future offline Whisper / Demucs vocal separation and AI transcription without requiring architectural rewrites.

---

## 11. Verification & Testing Summary

- **Unit Tests**: 16 dedicated lyrics tests + 60 existing Phase 1 & Phase 2 tests = **76 Total Tests Passing (100%)**.
- **Static Analysis (`flutter analyze`)**: 0 Errors.
- **Windows Release Build**: `build\windows\x64\runner\Release\mymusic.exe` successfully compiled.
- **Android Release Build**: `build\app\outputs\flutter-apk\app-release.apk` compiled.
