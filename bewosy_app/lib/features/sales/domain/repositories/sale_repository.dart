import '../../data/models/sale_model.dart';

abstract class SaleRepository {
  Future<List<Sale>> list({String? search, String? status, DateTime? from, DateTime? to});
  Future<Sale> get(int id);
  Future<String> nextNumber();
  Future<Sale> create(Sale sale);
  Future<Sale> update(int id, Sale sale);
  Future<void> cancel(int id);
  Future<void> delete(int id);
  Future<List<SaleReturn>> returns();
  Future<SaleReturn> createReturn(SaleReturn saleReturn);
  Future<List<Quotation>> quotations({String? status});
  Future<Quotation> createQuotation(Quotation quotation);
  Future<Quotation> updateQuotation(int id, Quotation quotation);
  Future<void> deleteQuotation(int id);
}
