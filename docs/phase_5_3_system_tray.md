# Phase 5.3 — System Tray

## Ringkasan Fitur
Fitur **System Tray** mengintegrasikan MyMusic ke dalam area notifikasi Windows (System Tray / Taskbar Corner Overflow). Pengguna dapat mengontrol pemutaran musik secara cepat serta membiarkan MyMusic terus memutar musik di latar belakang saat jendela utama ditutup (Minimize to Tray).

---

## Arsitektur & Implementasi
- **Win32 Shell Notify Icon:**
  - Diimplementasikan pada `windows/runner/desktop_native_integration.h` menggunakan `Shell_NotifyIconA` (`NIM_ADD`, `NIM_MODIFY`, `NIM_DELETE`) dengan `NOTIFYICONDATAA`.
  - Icon menggunakan resource executable default aplikasi (`IDI_APP_ICON`).
- **Context Menu Pop-up:**
  - Dibuat via `CreatePopupMenu()` dan `TrackPopupMenuEx()`.
  - Opsi Menu:
    1. **Buka MyMusic** (Restore/Focus window)
    2. **Mini Player Mode** (Toggle compact mode)
    3. **Play / Pause**
    4. **Lagu Berikutnya (Next)**
    5. **Lagu Sebelumnya (Previous)**
    6. **Keluar** (Graceful app shutdown, dispose tray, close audio engine)
- **Minimize to Tray (WM_CLOSE Interception):**
  - Ketika `Minimize to Tray` aktif, penekanan tombol close `(X)` pada jendela di-intercept di `HandleWindowMessage(WM_CLOSE)` sehingga window disembunyikan (`ShowWindow(SW_HIDE)`) tanpa menghentikan pemutaran audio.
  - Jika `Minimize to Tray` nonaktif, aplikasi akan ditutup normal sesuai standar Flutter.

---

## Pengaturan (Settings)
- **Settings → Desktop & Integrasi Sistem → Windows System Tray** (Default: `ON`).
- **Settings → Desktop & Integrasi Sistem → Minimize to Tray** (Default: `OFF`).
- Disimpan ke `SharedPreferences` (`pref_desktop_tray_enabled` & `pref_desktop_minimize_to_tray`).

---

## Pengujian & Verifikasi
- **Unit Tests:** `test/desktop_integration_test.dart` menguji penanganan action tray, sinkronisasi state ke PlayerProvider, dan persistensi preferensi tray.
- **Hasil:** 122/122 tests passed.
