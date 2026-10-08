import '../../domain/repositories/staff_repository.dart';
import '../models/staff_model.dart';
import '../services/staff_service.dart';

class StaffRepositoryImpl implements StaffRepository {
  final StaffService _service;
  StaffRepositoryImpl([StaffService? service]) : _service = service ?? StaffService();

  @override
  Future<List<StaffMember>> list() => _service.list();

  @override
  Future<StaffInvitation> invite({required int businessId, required String name, String role = 'SALESPERSON', String email = '', Map<String, dynamic>? permissions}) =>
      _service.invite(businessId: businessId, name: name, role: role, email: email, permissions: permissions);

  @override
  Future<List<StaffInvitation>> listInvitations(int businessId) => _service.listInvitations(businessId);

  @override
  Future<StaffInvitation> resendInvitation(int businessId, int invitationId) => _service.resendInvitation(businessId, invitationId);

  @override
  Future<void> cancelInvitation(int businessId, int invitationId) => _service.cancelInvitation(businessId, invitationId);

  @override
  Future<StaffMember> updateStaff(int businessId, int staffId, {String? role, Map<String, dynamic>? permissions, bool? isActive}) =>
      _service.updateStaff(businessId, staffId, role: role, permissions: permissions, isActive: isActive);

  @override
  Future<void> remove(int businessId, int staffId) => _service.remove(businessId, staffId);

  @override
  Future<StaffMember> regenerateLink(int businessId, int staffId) => _service.regenerateLink(businessId, staffId);
}
