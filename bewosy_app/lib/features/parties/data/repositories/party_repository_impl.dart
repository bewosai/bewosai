import '../../domain/repositories/party_repository.dart';
import '../models/party_model.dart';
import '../services/party_service.dart';

class PartyRepositoryImpl implements PartyRepository {
  final PartyService _service;
  PartyRepositoryImpl([PartyService? service]) : _service = service ?? PartyService();

  @override
  Future<List<Party>> list({String? search, String? partyType}) => _service.list(search: search, partyType: partyType);
  @override
  Future<Party> create(Party party) => _service.create(party);
  @override
  Future<Party> update(int id, Party party) => _service.update(id, party);
  @override
  Future<void> delete(int id) => _service.delete(id);
  @override
  Future<PartyLedger> ledger(int id) => _service.ledger(id);
  @override
  Future<List<PartyPayment>> payments({int? partyId}) => _service.payments(partyId: partyId);
  @override
  Future<PartyPayment> createPayment(PartyPayment payment) => _service.createPayment(payment);
  @override
  Future<void> deletePayment(int id) => _service.deletePayment(id);
  @override
  Future<Map<String, dynamic>> bulkImport(List<Map<String, dynamic>> parties) => _service.bulkImport(parties);
}
