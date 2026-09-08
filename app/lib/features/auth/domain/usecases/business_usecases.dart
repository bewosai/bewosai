import 'dart:io';

import '../../data/models/business_model.dart';
import '../../data/models/fiscal_year_model.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../repositories/auth_repository.dart';

class BusinessUseCases {
  final AuthRepository _repository;
  BusinessUseCases([AuthRepository? repository]) : _repository = repository ?? AuthRepositoryImpl();

  Future<List<Business>> listMyBusinesses() => _repository.myBusinesses();

  Future<Business> createBusiness(Business business, {String? referralCode}) =>
      _repository.createBusiness(business, referralCode: referralCode);

  Future<Business> updateBusiness(int id, Map<String, dynamic> fields, {File? logo}) =>
      _repository.updateBusiness(id, fields, logo: logo);

  Future<void> deleteBusiness(int id) => _repository.deleteBusiness(id);

  Future<String> closeFiscalYear(int id) => _repository.closeFiscalYear(id);

  Future<List<FiscalYear>> fiscalYears(int id) => _repository.fiscalYears(id);
}
