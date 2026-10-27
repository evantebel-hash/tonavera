import 'package:flutter_test/flutter_test.dart';
import 'package:mymusic/core/auth/windows_google_auth.dart';
import 'package:mymusic/core/auth/auth_service.dart';
import 'package:mymusic/firebase_options.dart';

void main() {
  group('Windows Google Auth & Platform Safety Unit Tests', () {
    test('1. WindowsGoogleAuth default client ID matches Windows Desktop OAuth client', () {
      expect(
        WindowsGoogleAuth.defaultClientId,
        '303373323332-l3m9tu4o0fjespsdrg83i88gs0rg7o18.apps.googleusercontent.com',
      );
      expect(WindowsGoogleAuth.defaultPort, 8085);
    });

    test('1b. Authorization URL contains response_type=code and PKCE params', () {
      final url = WindowsGoogleAuth.buildAuthorizationUrl(
        clientId: WindowsGoogleAuth.defaultClientId,
        redirectUri: 'http://127.0.0.1:8085',
        codeChallenge: 'challenge123',
        state: 'state123',
      );
      final q = url.queryParameters;
      expect(q['response_type'], 'code');
      expect(q['client_id'], WindowsGoogleAuth.defaultClientId);
      expect(q['redirect_uri'], 'http://127.0.0.1:8085');
      expect(q['scope'], 'openid email profile');
      expect(q['state'], 'state123');
      expect(q['code_challenge'], 'challenge123');
      expect(q['code_challenge_method'], 'S256');
      expect(q.containsKey('client_secret'), isFalse);
    });

    test('1c. Token exchange body uses the SAME Desktop client_id as the authorization URL, correct endpoint params, and NO client_secret', () {
      const redirectUri = 'http://127.0.0.1:8085';
      const verifier = 'test-verifier-ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';

      final authUrl = WindowsGoogleAuth.buildAuthorizationUrl(
        clientId: WindowsGoogleAuth.defaultClientId,
        redirectUri: redirectUri,
        codeChallenge: 'challenge123',
        state: 'state123',
      );

      final tokenBody = WindowsGoogleAuth.buildTokenBody(
        clientId: WindowsGoogleAuth.defaultClientId,
        code: 'theAuthorizationCode',
        codeVerifier: verifier,
        redirectUri: redirectUri,
      );

      // 1. client_id is identical on both sides of the flow.
      expect(tokenBody['client_id'], WindowsGoogleAuth.defaultClientId);
      expect(tokenBody['client_id'], authUrl.queryParameters['client_id']);

      // 2. Correct endpoint parameters for a public desktop client.
      expect(tokenBody['grant_type'], 'authorization_code');
      expect(tokenBody['redirect_uri'], redirectUri);
      expect(tokenBody['code'], 'theAuthorizationCode');
      expect(tokenBody['code_verifier'], verifier);

      // 3. Never a client_secret.
      expect(tokenBody.containsKey('client_secret'), isFalse);
    });

    test('1d. Web-helper URL carries only port + nonce in the query (NO tokens)', () {
      const nonce = 'N0nCe-0123456789-ABCDEFGHIJKLMNOPQRSTUVWXYZ-_';
      final uri = WindowsGoogleAuth.buildWebHelperUrl(
        baseUrl: WindowsGoogleAuth.defaultHelperBaseUrl,
        port: 43210,
        nonce: nonce,
      );

      expect(uri.scheme, 'https');
      expect(uri.host, 'my-music-24b7b.web.app');
      expect(uri.queryParameters['port'], '43210');
      expect(uri.queryParameters['nonce'], nonce);
      // Never tokens or a client_secret in the helper URL.
      expect(uri.queryParameters.containsKey('idtoken'), isFalse);
      expect(uri.queryParameters.containsKey('accesstoken'), isFalse);
      expect(uri.queryParameters.containsKey('client_secret'), isFalse);
      expect(uri.fragment, isEmpty);
    });

    test('1e. Log masking hides the nonce from helper URLs', () {
      const nonce = 'N0nCe-0123456789-ABCDEFGHIJKLMNOPQRSTUVWXYZ-_';
      final uri = WindowsGoogleAuth.buildWebHelperUrl(
        baseUrl: WindowsGoogleAuth.defaultHelperBaseUrl,
        port: 43210,
        nonce: nonce,
      );
      final masked = WindowsGoogleAuth.sanitizeUrlForLog(uri);
      expect(masked.contains(nonce), isFalse);
    });

    test('1f. Loopback POST origin allow-list accepts our Hosting origins and rejects others', () {
      final allowed = WindowsGoogleAuth.allowedHelperOrigins;
      expect(WindowsGoogleAuth.isAllowedHelperOrigin('https://my-music-24b7b.web.app', allowed), isTrue);
      expect(WindowsGoogleAuth.isAllowedHelperOrigin('https://my-music-24b7b.firebaseapp.com', allowed), isTrue);
      expect(WindowsGoogleAuth.isAllowedHelperOrigin('https://my-music-24b7b.web.app:8443', allowed), isTrue);
      expect(WindowsGoogleAuth.isAllowedHelperOrigin('https://evil.example.com', allowed), isFalse);
      expect(WindowsGoogleAuth.isAllowedHelperOrigin('http://127.0.0.1:8085', allowed), isFalse);
      expect(WindowsGoogleAuth.isAllowedHelperOrigin('file:///tmp/x.html', allowed), isFalse);
    });

    test('1g. Web-helper pre-body validation accepts a valid POST and rejects wrong method/path/content-type/origin', () {
      const allowed = WindowsGoogleAuth.allowedHelperOrigins;

      expect(
        WindowsGoogleAuth.validateHelperPreBody(
          method: 'POST', path: '/finish',
          contentTypeMime: 'application/x-www-form-urlencoded',
          originHeader: 'https://my-music-24b7b.web.app',
          allowedOrigins: allowed,
        ),
        HelperReject.none,
      );
      expect(
        WindowsGoogleAuth.validateHelperPreBody(
          method: 'GET', path: '/finish',
          contentTypeMime: 'application/x-www-form-urlencoded',
          originHeader: null, allowedOrigins: allowed,
        ),
        HelperReject.method,
      );
      expect(
        WindowsGoogleAuth.validateHelperPreBody(
          method: 'POST', path: '/favicon.ico',
          contentTypeMime: 'application/x-www-form-urlencoded',
          originHeader: null, allowedOrigins: allowed,
        ),
        HelperReject.path,
      );
      expect(
        WindowsGoogleAuth.validateHelperPreBody(
          method: 'POST', path: '/finish',
          contentTypeMime: 'text/plain',
          originHeader: null, allowedOrigins: allowed,
        ),
        HelperReject.contentType,
      );
      expect(
        WindowsGoogleAuth.validateHelperPreBody(
          method: 'POST', path: '/finish',
          contentTypeMime: 'application/x-www-form-urlencoded',
          originHeader: 'https://evil.example.com', allowedOrigins: allowed,
        ),
        HelperReject.origin,
      );
      // Missing Origin is tolerated (nonce is the primary binding).
      expect(
        WindowsGoogleAuth.validateHelperPreBody(
          method: 'POST', path: '/finish',
          contentTypeMime: 'application/x-www-form-urlencoded',
          originHeader: null, allowedOrigins: allowed,
        ),
        HelperReject.none,
      );
      // Opaque-origin serialization ("null") is normalized like a missing Origin.
      expect(
        WindowsGoogleAuth.validateHelperPreBody(
          method: 'POST', path: '/finish',
          contentTypeMime: 'application/x-www-form-urlencoded',
          originHeader: 'null', allowedOrigins: allowed,
        ),
        HelperReject.none,
      );
    });

    test('1i. Origin diagnostics are sanitized to scheme://host[:port]', () {
      expect(WindowsGoogleAuth.describeHelperOrigin(null), '<missing>');
      expect(WindowsGoogleAuth.describeHelperOrigin('null'), 'null');
      expect(
        WindowsGoogleAuth.describeHelperOrigin('https://my-music-24b7b.web.app'),
        'https://my-music-24b7b.web.app',
      );
      expect(
        WindowsGoogleAuth.describeHelperOrigin('https://my-music-24b7b.web.app:8443'),
        'https://my-music-24b7b.web.app:8443',
      );
      expect(
        WindowsGoogleAuth.describeHelperOrigin('https://h.example.com/index.html?a=1#frag'),
        'https://h.example.com',
      );
      expect(WindowsGoogleAuth.describeHelperOrigin('garbage'), '<malformed>');
    });

    test('1h. Web-helper post-body validation requires nonce match and at least one credential', () {
      const nonce = 'NONCE0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';

      // Valid: id_token present.
      expect(
        WindowsGoogleAuth.validateHelperPostBody(
          bodyParams: {'nonce': nonce, 'idtoken': 'x', 'accesstoken': 'y'},
          expectedNonce: nonce,
        ),
        HelperReject.none,
      );
      // Valid: access-token only (supported Firebase OAuthProvider path).
      expect(
        WindowsGoogleAuth.validateHelperPostBody(
          bodyParams: {'nonce': nonce, 'accesstoken': 'y'},
          expectedNonce: nonce,
        ),
        HelperReject.none,
      );
      // Wrong nonce.
      expect(
        WindowsGoogleAuth.validateHelperPostBody(
          bodyParams: {'nonce': 'WRONG', 'idtoken': 'x'},
          expectedNonce: nonce,
        ),
        HelperReject.nonce,
      );
      // No credential at all.
      expect(
        WindowsGoogleAuth.validateHelperPostBody(
          bodyParams: {'nonce': nonce},
          expectedNonce: nonce,
        ),
        HelperReject.payload,
      );
      // Empty credential fields count as missing.
      expect(
        WindowsGoogleAuth.validateHelperPostBody(
          bodyParams: {'nonce': nonce, 'idtoken': '', 'accesstoken': ''},
          expectedNonce: nonce,
        ),
        HelperReject.payload,
      );
    });

    test('2. DefaultFirebaseOptions contains real configuration for Windows', () {
      expect(DefaultFirebaseOptions.windows.projectId, 'my-music-24b7b');
      expect(DefaultFirebaseOptions.windows.apiKey, 'AIzaSyBNOli8oBqunQaK0Uekujea__NIbbAv_KM');
      expect(DefaultFirebaseOptions.windows.authDomain, 'my-music-24b7b.firebaseapp.com');
      expect(DefaultFirebaseOptions.windows.storageBucket, 'my-music-24b7b.firebasestorage.app');
    });

    test('3. DefaultFirebaseOptions contains unchanged real configuration for Android', () {
      expect(DefaultFirebaseOptions.android.projectId, 'my-music-24b7b');
      expect(DefaultFirebaseOptions.android.apiKey, 'AIzaSyBNOli8oBqunQaK0Uekujea__NIbbAv_KM');
      expect(DefaultFirebaseOptions.android.storageBucket, 'my-music-24b7b.firebasestorage.app');
    });

    test('4. AuthService error mapping cleanly handles Google cancelled errors', () {
      expect(AuthService.mapAuthError('user-cancelled'), contains('dibatalkan'));
      expect(AuthService.mapAuthError('12501'), contains('dibatalkan'));
      expect(AuthService.mapAuthError('Masuk dengan Google dibatalkan.'), contains('dibatalkan'));
    });

    test('5. AuthService error mapping cleanly handles network issues', () {
      expect(AuthService.mapAuthError('network-request-failed'), contains('jaringan'));
      expect(AuthService.mapAuthError('SocketException'), contains('jaringan'));
    });
  });
}
