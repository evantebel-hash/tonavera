import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../models/user_model.dart';
import 'auth_service.dart';

/// Outcome of validating a helper-page request; used for diagnostics.
enum HelperReject { none, method, path, contentType, origin, nonce, payload }

/// Handles Google authentication on Windows Desktop.
///
/// Two flows are implemented:
/// 1. [signIn]: RFC 8252 loopback OAuth (Authorization Code + PKCE) against the
///    Desktop OAuth client. Only usable for clients without an enforced
///    client_secret.
/// 2. [signInWithWebHelper]: Firebase-hosted helper page (Firebase Auth JS SDK)
///    performs Google Sign-In; the Google ID/access tokens are returned to this
///    app over a one-shot loopback POST, then [FirebaseAuth.signInWithCredential]
///    completes the login. Requires NO client_secret and no backend server.
class WindowsGoogleAuth {
  /// Windows Desktop OAuth Client ID from Google Cloud Console for project 'my-music-24b7b'.
  static const String defaultClientId =
      '303373323332-l3m9tu4o0fjespsdrg83i88gs0rg7o18.apps.googleusercontent.com';

  /// Preferred local loopback port for Desktop OAuth redirects.
  static const int defaultPort = 8085;

  /// Firebase Hosting helper page that performs Google Sign-In with the Firebase
  /// Auth JS SDK and returns the Google tokens to this app via a loopback POST.
  /// Hosting `firebase.json` uses `"public": "auth_helper"`, so `index.html` is
  /// served at the site ROOT (`/`), not under `/auth_helper/`.
  static const String defaultHelperBaseUrl =
      'https://my-music-24b7b.web.app/index.html';

  /// Time the Windows app waits for the user to finish Google login in the
  /// helper page before giving up.
  static const Duration defaultHelperTimeout = Duration(minutes: 5);

  /// Origins (scheme + host only) allowed to POST credentials to the loopback
  /// listener. Keep in sync with the Firebase Hosting site the helper is served
  /// from. Defense-in-depth; the one-time nonce is the primary binding.
  static const List<String> allowedHelperOrigins = [
    'https://my-music-24b7b.web.app',
    'https://my-music-24b7b.firebaseapp.com',
  ];

  /// Upper bound for the loopback POST body (Google id_token + access_token are
  /// each ~1-2 KB).
  static const int helperMaxPayloadBytes = 64 * 1024;

  static void _log(String message) {
    if (kDebugMode) {
      debugPrint('[WindowsGoogleAuth] $message');
    }
  }

  /// Performs Google Sign-In on Windows Desktop.
  static Future<UserModel> signIn({
    String clientId = defaultClientId,
    int port = defaultPort,
  }) async {
    _log('Starting OAuth');

    HttpServer? server;
    StreamSubscription<HttpRequest>? serverSub;
    bool serverClosed = false;

    Future<void> closeServer() async {
      if (serverClosed) return;
      serverClosed = true;
      try {
        await serverSub?.cancel();
      } catch (_) {}
      try {
        await server?.close(force: true);
      } catch (_) {}
      server = null;
    }

    try {
      // 1. Bind local loopback server
      HttpServer activeServer;
      try {
        activeServer = await HttpServer.bind(
          InternetAddress.loopbackIPv4,
          port,
        );
      } catch (_) {
        // Fallback to ephemeral port if 8085 is already in use
        activeServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      }
      server = activeServer;

      final int activePort = activeServer.port;
      final redirectUri = 'http://127.0.0.1:$activePort';
      _log('Local callback server listening on $redirectUri');

      // 2. Generate PKCE parameters
      final codeVerifier = _generateRandomString(64);
      final codeChallenge = _generateCodeChallenge(codeVerifier);
      final state = _generateRandomString(32);

      // 3. Construct Google OAuth Authorization URL
      final authUrl = buildAuthorizationUrl(
        clientId: clientId,
        redirectUri: redirectUri,
        codeChallenge: codeChallenge,
        state: state,
      );
      _log('Authorization URL created');

      // 4. Open default system browser on Windows.
      // NOTE: Do NOT use `cmd /c start <url>` — cmd treats '&' as a command
      // separator and truncates the URL after the first parameter (which
      // caused "Required parameter is missing: response_type").
      // rundll32 passes the full URL directly to the default browser.
      debugPrint(
        '[MyMusic][WindowsAuth] Opening browser: ${sanitizeUrlForLog(authUrl)}',
      );
      await Process.start('rundll32', [
        'url.dll,FileProtocolHandler',
        authUrl.toString(),
      ], mode: ProcessStartMode.detached);

      // 5. Wait for the redirect with timeout (3 minutes)
      final completer = Completer<String>();
      serverSub = activeServer.listen((HttpRequest request) async {
        final queryParams = request.uri.queryParameters;
        final response = request.response;
        response.headers.contentType = ContentType.html;

        final receivedState = queryParams['state'];
        final error = queryParams['error'];
        final code = queryParams['code'];

        // Ignore unrelated requests (e.g. /favicon.ico). Only the OAuth
        // redirect carries `code` or `error`. Completing the Future for a
        // stray request would abort the whole login prematurely.
        if (code == null && error == null) {
          response.statusCode = HttpStatus.notFound;
          await response.close();
          return;
        }

        _log('Callback received');

        if (error != null) {
          response.write(
            _buildHtmlResponse(
              success: false,
              title: 'Autentikasi Dibatalkan',
              message:
                  'Proses login dengan Google dibatalkan atau terjadi kesalahan ($error). Anda dapat menutup jendela ini.',
            ),
          );
          await response.close();

          if (!completer.isCompleted) {
            if (error.contains('access_denied')) {
              completer.completeError(
                const AuthException('Login dengan Google dibatalkan.'),
              );
            } else if (error.contains('redirect_uri_mismatch')) {
              completer.completeError(
                AuthException(
                  'Gagal masuk Google: Redirect URI ($redirectUri) belum terdaftar di Google Cloud Console. Tambahkan "$redirectUri" ke Authorized redirect URIs atau buat OAuth Client ID bertipe Desktop app.',
                ),
              );
            } else {
              completer.completeError(
                AuthException('Google OAuth Error: $error'),
              );
            }
          }
          return;
        }

        _log('Authorization code received');

        if (receivedState != state) {
          response.write(
            _buildHtmlResponse(
              success: false,
              title: 'Validasi Gagal',
              message:
                  'Status sesi autentikasi tidak valid (CSRF mismatch). Silakan coba lagi.',
            ),
          );
          await response.close();
          if (!completer.isCompleted) {
            completer.completeError(
              const AuthException(
                'Validasi sesi autentikasi gagal. Silakan coba lagi.',
              ),
            );
          }
          return;
        }

        _log('State verified');

        // Send the success page to the browser, then forward the authorization
        // code to the awaiting signIn() future. The local server stays alive
        // until token exchange + Firebase sign-in have completed.
        response.write(
          _buildHtmlResponse(
            success: true,
            title: 'Autentikasi Berhasil',
            message:
                'Akun Google Anda berhasil diverifikasi.<br>Anda dapat menutup tab ini dan kembali ke aplikasi <strong>MyMusic</strong>.',
          ),
        );
        await response.close();
        if (!completer.isCompleted) {
          completer.complete(code);
        }
      });

      _log('Waiting for callback');

      final authCode = await completer.future.timeout(
        const Duration(minutes: 3),
        onTimeout: () {
          throw const AuthException(
            'Batas waktu login Google telah habis. Silakan coba lagi.',
          );
        },
      );

      // 6. Exchange Authorization Code for Google ID Token & Access Token
      _log('Exchanging authorization code');
      final tokenUrl = Uri.https('oauth2.googleapis.com', '/token');
      // Public desktop client (RFC 8252 + RFC 7636 PKCE): client_secret is
      // intentionally NOT sent. redirect_uri and code_verifier match the values
      // used when the authorization URL was created above.
      _log(
        'Token request: grant_type=authorization_code, redirect_uri=$redirectUri, '
        'PKCE verifier present, client_secret NOT included',
      );
      final tokenBody = buildTokenBody(
        clientId: clientId,
        code: authCode,
        codeVerifier: codeVerifier,
        redirectUri: redirectUri,
      );

      final tokenResponse = await http.post(
        tokenUrl,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: tokenBody,
      );

      if (tokenResponse.statusCode != 200) {
        String googleError = 'unknown';
        String? googleErrorDescription;
        try {
          final errJson = jsonDecode(tokenResponse.body);
          if (errJson is Map && errJson['error'] is String) {
            googleError = errJson['error'] as String;
          }
          if (errJson is Map && errJson['error_description'] is String) {
            googleErrorDescription = errJson['error_description'] as String;
          }
        } catch (_) {}

        // Safe diagnostic: Google error codes/descriptions never contain the
        // authorization code, tokens, or PKCE verifier (by Google's design).
        _log(
          'Token exchange failed: HTTP ${tokenResponse.statusCode} error=$googleError'
          '${googleErrorDescription == null ? '' : ': $googleErrorDescription'}',
        );

        // Google's token endpoint returns "client_secret is missing." (both as
        // `invalid_client` and, as measured, `invalid_request`) when the
        // client_id it resolves is one that MUST be accompanied by its issued
        // client_secret. Every request-shape variation we tested is rejected
        // server-side, keyed purely to this client_id. This app never sends a
        // client_secret, so a secret-less login is only possible with a client
        // that Google treats as truly public (no issued client_secret).
        if ((googleError == 'invalid_client' ||
                googleError == 'invalid_request') &&
            (googleErrorDescription?.toLowerCase().contains('client_secret') ??
                false)) {
          throw const AuthException(
            'Gagal verifikasi token Google: Google mewajibkan client_secret untuk client_id ini '
            '(respons: "client_secret is missing"), tanpa melihat bentuk requestnya. Walau tipe '
            'klien tampil sebagai "Desktop" di Console, Google hanya menyetujui pertukaran kode '
            'tanpa secret bila credential tersebut tidak memiliki client_secret. Aplikasi ini tidak '
            'pernah mengirim client_secret. Gunakan OAuth client tanpa client_secret (atau masukkan '
            'secret milik client ini secara runtime) agar login tanpa secret bisa berhasil.',
          );
        }

        final errDescription = googleErrorDescription ?? googleError;
        throw AuthException(
          'Gagal verifikasi token Google: $errDescription (HTTP ${tokenResponse.statusCode}).',
        );
      }

      final tokenData = jsonDecode(tokenResponse.body) as Map<String, dynamic>;
      final idToken = tokenData['id_token'] as String?;
      final accessToken = tokenData['access_token'] as String?;
      _log('Google token received');

      if (idToken == null || idToken.isEmpty) {
        throw const AuthException('Gagal mendapatkan ID Token dari Google.');
      }

      // 7. Authenticate with Firebase Authentication using the Google Credential
      final OAuthCredential credential = GoogleAuthProvider.credential(
        idToken: idToken,
        accessToken: accessToken,
      );
      _log('Firebase credential created');

      final UserCredential userCredential = await FirebaseAuth.instance
          .signInWithCredential(credential);
      final User? fbUser = userCredential.user;

      if (fbUser == null) {
        throw const AuthException(
          'Gagal mendapatkan profil pengguna dari Firebase.',
        );
      }

      _log('Firebase signInWithCredential completed');

      return UserModel.fromFirebaseUser(
        uid: fbUser.uid,
        displayName: fbUser.displayName,
        email: fbUser.email,
        photoUrl: fbUser.photoURL,
        provider: 'google',
      );
    } on AuthException {
      rethrow;
    } on FirebaseAuthException catch (e) {
      _log('FirebaseAuthException: ${e.code}');
      throw AuthException(AuthService.mapAuthError(e));
    } catch (e) {
      _log('Unexpected error: ${e.runtimeType}');
      throw AuthException(AuthService.mapAuthError(e));
    } finally {
      // The loopback server must outlive token exchange and Firebase sign-in.
      await closeServer();
    }
  }

  /// Google Sign-In for Windows via a **Firebase-hosted web helper**.
  ///
  /// Steps:
  /// 1. Bind a loopback listener on a RANDOM port and generate a one-time nonce.
  /// 2. Open the browser to [helperBaseUrl] with `port` and `nonce` in the query
  ///    (these are not tokens).
  /// 3. The helper page runs `signInWithPopup` (Firebase Auth JS), then POSTs the
  ///    Google `id_token`/`access_token` back to `http://127.0.0.1:<port>/finish`
  ///    as a form body (never in the URL).
  /// 4. This app validates the POST (method, path, content-type, size, origin,
  ///    one-time nonce) and completes login with
  ///    [FirebaseAuth.signInWithCredential] BEFORE rendering the success page.
  ///
  /// No client_secret is used anywhere, and no backend server is required.
  static Future<UserModel> signInWithWebHelper({
    String helperBaseUrl = defaultHelperBaseUrl,
    Duration timeout = defaultHelperTimeout,
  }) async {
    _log('Web-helper sign-in: starting');

    HttpServer? server;
    StreamSubscription<HttpRequest>? serverSub;
    bool serverClosed = false;

    Future<void> closeServer() async {
      if (serverClosed) return;
      serverClosed = true;
      try {
        await serverSub?.cancel();
      } catch (_) {}
      try {
        await server?.close(force: true);
      } catch (_) {}
      server = null;
    }

    try {
      // One-time nonce binds the in-flight login to THIS app instance.
      final nonce = _generateRandomString(32);

      // Loopback listener on a RANDOM port (port 0 = ephemeral).
      final activeServer = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      server = activeServer;
      final int port = activeServer.port;
      _log('Loopback listener on 127.0.0.1:$port');

      final completer = Completer<UserModel>();
      serverSub = activeServer.listen((HttpRequest request) async {
        await _handleWebHelperRequest(
          request: request,
          expectedNonce: nonce,
          allowedOrigins: allowedHelperOrigins,
          maxPayloadBytes: helperMaxPayloadBytes,
          completer: completer,
        );
      });

      // Open the helper page. Only port+nonce travel in the URL (no tokens).
      final helperUri = buildWebHelperUrl(
        baseUrl: helperBaseUrl,
        port: port,
        nonce: nonce,
      );
      debugPrint(
        '[MyMusic][WindowsAuth] Opening helper page: ${sanitizeUrlForLog(helperUri)}',
      );
      await Process.start('rundll32', [
        'url.dll,FileProtocolHandler',
        helperUri.toString(),
      ], mode: ProcessStartMode.detached);

      // Wait for the one-shot result (either UserModel or an error).
      return await completer.future.timeout(
        timeout,
        onTimeout: () {
          throw const AuthException(
            'Batas waktu login Google telah habis. Silakan coba lagi.',
          );
        },
      );
    } on AuthException {
      rethrow;
    } on FirebaseAuthException catch (e) {
      _log('FirebaseAuthException: ${e.code}');
      throw AuthException(AuthService.mapAuthError(e));
    } catch (e) {
      _log('Web-helper error: ${e.runtimeType}');
      throw AuthException(AuthService.mapAuthError(e));
    } finally {
      await closeServer();
    }
  }

  /// Pre-body checks (method, path, content-type, origin) — no payload needed.
  ///
  /// Log/status mapping (kept compatible with prior behavior):
  /// - method/path -> 404; content-type/nonce/payload -> 400; origin -> 403.
  @visibleForTesting
  static HelperReject validateHelperPreBody({
    required String method,
    required String path,
    required String? contentTypeMime,
    required String? originHeader,
    required List<String> allowedOrigins,
  }) {
    if (method != 'POST') return HelperReject.method;
    if (path != '/finish') return HelperReject.path;
    if (contentTypeMime != 'application/x-www-form-urlencoded') {
      return HelperReject.contentType;
    }
    // The browser serializes an opaque origin as the literal string "null"
    // (e.g. some LNA/proxy contexts). Because missing origins are already
    // accepted here (the one-time nonce is the binding), "null" is normalized
    // to "missing" instead of being rejected for pure formatting reasons.
    final effectiveOrigin = (originHeader == null || originHeader == 'null')
        ? null
        : originHeader;
    if (effectiveOrigin != null &&
        !isAllowedHelperOrigin(effectiveOrigin, allowedOrigins)) {
      return HelperReject.origin;
    }
    return HelperReject.none;
  }

  /// Post-body checks: one-time nonce binding + presence of at least one
  /// credential field (either `idtoken` or `accesstoken`).
  @visibleForTesting
  static HelperReject validateHelperPostBody({
    required Map<String, String> bodyParams,
    required String expectedNonce,
  }) {
    if (bodyParams['nonce'] != expectedNonce) return HelperReject.nonce;
    final id = bodyParams['idtoken'];
    final access = bodyParams['accesstoken'];
    if ((id == null || id.isEmpty) && (access == null || access.isEmpty)) {
      return HelperReject.payload;
    }
    return HelperReject.none;
  }

  static int _statusForReject(HelperReject reject) {
    switch (reject) {
      case HelperReject.none:
        return HttpStatus.ok;
      case HelperReject.method:
      case HelperReject.path:
        return HttpStatus.notFound;
      case HelperReject.origin:
        return HttpStatus.forbidden;
      case HelperReject.contentType:
      case HelperReject.nonce:
      case HelperReject.payload:
        return HttpStatus.badRequest;
    }
  }

  static String _labelForReject(HelperReject reject) {
    switch (reject) {
      case HelperReject.none:
        return 'ok';
      case HelperReject.method:
        return 'method_rejected';
      case HelperReject.path:
        return 'path_rejected';
      case HelperReject.contentType:
        return 'content_type_rejected';
      case HelperReject.origin:
        return 'origin_rejected';
      case HelperReject.nonce:
        return 'nonce_rejected';
      case HelperReject.payload:
        return 'payload_rejected';
    }
  }

  /// CORS + Private-Network-Access headers, applied ONLY when [origin] is one of
  /// [allowedOrigins]. This is required for browsers to reach the loopback
  /// listener (form POST navigation or fetch + OPTIONS preflight) — it never
  /// opens the port to arbitrary origins.
  static void _setLoopbackCorsHeaders(
    HttpResponse response,
    String? origin,
    List<String> allowedOrigins,
  ) {
    if (origin == null || !isAllowedHelperOrigin(origin, allowedOrigins))
      return;
    response.headers.set('Access-Control-Allow-Origin', origin);
    response.headers.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
    response.headers.set('Access-Control-Allow-Headers', 'Content-Type');
    response.headers.set('Access-Control-Allow-Private-Network', 'true');
  }

  /// Validates the single expected POST from the helper page and, only after
  /// Firebase login succeeds, renders the success page and completes [completer].
  static Future<void> _handleWebHelperRequest({
    required HttpRequest request,
    required String expectedNonce,
    required List<String> allowedOrigins,
    required int maxPayloadBytes,
    required Completer<UserModel> completer,
  }) async {
    final response = request.response;
    final String requestPath = request.uri.path;

    // Every hit is logged with method + path ONLY (never payload/nonce/tokens).
    _log('Incoming loopback request: ${request.method} $requestPath');

    // Browsers may first send an OPTIONS preflight for a loopback fetch().
    // Answer it for an ALLOWED origin only; anything else is refused.
    if (request.method == 'OPTIONS' && requestPath == '/finish') {
      final preflightOrigin = request.headers.value('origin');
      if (preflightOrigin == null ||
          !isAllowedHelperOrigin(preflightOrigin, allowedOrigins)) {
        _log('origin_rejected');
        response.statusCode = HttpStatus.forbidden;
        await response.close();
        return;
      }
      _log('options_preflight_ok');
      _setLoopbackCorsHeaders(response, preflightOrigin, allowedOrigins);
      response.statusCode = HttpStatus.noContent;
      await response.close();
      return;
    }

    // Pre-body validation (method/path/content-type/origin).
    final requestedOrigin = request.headers.value('origin');
    final preBodyReject = validateHelperPreBody(
      method: request.method,
      path: requestPath,
      contentTypeMime: request.headers.contentType?.mimeType,
      originHeader: requestedOrigin,
      allowedOrigins: allowedOrigins,
    );
    if (preBodyReject != HelperReject.none) {
      if (preBodyReject == HelperReject.origin) {
        // Recon: safe origin form (scheme://host[:port]) + allow-list hosts only.
        _log(
          'origin_rejected received=${describeHelperOrigin(requestedOrigin)} '
          'allowed=${allowedOrigins.join(', ')}',
        );
      } else {
        _log(_labelForReject(preBodyReject));
      }
      response.statusCode = _statusForReject(preBodyReject);
      await response.close();
      return;
    }

    // Size-limited body read.
    final List<int> bodyBytes;
    try {
      bodyBytes = await _readBodyLimited(request, maxPayloadBytes);
    } on AuthException {
      _log('payload_rejected (body too large)');
      response.statusCode = HttpStatus.requestEntityTooLarge;
      await response.close();
      return;
    }

    final params = Uri.splitQueryString(utf8.decode(bodyBytes));

    // Post-body validation: nonce binding + at least one credential field.
    final postBodyReject = validateHelperPostBody(
      bodyParams: params,
      expectedNonce: expectedNonce,
    );
    if (postBodyReject != HelperReject.none) {
      _log(_labelForReject(postBodyReject));
      response.statusCode = _statusForReject(postBodyReject);
      await response.close();
      return;
    }

    final origin = request.headers.value('origin');
    final idToken = params['idtoken'];
    final accessToken = params['accesstoken'];

    // Only the FIRST valid POST consumes the flow; strays get a plain error.
    if (completer.isCompleted) {
      response.statusCode = HttpStatus.gone;
      await response.close();
      return;
    }

    _log('Valid callback received; signing in to Firebase');
    try {
      final user = await _signInToFirebaseWithGoogle(idToken, accessToken);
      _log('Firebase signInWithCredential completed');
      // The success page is rendered ONLY AFTER Firebase login succeeded.
      _setLoopbackCorsHeaders(response, origin, allowedOrigins);
      response.statusCode = HttpStatus.ok;
      response.headers.contentType = ContentType.html;
      response.write(
        _buildHtmlResponse(
          success: true,
          title: 'Autentikasi Berhasil',
          message:
              'Akun Google Anda berhasil diverifikasi dan aplikasi MyMusic sudah masuk.<br>Anda dapat menutup tab ini.',
        ),
      );
      await response.close();
      if (!completer.isCompleted) {
        completer.complete(user);
      }
    } catch (e) {
      final String errorMessage = _describeFirebaseError(e);
      if (!completer.isCompleted) {
        completer.completeError(
          e is AuthException ? e : AuthException(errorMessage),
        );
      }
      _setLoopbackCorsHeaders(response, origin, allowedOrigins);
      response.statusCode = HttpStatus.internalServerError;
      response.headers.contentType = ContentType.html;
      response.write(
        _buildHtmlResponse(
          success: false,
          title: 'Autentikasi Gagal',
          message: '$errorMessage Tutup tab ini dan coba lagi dari aplikasi.',
        ),
      );
      await response.close();
    }
  }

  /// Produces a safe, user-displayable description of a login error.
  /// Firebase error codes never contain tokens, nonce, or secrets.
  static String _describeFirebaseError(Object e) {
    if (e is FirebaseAuthException) {
      return 'Login Google ditolak Firebase (${e.code}).';
    }
    if (e is AuthException) {
      return e.message;
    }
    return AuthService.mapAuthError(e);
  }

  /// Converts the Google credentials obtained by the web helper into a Firebase
  /// user. Primary path uses [GoogleAuthProvider.credential] with id_token +
  /// access_token; if native [FirebaseAuth.signInWithCredential] rejects an
  /// id_token issued to the project's *web* OAuth client, or when the web helper
  /// only returned an access token, falls back to the officially supported
  /// access-token-only [OAuthProvider] flow.
  static Future<UserModel> _signInToFirebaseWithGoogle(
    String? idToken,
    String? accessToken,
  ) async {
    UserCredential userCredential;
    if (idToken != null && idToken.isNotEmpty) {
      final OAuthCredential googleCredential = GoogleAuthProvider.credential(
        idToken: idToken,
        accessToken: accessToken,
      );
      try {
        userCredential = await FirebaseAuth.instance.signInWithCredential(
          googleCredential,
        );
      } on FirebaseAuthException {
        if (accessToken == null || accessToken.isEmpty) {
          rethrow;
        }
        _log(
          'id_token-based sign-in rejected; retrying with access token only',
        );
        userCredential = await FirebaseAuth.instance.signInWithCredential(
          OAuthProvider('google.com').credential(accessToken: accessToken),
        );
      }
    } else if (accessToken != null && accessToken.isNotEmpty) {
      // The web helper delivered an access token WITHOUT an id_token (web client
      // OpenID scopes/consent may omit it). Use the documented access-token-only
      // OAuth provider flow instead of failing on a missing id_token.
      _log('id_token absent; signing in with access token only');
      userCredential = await FirebaseAuth.instance.signInWithCredential(
        OAuthProvider('google.com').credential(accessToken: accessToken),
      );
    } else {
      throw const AuthException('Tidak ada kredensial Google yang diterima.');
    }

    final User? fbUser = userCredential.user;
    if (fbUser == null) {
      throw const AuthException(
        'Gagal mendapatkan profil pengguna dari Firebase.',
      );
    }

    return UserModel.fromFirebaseUser(
      uid: fbUser.uid,
      displayName: fbUser.displayName,
      email: fbUser.email,
      photoUrl: fbUser.photoURL,
      provider: 'google',
    );
  }

  /// Reads the request body but never allows more than [maxBytes].
  static Future<List<int>> _readBodyLimited(
    HttpRequest request,
    int maxBytes,
  ) async {
    final builder = BytesBuilder(copy: false);
    await for (final chunk in request) {
      builder.add(chunk);
      if (builder.length > maxBytes) {
        throw const AuthException('Payload melebihi batas yang diizinkan.');
      }
    }
    return builder.takeBytes();
  }

  /// Builds the URL that opens the Firebase-hosted helper page.
  ///
  /// Only the loopback [port] and the one-time [nonce] are placed in the query
  /// string — never tokens.
  @visibleForTesting
  static Uri buildWebHelperUrl({
    required String baseUrl,
    required int port,
    required String nonce,
  }) {
    final base = Uri.parse(baseUrl);
    final params = Map<String, String>.from(base.queryParameters);
    params['port'] = '$port';
    params['nonce'] = nonce;
    return base.replace(queryParameters: params);
  }

  /// True when [origin] is one of [allowedOrigins] (scheme + host only, https).
  @visibleForTesting
  static bool isAllowedHelperOrigin(
    String origin,
    List<String> allowedOrigins,
  ) {
    final uri = Uri.tryParse(origin);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return false;
    final normalized = '${uri.scheme}://${uri.host}';
    return allowedOrigins.contains(normalized);
  }

  /// Sanitized origin for diagnostics: scheme://host[:port] only. Never includes
  /// path, query, fragment, nonce, or credentials.
  @visibleForTesting
  static String describeHelperOrigin(String? origin) {
    if (origin == null) return '<missing>';
    if (origin == 'null') return 'null';
    final uri = Uri.tryParse(origin);
    if (uri == null || uri.host.isEmpty) return '<malformed>';
    final port = uri.hasPort ? ':${uri.port}' : '';
    return '${uri.scheme}://${uri.host}$port';
  }

  /// Builds the Google OAuth 2.0 Authorization Code + PKCE request URL.
  @visibleForTesting
  static Uri buildAuthorizationUrl({
    required String clientId,
    required String redirectUri,
    required String codeChallenge,
    required String state,
  }) {
    return Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
      'response_type': 'code',
      'client_id': clientId,
      'redirect_uri': redirectUri,
      'scope': 'openid email profile',
      'code_challenge': codeChallenge,
      'code_challenge_method': 'S256',
      'state': state,
      'prompt': 'select_account',
    });
  }

  /// Builds the `POST https://oauth2.googleapis.com/token` form body for the
  /// authorization code exchange.
  ///
  /// Implements Google's public desktop client flow: **no client_secret** is
  /// ever included. The [clientId] and [redirectUri] are identical to those in
  /// [buildAuthorizationUrl], and [codeVerifier] is the PKCE verifier whose
  /// S256 challenge was sent with the authorization request.
  @visibleForTesting
  static Map<String, String> buildTokenBody({
    required String clientId,
    required String code,
    required String codeVerifier,
    required String redirectUri,
  }) {
    return {
      'client_id': clientId,
      'code': code,
      'code_verifier': codeVerifier,
      'grant_type': 'authorization_code',
      'redirect_uri': redirectUri,
    };
  }

  /// Masks sensitive one-time values (state, code_challenge, nonce) for logging.
  @visibleForTesting
  static String sanitizeUrlForLog(Uri url) {
    final masked = Map<String, String>.from(url.queryParameters);
    for (final key in ['state', 'code_challenge', 'nonce']) {
      final v = masked[key];
      if (v != null && v.length > 6) {
        masked[key] = '${v.substring(0, 4)}…(masked)';
      }
    }
    return url.replace(queryParameters: masked).toString();
  }

  static String _generateRandomString(int length) {
    const charset =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  static String _generateCodeChallenge(String verifier) {
    final bytes = ascii.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }

  static String _buildHtmlResponse({
    required bool success,
    required String title,
    required String message,
  }) {
    final color = success ? '#10b981' : '#f43f5e';
    final icon = success ? '&#10003;' : '&#10007;';

    return '''<!DOCTYPE html>
<html lang="id">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>MyMusic - $title</title>
  <style>
    * { box-sizing: border-box; }
    body {
      background-color: #0b0f14;
      color: #e2e8f0;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      display: flex;
      align-items: center;
      justify-content: center;
      height: 100vh;
      margin: 0;
      padding: 20px;
    }
    .card {
      background: #141b22;
      border: 1px solid rgba(255, 255, 255, 0.08);
      border-top: 3px solid $color;
      border-radius: 16px;
      padding: 36px 32px;
      text-align: center;
      max-width: 420px;
      width: 100%;
      box-shadow: 0 20px 40px rgba(0, 0, 0, 0.6);
    }
    .icon {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      width: 56px;
      height: 56px;
      border-radius: 50%;
      background: rgba(${success ? '16, 185, 129' : '244, 63, 94'}, 0.15);
      color: $color;
      font-size: 28px;
      margin-bottom: 20px;
    }
    h1 {
      margin: 0 0 12px;
      font-size: 20px;
      font-weight: 600;
      color: #f8fafc;
      letter-spacing: -0.02em;
    }
    p {
      color: #94a3b8;
      font-size: 14px;
      line-height: 1.6;
      margin: 0;
    }
    .footer {
      margin-top: 24px;
      padding-top: 16px;
      border-top: 1px solid rgba(255, 255, 255, 0.06);
      font-size: 12px;
      color: #64748b;
    }
  </style>
</head>
<body>
  <div class="card">
    <div class="icon">$icon</div>
    <h1>$title</h1>
    <p>$message</p>
    <div class="footer">MyMusic Obsidian Emerald Edition</div>
  </div>
  ${success ? '<script>setTimeout(function(){ window.close(); }, 3500);</script>' : ''}
</body>
</html>''';
  }
}
