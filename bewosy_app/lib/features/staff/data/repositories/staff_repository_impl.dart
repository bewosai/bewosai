import '../../domain/repositories/staff_repository.dart';
import '../models/staff_model.dart';
import '../services/staff_service.dart';

class StaffRepositoryImpl implements StaffRepository {
  final StaffService _service;
  StaffRepositoryImpl([StaffService? service]) : _service = service ?? StaffService();

  @override
  Future<List<StaffMember>> list() => _service.list();

  @override
  Future<StaffMember> invite({required String email, String name = '', String role = 'CASHIER'}) =>
      _service.invite(email: email, name: name, role: role);

  @override
  Future<StaffMember> updateStaff(int businessId, int staffId, {String? role, Map<String, dynamic>? permissions, bool? isActive}) =>
      _service.updateStaff(businessId, staffId, role: role, permissions: permissions, isActive: isActive);

  @override
  Future<void> remove(int businessId, int staffId) => _service.remove(businessId, staffId);
}
