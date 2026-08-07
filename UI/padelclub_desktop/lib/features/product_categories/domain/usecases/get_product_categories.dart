import 'package:padelclub_desktop/features/product_categories/domain/entities/product_category.dart';
import 'package:padelclub_desktop/features/product_categories/domain/repositories/product_category_repository.dart';

class GetProductCategories {
  final ProductCategoryRepository repository;

  const GetProductCategories(this.repository);

  Future<List<ProductCategory>> call({Map<String, dynamic>? filter}) {
    return repository.getProductCategories(filter: filter);
  }
}
