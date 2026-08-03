import '../../data/models/recycle_bin_model.dart';
import '../../data/repositories/recycle_bin_repository_impl.dart';
import '../repositories/recycle_bin_repository.dart';

class RecycleBinUseCases {
  final RecycleBinRepository _repository;
  RecycleBinUseCases([RecycleBinRepository? repository]) : _repository = repository ?? RecycleBinRepositoryImpl();

  Future<List<RecycleBinItem>> listItems() => _repository.list();
  Future<void> restore(String type, int id) => _repository.restore(type, id);
  Future<void> permanentlyDelete(String type, int id) => _repository.permanentlyDelete(type, id);
}
