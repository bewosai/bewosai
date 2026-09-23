import '../../data/models/staff_model.dart';

abstract class StaffRepository {
  Future<List<StaffMember>> list();
  Future<StaffMember> invite({required int businessId, required String name, String role, Map<String, dynamic>? permissions});
  Future<StaffMember> updateStaff(int businessId, int staffId, {String? role, Map<String, dynamic>? permissions, bool? isActive});
  Future<void> remove(int businessId, int staffId);
  Future<StaffMember> regenerateLink(int businessId, int staffId);
}
