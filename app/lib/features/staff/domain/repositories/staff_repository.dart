import '../../data/models/staff_model.dart';

abstract class StaffRepository {
  Future<List<StaffMember>> list();
  Future<StaffInvitation> invite({required int businessId, required String name, String role, String email, Map<String, dynamic>? permissions});
  Future<List<StaffInvitation>> listInvitations(int businessId);
  Future<StaffInvitation> resendInvitation(int businessId, int invitationId);
  Future<void> cancelInvitation(int businessId, int invitationId);
  Future<StaffMember> updateStaff(int businessId, int staffId, {String? role, Map<String, dynamic>? permissions, bool? isActive});
  Future<void> remove(int businessId, int staffId);
  Future<StaffMember> regenerateLink(int businessId, int staffId);
}
