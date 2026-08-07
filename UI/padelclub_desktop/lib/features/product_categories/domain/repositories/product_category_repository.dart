import 'package:padelclub_desktop/features/product_categories/domain/entities/product_category.dart';

abstract class ProductCategoryRepository {
  Future<List<ProductCategory>> getProductCategories({Map<String, dynamic>? filter});
}
