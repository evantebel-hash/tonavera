import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationPermissionService {
  static const MethodChannel _channel = MethodChannel(
    'com.mymusic/notification_permission',
  );
  static const String _prefKeyAsked = 'notification_permission_requested_once';

  /// Check whether notification permission has been granted
  static Future<bool> hasPermission() async {
    if (!Platform.isAndroid) return true;
    try {
      final res = await _channel.invokeMethod<bool>(
        'hasNotificationPermission',
      );
      return res ?? false;
    } catch (e) {
      debugPrint(
        '[MyMusic][MediaSession] Error checking notification permission: $e',
      );
      return false;
    }
  }

  /// Request notification permission once gracefully on Android 13+
  static Future<bool> requestPermissionIfNeeded() async {
    if (!Platform.isAndroid) return true;
    try {
      final hasPerm = await hasPermission();
      if (hasPerm) return true;

      final prefs = await SharedPreferences.getInstance();
      final alreadyAsked = prefs.getBool(_prefKeyAsked) ?? false;
      if (alreadyAsked) {
        debugPrint(
          '[MyMusic][MediaSession] notification permission already requested previously, skipping prompt',
        );
        return false;
      }

      await prefs.setBool(_prefKeyAsked, true);
      final granted = await _channel.invokeMethod<bool>(
        'requestNotificationPermission',
      );
      final result = granted ?? false;
      if (!result) {
        debugPrint('[MyMusic][MediaSession] notification permission denied');
      }
      return result;
    } catch (e) {
      debugPrint('[MyMusic][MediaSession] notification permission denied');
      return false;
    }
  }
}
