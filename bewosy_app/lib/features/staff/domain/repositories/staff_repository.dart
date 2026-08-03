import '../../data/models/staff_model.dart';

abstract class StaffRepository {
  Future<List<StaffMember>> list();
  Future<StaffMember> invite({required String email, String name, String role});
  Future<StaffMember> updateStaff(int businessId, int staffId, {String? role, Map<String, dynamic>? permissions, bool? isActive});
  Future<void> remove(int businessId, int staffId);
}
