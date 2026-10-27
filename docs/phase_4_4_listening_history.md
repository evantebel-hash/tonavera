# PHASE 4.4 — LISTENING HISTORY DOKUMENTASI

## 1. Feature Overview
Listening History menyediakan linimasa pemutaran lagu pengguna dari yang terbaru ke yang terlama (Newest-first) lengkap dengan status pemutaran (`Selesai` / `Dilewati`), waktu mulai, dan durasi mendengarkan.

---

## 2. Pengelompokan & Paginasi
- **Pengelompokan Tanggal (Date Grouping)**:
  - `Hari Ini`
  - `Kemarin`
  - Tanggal spesifik (`D MMMM YYYY`)
- **Paginasi Ringan (Pagination & Lazy Loading)**:
  - Pemuatan awal sejumlah 50 rekaman riwayat.
  - Tombol atau trigger `Muat Lebih Banyak` memuat blok 50 rekaman berikutnya dengan `LIMIT` dan `OFFSET` di SQLite tanpa membebani memori.

---

## 3. Penghapusan Riwayat (Clear History)
- Menyediakan tombol pembersihan riwayat dengan modal dialog konfirmasi eksplisit.
- **Integritas Data Terjamin**: Pembersihan riwayat hanya mengosongkan tabel `listening_histories`. Lagu lokal, metadata lagu, playlist, daftar favorit, antrean pemutar, dan file audio di storage tetap 100% utuh.
