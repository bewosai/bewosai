import '../../../../core/network/api_client.dart';
import '../models/staff_model.dart';

// Role-appropriate starting permissions - mirrors client/src/utils/staffRoles.js
// exactly, so a role picked on the phone starts with the same ticks as on the
// web. A role only sets the starting point; the owner can change any of it.
const _all = {'view': true, 'create': true, 'edit': true, 'delete': true};
const _noDelete = {'view': true, 'create': true, 'edit': true, 'delete': false};
const _add = {'view': true, 'create': true, 'edit': false, 'delete': false};
const _viewOnly = {'view': true, 'create': false, 'edit': false, 'delete': false};
const _noAccess = {'view': false, 'create': false, 'edit': false, 'delete': false};
const _modules = ['sales', 'purchases', 'expenses', 'inventory', 'parties', 'payments', 'banking', 'reports', 'staff'];

Map<String, dynamic> _preset(Map<String, Map<String, bool>> set, [Map<String, bool> rest = _noAccess]) => {
      for (final m in _modules) m: Map<String, bool>.from(set[m] ?? rest),
    };

Map<String, dynamic> defaultPermissionsFor(String role) {
  switch (role) {
    case 'PARTNER':
      return _preset({'staff': _noAccess}, _all);
    case 'MANAGER':
      return _preset({
        'sales': _noDelete, 'purchases': _noDelete, 'expenses': _noDelete, 'inventory': _noDelete,
        'parties': _noDelete, 'payments': _noDelete, 'banking': _viewOnly, 'staff': _viewOnly, 'reports': _viewOnly,
      });
    case 'ACCOUNTANT':
      return _preset({
        'sales': _viewOnly, 'purchases': _viewOnly, 'expenses': _noDelete, 'inventory': _viewOnly,
        'parties': _noDelete, 'payments': _noDelete, 'banking': _noDelete, 'reports': _viewOnly,
      });
    case 'SALESPERSON':
      return _preset({'sales': _noDelete, 'parties': _add, 'inventory': _viewOnly, 'payments': _add});
    case 'CASHIER':
      return _preset({
        'sales': _add, 'expenses': _add, 'inventory': _viewOnly, 'parties': _add, 'payments': _add, 'reports': _viewOnly,
      });
    case 'ENTRY':
      return _preset({
        'sales': _add, 'purchases': _add, 'expenses': _add, 'inventory': _add, 'parties': _add, 'payments': _add,
      });
    case 'INVENTORY_MANAGER':
      return _preset({'inventory': _noDelete, 'purchases': _noDelete, 'parties': _viewOnly});
    case 'VIEWER':
      return _preset({'staff': _noAccess}, _viewOnly);
    default:
      return _preset(const {}, _all);
  }
}

class StaffService {
  final _dio = ApiClient.instance.dio;

  Future<List<StaffMember>> list() async {
    try {
      final res = await _dio.get('/staff/', queryParameters: {'page_size': 100});
      final data = res.data;
      final results = data is Map ? (data['results'] as List? ?? []) : (data as List);
      return results.map((e) => StaffMember.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  /// Creates an invitation (not a member yet): the person opens the link,
  /// proves their email with a code and accepts. The returned token is the only
  /// time the link can be shown. A non-empty [email] means only it can accept.
  Future<StaffInvitation> invite({
    required int businessId,
    required String name,
    String role = 'SALESPERSON',
    String email = '',
    Map<String, dynamic>? permissions,
  }) async {
    try {
      final res = await _dio.post('/auth/businesses/$businessId/staff/', data: {
        'name': name,
        'role': role,
        'email': email,
        // What the owner ticked, or the role's starting set when they didn't customise.
        'permissions': permissions ?? defaultPermissionsFor(role),
      });
      return StaffInvitation.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<List<StaffInvitation>> listInvitations(int businessId) async {
    try {
      final res = await _dio.get('/auth/businesses/$businessId/staff/invitations/', queryParameters: {'page_size': 100});
      final data = res.data;
      final results = data is Map ? (data['results'] as List? ?? []) : (data as List);
      return results.map((e) => StaffInvitation.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  /// New link and a fresh 7 days; the old link stops working.
  Future<StaffInvitation> resendInvitation(int businessId, int invitationId) async {
    try {
      final res = await _dio.post('/auth/businesses/$businessId/staff/invitations/$invitationId/resend/');
      return StaffInvitation.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<void> cancelInvitation(int businessId, int invitationId) async {
    try {
      await _dio.delete('/auth/businesses/$businessId/staff/invitations/$invitationId/');
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  // Old-style bearer link, only for staff added before email invitations:
  // issues a fresh login_token, instantly invalidating the previous one.
  Future<StaffMember> regenerateLink(int businessId, int staffId) async {
    try {
      final res = await _dio.post('/auth/businesses/$businessId/staff/$staffId/regenerate-link/');
      return StaffMember.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<StaffMember> updateStaff(int businessId, int staffId, {String? role, Map<String, dynamic>? permissions, bool? isActive}) async {
    try {
      final res = await _dio.patch('/auth/businesses/$businessId/staff/$staffId/', data: {
        'role': ?role,
        'permissions': ?permissions,
        'is_active': ?isActive,
      });
      return StaffMember.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<void> remove(int businessId, int staffId) async {
    try {
      await _dio.delete('/auth/businesses/$businessId/staff/$staffId/');
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }
}
