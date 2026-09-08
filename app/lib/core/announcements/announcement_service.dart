import '../network/api_client.dart';
import 'announcement_model.dart';

/// Platform announcements from Super Admin — public endpoint, any
/// authenticated user can read active ones. Mirrors the web app's
/// notification-bell Announcements section.
class AnnouncementService {
  final _dio = ApiClient.instance.dio;

  Future<List<Announcement>> fetchActive() async {
    try {
      final res = await _dio.get('/superadmin/announcements/active/');
      final data = res.data as List;
      return data.map((e) => Announcement.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }
}
