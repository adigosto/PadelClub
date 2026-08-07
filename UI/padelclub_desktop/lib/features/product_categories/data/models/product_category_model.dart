import 'package:padelclub_desktop/features/product_categories/domain/entities/product_category.dart';

class ProductCategoryModel extends ProductCategory {
  ProductCategoryModel({super.id, required super.name});

  factory ProductCategoryModel.fromJson(Map<String, dynamic> json) {
    return ProductCategoryModel(
      id: json['id'] as int?,
      name: json['name'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
      };
}
