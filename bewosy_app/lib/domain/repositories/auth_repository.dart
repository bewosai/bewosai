// Abstract contract — the data layer implements this
abstract class AuthRepository {
  Future<Map<String, dynamic>> sendOtp(String email, {bool isSignup = false});
  Future<Map<String, dynamic>> verifyOtp(String email, String code, {bool remember});
  Future<Map<String, dynamic>> setAccountType(String accountType);
  Future<void> logout(String? refreshToken);
}
