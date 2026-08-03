import '../../data/models/recycle_bin_model.dart';

abstract class RecycleBinRepository {
  Future<List<RecycleBinItem>> list();
  Future<void> restore(String type, int id);
  Future<void> permanentlyDelete(String type, int id);
}
