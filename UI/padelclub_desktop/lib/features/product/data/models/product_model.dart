import 'package:padelclub_desktop/features/product/domain/entities/product.dart';

class ProductModel extends Product {
  ProductModel({
    super.id,
    required super.name,
    required super.description,
    required super.price,
    required super.stockQuantity,
    required super.productState,
    super.imageUrl,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'] as int?,
      name: json['name'] as String,
      description: json['description'] as String,
      price: (json['price'] as num).toDouble(),
      stockQuantity: (json['stockQuantity'] as num).toInt(),
      productState: json['productState'] as String,
      imageUrl: json['imageUrl'] as String?,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'price': price,
        'stockQuantity': stockQuantity,
        'productState': productState,
        'imageUrl': imageUrl,
      };
}
