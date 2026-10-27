import 'package:flutter/foundation.dart';

class ApiConfig {
  static const String _customBaseUrl = String.fromEnvironment(
    'MYMUSIC_API_URL',
    defaultValue: '',
  );
  static const String _environment = String.fromEnvironment(
    'MYMUSIC_ENV',
    defaultValue: 'development',
  );

  static String get baseUrl {
    if (_customBaseUrl.isNotEmpty) {
      return _customBaseUrl;
    }
    if (_environment == 'production') {
      return 'https://api.mymusic.app/v1';
    }
    if (kIsWeb) {
      return 'http://127.0.0.1/mymusic/public/api';
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2/mymusic/public/api';
    }
    return 'http://127.0.0.1/mymusic/public/api';
  }

  static String get storageBaseUrl {
    if (_customBaseUrl.isNotEmpty) {
      return _customBaseUrl.replaceAll('/api', '/writable');
    }
    if (_environment == 'production') {
      return 'https://api.mymusic.app/writable';
    }
    if (kIsWeb) {
      return 'http://127.0.0.1/mymusic/writable';
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2/mymusic/writable';
    }
    return 'http://127.0.0.1/mymusic/writable';
  }
}
