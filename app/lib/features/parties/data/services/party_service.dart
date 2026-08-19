import '../../../../core/network/api_client.dart';
import '../models/party_model.dart';

class PartyService {
  final _dio = ApiClient.instance.dio;

  Future<List<Party>> list({String? search, String? partyType}) async {
    try {
      final res = await _dio.get('/parties/', queryParameters: {
        'page_size': 200,
        if (search != null && search.isNotEmpty) 'search': search,
        if (partyType != null && partyType.isNotEmpty) 'party_type': partyType,
      });
      final data = res.data;
      final results = data is Map ? (data['results'] as List? ?? []) : (data as List);
      return results.map((e) => Party.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<Party> create(Party party) async {
    try {
      final res = await _dio.post('/parties/', data: party.toJson());
      return Party.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<Party> update(int id, Party party) async {
    try {
      final res = await _dio.put('/parties/$id/', data: party.toJson());
      return Party.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<void> delete(int id) async {
    try {
      await _dio.delete('/parties/$id/');
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<PartyLedger> ledger(int id) async {
    try {
      final res = await _dio.get('/parties/$id/ledger/');
      return PartyLedger.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<List<PartyPayment>> payments({int? partyId}) async {
    try {
      final res = await _dio.get('/parties/payments/', queryParameters: {
        'page_size': 200,
        'party': ?partyId,
      });
      final data = res.data;
      final results = data is Map ? (data['results'] as List? ?? []) : (data as List);
      return results.map((e) => PartyPayment.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<PartyPayment> createPayment(PartyPayment payment) async {
    try {
      final res = await _dio.post('/parties/payments/', data: payment.toJson());
      return PartyPayment.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  /// Posts an already-server-shaped payload directly — used by [SyncService]
  /// to replay a payment queued while offline.
  Future<PartyPayment> createPaymentRaw(Map<String, dynamic> payload) async {
    try {
      final res = await _dio.post('/parties/payments/', data: payload);
      return PartyPayment.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<void> deletePayment(int id) async {
    try {
      await _dio.delete('/parties/payments/$id/');
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<Map<String, dynamic>> bulkImport(List<Map<String, dynamic>> parties) async {
    try {
      final res = await _dio.post('/parties/bulk-import/', data: {'parties': parties});
      return res.data as Map<String, dynamic>;
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }
}
