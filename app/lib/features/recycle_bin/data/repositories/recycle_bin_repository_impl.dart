import '../../domain/repositories/recycle_bin_repository.dart';
import '../models/recycle_bin_model.dart';
import '../services/recycle_bin_service.dart';

class RecycleBinRepositoryImpl implements RecycleBinRepository {
  final RecycleBinService _service;
  RecycleBinRepositoryImpl([RecycleBinService? service]) : _service = service ?? RecycleBinService();

  @override
  Future<List<RecycleBinItem>> list() => _service.list();
  @override
  Future<void> restore(String type, int id) => _service.restore(type, id);
  @override
  Future<void> permanentlyDelete(String type, int id) => _service.permanentlyDelete(type, id);
}
