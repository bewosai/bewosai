import '../../data/models/sale_model.dart';
import '../../data/repositories/sale_repository_impl.dart';
import '../repositories/sale_repository.dart';

class SaleUseCases {
  final SaleRepository _repository;
  SaleUseCases([SaleRepository? repository]) : _repository = repository ?? SaleRepositoryImpl();

  Future<List<Sale>> listSales({String? search, String? status, DateTime? from, DateTime? to}) =>
      _repository.list(search: search, status: status, from: from, to: to);

  Future<Sale> getSale(int id) => _repository.get(id);

  Future<String> nextInvoiceNumber() => _repository.nextNumber();

  Future<Sale> createSale(Sale sale) => _repository.create(sale);

  Future<Sale> updateSale(int id, Sale sale) => _repository.update(id, sale);

  Future<void> cancelSale(int id) => _repository.cancel(id);

  Future<void> deleteSale(int id) => _repository.delete(id);

  Future<List<SaleReturn>> listReturns() => _repository.returns();

  Future<SaleReturn> createReturn(SaleReturn saleReturn) => _repository.createReturn(saleReturn);

  Future<List<Quotation>> listQuotations({String? status}) => _repository.quotations(status: status);

  Future<Quotation> createQuotation(Quotation quotation) => _repository.createQuotation(quotation);

  Future<Quotation> updateQuotation(int id, Quotation quotation) => _repository.updateQuotation(id, quotation);

  Future<void> deleteQuotation(int id) => _repository.deleteQuotation(id);
}
