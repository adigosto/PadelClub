import 'package:padelclub_desktop/features/product_types/domain/entities/product_type.dart';
import 'package:padelclub_desktop/features/product_types/domain/repositories/product_type_repository.dart';

class GetProductTypes {
  final ProductTypeRepository repository;

  const GetProductTypes(this.repository);

  Future<List<ProductType>> call({Map<String, dynamic>? filter}) {
    return repository.getProductTypes(filter: filter);
  }
}
