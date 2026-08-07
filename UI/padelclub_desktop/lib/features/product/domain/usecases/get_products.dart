import 'package:padelclub_desktop/features/product/domain/entities/product.dart';
import 'package:padelclub_desktop/features/product/domain/repositories/product_repository.dart';

class GetProducts {
  final ProductRepository repository;

  const GetProducts(this.repository);

  Future<List<Product>> call({Map<String, dynamic>? filter}) {
    return repository.getProducts(filter: filter);
  }
}
