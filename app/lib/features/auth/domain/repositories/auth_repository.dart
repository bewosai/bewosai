import 'dart:io';

import '../../data/models/business_model.dart';
import '../../data/models/fiscal_year_model.dart';
import '../../data/models/user_model.dart';
import '../../data/services/auth_service.dart';

abstract class AuthRepository {
  Future<OtpResult> sendOtp(String email, {bool isSignup});
  Future<VerifyOtpResult> verifyOtp(String email, String code, {bool remember, String name});
  Future<VerifyOtpResult> googleLogin(String idToken, {bool remember});
  Future<VerifyOtpResult> staffLogin(String token);
  Future<void> setAccountType(String accountType);
  Future<void> logout(String? refresh);
  Future<AppUser> getMe();
  Future<AppUser> updateMe({String? name, String? phone});
  Future<List<Business>> myBusinesses();
  Future<Business> createBusiness(Business business, {String? referralCode});
  Future<Business> updateBusiness(int id, Map<String, dynamic> fields, {File? logo});
  Future<void> deleteBusiness(int id);
  Future<String> closeFiscalYear(int id);
  Future<List<FiscalYear>> fiscalYears(int id);
}
