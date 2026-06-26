// Business logic lives here, not in the presentation layer
import '../repositories/auth_repository.dart';

class SendOtpUseCase {
  final AuthRepository _repo;
  SendOtpUseCase(this._repo);

  Future<Map<String, dynamic>> call(String email) => _repo.sendOtp(email);
}

class VerifyOtpUseCase {
  final AuthRepository _repo;
  VerifyOtpUseCase(this._repo);

  Future<Map<String, dynamic>> call(
    String email,
    String code, {
    bool remember = false,
  }) =>
      _repo.verifyOtp(email, code, remember: remember);
}

class SetAccountTypeUseCase {
  final AuthRepository _repo;
  SetAccountTypeUseCase(this._repo);

  Future<Map<String, dynamic>> call(String accountType) =>
      _repo.setAccountType(accountType);
}

class LogoutUseCase {
  final AuthRepository _repo;
  LogoutUseCase(this._repo);

  Future<void> call(String? refreshToken) => _repo.logout(refreshToken);
}
