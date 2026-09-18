import '../../../../core/network/api_client.dart';
import '../models/staff_model.dart';

// Role-appropriate starting permissions for a newly invited staff member —
// mirrors client/src/pages/StaffPage.jsx's DEFAULT_PERMISSIONS exactly, so a
// Cashier or Viewer invited from mobile starts out just as restricted as one
// invited from web, instead of getting blanket access to every module
// (sales, purchases, banking, staff management, ...) because none was
// specified. The owner can still adjust individual modules afterwards.
const _fullAccess = {'view': true, 'create': true, 'edit': true, 'delete': true};
const _viewOnly = {'view': true, 'create': false, 'edit': false, 'delete': false};
const _noAccess = {'view': false, 'create': false, 'edit': false, 'delete': false};

Map<String, dynamic> defaultPermissionsFor(String role) {
  switch (role) {
    case 'MANAGER':
      return {
        'sales': {'view': true, 'create': true, 'edit': true, 'delete': false},
        'purchases': {'view': true, 'create': true, 'edit': true, 'delete': false},
        'expenses': {'view': true, 'create': true, 'edit': true, 'delete': false},
        'inventory': {'view': true, 'create': true, 'edit': true, 'delete': false},
        'parties': {'view': true, 'create': true, 'edit': true, 'delete': false},
        'payments': {'view': true, 'create': true, 'edit': true, 'delete': false},
        'banking': _viewOnly,
        'staff': _viewOnly,
        'reports': _viewOnly,
      };
    case 'CASHIER':
      return {
        'sales': {'view': true, 'create': true, 'edit': false, 'delete': false},
        'purchases': _noAccess,
        'expenses': {'view': true, 'create': true, 'edit': false, 'delete': false},
        'inventory': _viewOnly,
        'parties': {'view': true, 'create': true, 'edit': false, 'delete': false},
        'payments': {'view': true, 'create': true, 'edit': false, 'delete': false},
        'banking': _noAccess,
        'staff': _noAccess,
        'reports': _viewOnly,
      };
    case 'VIEWER':
      return {
        for (final m in ['sales', 'purchases', 'expenses', 'inventory', 'parties', 'payments', 'banking', 'staff', 'reports'])
          m: _viewOnly,
      };
    default:
      return {
        for (final m in ['sales', 'purchases', 'expenses', 'inventory', 'parties', 'payments', 'banking', 'staff', 'reports'])
          m: _fullAccess,
      };
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

  // Staff created here have no email/phone of their own — they sign in
  // purely through the login link this generates (see
  // AppConstants.staffLoginUrl / accounts.views.StaffListView.post).
  Future<StaffMember> invite({required int businessId, required String name, String role = 'CASHIER'}) async {
    try {
      final res = await _dio.post('/auth/businesses/$businessId/staff/', data: {
        'name': name,
        'role': role,
        'permissions': defaultPermissionsFor(role),
      });
      return StaffMember.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  // Issues a fresh login_token, instantly invalidating whatever link was
  // out there before — used both to re-share an existing staff member's
  // link and to retroactively create one for a member that predates it.
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
