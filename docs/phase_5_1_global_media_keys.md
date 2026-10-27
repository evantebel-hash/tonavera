# Phase 5.1 — Global Media Keys

## Ringkasan Fitur
Fitur **Global Media Keys** memungkinkan pengguna mengontrol pemutaran musik di MyMusic menggunakan tombol media keyboard hardware (Play/Pause, Next Track, Previous Track, Volume Up, Volume Down, dan Mute) meskipun aplikasi sedang diminimalkan, berjalan di latar belakang, atau pengguna sedang aktif membuka aplikasi lain.

---

## Arsitektur & Implementasi
- **Platform Native Hook (Windows):** Diimplementasikan melalui Windows Win32 API `RegisterHotKey` dan `UnregisterHotKey` pada `windows/runner/desktop_native_integration.h`.
- **Virtual Key Mapping:**
  - `VK_MEDIA_PLAY_PAUSE` (0xB3) -> Toggle Play / Pause
  - `VK_MEDIA_NEXT_TRACK` (0xB0) -> Next Track
  - `VK_MEDIA_PREV_TRACK` (0xB1) -> Previous Track
  - `VK_VOLUME_UP` (0xAF) -> Volume Up
  - `VK_VOLUME_DOWN` (0xAE) -> Volume Down
  - `VK_VOLUME_MUTE` (0xAD) -> Toggle Mute
- **Komunikasi Dua Arah:** Menggunakan `flutter::MethodChannel` (`com.mymusic.desktop/integration`).
- **Penanganan State:** Panggilan dari media key diteruskan secara langsung ke metode yang sudah ada di `PlayerProvider` (`togglePlayPause()`, `next()`, `previous()`, `setVolume()`, `toggleMute()`). Tidak ada pembuatan player atau queue baru.

---

## Pengaturan (Settings)
- **Settings → Desktop & Integrasi Sistem → Global Media Keys** (Default: `ON`).
- Dapat diaktifkan / dinonaktifkan secara dinamis saat runtime melalui `DesktopIntegrationService.setMediaKeysEnabled()`.
- Disimpan ke `SharedPreferences` dengan kunci `pref_desktop_media_keys_enabled`.

---

## Pengujian & Verifikasi
- **Unit Tests:** `test/desktop_integration_test.dart` menguji pemetaan action media keys (`onPlayPause`, `onNext`, `onPrevious`, `onVolumeUp`, `onVolumeDown`, `onToggleMute`) yang memanggil PlayerProvider tanpa merusak queue, shuffle, repeat, maupun equalizer.
- **Hasil:** 122/122 tests passed.
