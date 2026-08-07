import 'package:padelclub_desktop/features/product_types/domain/entities/product_type.dart';

class ProductTypeModel extends ProductType {
  ProductTypeModel({super.id, required super.name});

  factory ProductTypeModel.fromJson(Map<String, dynamic> json) {
    return ProductTypeModel(
      id: json['id'] as int?,
      name: json['name'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
      };
}
