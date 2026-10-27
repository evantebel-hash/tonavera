# PHASE 4.2 — TOP MUSIC DOKUMENTASI

## 1. Feature Overview
Top Music menampilkan peringkat lagu, artis, dan album teratas yang paling sering didengarkan oleh pengguna berdasarkan riwayat pemutaran aktual di SQLite lokal.

---

## 2. Kategori Peringkat
1. **Lagu Teratas (Top Songs)**:
   - Menampilkan peringkat 1 sampai N, cover artwork, judul lagu, nama artis, jumlah pemutaran (`X putaran`), dan tombol Play langsung.
   - Mengintegrasikan aksi Play dengan `PlayerProvider` tanpa mengganggu antrean atau status pemutar yang ada.
2. **Artis Teratas (Top Artists)**:
   - Menampilkan nama artis, jumlah lagu unik yang diputar, total frekuensi putar, dan total akumulasi waktu mendengarkan.
3. **Album Teratas (Top Albums)**:
   - Menampilkan judul album, nama artis, total frekuensi putar, dan total akumulasi durasi.

---

## 3. Aturan Pengurutan Deterministik
Peringkat diurutkan secara deterministik dengan prioritas:
1. `play_count DESC` (Frekuensi pemutaran terbanyak)
2. `total_duration DESC` (Total durasi mendengarkan terlama)
3. `title ASC` (Urutan alfabet jika terjadi nilai imbang)

---

## 4. Dukungan Filter Waktu
Peringkat Top Music secara dinamis mengikuti filter rentang waktu:
- Hari Ini
- 7 Hari Terakhir
- 30 Hari Terakhir
- Tahun Ini
- Semua Waktu
