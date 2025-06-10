import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  // Singleton setup
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal() {
    _startAutoRefresh();
  }

  static Timer? _refreshTimer;

  static const String kcUrl = 'https://id.tif.uin-suska.ac.id';
  static const String tokenUrl = '$kcUrl/realms/dev/protocol/openid-connect/token';
  static const String clientId = 'setoran-mobile-dev';
  static const String clientSecret = 'aqJp3xnXKudgC7RMOshEQP7ZoVKWzoSl';
  static const String scope = 'openid email roles profile';
  static const String baseUrl = 'https://api.tif.uin-suska.ac.id/setoran-dev/v1';

  Future<bool> login(String username, String password) async {
    try {
      await logout();

      final response = await http.post(
        Uri.parse(tokenUrl),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'client_id': clientId,
          'client_secret': clientSecret,
          'grant_type': 'password',
          'username': username,
          'password': password,
          'scope': scope,
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', data['access_token']);
        await prefs.setString('refresh_token', data['refresh_token']);
        await prefs.setInt('token_time_millis', DateTime.now().millisecondsSinceEpoch);
        print('Login berhasil, token disimpan.');
        return true;
      } else {
        print('Login gagal: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('Login error: $e');
      return false;
    }
  }

  Future<bool> refreshToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final refreshToken = prefs.getString('refresh_token');
      if (refreshToken == null) {
        print('Refresh token tidak ditemukan.');
        return false;
      }

      final response = await http.post(
        Uri.parse(tokenUrl),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'client_id': clientId,
          'client_secret': clientSecret,
          'grant_type': 'refresh_token',
          'refresh_token': refreshToken,
          'scope': scope,
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        await prefs.setString('access_token', data['access_token']);
        await prefs.setString('refresh_token', data['refresh_token']);
        await prefs.setInt('token_time_millis', DateTime.now().millisecondsSinceEpoch);
        print('Refresh token berhasil.');
        return true;
      } else {
        print('Refresh token gagal: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error saat refresh token: $e');
      return false;
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    await prefs.remove('token_time_millis');
    print('Logout, data token dihapus.');
  }

  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('access_token');
    final tokenTime = prefs.getInt('token_time_millis');

    if (accessToken == null || tokenTime == null) {
      return null;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final elapsed = now - tokenTime;

    if (elapsed > 780000) { // >13 menit
      print('Token lebih dari 13 menit, mencoba refresh...');
      final refreshed = await refreshToken();
      if (!refreshed) {
        print('[ERROR] Refresh token gagal, logout dan hapus token.');
        await logout(); // <-- Tambahan: logout otomatis
        return null;
      }
      return prefs.getString('access_token');
    }

    return accessToken;
  }


  Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('refresh_token');
  }

  Future<bool> postSetoranMahasiswa({
    required String nim,
    required Map<String, dynamic> dataSetoran,
  }) async {
    final token = await getAccessToken();

    if (token == null) {
      print('Token tidak ditemukan, login terlebih dahulu.');
      return false;
    }

    if (dataSetoran['data_setoran'] == null || (dataSetoran['data_setoran'] as List).isEmpty) {
      print('Data setoran tidak lengkap: data_setoran kosong.');
      return false;
    }

    if (dataSetoran['tgl_setoran'] == null || dataSetoran['tgl_setoran'].toString().isEmpty) {
      print('Data setoran tidak lengkap: tgl_setoran kosong.');
      return false;
    }

    final url = Uri.parse('$baseUrl/mahasiswa/setoran/$nim');

    try {
      print('Payload JSON: ${jsonEncode(dataSetoran)}');

      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(dataSetoran),
      );

      print('Status code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('Setoran berhasil dikirim.');
        return true;
      } else {
        final responseBody = jsonDecode(response.body);
        print('Gagal mengirim setoran: ${response.statusCode}');
        print('Pesan error: ${responseBody['message'] ?? response.body}');
        return false;
      }
    } catch (e) {
      print('Error saat mengirim setoran: $e');
      return false;
    }
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(minutes: 13), (_) async {
      print('[Auto Refresh] Mengecek dan me-refresh token...');
      final success = await refreshToken();
      if (!success) {
        print('[Auto Refresh] Refresh token gagal. Token mungkin sudah tidak valid.');
      }
    });
  }
}
