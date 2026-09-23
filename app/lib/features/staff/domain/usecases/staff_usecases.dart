import '../../data/models/staff_model.dart';
import '../../data/repositories/staff_repository_impl.dart';
import '../../data/services/staff_service.dart' show defaultPermissionsFor;
import '../repositories/staff_repository.dart';

class StaffUseCases {
  final StaffRepository _repository;
  StaffUseCases([StaffRepository? repository]) : _repository = repository ?? StaffRepositoryImpl();

  Future<List<StaffMember>> listStaff() => _repository.list();

  Future<StaffMember> inviteStaff({required int businessId, required String name, String role = 'CASHIER', Map<String, dynamic>? permissions}) =>
      _repository.invite(businessId: businessId, name: name, role: role, permissions: permissions);

  // The role and its permission matrix have to change together: the backend
  // enforces the stored matrix (not the role label), so sending only the role
  // would leave e.g. a promoted Cashier still restricted like a Cashier.
  Future<StaffMember> updateRole(int businessId, int staffId, String role) =>
      _repository.updateStaff(businessId, staffId, role: role, permissions: defaultPermissionsFor(role));

  /// Saves exactly which features this person may use, leaving their role as is.
  Future<StaffMember> updatePermissions(int businessId, int staffId, Map<String, dynamic> permissions) =>
      _repository.updateStaff(businessId, staffId, permissions: permissions);

  Future<StaffMember> setActive(int businessId, int staffId, bool active) =>
      _repository.updateStaff(businessId, staffId, isActive: active);

  Future<void> removeStaff(int businessId, int staffId) => _repository.remove(businessId, staffId);

  Future<StaffMember> regenerateLink(int businessId, int staffId) => _repository.regenerateLink(businessId, staffId);
}
