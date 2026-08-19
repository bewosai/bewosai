import 'dart:io';

import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../models/business_model.dart';
import '../models/user_model.dart';

class OtpResult {
  final bool success;
  final String message;
  final bool userExists;
  OtpResult({required this.success, required this.message, this.userExists = false});
}

class VerifyOtpResult {
  final String access;
  final String refresh;
  final AppUser user;
  final bool isNewUser;
  final bool needsProfileSetup;
  final List<Business> businesses;

  VerifyOtpResult({
    required this.access,
    required this.refresh,
    required this.user,
    required this.isNewUser,
    required this.needsProfileSetup,
    required this.businesses,
  });
}

class AuthService {
  final _dio = ApiClient.instance.dio;

  Future<OtpResult> sendOtp(String email, {bool isSignup = false}) async {
    try {
      final res = await _dio.post('/auth/send-otp/', data: {
        'email': email,
        'is_signup': isSignup,
      });
      return OtpResult(
        success: res.data['success'] as bool? ?? true,
        message: res.data['message'] as String? ?? 'OTP sent',
        userExists: res.data['user_exists'] as bool? ?? false,
      );
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<VerifyOtpResult> verifyOtp(String email, String code, {bool remember = false, String name = ''}) async {
    try {
      final res = await _dio.post('/auth/verify-otp/', data: {
        'email': email,
        'code': code,
        'remember': remember,
        if (name.isNotEmpty) 'name': name,
      });
      return _verifyOtpResultFromResponse(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<VerifyOtpResult> googleLogin(String idToken, {bool remember = false}) async {
    try {
      final res = await _dio.post('/auth/google-login/', data: {
        'id_token': idToken,
        'remember': remember,
      });
      return _verifyOtpResultFromResponse(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  VerifyOtpResult _verifyOtpResultFromResponse(Map<String, dynamic> data) {
    return VerifyOtpResult(
      access: data['access'] as String,
      refresh: data['refresh'] as String,
      user: AppUser.fromJson(data['user'] as Map<String, dynamic>),
      isNewUser: data['is_new_user'] as bool? ?? false,
      needsProfileSetup: data['needs_profile_setup'] as bool? ?? false,
      businesses: (data['businesses'] as List? ?? [])
          .map((e) => Business.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<void> setAccountType(String accountType) async {
    try {
      await _dio.post('/auth/set-account-type/', data: {'account_type': accountType});
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<void> logout(String? refresh) async {
    try {
      if (refresh != null) {
        await _dio.post('/auth/logout/', data: {'refresh': refresh});
      }
    } catch (_) {
      // best-effort
    }
  }

  Future<AppUser> me() async {
    try {
      final res = await _dio.get('/auth/me/');
      return AppUser.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<AppUser> updateMe({String? name, String? phone}) async {
    try {
      final res = await _dio.patch('/auth/me/', data: {
        'name': ?name,
        'phone': ?phone,
      });
      return AppUser.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<List<Business>> myBusinesses() async {
    try {
      final res = await _dio.get('/auth/businesses/', queryParameters: {'page_size': 100});
      final data = res.data;
      final results = data is Map ? (data['results'] as List? ?? []) : (data as List);
      return results.map((e) => Business.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<Business> createBusiness(Business business) async {
    try {
      final res = await _dio.post('/auth/businesses/', data: business.toJson());
      return Business.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<Business> updateBusiness(int id, Map<String, dynamic> fields, {File? logo}) async {
    try {
      final Response res;
      if (logo == null) {
        res = await _dio.patch('/auth/businesses/$id/', data: fields);
      } else {
        final map = <String, dynamic>{...fields};
        map['logo'] = await MultipartFile.fromFile(
          logo.path,
          filename: logo.path.split(RegExp(r'[/\\]')).last,
        );
        res = await _dio.patch('/auth/businesses/$id/', data: FormData.fromMap(map));
      }
      return Business.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<void> deleteBusiness(int id) async {
    try {
      await _dio.delete('/auth/businesses/$id/');
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  /// Archives [id] and returns the freshly created replacement business, with
  /// the old business's total bank/cash balance carried forward as its opening balance.
  Future<Business> closeFiscalYear(int id) async {
    try {
      final res = await _dio.post('/auth/businesses/$id/close-fiscal-year/');
      return Business.fromJson(res.data['new_business'] as Map<String, dynamic>);
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }
}
