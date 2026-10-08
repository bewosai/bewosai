import 'package:flutter/material.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/token_storage.dart';
import '../../data/models/staff_model.dart';
import '../../domain/usecases/staff_usecases.dart';

class StaffProvider extends ChangeNotifier {
  final _useCases = StaffUseCases();

  List<StaffMember> staff = [];
  /// Invitations still waiting for the person to verify their email and accept.
  List<StaffInvitation> invitations = [];
  bool isLoading = false;
  String? error;

  Future<int?> _businessId() async {
    final business = await TokenStorage.instance.currentBusiness;
    final id = business?['id'];
    return id is int ? id : int.tryParse('${id ?? ''}');
  }

  Future<void> load() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final businessId = await _businessId();
      final results = await Future.wait([
        _useCases.listStaff(),
        if (businessId != null) _useCases.listInvitations(businessId),
      ]);
      staff = results[0] as List<StaffMember>;
      invitations = results.length > 1 ? results[1] as List<StaffInvitation> : [];
    } catch (e) {
      error = e is ApiException ? e.message : e.toString();
    }
    isLoading = false;
    notifyListeners();
  }

  /// Set when an invitation is created or resent — the only time its link (token)
  /// is available, so the UI can show and share it straight away.
  StaffInvitation? lastInvitation;
  /// Set after a legacy login link is regenerated.
  StaffMember? lastLinkMember;

  Future<bool> invite({
    required int businessId,
    required String name,
    String role = 'SALESPERSON',
    String email = '',
    Map<String, dynamic>? permissions,
  }) =>
      _guard(() async {
        lastInvitation = null;
        final created = await _useCases.inviteStaff(
          businessId: businessId, name: name, role: role, email: email, permissions: permissions,
        );
        invitations = [created, ...invitations];
        lastInvitation = created;
        return true;
      });

  Future<bool> resendInvitation(int businessId, int invitationId) => _guard(() async {
        lastInvitation = null;
        final updated = await _useCases.resendInvitation(businessId, invitationId);
        invitations = invitations.map((i) => i.id == invitationId ? updated : i).toList();
        lastInvitation = updated;
        return true;
      });

  Future<bool> cancelInvitation(int businessId, int invitationId) => _guard(() async {
        await _useCases.cancelInvitation(businessId, invitationId);
        invitations = invitations.where((i) => i.id != invitationId).toList();
        return true;
      });

  Future<bool> regenerateLink(int businessId, int staffId) => _guard(() async {
        final updated = await _useCases.regenerateLink(businessId, staffId);
        staff = staff.map((s) => s.id == staffId ? updated : s).toList();
        lastLinkMember = updated;
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
