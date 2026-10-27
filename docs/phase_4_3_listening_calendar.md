# PHASE 4.3 — LISTENING CALENDAR DOKUMENTASI

## 1. Feature Overview
Listening Calendar menyajikan visualisasi kalender bulanan interaktif dengan intensitas aktivitas mendengarkan musik (heatmap) untuk setiap tanggal, serta rincian sesi pemutaran pada tanggal yang dipilih.

---

## 2. Navigasi & Tampilan
- **Navigasi Bulan**: Mendukung navigasi bulan sebelumnya dan selanjutnya dengan transisi tahun yang aman (e.g. Desember $\leftrightarrow$ Januari).
- **Indikator Intensitas Aktivitas**:
  - `0 menit`: Permukaan normal (tanpa aktivitas).
  - `<15 menit`: Intensitas rendah (tint transparan 30%).
  - `<60 menit`: Intensitas sedang (tint transparan 60%).
  - `>60 menit`: Intensitas tinggi (warna aksen primer solid).
- **Interaksi Tanggal**: Mengetuk tanggal tertentu akan memunculkan daftar lagu yang diputar pada hari tersebut lengkap dengan jam pemutaran dan durasinya.

---

## 3. Boundary Tanggal & Timezone
Kueri kalender menggunakan rentang `00:00:00.000` sampai `23:59:59.999` berdasarkan zona waktu lokal perangkat pengguna untuk mencegah kesalahan grouping di sekitar tengah malam.
