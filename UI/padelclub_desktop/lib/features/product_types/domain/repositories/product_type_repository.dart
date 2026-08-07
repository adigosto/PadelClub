import 'package:padelclub_desktop/features/product_types/domain/entities/product_type.dart';

abstract class ProductTypeRepository {
  Future<List<ProductType>> getProductTypes({Map<String, dynamic>? filter});
}
