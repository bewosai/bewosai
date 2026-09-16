import '../../data/models/staff_model.dart';
import '../../data/repositories/staff_repository_impl.dart';
import '../repositories/staff_repository.dart';

class StaffUseCases {
  final StaffRepository _repository;
  StaffUseCases([StaffRepository? repository]) : _repository = repository ?? StaffRepositoryImpl();

  Future<List<StaffMember>> listStaff() => _repository.list();

  Future<StaffMember> inviteStaff({required int businessId, required String name, String role = 'CASHIER'}) =>
      _repository.invite(businessId: businessId, name: name, role: role);

  Future<StaffMember> updateRole(int businessId, int staffId, String role) =>
      _repository.updateStaff(businessId, staffId, role: role);

  Future<void> removeStaff(int businessId, int staffId) => _repository.remove(businessId, staffId);

  Future<StaffMember> regenerateLink(int businessId, int staffId) => _repository.regenerateLink(businessId, staffId);
}
