import '../../domain/repositories/sale_repository.dart';
import '../models/sale_model.dart';
import '../services/sale_service.dart';

class SaleRepositoryImpl implements SaleRepository {
  final SaleService _service;
  SaleRepositoryImpl([SaleService? service]) : _service = service ?? SaleService();

  @override
  Future<List<Sale>> list({String? search, String? status, DateTime? from, DateTime? to}) =>
      _service.list(search: search, status: status, from: from, to: to);

  @override
  Future<Sale> get(int id) => _service.get(id);

  @override
  Future<String> nextNumber() => _service.nextNumber();

  @override
  Future<Sale> create(Sale sale) => _service.create(sale);

  @override
  Future<Sale> update(int id, Sale sale) => _service.update(id, sale);

  @override
  Future<void> cancel(int id) => _service.cancel(id);

  @override
  Future<void> delete(int id) => _service.delete(id);

  @override
  Future<List<SaleReturn>> returns() => _service.returns();

  @override
  Future<SaleReturn> createReturn(SaleReturn saleReturn) => _service.createReturn(saleReturn);

  @override
  Future<List<Quotation>> quotations({String? status}) => _service.quotations(status: status);

  @override
  Future<Quotation> createQuotation(Quotation quotation) => _service.createQuotation(quotation);

  @override
  Future<Quotation> updateQuotation(int id, Quotation quotation) => _service.updateQuotation(id, quotation);

  @override
  Future<void> deleteQuotation(int id) => _service.deleteQuotation(id);
}
