import 'package:flutter/material.dart';
import '../../../../core/network/api_client.dart';
import '../../data/models/recycle_bin_model.dart';
import '../../domain/usecases/recycle_bin_usecases.dart';

class RecycleBinProvider extends ChangeNotifier {
  final _useCases = RecycleBinUseCases();

  List<RecycleBinItem> items = [];
  bool isLoading = false;
  String? error;

  Future<void> load() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      items = await _useCases.listItems();
    } catch (e) {
      error = e is ApiException ? e.message : e.toString();
    }
    isLoading = false;
    notifyListeners();
  }

  Future<bool> restore(String type, int id) => _guard(() async {
        await _useCases.restore(type, id);
        items = items.where((r) => !(r.type == type && r.id == id)).toList();
        return true;
      });

  Future<bool> permanentlyDelete(String type, int id) => _guard(() async {
        await _useCases.permanentlyDelete(type, id);
        items = items.where((r) => !(r.type == type && r.id == id)).toList();
        return true;
      });

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
