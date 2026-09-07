import 'dart:io';

import '../../domain/repositories/auth_repository.dart';
import '../models/business_model.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthService _service;
  AuthRepositoryImpl([AuthService? service]) : _service = service ?? AuthService();

  @override
  Future<OtpResult> sendOtp(String email, {bool isSignup = false}) =>
      _service.sendOtp(email, isSignup: isSignup);

  @override
  Future<VerifyOtpResult> verifyOtp(String email, String code, {bool remember = false, String name = ''}) =>
      _service.verifyOtp(email, code, remember: remember, name: name);

  @override
  Future<VerifyOtpResult> googleLogin(String idToken, {bool remember = false}) =>
      _service.googleLogin(idToken, remember: remember);

  @override
  Future<void> setAccountType(String accountType) => _service.setAccountType(accountType);

  @override
  Future<void> logout(String? refresh) => _service.logout(refresh);

  @override
  Future<AppUser> getMe() => _service.me();

  @override
  Future<AppUser> updateMe({String? name, String? phone}) => _service.updateMe(name: name, phone: phone);

  @override
  Future<List<Business>> myBusinesses() => _service.myBusinesses();

  @override
  Future<Business> createBusiness(Business business, {String? referralCode}) =>
      _service.createBusiness(business, referralCode: referralCode);

  @override
  Future<Business> updateBusiness(int id, Map<String, dynamic> fields, {File? logo}) =>
      _service.updateBusiness(id, fields, logo: logo);

  @override
  Future<void> deleteBusiness(int id) => _service.deleteBusiness(id);

  @override
  Future<Business> closeFiscalYear(int id) => _service.closeFiscalYear(id);
}
