import '../network/api_client.dart';

class FeatureService {
  final _dio = ApiClient.instance.dio;

  /// Effective on/off map for the current business on this platform — the
  /// same endpoint the React web client reads, so Desktop and Mobile can
  /// never show a different feature set for the same business. See backend
  /// superadmin.views.EffectiveFeaturesView.
  Future<Map<String, bool>> effective() async {
    try {
      final res = await _dio.get('/features/');
      final data = res.data;
      final raw = data is Map ? data['features'] as Map? : null;
      if (raw == null) return {};
      return raw.map((k, v) => MapEntry(k as String, v == true));
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }
}
