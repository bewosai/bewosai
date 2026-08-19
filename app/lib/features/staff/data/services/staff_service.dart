import '../../../../core/network/api_client.dart';
import '../models/staff_model.dart';

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

  Future<StaffMember> invite({required String email, String name = '', String role = 'CASHIER'}) async {
    try {
      final res = await _dio.post('/staff/invite/', data: {
        'email': email,
        'name': name,
        'role': role,
      });
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
