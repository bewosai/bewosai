// Presentation layer — coordinates usecases, manages UI state
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/user_model.dart';
import '../../data/models/business_model.dart';
import '../../data/services/api_service.dart';
import '../../domain/usecases/auth_usecases.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthProvider extends ChangeNotifier {
  final AuthRepository _repo;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // Use-cases
  late final SendOtpUseCase _sendOtpUc;
  late final VerifyOtpUseCase _verifyOtpUc;
  late final SetAccountTypeUseCase _setAccountTypeUc;
  late final LogoutUseCase _logoutUc;

  UserModel? _user;
  List<BusinessModel> _businesses = [];
  BusinessModel? _currentBusiness;
  bool _loading = false;
  String? _error;

  AuthProvider(this._repo) {
    _sendOtpUc = SendOtpUseCase(_repo);
    _verifyOtpUc = VerifyOtpUseCase(_repo);
    _setAccountTypeUc = SetAccountTypeUseCase(_repo);
    _logoutUc = LogoutUseCase(_repo);
  }

  UserModel? get user => _user;
  List<BusinessModel> get businesses => _businesses;
  BusinessModel? get currentBusiness => _currentBusiness;
  bool get loading => _loading;
  String? get error => _error;
  bool get isLoggedIn => _user != null;

  Future<void> loadFromStorage() async {
    try {
      final userJson = await _storage.read(key: AppConstants.keyUser);
      final bizJson =
          await _storage.read(key: AppConstants.keyCurrentBusiness);
      if (userJson != null) {
        _user = UserModel.fromJson(
            Map<String, dynamic>.from(jsonDecode(userJson) as Map));
      }
      if (bizJson != null) {
        _currentBusiness = BusinessModel.fromJson(
            Map<String, dynamic>.from(jsonDecode(bizJson) as Map));
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<Map<String, dynamic>> sendOtp(String email, {bool isSignup = false}) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final result = await _sendOtpUc(email, isSignup: isSignup);
      return {'ok': true, ...result};
    } catch (e) {
      _error = _parseError(e);
      bool userExists = false;
      if (e is DioException && e.response?.data is Map) {
        userExists = (e.response!.data['user_exists'] ?? false) == true;
      }
      return {'ok': false, 'error': _error, 'user_exists': userExists};
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
      final data = await _verifyOtpUc(email, code, remember: remember);

      _user = UserModel.fromJson(
          Map<String, dynamic>.from(data['user'] as Map));
      await _storage.write(
          key: AppConstants.keyUser, value: jsonEncode(_user!.toJson()));

      _businesses = (data['businesses'] as List? ?? [])
          .map((b) => BusinessModel.fromJson(
              Map<String, dynamic>.from(b as Map)))
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
      final data = await _setAccountTypeUc(accountType);
      _user = UserModel.fromJson(
          Map<String, dynamic>.from(data['user'] as Map));
      await _storage.write(
          key: AppConstants.keyUser, value: jsonEncode(_user!.toJson()));
      _businesses = (data['businesses'] as List? ?? [])
          .map((b) => BusinessModel.fromJson(
              Map<String, dynamic>.from(b as Map)))
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
    final refresh = await _storage.read(key: AppConstants.keyRefreshToken);
    await _logoutUc(refresh);
    _user = null;
    _businesses = [];
    _currentBusiness = null;
    notifyListeners();
  }

  String _parseError(dynamic e) => ApiService.errorMessage(e);
}
