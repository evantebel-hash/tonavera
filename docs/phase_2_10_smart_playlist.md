# PHASE 2.10 — SMART PLAYLIST
# DOKUMENTASI TEKNIS & ARSITEKTUR

## 1. Ringkasan Fitur
Phase 2.10 menghadirkan fitur **Smart Playlist** (Daftar Putar Cerdas), yaitu playlist dinamis berbasis aturan/kriteria filter yang dievaluasi secara *real-time* terhadap seluruh lagu di database lokal. Berbeda dari playlist normal yang statis, keanggotaan lagu di dalam Smart Playlist akan otomatis menyesuaikan diri ketika library bertambah, lagu difavoritkan, atau statistik pemutaran berubah.

## 2. Struktur Data & Migrasi Skema SQLite
Skema SQLite dinaikkan ke **Versi 4** dengan penambahan kolom pada tabel `playlists`:
- `playlist_type TEXT DEFAULT 'normal'`: Membedakan `'normal'` dan `'smart'`.
- `smart_config TEXT`: Menyimpan konfigurasi aturan dalam format JSON serializable.

## 3. Aturan Kriteria & Operator yang Didukung
Field yang didukung:
- `title` (Judul)
- `artist` (Artis)
- `album` (Album)
- `genre` (Genre)
- `favorite` (Status Favorit: Ya / Tidak)
- `playCount` (Jumlah Putar dari riwayat pemutaran `listening_histories`)
- `duration` (Durasi dalam detik)
- `format` (Format audio: mp3, flac, m4a, dll.)
- `lastPlayed` (Terakhir diputar dalam N hari)
- `albumArtist` (Artis Album)

Operator yang didukung:
- `equals`, `notEquals`, `contains`, `startsWith`, `endsWith`
- `greaterThan` (`>`), `greaterThanOrEqual` (`>=`), `lessThan` (`<`), `lessThanOrEqual` (`<=`)
- `isTrue`, `isFalse`
- `withinLastNDays`

Logika Evaluasi:
- `SmartRuleLogic.all` (AND - semua kriteria harus terpenuhi)
- `SmartRuleLogic.any` (OR - salah satu kriteria terpenuhi)

## 4. Pengurutan & Batasan (Sorting & Limits)
- Pengurutan: Judul (A-Z / Z-A), Artis (A-Z), Album (A-Z), Jumlah Putar (Tertinggi / Terendah), Durasi (Terlama / Terpendek), Acak (Random).
- Batas Maksimal: Tanpa Batas, 10, 25, 50, 100 lagu.

## 5. Evaluasi Dinamis & Konsistensi Player
- Smart Playlist tidak menyimpan ID lagu secara permanen di tabel relasi `playlist_songs`.
- Saat membuka playlist atau memutar lagu, daftar lagu dievaluasi secara dinamis oleh [`SmartPlaylistService.evaluateSmartPlaylist`](file:///c:/xampp/htdocs/mymusic/mymusic_flutter/lib/services/smart_playlist_service.dart).
- Pemutaran lagu, antrean (*queue*), shuffle, dan repeat bekerja persis seperti playlist biasa dengan snapshot ID lagu yang aman.
- Saat pembersih lagu duplikat menghapus file atau lagu diubah status favoritnya, Smart Playlist langsung menyesuaikan secara instan.
