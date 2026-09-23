import '../../domain/repositories/staff_repository.dart';
import '../models/staff_model.dart';
import '../services/staff_service.dart';

class StaffRepositoryImpl implements StaffRepository {
  final StaffService _service;
  StaffRepositoryImpl([StaffService? service]) : _service = service ?? StaffService();

  @override
  Future<List<StaffMember>> list() => _service.list();

  @override
  Future<StaffMember> invite({required int businessId, required String name, String role = 'CASHIER', Map<String, dynamic>? permissions}) =>
      _service.invite(businessId: businessId, name: name, role: role, permissions: permissions);

  @override
  Future<StaffMember> updateStaff(int businessId, int staffId, {String? role, Map<String, dynamic>? permissions, bool? isActive}) =>
      _service.updateStaff(businessId, staffId, role: role, permissions: permissions, isActive: isActive);

  @override
  Future<void> remove(int businessId, int staffId) => _service.remove(businessId, staffId);

  @override
  Future<StaffMember> regenerateLink(int businessId, int staffId) => _service.regenerateLink(businessId, staffId);
}
