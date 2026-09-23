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

  // Set on a successful invite so the UI can immediately hand over the new
  // staff member's login link (they have no email/phone to send it to any
  // other way) — cleared the next time an invite starts.
  StaffMember? lastInvited;

  Future<bool> invite({
    required int businessId,
    required String name,
    String role = 'CASHIER',
    Map<String, dynamic>? permissions,
  }) =>
      _guard(() async {
        lastInvited = null;
        final created = await _useCases.inviteStaff(businessId: businessId, name: name, role: role, permissions: permissions);
        staff = [...staff, created];
        lastInvited = created;
        return true;
      });

  Future<bool> regenerateLink(int businessId, int staffId) => _guard(() async {
        final updated = await _useCases.regenerateLink(businessId, staffId);
        staff = staff.map((s) => s.id == staffId ? updated : s).toList();
        lastInvited = updated;
        return true;
      });

  Future<bool> updateRole(int businessId, int staffId, String role) => _guard(() async {
        final updated = await _useCases.updateRole(businessId, staffId, role);
        staff = staff.map((s) => s.id == staffId ? updated : s).toList();
        return true;
      });

  Future<bool> updatePermissions(int businessId, int staffId, Map<String, dynamic> permissions) => _guard(() async {
        final updated = await _useCases.updatePermissions(businessId, staffId, permissions);
        staff = staff.map((s) => s.id == staffId ? updated : s).toList();
        return true;
      });

  Future<bool> setActive(int businessId, int staffId, bool active) => _guard(() async {
        final updated = await _useCases.setActive(businessId, staffId, active);
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
