import 'package:flutter/material.dart';
import '../../../../core/network/api_client.dart';
import '../../data/models/staff_model.dart';
import '../../domain/usecases/staff_usecases.dart';

class StaffProvider extends ChangeNotifier {
  final _useCases = StaffUseCases();

  List<StaffMember> staff = [];
  bool isLoading = false;
  String? error;

  Future<void> load() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      staff = await _useCases.listStaff();
    } catch (e) {
      error = e is ApiException ? e.message : e.toString();
    }
    isLoading = false;
    notifyListeners();
  }

  Future<bool> invite({required String email, String name = '', String role = 'CASHIER'}) => _guard(() async {
        final created = await _useCases.inviteStaff(email: email, name: name, role: role);
        staff = [...staff, created];
        return true;
      });

  Future<bool> updateRole(int businessId, int staffId, String role) => _guard(() async {
        final updated = await _useCases.updateRole(businessId, staffId, role);
        staff = staff.map((s) => s.id == staffId ? updated : s).toList();
        return true;
      });

  Future<bool> remove(int businessId, int staffId) => _guard(() async {
        await _useCases.removeStaff(businessId, staffId);
        staff = staff.where((s) => s.id != staffId).toList();
        return true;
      });

  Future<bool> _guard(Future<bool> Function() action) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final result = await action();
      isLoading = false;
      notifyListeners();
      return result;
    } catch (e) {
      isLoading = false;
      error = e is ApiException ? e.message : e.toString();
      notifyListeners();
      return false;
    }
  }
}
