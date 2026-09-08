import 'dart:io';

import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../models/business_model.dart';
import '../models/fiscal_year_model.dart';
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

  /// [identifier] is an email or (for an existing account with a phone on
  /// file) a phone number — the backend resolves either to wherever the
  /// account's OTP actually gets sent (email only, until an SMS provider is
  /// wired up server-side).
  Future<OtpResult> sendOtp(String identifier, {bool isSignup = false}) async {
    try {
      final res = await _dio.post('/auth/send-otp/', data: {
        'identifier': identifier,
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

  Future<VerifyOtpResult> verifyOtp(String identifier, String code, {bool remember = false, String name = ''}) async {
    try {
      final res = await _dio.post('/auth/verify-otp/', data: {
        'identifier': identifier,
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

  Future<Business> createBusiness(Business business, {String? referralCode}) async {
    try {
      final data = business.toJson();
      if (referralCode != null && referralCode.trim().isNotEmpty) {
        data['referral_code'] = referralCode.trim().toUpperCase();
      }
      final res = await _dio.post('/auth/businesses/', data: data);
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

  /// Closes business [id]'s current fiscal year in place — the business,
  /// and every record in it, stays exactly where it is; only that date
  /// range becomes read-only server-side. Returns the closed period's
  /// label (e.g. "2082/83") for the confirmation message.
  Future<String> closeFiscalYear(int id) async {
    try {
      final res = await _dio.post('/auth/businesses/$id/close-fiscal-year/');
      return (res.data['fiscal_year']?['label'] as String?) ?? '';
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  /// Past closed fiscal years for business [id] — read-only, shown in
  /// Settings so a closed year stays visible even though it's no longer
  /// editable.
  Future<List<FiscalYear>> fiscalYears(int id) async {
    try {
      final res = await _dio.get('/auth/businesses/$id/fiscal-years/');
      final data = res.data;
      final results = data is Map ? (data['results'] as List? ?? []) : (data as List);
      return results.map((e) => FiscalYear.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }
}
