#pragma once

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <windows.h>
#include <shellapi.h>
#include <memory>
#include <string>
#include <vector>

#define WM_MYMUSIC_TRAY (WM_USER + 101)
#define ID_TRAY_EXIT 2001
#define ID_TRAY_SHOW 2002
#define ID_TRAY_PLAYPAUSE 2003
#define ID_TRAY_NEXT 2004
#define ID_TRAY_PREV 2005
#define ID_TRAY_MINIPLAYER 2006

class DesktopNativeIntegration {
 public:
  static DesktopNativeIntegration& Instance() {
    static DesktopNativeIntegration instance;
    return instance;
  }

  void Initialize(flutter::BinaryMessenger* messenger, HWND window_handle) {
    window_handle_ = window_handle;
    channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
        messenger, "com.mymusic.desktop/integration",
        &flutter::StandardMethodCodec::GetInstance());

    channel_->SetMethodCallHandler([this](const flutter::MethodCall<flutter::EncodableValue>& call,
                                          std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
      HandleMethodCall(call, std::move(result));
    });

    // Register Global Media Keys Hotkeys
    RegisterGlobalMediaKeys();
  }

  void RegisterGlobalMediaKeys() {
    if (!window_handle_) return;
    // Unregister first if any
    UnregisterHotKey(window_handle_, 1001);
    UnregisterHotKey(window_handle_, 1002);
    UnregisterHotKey(window_handle_, 1003);

    // Only register Play/Pause, Next, and Previous.
    // Volume keys (Volume Up, Volume Down, Mute) are deliberately EXCLUDED
    // so Windows master volume controls continue working unimpeded.
    if (global_media_keys_enabled_) {
      RegisterHotKey(window_handle_, 1001, 0, VK_MEDIA_PLAY_PAUSE);
      RegisterHotKey(window_handle_, 1002, 0, VK_MEDIA_NEXT_TRACK);
      RegisterHotKey(window_handle_, 1003, 0, VK_MEDIA_PREV_TRACK);
    }
  }

  void UnregisterGlobalMediaKeys() {
    if (!window_handle_) return;
    UnregisterHotKey(window_handle_, 1001);
    UnregisterHotKey(window_handle_, 1002);
    UnregisterHotKey(window_handle_, 1003);
  }

  void UpdateTray(bool enable, const std::string& tooltip = "TONAVERA") {
    if (!window_handle_) return;
    if (enable) {
      NOTIFYICONDATAA nid = {sizeof(nid)};
      nid.hWnd = window_handle_;
      nid.uID = 1;
      nid.uFlags = NIF_ICON | NIF_MESSAGE | NIF_TIP;
      nid.uCallbackMessage = WM_MYMUSIC_TRAY;
      nid.hIcon = (HICON)GetClassLongPtr(window_handle_, GCLP_HICON);
      if (!nid.hIcon) {
        nid.hIcon = LoadIcon(GetModuleHandle(nullptr), MAKEINTRESOURCE(101));
      }
      strncpy_s(nid.szTip, tooltip.c_str(), sizeof(nid.szTip) - 1);

      if (tray_installed_) {
        Shell_NotifyIconA(NIM_MODIFY, &nid);
      } else {
        if (Shell_NotifyIconA(NIM_ADD, &nid)) {
          tray_installed_ = true;
        }
      }
    } else {
      if (tray_installed_) {
        NOTIFYICONDATAA nid = {sizeof(nid)};
        nid.hWnd = window_handle_;
        nid.uID = 1;
        Shell_NotifyIconA(NIM_DELETE, &nid);
        tray_installed_ = false;
      }
    }
  }

  void ShowTrayMenu() {
    if (!window_handle_) return;
    POINT pt;
    GetCursorPos(&pt);

    HMENU hMenu = CreatePopupMenu();
    InsertMenuA(hMenu, 0, MF_BYPOSITION | MF_STRING, ID_TRAY_SHOW, "Buka TONAVERA");
    InsertMenuA(hMenu, 1, MF_BYPOSITION | MF_STRING, ID_TRAY_MINIPLAYER, "Mini Player Mode");
    InsertMenuA(hMenu, 2, MF_BYPOSITION | MF_SEPARATOR, 0, nullptr);
    InsertMenuA(hMenu, 3, MF_BYPOSITION | MF_STRING, ID_TRAY_PLAYPAUSE, "Play / Pause");
    InsertMenuA(hMenu, 4, MF_BYPOSITION | MF_STRING, ID_TRAY_PREV, "Lagu Sebelumnya");
    InsertMenuA(hMenu, 5, MF_BYPOSITION | MF_STRING, ID_TRAY_NEXT, "Lagu Berikutnya");
    InsertMenuA(hMenu, 6, MF_BYPOSITION | MF_SEPARATOR, 0, nullptr);
    InsertMenuA(hMenu, 7, MF_BYPOSITION | MF_STRING, ID_TRAY_EXIT, "Keluar");

    SetForegroundWindow(window_handle_);
    TrackPopupMenu(hMenu, TPM_BOTTOMALIGN | TPM_LEFTALIGN, pt.x, pt.y, 0, window_handle_, nullptr);
    DestroyMenu(hMenu);
  }

  bool HandleWindowMessage(HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam, LRESULT* out_result) {
    if (message == WM_HOTKEY) {
      switch (wparam) {
        case 1001:
          EmitMediaEvent("playPause");
          return true;
        case 1002:
          EmitMediaEvent("next");
          return true;
        case 1003:
          EmitMediaEvent("previous");
          return true;
      }
    } else if (message == WM_APPCOMMAND) {
      short cmd = GET_APPCOMMAND_LPARAM(lparam);
      switch (cmd) {
        case APPCOMMAND_MEDIA_PLAY_PAUSE:
        case APPCOMMAND_MEDIA_PLAY:
        case APPCOMMAND_MEDIA_PAUSE:
          EmitMediaEvent("playPause");
          return true;
        case APPCOMMAND_MEDIA_NEXTTRACK:
          EmitMediaEvent("next");
          return true;
        case APPCOMMAND_MEDIA_PREVIOUSTRACK:
          EmitMediaEvent("previous");
          return true;
        // Do NOT intercept APPCOMMAND_VOLUME_UP, APPCOMMAND_VOLUME_DOWN, or APPCOMMAND_VOLUME_MUTE.
        // Let Windows master sound system process volume freely.
      }
    } else if (message == WM_GETMINMAXINFO) {
      if (is_mini_player_mode_) {
        MINMAXINFO* mmi = reinterpret_cast<MINMAXINFO*>(lparam);
        mmi->ptMinTrackSize.x = 200;
        mmi->ptMinTrackSize.y = 100;
        *out_result = 0;
        return true;
      }
    } else if (message == WM_MYMUSIC_TRAY) {
      if (LOWORD(lparam) == WM_LBUTTONDBLCLK || LOWORD(lparam) == WM_LBUTTONUP) {
        ShowWindow(window_handle_, SW_RESTORE);
        SetForegroundWindow(window_handle_);
        EmitWindowEvent("show");
        return true;
      } else if (LOWORD(lparam) == WM_RBUTTONUP) {
        ShowTrayMenu();
        return true;
      }
    } else if (message == WM_COMMAND) {
      int wmId = LOWORD(wparam);
      switch (wmId) {
        case ID_TRAY_SHOW:
          ShowWindow(window_handle_, SW_RESTORE);
          SetForegroundWindow(window_handle_);
          EmitWindowEvent("show");
          return true;
        case ID_TRAY_MINIPLAYER:
          ShowWindow(window_handle_, SW_RESTORE);
          SetForegroundWindow(window_handle_);
          EmitWindowEvent("showMiniPlayer");
          return true;
        case ID_TRAY_PLAYPAUSE:
          EmitMediaEvent("playPause");
          return true;
        case ID_TRAY_PREV:
          EmitMediaEvent("previous");
          return true;
        case ID_TRAY_NEXT:
          EmitMediaEvent("next");
          return true;
        case ID_TRAY_EXIT:
          UpdateTray(false);
          DestroyWindow(window_handle_);
          return true;
      }
    } else if (message == WM_CLOSE) {
      if (minimize_to_tray_enabled_ && tray_installed_) {
        ShowWindow(window_handle_, SW_HIDE);
        EmitWindowEvent("minimizedToTray");
        *out_result = 0;
        return true;
      }
    } else if (message == WM_DROPFILES) {
      HDROP hDrop = (HDROP)wparam;
      UINT count = DragQueryFileA(hDrop, 0xFFFFFFFF, nullptr, 0);
      std::vector<flutter::EncodableValue> file_list;
      for (UINT i = 0; i < count; ++i) {
        char buffer[MAX_PATH];
        if (DragQueryFileA(hDrop, i, buffer, MAX_PATH)) {
          file_list.push_back(flutter::EncodableValue(std::string(buffer)));
        }
      }
      DragFinish(hDrop);

      if (channel_ && !file_list.empty()) {
        channel_->InvokeMethod("onFilesDropped", std::make_unique<flutter::EncodableValue>(file_list));
      }
      return true;
    }
    return false;
  }

  void EmitMediaEvent(const std::string& action) {
    if (channel_) {
      channel_->InvokeMethod("onMediaKeyAction", std::make_unique<flutter::EncodableValue>(action));
    }
  }

  void EmitWindowEvent(const std::string& action) {
    if (channel_) {
      channel_->InvokeMethod("onWindowEvent", std::make_unique<flutter::EncodableValue>(action));
    }
  }

  void SetWindowSizeForHwnd(HWND hwnd, int logical_width, int logical_height) {
    if (!hwnd) return;

    UINT dpi = 96;
    HMODULE user32 = GetModuleHandleA("user32.dll");
    if (user32) {
      typedef UINT(WINAPI * GetDpiForWindowFn)(HWND);
      auto getDpi = reinterpret_cast<GetDpiForWindowFn>(GetProcAddress(user32, "GetDpiForWindow"));
      if (getDpi) {
        dpi = getDpi(hwnd);
      }
    }
    double scale = dpi / 96.0;
    int physical_w = static_cast<int>(logical_width * scale);
    int physical_h = static_cast<int>(logical_height * scale);

    RECT rect;
    GetWindowRect(hwnd, &rect);
    SetWindowPos(hwnd, nullptr, rect.left, rect.top, physical_w, physical_h,
                 SWP_NOZORDER | SWP_NOACTIVATE | SWP_FRAMECHANGED);
  }

  void SetAlwaysOnTop(bool always_on_top) {
    if (!window_handle_) return;
    SetWindowPos(window_handle_,
                 always_on_top ? HWND_TOPMOST : HWND_NOTOPMOST,
                 0, 0, 0, 0,
                 SWP_NOMOVE | SWP_NOSIZE);
  }

  void SetWindowSize(int logical_width, int logical_height) {
    SetWindowSizeForHwnd(window_handle_, logical_width, logical_height);
  }

  void SetWindowPosition(int x, int y) {
    if (!window_handle_) return;
    SetWindowPos(window_handle_, nullptr, x, y, 0, 0, SWP_NOSIZE | SWP_NOZORDER);
  }

  void RegisterSubWindow(flutter::BinaryMessenger* messenger, HWND sub_hwnd) {
    auto sub_channel = std::make_shared<flutter::MethodChannel<flutter::EncodableValue>>(
        messenger, "com.mymusic.desktop/integration",
        &flutter::StandardMethodCodec::GetInstance());

    sub_channel->SetMethodCallHandler([this, sub_hwnd](const flutter::MethodCall<flutter::EncodableValue>& call,
                                                      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
      const std::string& method = call.method_name();

      if (method == "setWindowSize") {
        if (const auto* map = std::get_if<flutter::EncodableMap>(call.arguments())) {
          int w = ExtractInt(*map, "width", 480);
          int h = ExtractInt(*map, "height", 125);
          if (w < 420) w = 420;
          if (w > 560) w = 560;
          if (h < 115) h = 115;
          if (h > 140) h = 140;
          SetWindowSizeForHwnd(sub_hwnd, w, h);
          result->Success(flutter::EncodableValue(true));
          return;
        }
      } else if (method == "setWindowPosition") {
        if (const auto* map = std::get_if<flutter::EncodableMap>(call.arguments())) {
          int x = ExtractInt(*map, "x", 100);
          int y = ExtractInt(*map, "y", 100);
          SetWindowPos(sub_hwnd, nullptr, x, y, 0, 0, SWP_NOSIZE | SWP_NOZORDER);
          result->Success(flutter::EncodableValue(true));
          return;
        }
      } else if (method == "setAlwaysOnTop") {
        if (const auto* val = std::get_if<bool>(call.arguments())) {
          SetWindowPos(sub_hwnd, *val ? HWND_TOPMOST : HWND_NOTOPMOST, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE);
          result->Success(flutter::EncodableValue(true));
          return;
        }
      } else if (method == "startDrag") {
        ReleaseCapture();
        SendMessage(sub_hwnd, WM_NCLBUTTONDOWN, HTCAPTION, 0);
        result->Success(flutter::EncodableValue(true));
        return;
      } else if (method == "makeFrameless") {
        LONG_PTR style = GetWindowLongPtr(sub_hwnd, GWL_STYLE);
        style &= ~(WS_CAPTION | WS_THICKFRAME | WS_MINIMIZEBOX | WS_MAXIMIZEBOX | WS_SYSMENU);
        style |= WS_POPUP;
        SetWindowLongPtr(sub_hwnd, GWL_STYLE, style);
        SetWindowPos(sub_hwnd, nullptr, 0, 0, 0, 0,
                     SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_FRAMECHANGED);
        result->Success(flutter::EncodableValue(true));
        return;
      } else if (method == "getScreenSize") {
        int cx = GetSystemMetrics(SM_CXSCREEN);
        int cy = GetSystemMetrics(SM_CYSCREEN);
        flutter::EncodableMap res;
        res[flutter::EncodableValue("width")] = flutter::EncodableValue(cx);
        res[flutter::EncodableValue("height")] = flutter::EncodableValue(cy);
        result->Success(flutter::EncodableValue(res));
        return;
      } else if (method == "showWindow") {
        ShowWindow(sub_hwnd, SW_SHOW);
        SetForegroundWindow(sub_hwnd);
        result->Success(flutter::EncodableValue(true));
        return;
      } else if (method == "hideWindow" || method == "closeWindow") {
        ShowWindow(sub_hwnd, SW_HIDE);
        result->Success(flutter::EncodableValue(true));
        return;
      }

      HandleMethodCall(call, std::move(result));
    });

    sub_channels_.push_back(sub_channel);
  }

  void Cleanup() {
    UnregisterGlobalMediaKeys();
    UpdateTray(false);
  }

 private:
  DesktopNativeIntegration() = default;
  ~DesktopNativeIntegration() {
    Cleanup();
  }

  static int ExtractInt(const flutter::EncodableMap& map, const std::string& key, int default_val = 0) {
    auto it = map.find(flutter::EncodableValue(key));
    if (it != map.end()) {
      if (std::holds_alternative<int32_t>(it->second)) {
        return std::get<int32_t>(it->second);
      } else if (std::holds_alternative<int64_t>(it->second)) {
        return static_cast<int>(std::get<int64_t>(it->second));
      }
    }
    return default_val;
  }

  void HandleMethodCall(const flutter::MethodCall<flutter::EncodableValue>& call,
                        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
    const std::string& method = call.method_name();

    if (method == "setGlobalMediaKeysEnabled") {
      if (const auto* val = std::get_if<bool>(call.arguments())) {
        global_media_keys_enabled_ = *val;
        RegisterGlobalMediaKeys();
        result->Success(flutter::EncodableValue(true));
        return;
      }
      result->Error("INVALID_ARGUMENT", "Boolean expected");
    } else if (method == "setSystemTrayEnabled") {
      if (const auto* map = std::get_if<flutter::EncodableMap>(call.arguments())) {
        auto it = map->find(flutter::EncodableValue("enabled"));
        bool enabled = it != map->end() && std::get<bool>(it->second);
        std::string tip = "TONAVERA";
        auto tipIt = map->find(flutter::EncodableValue("tooltip"));
        if (tipIt != map->end()) {
          tip = std::get<std::string>(tipIt->second);
        }
        UpdateTray(enabled, tip);
        result->Success(flutter::EncodableValue(true));
        return;
      }
      result->Error("INVALID_ARGUMENT", "Map expected");
    } else if (method == "setMinimizeToTray") {
      if (const auto* val = std::get_if<bool>(call.arguments())) {
        minimize_to_tray_enabled_ = *val;
        result->Success(flutter::EncodableValue(true));
        return;
      }
      result->Error("INVALID_ARGUMENT", "Boolean expected");
    } else if (method == "setAlwaysOnTop") {
      if (const auto* val = std::get_if<bool>(call.arguments())) {
        SetAlwaysOnTop(*val);
        result->Success(flutter::EncodableValue(true));
        return;
      }
      result->Error("INVALID_ARGUMENT", "Boolean expected");
    } else if (method == "setWindowSize") {
      if (const auto* map = std::get_if<flutter::EncodableMap>(call.arguments())) {
        int w = ExtractInt(*map, "width", 1280);
        int h = ExtractInt(*map, "height", 720);
        is_mini_player_mode_ = (w <= 500 && h <= 300);
        SetWindowSize(w, h);
        result->Success(flutter::EncodableValue(true));
        return;
      }
      result->Error("INVALID_ARGUMENT", "Map expected");
    } else if (method == "setWindowPosition") {
      if (const auto* map = std::get_if<flutter::EncodableMap>(call.arguments())) {
        int x = ExtractInt(*map, "x", 100);
        int y = ExtractInt(*map, "y", 100);
        SetWindowPosition(x, y);
        result->Success(flutter::EncodableValue(true));
        return;
      }
      result->Error("INVALID_ARGUMENT", "Map expected");
    } else if (method == "restoreWindow") {
      if (window_handle_) {
        ShowWindow(window_handle_, SW_RESTORE);
        SetForegroundWindow(window_handle_);
      }
      result->Success(flutter::EncodableValue(true));
    } else if (method == "hideWindow") {
      if (window_handle_) {
        ShowWindow(window_handle_, SW_HIDE);
      }
      result->Success(flutter::EncodableValue(true));
    } else if (method == "minimizeWindow") {
      if (window_handle_) {
        ShowWindow(window_handle_, SW_MINIMIZE);
      }
      result->Success(flutter::EncodableValue(true));
    } else if (method == "closeApp") {
      Cleanup();
      if (window_handle_) {
        DestroyWindow(window_handle_);
      }
      result->Success(flutter::EncodableValue(true));
    } else {
      result->NotImplemented();
    }
  }

  HWND window_handle_ = nullptr;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  bool global_media_keys_enabled_ = true;
  bool minimize_to_tray_enabled_ = false;
  bool tray_installed_ = false;
  bool is_mini_player_mode_ = false;
  std::vector<std::shared_ptr<flutter::MethodChannel<flutter::EncodableValue>>> sub_channels_;
};
