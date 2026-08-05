import '../../../../core/network/api_client.dart';
import '../models/recycle_bin_model.dart';

class RecycleBinService {
  final _dio = ApiClient.instance.dio;

  Future<List<RecycleBinItem>> list() async {
    try {
      final res = await _dio.get('/purchases/recycle-bin/');
      return (res.data as List).map((e) => RecycleBinItem.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<void> restore(String type, int id) async {
    try {
      await _dio.post('/purchases/recycle-bin/restore/$type/$id/');
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<void> permanentlyDelete(String type, int id) async {
    try {
      await _dio.delete('/purchases/recycle-bin/delete/$type/$id/');
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }
}
