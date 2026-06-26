import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user_model.dart';
import '../models/business_model.dart';
import '../services/api_service.dart';
import '../../core/constants/app_constants.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _api;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  UserModel? _user;
  List<BusinessModel> _businesses = [];
  BusinessModel? _currentBusiness;
  bool _loading = false;
  String? _error;

  AuthProvider(this._api);

  UserModel? get user => _user;
  List<BusinessModel> get businesses => _businesses;
  BusinessModel? get currentBusiness => _currentBusiness;
  bool get loading => _loading;
  String? get error => _error;
  bool get isLoggedIn => _user != null;
  bool get needsBusinessSetup =>
      _user != null &&
      _businesses.isEmpty &&
      _user!.accountType == 'business';

  Future<void> loadFromStorage() async {
    try {
      final userJson = await _storage.read(key: AppConstants.keyUser);
      final bizJson =
          await _storage.read(key: AppConstants.keyCurrentBusiness);
      if (userJson != null) {
        _user = UserModel.fromJson(jsonDecode(userJson));
      }
      if (bizJson != null) {
        _currentBusiness = BusinessModel.fromJson(jsonDecode(bizJson));
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<Map<String, dynamic>> sendOtp(String email) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final res =
          await _api.post('/auth/send-otp/', data: {'email': email});
      return {
        'ok': true,
        'user_exists': res.data['user_exists'] ?? false,
        'otp': res.data['otp'],
      };
    } catch (e) {
      _error = _parseError(e);
      return {'ok': false, 'error': _error};
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> verifyOtp(
    String email,
    String code, {
    bool remember = false,
  }) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final res = await _api.post('/auth/verify-otp/', data: {
        'email': email,
        'code': code,
        'remember': remember,
      });
      final data = res.data;
      await _storage.write(
          key: AppConstants.keyAccessToken, value: data['access']);
      await _storage.write(
          key: AppConstants.keyRefreshToken, value: data['refresh']);
      _user = UserModel.fromJson(data['user']);
      await _storage.write(
          key: AppConstants.keyUser, value: jsonEncode(_user!.toJson()));

      _businesses = (data['businesses'] as List? ?? [])
          .map((b) => BusinessModel.fromJson(b))
          .toList();

      if (_businesses.length == 1) {
        await selectBusiness(_businesses.first);
      }

      return {
        'ok': true,
        'is_new': data['is_new_user'] ?? false,
        'needs_profile': data['needs_profile_setup'] ?? false,
        'account_type': _user!.accountType,
        'businesses': _businesses,
      };
    } catch (e) {
      _error = _parseError(e);
      return {'ok': false, 'error': _error};
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> setAccountType(String accountType) async {
    _loading = true;
    notifyListeners();
    try {
      final res = await _api.post('/auth/set-account-type/',
          data: {'account_type': accountType});
      final data = res.data;
      _user = UserModel.fromJson(data['user']);
      await _storage.write(
          key: AppConstants.keyUser, value: jsonEncode(_user!.toJson()));
      _businesses = (data['businesses'] as List? ?? [])
          .map((b) => BusinessModel.fromJson(b))
          .toList();
      if (_businesses.length == 1) await selectBusiness(_businesses.first);
      return {'ok': true, 'account_type': _user!.accountType};
    } catch (e) {
      return {'ok': false, 'error': _parseError(e)};
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> selectBusiness(BusinessModel biz) async {
    _currentBusiness = biz;
    await _storage.write(
        key: AppConstants.keyCurrentBusiness,
        value: jsonEncode(biz.toJson()));
    await _storage.write(
        key: AppConstants.keyBusinessId, value: biz.id.toString());
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      final refresh =
          await _storage.read(key: AppConstants.keyRefreshToken);
      if (refresh != null) {
        await _api.post('/auth/logout/', data: {'refresh': refresh});
      }
    } catch (_) {}
    await _storage.deleteAll();
    _user = null;
    _businesses = [];
    _currentBusiness = null;
    notifyListeners();
  }

  String _parseError(dynamic e) {
    try {
      if (e is Exception) return e.toString().replaceAll('Exception: ', '');
      return 'An error occurred. Please try again.';
    } catch (_) {
      return 'An error occurred.';
    }
  }
}
