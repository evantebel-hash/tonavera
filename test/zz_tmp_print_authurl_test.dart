import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mymusic/core/auth/windows_google_auth.dart';

void main() {
  test('print masked authorization url', () {
    final url = WindowsGoogleAuth.buildAuthorizationUrl(
      clientId: WindowsGoogleAuth.defaultClientId,
      redirectUri: 'http://127.0.0.1:8085',
      codeChallenge: 'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM',
      state: 'abc123DEF456ghi789',
    );
    File('zz_authurl_out.txt').writeAsStringSync(
      'RAW_QUERY=${url.query}\n'
      'KEYS=${url.queryParameters.keys.toList()}\n'
      'MASKED=${WindowsGoogleAuth.sanitizeUrlForLog(url)}\n',
    );
    expect(url.queryParameters['response_type'], 'code');
  });
}
