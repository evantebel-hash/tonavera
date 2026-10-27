# Phase 5.2 — Mini Player Window

## Ringkasan Fitur
Fitur **Mini Player Window** menyediakan mode jendela ultra-kompak (380x150 px) khusus desktop dengan dukungan **Always on Top**, menampilkan artwork album, judul lagu, artis, playback position/duration slider, tombol kendali (Play/Pause, Next, Previous), dan tombol kembali ke ukuran penuh.

---

## Arsitektur & Sinkronisasi State
- **Single State Guarantee:** Mini Player berbagi `PlayerProvider` yang sama dengan Main Window dan Now Playing Screen.
- **Window Resizing & Pinning:**
  - Ukuran jendela diubah menggunakan Win32 `SetWindowPos` dengan mempertahankan aspek rasio kompak.
  - Opsi *Always on Top* diatur melalui `HWND_TOPMOST` / `HWND_NOTOPMOST`.
- **UI Widget:** `DesktopMiniPlayerView` (`lib/widgets/desktop/desktop_mini_player_view.dart`) dibangun dengan komponen yang ringan, memanfaatkan semantic tooltips dan keyboard accessible controls.
- **Transisi Dua Arah:** Pengguna dapat berpindah dari Main View ke Mini Player melalui tombol di header atau tray menu, serta kembali ke Full Mode kapan saja.

---

## Pengaturan (Settings)
- **Settings → Desktop & Integrasi Sistem → Mini Player Always on Top** (Default: `OFF`).
- Disimpan ke `SharedPreferences` dengan kunci `pref_desktop_always_on_top`.

---

## Pengujian & Verifikasi
- **Unit Tests:** `test/desktop_integration_test.dart` menguji persistensi status mini player, sinkronisasi state playback, pemanggilan kontrol audio dari mini player ke PlayerProvider.
- **Hasil:** 122/122 tests passed.
