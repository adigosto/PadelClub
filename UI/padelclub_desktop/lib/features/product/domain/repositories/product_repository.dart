import 'package:padelclub_desktop/features/product/domain/entities/product.dart';

abstract class ProductRepository {
  Future<List<Product>> getProducts({Map<String, dynamic>? filter});
}
