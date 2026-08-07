import 'package:padelclub_desktop/features/product/data/datasources/product_remote_data_source.dart';
import 'package:padelclub_desktop/features/product/domain/entities/product.dart';
import 'package:padelclub_desktop/features/product/domain/repositories/product_repository.dart';

class ProductRepositoryImpl implements ProductRepository {
  final ProductRemoteDataSource remoteDataSource;

  ProductRepositoryImpl({required this.remoteDataSource});

  @override
  Future<List<Product>> getProducts({Map<String, dynamic>? filter}) async {
    final result = await remoteDataSource.getProducts(filter: filter);
    return result.cast<Product>().toList();
  }
}
