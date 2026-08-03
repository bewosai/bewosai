import 'package:flutter/material.dart';
import '../../../../core/network/api_client.dart';
import '../../data/models/sale_model.dart';
import '../../domain/usecases/sale_usecases.dart';

class SaleProvider extends ChangeNotifier {
  final _useCases = SaleUseCases();

  List<Sale> sales = [];
  List<Quotation> quotations = [];
  List<SaleReturn> returns = [];
  bool isLoading = false;
  String? error;

  Future<void> load() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      sales = await _useCases.listSales();
    } catch (e) {
      error = e is ApiException ? e.message : e.toString();
    }
    isLoading = false;
    notifyListeners();
  }

  Future<void> loadQuotations() async {
    try {
      quotations = await _useCases.listQuotations();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> loadReturns() async {
    try {
      returns = await _useCases.listReturns();
      notifyListeners();
    } catch (_) {}
  }

  Future<String> nextNumber() => _useCases.nextInvoiceNumber();

  Future<Sale?> save(Sale sale, {int? id}) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      Sale result;
      if (id != null) {
        result = await _useCases.updateSale(id, sale);
        sales = sales.map((s) => s.id == id ? result : s).toList();
      } else {
        result = await _useCases.createSale(sale);
        sales = [result, ...sales];
      }
      isLoading = false;
      notifyListeners();
      return result;
    } catch (e) {
      isLoading = false;
      error = e is ApiException ? e.message : e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<bool> cancel(int id) => _guard(() async {
        await _useCases.cancelSale(id);
        sales = sales.map((s) => s.id == id
            ? Sale(
                id: s.id, invoiceNumber: s.invoiceNumber, customer: s.customer,
                customerName: s.customerName, partyPhone: s.partyPhone, saleDate: s.saleDate,
                dueDate: s.dueDate, subtotal: s.subtotal, discount: s.discount, taxRate: s.taxRate,
                taxAmount: s.taxAmount, total: s.total, paidAmount: s.paidAmount, dueAmount: s.dueAmount,
                paymentMethod: s.paymentMethod, status: 'CANCELLED', saleType: s.saleType,
                notes: s.notes, items: s.items, createdAt: s.createdAt,
              )
            : s).toList();
        return true;
      });

  Future<bool> saveQuotation(Quotation quotation, {int? id}) => _guard(() async {
        if (id != null) {
          final updated = await _useCases.updateQuotation(id, quotation);
          quotations = quotations.map((q) => q.id == id ? updated : q).toList();
        } else {
          final created = await _useCases.createQuotation(quotation);
          quotations = [created, ...quotations];
        }
        return true;
      });

  Future<bool> deleteQuotation(int id) => _guard(() async {
        await _useCases.deleteQuotation(id);
        quotations = quotations.where((q) => q.id != id).toList();
        return true;
      });

  Future<bool> createReturn(SaleReturn saleReturn) => _guard(() async {
        final created = await _useCases.createReturn(saleReturn);
        returns = [created, ...returns];
        await load();
        return true;
      });

  double get thisMonthTotal {
    final now = DateTime.now();
    return sales
        .where((s) => s.saleDate != null && s.saleDate!.year == now.year && s.saleDate!.month == now.month)
        .fold(0.0, (sum, s) => sum + s.total);
  }

  double get totalReceivable => sales.where((s) => s.status == 'CONFIRMED').fold(0.0, (sum, s) => sum + s.dueAmount);
  int get overdueCount => sales.where((s) => s.isOverdue).length;

  Future<bool> _guard(Future<bool> Function() action) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final result = await action();
      isLoading = false;
      notifyListeners();
      return result;
    } catch (e) {
      isLoading = false;
      error = e is ApiException ? e.message : e.toString();
      notifyListeners();
      return false;
    }
  }
}
