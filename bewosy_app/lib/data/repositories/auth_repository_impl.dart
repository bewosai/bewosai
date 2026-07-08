// Implements the domain contract using ApiService + SecureStorage
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/constants/app_constants.dart';
import '../../domain/repositories/auth_repository.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';

class AuthRepositoryImpl implements AuthRepository {
  final ApiService _api;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  AuthRepositoryImpl(this._api);

  @override
  Future<Map<String, dynamic>> sendOtp(String email, {bool isSignup = false}) async {
    final res = await _api.post('/auth/send-otp/', data: {
      'email': email,
      'is_signup': isSignup,
    });
    return Map<String, dynamic>.from(res.data as Map);
  }

  @override
  Future<Map<String, dynamic>> verifyOtp(
    String email,
    String code, {
    bool remember = false,
  }) async {
    final res = await _api.post('/auth/verify-otp/', data: {
      'email': email,
      'code': code,
      'remember': remember,
    });
    final data = Map<String, dynamic>.from(res.data as Map);

    // Persist tokens
    await _storage.write(
        key: AppConstants.keyAccessToken, value: data['access'] as String?);
    await _storage.write(
        key: AppConstants.keyRefreshToken, value: data['refresh'] as String?);

    final user = UserModel.fromJson(
        Map<String, dynamic>.from(data['user'] as Map));
    await _storage.write(
        key: AppConstants.keyUser, value: jsonEncode(user.toJson()));

    return data;
  }

  @override
  Future<Map<String, dynamic>> setAccountType(String accountType) async {
    final res = await _api.post('/auth/set-account-type/',
        data: {'account_type': accountType});
    return Map<String, dynamic>.from(res.data as Map);
  }

  @override
  Future<void> logout(String? refreshToken) async {
    if (refreshToken != null) {
      try {
        await _api.post('/auth/logout/', data: {'refresh': refreshToken});
      } catch (_) {}
    }
    await _storage.deleteAll();
  }
}
