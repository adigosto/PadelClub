import 'package:padelclub_desktop/features/product_categories/data/datasources/product_category_remote_data_source.dart';
import 'package:padelclub_desktop/features/product_categories/domain/entities/product_category.dart';
import 'package:padelclub_desktop/features/product_categories/domain/repositories/product_category_repository.dart';

class ProductCategoryRepositoryImpl implements ProductCategoryRepository {
  final ProductCategoryRemoteDataSource remoteDataSource;

  ProductCategoryRepositoryImpl({required this.remoteDataSource});

  @override
  Future<List<ProductCategory>> getProductCategories({
    Map<String, dynamic>? filter,
  }) async {
    return await remoteDataSource.getProductCategories(filter: filter);
  }
}
