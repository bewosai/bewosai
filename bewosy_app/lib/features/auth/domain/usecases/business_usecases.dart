import '../../data/models/business_model.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../repositories/auth_repository.dart';

class BusinessUseCases {
  final AuthRepository _repository;
  BusinessUseCases([AuthRepository? repository]) : _repository = repository ?? AuthRepositoryImpl();

  Future<List<Business>> listMyBusinesses() => _repository.myBusinesses();

  Future<Business> createBusiness(Business business) => _repository.createBusiness(business);

  Future<Business> updateBusiness(int id, Map<String, dynamic> fields) => _repository.updateBusiness(id, fields);

  Future<void> deleteBusiness(int id) => _repository.deleteBusiness(id);

  Future<Business> closeFiscalYear(int id) => _repository.closeFiscalYear(id);
}
