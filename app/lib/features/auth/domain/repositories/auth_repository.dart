import '../../data/models/business_model.dart';
import '../../data/models/user_model.dart';
import '../../data/services/auth_service.dart';

abstract class AuthRepository {
  Future<OtpResult> sendOtp(String email, {bool isSignup});
  Future<VerifyOtpResult> verifyOtp(String email, String code, {bool remember, String name});
  Future<void> setAccountType(String accountType);
  Future<void> logout(String? refresh);
  Future<AppUser> getMe();
  Future<AppUser> updateMe({String? name, String? phone});
  Future<List<Business>> myBusinesses();
  Future<Business> createBusiness(Business business);
  Future<Business> updateBusiness(int id, Map<String, dynamic> fields);
  Future<void> deleteBusiness(int id);
  Future<Business> closeFiscalYear(int id);
}
