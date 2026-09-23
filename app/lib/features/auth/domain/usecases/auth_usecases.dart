import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../data/services/auth_service.dart';
import '../repositories/auth_repository.dart';

class AuthUseCases {
  final AuthRepository _repository;
  AuthUseCases([AuthRepository? repository]) : _repository = repository ?? AuthRepositoryImpl();

  Future<OtpResult> sendOtp(String identifier, {bool isSignup = false}) => _repository.sendOtp(identifier, isSignup: isSignup);

  Future<VerifyOtpResult> verifyOtp(String identifier, String code, {bool remember = false, String name = ''}) =>
      _repository.verifyOtp(identifier, code, remember: remember, name: name);

  Future<VerifyOtpResult> googleLogin(String idToken, {bool remember = false}) =>
      _repository.googleLogin(idToken, remember: remember);

  Future<VerifyOtpResult> staffLogin(String token) => _repository.staffLogin(token);

  Future<void> setAccountType(String accountType) => _repository.setAccountType(accountType);

  Future<void> logout(String? refresh) => _repository.logout(refresh);

  Future<AppUser> getMe() => _repository.getMe();

  Future<AppUser> updateProfile({String? name, String? phone}) => _repository.updateMe(name: name, phone: phone);
}
