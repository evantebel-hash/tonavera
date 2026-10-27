# Phase 6.2 — Notification Player Documentation

## Overview
Phase 6.2 implements persistent Android `MediaStyle` notification controls for active audio playback in foreground, background, and lock screen states.

## Key Features & Lifecycle
- **Persistent Media Notification**: Displays current artwork, title, artist, play/pause, next, and previous buttons.
- **Background Playback**: Supported by `FOREGROUND_SERVICE` with `mediaPlayback` type on Android 14+ (API 34+).
- **Settings Toggle**: Users can toggle Notification & Lock Screen Player ON/OFF via Settings (`notificationPlayerEnabled`).
- **Permission Safety**: Includes `POST_NOTIFICATIONS` permission declaration with graceful fallback if permission is not granted on runtime.

## Testing & Verification
- Release APK build verified.
- Unit test suite verified.
