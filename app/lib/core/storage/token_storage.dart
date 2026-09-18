import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';

/// Local cache of the auth session: JWT tokens (secure storage) plus the
/// logged-in user / business list / selected business (shared prefs, JSON
/// encoded) so the app can paint instantly on cold start before the network
/// round-trip in [AuthProvider.bootstrap] completes.
class TokenStorage {
  TokenStorage._internal();
  static final TokenStorage instance = TokenStorage._internal();

  final FlutterSecureStorage _secure = const FlutterSecureStorage();

  Future<bool> get isLoggedIn async => (await accessToken) != null;

  Future<String?> get accessToken => _secure.read(key: AppConstants.keyAccessToken);

  Future<String?> get refreshToken => _secure.read(key: AppConstants.keyRefreshToken);

  Future<void> saveTokens({required String access, required String refresh}) async {
    await _secure.write(key: AppConstants.keyAccessToken, value: access);
    await _secure.write(key: AppConstants.keyRefreshToken, value: refresh);
  }

  Future<void> saveAccessToken(String access) =>
      _secure.write(key: AppConstants.keyAccessToken, value: access);

  Future<void> saveRefreshToken(String refresh) =>
      _secure.write(key: AppConstants.keyRefreshToken, value: refresh);

  Future<Map<String, dynamic>?> get user async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(AppConstants.keyUser);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> saveUser(Map<String, dynamic> json) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keyUser, jsonEncode(json));
  }

  Future<List<dynamic>> get businesses async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(AppConstants.keyBusinesses);
    if (raw == null) return [];
    return jsonDecode(raw) as List<dynamic>;
  }

  Future<void> saveBusinesses(List<Map<String, dynamic>> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keyBusinesses, jsonEncode(list));
  }

  Future<Map<String, dynamic>?> get currentBusiness async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(AppConstants.keyCurrentBusiness);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> saveCurrentBusiness(Map<String, dynamic> json) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keyCurrentBusiness, jsonEncode(json));
  }

  Future<void> clearBusinessSelection() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.keyCurrentBusiness);
  }

  /// Full logout: wipes tokens and every cached value.
  Future<void> clear() async {
    await _secure.delete(key: AppConstants.keyAccessToken);
    await _secure.delete(key: AppConstants.keyRefreshToken);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.keyUser);
    await prefs.remove(AppConstants.keyBusinesses);
    await prefs.remove(AppConstants.keyCurrentBusiness);
  }
}
