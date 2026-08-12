import 'package:flutter/material.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/offline/app_database.dart';
import '../../../../core/offline/connectivity_service.dart';
import '../../../../core/storage/token_storage.dart';
import '../../data/models/party_model.dart';
import '../../domain/usecases/party_usecases.dart';

class PartyProvider extends ChangeNotifier {
  final _useCases = PartyUseCases();

  List<Party> parties = [];
  List<PartyPayment> payments = [];
  bool isLoading = false;
  String? error;

  /// True when [parties] came from the local cache — see
  /// [InventoryProvider.isOffline] for why this exists.
  bool isOffline = false;

  Future<String> _businessId() async {
    final business = await TokenStorage.instance.currentBusiness;
    return '${business?['id'] ?? ''}';
  }

  Future<void> load() async {
    isLoading = true;
    error = null;
    notifyListeners();

    final businessId = await _businessId();
    final online = await ConnectivityService.instance.checkOnline();
    if (!online) {
      isOffline = true;
      if (businessId.isNotEmpty) {
        final cached = await AppDatabase.instance.readCache('cached_parties', businessId);
        parties = cached.map(Party.fromJson).toList();
      }
      isLoading = false;
      notifyListeners();
      return;
    }

    try {
      parties = await _useCases.listParties();
      isOffline = false;
      if (businessId.isNotEmpty) {
        await AppDatabase.instance.replaceCache(
          'cached_parties',
          businessId,
          parties.map((p) => p.toCacheJson()).toList(),
        );
      }
    } catch (e) {
      if (businessId.isNotEmpty) {
        final cached = await AppDatabase.instance.readCache('cached_parties', businessId);
        if (cached.isNotEmpty) {
          parties = cached.map(Party.fromJson).toList();
          isOffline = true;
          isLoading = false;
          notifyListeners();
          return;
        }
      }
      error = e is ApiException ? e.message : e.toString();
    }
    isLoading = false;
    notifyListeners();
  }

  Future<void> loadPayments() async {
    try {
      payments = await _useCases.listPayments();
      notifyListeners();
    } catch (_) {}
  }

  Future<bool> save(Party party, {int? id}) => _guard(() async {
        if (id != null) {
          final updated = await _useCases.saveParty(party, id: id);
          parties = parties.map((p) => p.id == id ? updated : p).toList();
        } else {
          final created = await _useCases.saveParty(party);
          parties = [created, ...parties];
        }
        return true;
      });

  /// Creates a party and returns it directly (unlike [save], which only reports success/failure) —
  /// used by inline "add new customer/supplier" pickers that need the created party's id right away.
  Future<Party?> quickCreate(Party party) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final created = await _useCases.saveParty(party);
      parties = [created, ...parties];
      isLoading = false;
      notifyListeners();
      return created;
    } catch (e) {
      isLoading = false;
      error = e is ApiException ? e.message : e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<bool> delete(int id) => _guard(() async {
        await _useCases.deleteParty(id);
        parties = parties.where((p) => p.id != id).toList();
        return true;
      });

  Future<PartyLedger?> ledger(int id) async {
    try {
      return await _useCases.getLedger(id);
    } catch (e) {
      error = e is ApiException ? e.message : e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<bool> addPayment(PartyPayment payment) => _guard(() async {
        final created = await _useCases.addPayment(payment);
        payments = [created, ...payments];
        await load();
        return true;
      });

  Future<bool> deletePayment(int id) => _guard(() async {
        await _useCases.deletePayment(id);
        payments = payments.where((p) => p.id != id).toList();
        await load();
        return true;
      });

  List<Party> get customers => parties.where((p) => p.isCustomer).toList();
  List<Party> get suppliers => parties.where((p) => p.isSupplier).toList();
  double get totalReceivable =>
      parties.where((p) => p.balance > 0).fold(0.0, (sum, p) => sum + p.balance);

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
