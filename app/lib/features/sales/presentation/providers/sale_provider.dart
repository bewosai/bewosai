import 'dart:async';

import 'package:flutter/material.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/offline/app_database.dart';
import '../../../../core/offline/connectivity_service.dart';
import '../../../../core/offline/sync_service.dart';
import '../../../../core/storage/token_storage.dart';
import '../../data/models/sale_model.dart';
import '../../domain/usecases/sale_usecases.dart';
import '../../../../core/calendar/nepal_time.dart';

class SaleProvider extends ChangeNotifier {
  final _useCases = SaleUseCases();

  List<Sale> sales = [];
  List<Quotation> quotations = [];
  List<SaleReturn> returns = [];
  bool isLoading = false;
  String? error;

  Future<String> _businessId() async {
    final business = await TokenStorage.instance.currentBusiness;
    return '${business?['id'] ?? ''}';
  }

  Future<void> load() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final pending = await _pendingSales();
      sales = [...pending, ...await _useCases.listSales()];
    } catch (e) {
      sales = await _pendingSales();
      if (sales.isEmpty) error = e is ApiException ? e.message : e.toString();
    }
    isLoading = false;
    notifyListeners();
  }

  Future<List<Sale>> _pendingSales() async {
    final businessId = await _businessId();
    if (businessId.isEmpty) return [];
    final rows = await AppDatabase.instance.pendingSales(businessId);
    return rows.map((json) => Sale(
          id: json['temp_id'] as int,
          invoiceNumber: json['invoice_number'] as String? ?? '',
          customer: json['customer'] as int?,
          customerName: '',
          partyPhone: '',
          saleDate: DateTime.tryParse(json['sale_date'] as String? ?? ''),
          dueDate: DateTime.tryParse(json['due_date'] as String? ?? ''),
          subtotal: (json['items'] as List? ?? [])
              .fold(0.0, (sum, i) => sum + ((i['quantity'] as num? ?? 0) * (i['unit_price'] as num? ?? 0) - (i['discount_amount'] as num? ?? 0))),
          discount: (json['discount'] as num?)?.toDouble() ?? 0,
          taxRate: (json['tax_rate'] as num?)?.toDouble() ?? 0,
          taxAmount: 0,
          total: (json['paid_amount'] as num?)?.toDouble() ?? 0,
          paidAmount: (json['paid_amount'] as num?)?.toDouble() ?? 0,
          dueAmount: 0,
          paymentMethod: json['payment_method'] as String? ?? 'CASH',
          status: json['status'] as String? ?? 'CONFIRMED',
          saleType: json['sale_type'] as String? ?? 'SALE',
          notes: json['notes'] as String? ?? '',
          items: (json['items'] as List? ?? [])
              .map((e) => SaleItem.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList(),
          createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
          pendingSync: true,
          syncError: json['sync_error'] as String?,
        ))
        .toList()
        .reversed
        .toList();
  }

  Future<void> loadQuotations() async {
    try {
      quotations = await _useCases.listQuotations();
      notifyListeners();
    } catch (_) {}
  }

  bool isLoadingReturns = false;
  String? returnsError;

  // A failed load used to be swallowed, so the Sales Return list looked the same
  // as "no returns yet" — keep the reason so the screen can say what happened.
  Future<void> loadReturns() async {
    isLoadingReturns = true;
    returnsError = null;
    notifyListeners();
    try {
      returns = await _useCases.listReturns();
    } catch (e) {
      returnsError = e is ApiException ? e.message : e.toString();
    }
    isLoadingReturns = false;
    notifyListeners();
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
      } else if (!await ConnectivityService.instance.checkOnline()) {
        result = await _saveOffline(sale);
        sales = [result, ...sales];
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

  /// Queues [sale] in the local outbox instead of posting it, returning a
  /// negative-ID stand-in so Quick POS can show its normal "saved" flow —
  /// [SyncService] replays it against the real API on reconnect.
  Future<Sale> _saveOffline(Sale sale) async {
    final businessId = await _businessId();
    final tempId = await AppDatabase.instance.enqueueSale(businessId, sale.toJson());
    await SyncService.instance.refreshPendingCount();
    return Sale(
      id: tempId,
      invoiceNumber: sale.invoiceNumber,
      customer: sale.customer,
      customerName: sale.customerName,
      partyPhone: sale.partyPhone,
      saleDate: sale.saleDate,
      dueDate: sale.dueDate,
      subtotal: sale.subtotal,
      discount: sale.discount,
      taxRate: sale.taxRate,
      taxAmount: sale.taxAmount,
      total: sale.total,
      paidAmount: sale.paidAmount,
      dueAmount: sale.dueAmount,
      paymentMethod: sale.paymentMethod,
      status: sale.status,
      saleType: sale.saleType,
      notes: sale.notes,
      items: sale.items,
      createdAt: NepalTime.now(),
      pendingSync: true,
    );
  }

  /// Rewrites a queued offline sale that the server rejected (see
  /// [Sale.syncError]) with corrected data — e.g. a new invoice number —
  /// and clears the flag so the next sync pass retries it.
  Future<Sale?> updatePendingSale(int tempId, Sale sale) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      await AppDatabase.instance.updatePendingSale(tempId, sale.toJson());
      final updated = Sale(
        id: tempId,
        invoiceNumber: sale.invoiceNumber,
        customer: sale.customer,
        customerName: sale.customerName,
        partyPhone: sale.partyPhone,
        saleDate: sale.saleDate,
        dueDate: sale.dueDate,
        subtotal: sale.subtotal,
        discount: sale.discount,
        taxRate: sale.taxRate,
        taxAmount: sale.taxAmount,
        total: sale.total,
        paidAmount: sale.paidAmount,
        dueAmount: sale.dueAmount,
        paymentMethod: sale.paymentMethod,
        status: sale.status,
        saleType: sale.saleType,
        notes: sale.notes,
        items: sale.items,
        createdAt: sale.createdAt ?? NepalTime.now(),
        pendingSync: true,
      );
      sales = sales.map((s) => s.id == tempId ? updated : s).toList();
      isLoading = false;
      notifyListeners();
      // Fire-and-forget: don't make the user wait on connectivity just to
      // save their fix locally — the outbox banner reflects the outcome.
      unawaited(SyncService.instance.drain());
      return updated;
    } catch (e) {
      isLoading = false;
      error = e is ApiException ? e.message : e.toString();
      notifyListeners();
      return null;
    }
  }

  /// Moves the invoice to the Recycle Bin (soft delete on the backend) and
  /// drops it from the list.
  Future<bool> delete(int id) => _guard(() async {
        await _useCases.deleteSale(id);
        sales = sales.where((s) => s.id != id).toList();
        return true;
      });

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
    final now = NepalTime.now();
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
