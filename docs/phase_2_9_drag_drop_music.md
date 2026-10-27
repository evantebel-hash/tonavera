# PHASE 2.9 — DRAG & DROP MUSIC & IMPORT PIPELINE
# DOKUMENTASI TEKNIS & ARSITEKTUR

## 1. Ringkasan Fitur
Phase 2.9 mengimplementasikan fitur impor musik terpusat yang mendukung mekanisme **Drag & Drop** pada platform Desktop (Windows/macOS/Linux) serta pemilihan file audio tunggal, multipel, dan seleksi direktori/folder (File/Folder Picker) pada Desktop dan Mobile (Android).

## 2. Format Audio yang Didukung
Seluruh validasi format disentralisasi di [`AudioFileValidator`](file:///c:/xampp/htdocs/mymusic/mymusic_flutter/lib/core/utils/audio_file_validator.dart):
- `.mp3`
- `.flac`
- `.m4a`
- `.wav`
- `.ogg`
- `.opus`
- `.aac`

Format yang tidak valid (arsip `.zip`/`.rar`, file eksekusi `.exe`/`.bat`, dokumen teks, dsb.) secara otomatis difilter dan tidak akan dieksekusi atau diproses.

## 3. Alur Pipeline Impor (`MusicImportService`)
1. **Resolusi Path:** Menerima daftar path file atau folder.
2. **Recursive Scan:** Menelusuri seluruh subfolder secara rekursif jika target adalah direktori.
3. **Filter Format:** Memeriksa ekstensi menggunakan `AudioFileValidator`.
4. **Pencegahan Duplikat:**
   - Cek 1: Exact canonical file path matching terhadap database SQLite.
   - Cek 2: `SongModel.trackHash` matching (title + artist + album + duration) terhadap koleksi pustaka. File duplikat dilewati (*skipped*) tanpa merusak metadata yang sudah ada.
5. **Ekstraksi Metadata & Artwork:**
   - Membaca ID3/Vorbis/MP4 tags melalui `audiotags`.
   - Normalisasi metadata melalui `NormalizedSongMetadata`.
   - Ekstraksi gambar/cover art dan penyimpanan ke cache disk lokal (`ArtworkCacheService`).
6. **Penyimpanan Transaksional SQLite:**
   - Menyimpan entri artis (`artists`), album (`albums`), genre (`genres`), dan lagu (`songs`).
   - Menyimpan ke playlist target jika user mengimpor langsung ke playlist.
7. **Streaming Progress & Batal (Cancellation):**
   - Dialog proses non-blocking yang menampilkan jumlah file diproses, nama file aktif, jumlah sukses, dan jumlah duplikat dilewati.
   - Tombol "Batalkan" yang menghentikan iterasi file berikutnya tanpa merusak transaksi yang sudah berhasil disimpan.

## 4. Keamanan Audio Engine & Player
- Audio engine (`_audioPlayerA`, `_audioPlayerB`, crossfade, gapless, equalizer) tidak dihentikan atau diubah saat proses impor berlangsung.
- Jika lagu yang sedang diputar berada di folder yang sedang diimpor, pemutaran lagu tetap berjalan lancar.

## 5. Kompatibilitas Local-First & Cloud Sync
- 100% beroperasi secara offline tanpa ketergantungan pada server XAMPP, Apache, PHP API, atau PostgreSQL.
- Pustaka SQLite lokal bertindak sebagai *Single Source of Truth*.
