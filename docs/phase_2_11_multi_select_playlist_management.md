# PHASE 2.11 — MULTI-SELECT PLAYLIST MANAGEMENT DOKUMENTASI

## 1. Feature Overview
Sistem Multi-Select Playlist Management pada MyMusic menyediakan alur interaksi terpadu di Desktop dan Android untuk memilih satu atau banyak lagu di seluruh library lokal dan mengelolanya secara massal (Bulk Actions) tanpa mengganggu pemutaran audio, antrean lagu, daftar favorit, maupun history pemutaran.

---

## 2. Selection Architecture
- **MultiSelectController (`lib/controllers/multi_select_controller.dart`)**:
  - `Set<int> _selectedIds`: Menggunakan `Set<int>` untuk lookup $O(1)$ efisien pada ribuan lagu.
  - `bool _isSelectionMode`: Mengontrol mode seleksi aktif.
  - `int? _anchorIndex`: Penanda index awal untuk seleksi rentang (Range Selection).
  - `startSelection(int id, {int? index})`: Memulai mode seleksi saat user melakukan interaksi pertama (e.g. Long-press / Ctrl+Click).
  - `toggleSelection(int id, {int? index})`: Menambah atau menghapus lagu dari seleksi aktif.
  - `selectRange(List<int> visibleIds, int fromIndex, int toIndex)`: Memilih seluruh lagu dalam rentang visual aktif yang sedang ditampilkan.
  - `selectAll(List<int> visibleIds)`: Memilih seluruh lagu pada tampilan / filter saat ini.
  - `deselectAll()`: Mengosongkan seleksi pada item yang sedang ditampilkan.
  - `clear()`: Mengosongkan seleksi dan keluar dari mode seleksi.
  - `handleItemTap(...)`: Mengatur branching interaksi apakah `Ctrl+Click`, `Shift+Click`, atau `Tap` biasa saat mode seleksi aktif.

---

## 3. Platform Interactions & Gestures
### Android Mobile:
1. **Long-Press**: Menahan salah satu lagu akan mengaktifkan `Selection Mode` dan memilih lagu tersebut.
2. **Tap**: Setelah mode seleksi aktif, tap pada lagu lain akan melakukan toggle centang tanpa memulai pemutaran lagu.
3. **Selection Toolbar**: Menampilkan tombol batal/kembali (`Close`), jumlah lagu terpilih (`X dipilih`), toggle `Pilih Semua` / `Batal Pilih`, dan tombol aksi (`Tambah ke Playlist` / `Hapus dari Playlist`).
4. **Back Gesture / PopScope**: Menekan tombol Back sistem Android ketika dalam mode seleksi akan keluar dari mode seleksi terlebih dahulu, bukan langsung keluar dari layar.

### Windows Desktop:
1. **Ctrl + Click**: Toggle lagu masuk/keluar dari seleksi tanpa memulai pemutaran.
2. **Shift + Click**: Menyeleksi deretan lagu dari anchor lagu terakhir yang diklik hingga lagu target berdasarkan list yang sedang difilter/ditampilkan.
3. **Single Click Normal**: Memutar lagu seperti biasa ketika mode seleksi belum aktif.

---

## 4. Search & Filter Preservation
- Mode seleksi mempertahankan daftar lagu yang telah dipilih meskipun query pencarian atau filter artis/album/genre diubah.
- Aksi `Select All` hanya memilih lagu yang sedang terlihat di hasil filter/pencarian aktif (Current View), mencegah penambahan lagu yang tidak disengaja di luar filter.

---

## 5. Bulk Database Operations & Safety
- **Atomic Transactions**:
  - Operasi massal (`addSongsToPlaylist`, `addSongsToMultiplePlaylists`, `removeSongsFromPlaylist`) dibungkus dalam `db.transaction(...)`.
- **Order Preservation**:
  - Saat menambahkan sejumlah lagu ke playlist, sistem mengambil index maksimum `COALESCE(MAX(position_order), -1) + 1` lalu menambahkan setiap lagu secara berurutan sesuai urutan seleksi.
- **Duplicate Prevention**:
  - Tabel SQLite `playlist_songs` memiliki primary key ganda `(playlist_id, song_id)`.
  - Operasi insert menggunakan `ConflictAlgorithm.ignore` sehingga tidak terjadi duplikasi lagu di dalam playlist yang sama saat user menambahkan lagu yang sudah ada.
- **Non-Destructive Removal**:
  - Menghapus lagu dari playlist hanya menghapus baris relasi di tabel `playlist_songs`.
  - Record lagu di tabel `songs`, file audio di storage, data favorites, dan listening history tetap utuh dan aman.

---

## 6. Player & Audio Engine Safety
- Tidak ada modifikasi pada `_audioPlayerA`, `_audioPlayerB`, crossfade, equalizer, playback speed, atau sleep timer.
- Menghapus lagu yang sedang diputar dari sebuah playlist tidak akan menghentikan pemutaran lagu tersebut dan tidak akan merusak `player.queue`.

---

## 7. Automated Testing
- **Multi-Select Unit & DB Suite (`test/multi_select_playlist_test.dart`)**:
  - Single item selection & mode activation.
  - Multi-item toggling & Deselect All.
  - Select All on visible subset of items.
  - Shift-range selection with anchor index.
  - Bulk add to playlist with order preservation and duplicate prevention.
  - Bulk add to multiple playlists atomically.
  - Non-destructive bulk removal from playlist.
- **Full Suite**: 103/103 tests passed.
