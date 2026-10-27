# PHASE 4.1 — LISTENING STATISTICS DOKUMENTASI

## 1. Feature Overview
Listening Statistics menyajikan ringkasan holistik aktivitas mendengarkan musik pengguna yang dihitung secara akurat dan dinamis dari riwayat pemutaran SQLite lokal (`listening_histories`). Fitur ini sepenuhnya bekerja secara **Local-First & Offline** tanpa memerlukan otentikasi remote, API server eksternal, XAMPP, maupun PHP backend.

---

## 2. Metrik Statistik
- **Total Waktu Mendengarkan (`totalListeningTimeSeconds`)**: Akumulasi durasi riil pemutaran lagu (detik) dari sesi pemutaran pengguna.
- **Total Lagu Diputar (`totalPlays`)**: Jumlah total sesi pemutaran lagu.
- **Lagu Unik (`uniqueSongs`)**: Menghitung `COUNT(DISTINCT song_id)`.
- **Artis Unik (`uniqueArtists`)**: Menghitung `COUNT(DISTINCT artist_id)`.
- **Album Unik (`uniqueAlbums`)**: Menghitung `COUNT(DISTINCT album_id)`.
- **Tingkat Penyelesaian (`completionRate`)**: Persentase lagu yang didengarkan hingga selesai (`completed = 1`) dibandingkan total putaran.
- **Rata-rata Durasi (`averageDurationSeconds`)**: Rata-rata waktu mendengarkan per lagu.

---

## 3. Filter Rentang Waktu (Time Range)
Sistem mendukung filtering dinamis:
- **Hari Ini (`today`)**: Dimulai dari `00:00:00` hari ini waktu lokal.
- **7 Hari Terakhir (`last7Days`)**: Dimulai dari 6 hari yang lalu hingga akhir hari ini.
- **30 Hari Terakhir (`last30Days`)**: Dimulai dari 29 hari yang lalu hingga akhir hari ini.
- **Tahun Ini (`thisYear`)**: Dimulai dari 1 Januari tahun berjalan.
- **Semua Waktu (`allTime`)**: Seluruh riwayat dari awal.

---

## 4. Efisiensi & Kueri Database
Agregasi dihitung langsung pada level database menggunakan query SQL:
```sql
SELECT 
  COUNT(lh.id) AS total_plays,
  COALESCE(SUM(lh.duration_played), 0) AS total_time_seconds,
  COUNT(DISTINCT lh.song_id) AS unique_songs,
  COUNT(DISTINCT s.artist_id) AS unique_artists,
  COUNT(DISTINCT s.album_id) AS unique_albums,
  COALESCE(SUM(CASE WHEN lh.completed = 1 THEN 1 ELSE 0 END), 0) AS completed_plays,
  COALESCE(SUM(CASE WHEN lh.skipped = 1 THEN 1 ELSE 0 END), 0) AS skipped_plays
FROM listening_histories lh
LEFT JOIN songs s ON lh.song_id = s.id
WHERE lh.started_at >= ? AND lh.started_at <= ?;
```
Didukung dengan index SQLite `idx_lh_started_at` dan `idx_lh_song_id`.
