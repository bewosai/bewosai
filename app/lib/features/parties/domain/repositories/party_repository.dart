import '../../data/models/party_model.dart';

abstract class PartyRepository {
  Future<List<Party>> list({String? search, String? partyType});
  Future<Party> create(Party party);
  Future<Party> update(int id, Party party);
  Future<void> delete(int id);
  Future<PartyLedger> ledger(int id);
  Future<List<PartyPayment>> payments({int? partyId});
  Future<PartyPayment> createPayment(PartyPayment payment);
  Future<void> deletePayment(int id);
  Future<Map<String, dynamic>> bulkImport(List<Map<String, dynamic>> parties);
}
