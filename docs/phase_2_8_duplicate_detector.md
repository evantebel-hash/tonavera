# Phase 2.8 — Duplicate Music Detector

Dokumentasi implementasi fitur **Duplicate Music Detector** pada aplikasi MyMusic Flutter (Windows & Android).

---

## 1. Feature Overview
Fitur **Duplicate Music Detector** dirancang untuk mendeteksi, mengelompokkan, dan membersihkan file lagu duplikat di pustaka lokal perangkat secara aman, transparan, dan 100% *Local-First* tanpa ketergantungan pada koneksi internet, backend server, atau layanan pihak ketiga.

---

## 2. Duplicate Detection Algorithm
Algoritma pemindaian bekerja dengan tahapan multi-level:
1. Mengambil seluruh lagu dari database SQLite lokal (`LocalMusicRepository.getAllSongs()`) dalam satu kali operasi batch efisien.
2. Melakukan pengelompokan berdasarkan key hashing dan metadata signature.
3. Menghitung skor kelengkapan metadata (*metadata completeness score*) dan kualitas format file untuk memberikan rekomendasi file terbaik yang harus dipertahankan.
4. Menghasilkan daftar `DuplicateGroup` yang siap ditinjau oleh pengguna.

---

## 3. Match Levels & Confidence
Deteksi duplikat menggunakan tingkatan kecocokan terstruktur:

- **Level 1 — Exact File Path**:
  Memastikan tidak ada entri ganda untuk file fisik yang persis sama.
- **Level 2 — Track Hash**:
  Menggunakan `SongModel.trackHash` (`normalize(title)|normalize(artist)|normalize(album)|duration`). Memberikan kecocokan paling kuat untuk file dengan identitas musik yang sama persis.
- **Level 3 — Normalized Metadata Match**:
  Membandingkan Title, Artist, Album, dan Duration setelah dinormalisasi (lowercase, trim whitespace, Unicode space normalization).
- **Level 4 — Secondary Strong Match**:
  Mencocokkan Title dan Artist dengan durasi yang identik meskipun album berbeda (misalnya versi album vs single/greatest hits).

---

## 4. Confidence Reason
Setiap grup duplikat menampilkan alasan deteksi yang jelas kepada pengguna:
- `trackHash`: *"Same trackHash (Identik title, artist, album, dan durasi)"*
- `metadataExact`: *"Same title, artist, album, dan durasi yang dinormalisasi"*
- `metadataStrong`: *"Same title, artist, dan durasi lagu"*

---

## 5. Recommended Keep Logic
Sistem memberikan rekomendasi file yang dipertahankan (`recommendedKeepSongId`) secara objektif berdasarkan skor:
1. **Keberadaan File**: File yang benar-benar ada di disk (`File.existsSync()`).
2. **Kelengkapan Metadata**: Bobot tambahan jika memiliki title, artistName, albumTitle, genreName, cover art, dan lirik.
3. **Format Audio**: Prioritas kualitas format lossless/audio encoding (`FLAC` > `M4A/AAC` > `MP3` > `Lainnya`).
4. **Ukuran File**: File dengan ukuran lebih besar (indikasi bitrate lebih tinggi) diutamakan jika format setara.

> **Catatan**: Rekomendasi ini hanya sebagai default seleksi di UI. Pengguna selalu memiliki kebebasan penuh untuk memilih file lain yang ingin dipertahankan.

---

## 6. Deletion Safety
Fitur ini menerapkan standar keamanan penghapusan tertinggi:
- **Tidak ada penghapusan otomatis tanpa konfirmasi.**
- Dialog konfirmasi eksplisit menampilkan daftar path file fisik, jumlah file, dan total ukuran penyimpanan (MB) yang akan dibebaskan.
- Validasi izin tulis / lock check sebelum penghapusan.

---

## 7. SQLite & Database Consistency
Setelah file fisik berhasil dihapus:
1. Data lagu dihapus dari tabel `songs` via `LocalMusicRepository.deleteSong()`.
2. Relasi SQLite yang memiliki `ON DELETE CASCADE` (`playlist_songs`, `favorites`, `listening_histories`, `player_queues`) dibersihkan secara otomatis tanpa meninggalkan *orphan records*.

---

## 8. Playlist, Favorite, and History Behavior
- **Favorites**: Jika file yang dihapus berstatus favorit sedangkan file yang dipertahankan belum favorit, status favorit secara otomatis dipindahkan/ditambahkan ke file yang dipertahankan.
- **Playlists**: Jika file yang dihapus terdapat dalam playlist, entri playlist dialihkan ke file yang dipertahankan sehingga pengguna tidak kehilangan playlist mereka.
- **Listening History**: Riwayat mendengarkan tetap aman dan tidak dirusak.

---

## 9. Player Protection
- Sistem memeriksa apakah file yang akan dihapus sedang aktif diputar oleh `PlayerProvider` (`isSongActiveInPlayer`).
- Jika file sedang diputar, penghapusan ditolak dengan pesan: *"Lagu sedang diputar oleh player. Harap hentikan atau lewati pemutaran sebelum menghapus."*
- Jika file berada dalam antrean (`queue`), lagu tersebut dikeluarkan dari antrean secara aman tanpa mengganggu pemutaran lagu lain.

---

## 10. Offline Behavior & No Cloud Dependency
- Berjalan 100% secara offline tanpa memerlukan koneksi jaringan, database server PostgreSQL, atau PHP API/XAMPP.
- Pengguna yang belum login/terotentikasi tetap dapat menggunakan fitur ini secara mandiri.

---

## 11. Sync Outbox Interaction
- Operasi favorit dan histori tetap menggunakan antrean `SyncOutboxRepository` standar yang ada di repository tanpa memodifikasi schema outbox.
- Penghapusan file lokal tidak membuat mutasi cloud palsu karena file fisik bersifat *device-local*.

---

## 12. Responsive UI (Windows Desktop & Android)
- **Windows Desktop (Width >= 800px)**:
  - Panel Kiri: Daftar grup duplikat dengan counter total lagu.
  - Panel Kanan: Detail grup terpilih, selector radio kandidat file, perbandingan format & ukuran file, tombol *"Buka di Folder / Explorer"*, serta aksi *"Pertahankan Pilihan & Hapus Sisanya"* dan *"Lewati"*.
- **Android Mobile**:
  - Tampilan kartu vertikal responsif dengan pemilihan radio yang nyaman untuk layar sentuh, aman dari keyboard/overflow.

---

## 13. Navigasi & Entry Points
Fitur Duplicate Detector dapat diakses melalui:
1. **Pengaturan & Alat** (`SettingsScreen`) → Bagian *Pustaka & Pemeliharaan* → *Pembersih Lagu Duplikat*.
2. **Koleksi Saya** (`LibraryScreen`) → Item menu *Pembersih Lagu Duplikat*.

---

## 14. Known Limitations & Future Enhancements
- **Audio Fingerprinting (AcoustID / Chromaprint)**: Saat ini deteksi menggunakan perpaduan trackHash, duration, dan normalized metadata. Audio fingerprinting biner penuh direncanakan sebagai *future enhancement* pada rilis mendatang tanpa membebani ukuran bundle saat ini.
