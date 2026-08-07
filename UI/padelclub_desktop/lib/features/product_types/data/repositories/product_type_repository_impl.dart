import 'package:padelclub_desktop/features/product_types/data/datasources/product_type_remote_data_source.dart';
import 'package:padelclub_desktop/features/product_types/domain/entities/product_type.dart';
import 'package:padelclub_desktop/features/product_types/domain/repositories/product_type_repository.dart';

class ProductTypeRepositoryImpl implements ProductTypeRepository {
  final ProductTypeRemoteDataSource remoteDataSource;

  ProductTypeRepositoryImpl({required this.remoteDataSource});

  @override
  Future<List<ProductType>> getProductTypes({Map<String, dynamic>? filter}) async {
    return await remoteDataSource.getProductTypes(filter: filter);
  }
}
