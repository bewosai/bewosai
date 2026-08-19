import '../../data/models/party_model.dart';
import '../../data/repositories/party_repository_impl.dart';
import '../repositories/party_repository.dart';

class PartyUseCases {
  final PartyRepository _repository;
  PartyUseCases([PartyRepository? repository]) : _repository = repository ?? PartyRepositoryImpl();

  Future<List<Party>> listParties({String? search, String? partyType}) =>
      _repository.list(search: search, partyType: partyType);

  Future<Party> saveParty(Party party, {int? id}) =>
      id != null ? _repository.update(id, party) : _repository.create(party);

  Future<void> deleteParty(int id) => _repository.delete(id);

  Future<PartyLedger> getLedger(int id) => _repository.ledger(id);

  Future<List<PartyPayment>> listPayments({int? partyId}) => _repository.payments(partyId: partyId);

  Future<PartyPayment> addPayment(PartyPayment payment) => _repository.createPayment(payment);

  Future<void> deletePayment(int id) => _repository.deletePayment(id);

  Future<Map<String, dynamic>> bulkImportParties(List<Map<String, dynamic>> rows) =>
      _repository.bulkImport(rows);
}
