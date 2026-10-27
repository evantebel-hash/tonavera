import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/config/api_config.dart';

class ApiService {
  static const String _tokenKey = 'jwt_auth_token';
  static const String _userKey = 'cached_user_profile';

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  static Future<void> saveCachedUser(Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, json.encode(userData));
  }

  static Future<Map<String, dynamic>?> getCachedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_userKey);
    if (str != null && str.isNotEmpty) {
      try {
        return json.decode(str) as Map<String, dynamic>;
      } catch (_) {}
    }
    return null;
  }

  static Future<void> clearCachedUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
  }

  static Future<Map<String, String>> _getHeaders() async {
    final token = await getToken();
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static Future<Map<String, dynamic>> get(String endpoint) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/$endpoint');
      final headers = await _getHeaders();

      final response = await http
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 5));
      return _parseResponse(response);
    } catch (e) {
      return _handleNetworkError(e);
    }
  }

  static Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/$endpoint');
      final headers = await _getHeaders();

      final response = await http
          .post(url, headers: headers, body: json.encode(body))
          .timeout(const Duration(seconds: 5));
      return _parseResponse(response);
    } catch (e) {
      return _handleNetworkError(e);
    }
  }

  static Future<Map<String, dynamic>> put(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/$endpoint');
      final headers = await _getHeaders();

      final response = await http
          .put(url, headers: headers, body: json.encode(body))
          .timeout(const Duration(seconds: 5));
      return _parseResponse(response);
    } catch (e) {
      return _handleNetworkError(e);
    }
  }

  static Future<Map<String, dynamic>> delete(String endpoint) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/$endpoint');
      final headers = await _getHeaders();

      final response = await http
          .delete(url, headers: headers)
          .timeout(const Duration(seconds: 5));
      return _parseResponse(response);
    } catch (e) {
      return _handleNetworkError(e);
    }
  }

  static Map<String, dynamic> _handleNetworkError(dynamic error) {
    return {
      'status': false,
      'message':
          'Server authentication tidak dapat dijangkau. Anda tetap dapat menggunakan Local Music Library secara offline.',
      'data': null,
    };
  }

  static Map<String, dynamic> _parseResponse(http.Response response) {
    try {
      final decoded = json.decode(response.body);
      if (decoded is Map<String, dynamic>) {
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return decoded;
        } else {
          return {
            'status': false,
            'message':
                decoded['message'] ??
                'Terjadi kesalahan pada server (${response.statusCode})',
            'data': decoded['data'],
          };
        }
      }
      return {
        'status': false,
        'message': 'Format response tidak valid (${response.statusCode})',
        'data': null,
      };
    } catch (e) {
      return {
        'status': false,
        'message': 'Gagal memproses data server: $e',
        'data': null,
      };
    }
  }
}
