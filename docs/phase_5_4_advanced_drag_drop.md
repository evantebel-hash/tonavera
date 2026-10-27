# Phase 5.4 — Advanced Drag & Drop & Reorder

## Ringkasan Fitur
Fitur **Advanced Drag & Drop** memungkinkan pengguna memasukkan berkas audio atau direktori musik ke dalam MyMusic secara langsung dari Windows Explorer / File Manager, dengan deteksi target drop visual dan integrasi mulus ke Unified Import Pipeline Phase 2, serta mendukung penyusunan ulang lagu (Reorder) menggunakan mouse drag pada Playlist dan Antrean Pemutaran (Queue).

---

## Arsitektur & Implementasi
1. **Windows Native Drag & Drop Hook:**
   - Diaktifkan pada `windows/runner/flutter_window.cpp` via Win32 `DragAcceptFiles(hwnd, TRUE)`.
   - Menangani pesan Windows `WM_DROPFILES` pada `windows/runner/desktop_native_integration.h` menggunakan `DragQueryFileW`.
   - Mengirim daftar absolute path file dan direktori yang di-drop ke layer Flutter Dart melalui `MethodChannel.invokeMethod('onFilesDropped')`.

2. **Visual Drop Target Overlay:**
   - `MainNavigationScreen` mendengarkan event drag & drop dan menampilkan feedback visual animasi dengan teks `"DROP MUSIK KE SINI - Lepaskan file atau folder untuk mengimpor ke library MyMusic"`.

3. **Integrasi ke Unified Import Pipeline:**
   - File/folder yang di-drop diproses melalui `MusicImportService.instance.importFilesAndFolders(paths)`.
   - Memanfaatkan *Duplicate Detector*, ekstraksi metadata tags (Title, Artist, Album, Genre, Artwork), dan SQLite batch transaction.
   - Menampilkan SnackBar hasil import: `"Selesai: X diimpor, Y dilewati (duplikat), Z gagal"`.

4. **Desktop Mouse Drag Reorder:**
   - **Playlist Reordering:** Menggunakan `ReorderableListView.builder` pada `PlaylistDetailScreen` dan `LocalMusicRepository.reorderPlaylistSongs()`, memperbarui kolom `position` secara aman di SQLite.
   - **Queue Reordering:** Menggunakan `ReorderableListView.builder` pada `PlayerScreen` (Queue Modal) yang memanggil `PlayerProvider.reorderQueue()`.

---

## Pengujian & Verifikasi
- **Unit Tests:** `test/desktop_integration_test.dart` menguji penanganan payload drop file/folder, validasi format, dan delegasi ke import pipeline.
- **Hasil:** 122/122 tests passed.
