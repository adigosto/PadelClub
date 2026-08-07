import 'package:json_annotation/json_annotation.dart';

part 'product.g.dart';

@JsonSerializable()
class Product {
  int? id;
  String name;
  String description;
  double price;
  int stockQuantity;
  String productState;
  String? imageUrl;

  Product({
    this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.stockQuantity,
    required this.productState,
    this.imageUrl,
  });

  factory Product.fromJson(Map<String, dynamic> json) => _$ProductFromJson(json);

  Map<String, dynamic> toJson() => _$ProductToJson(this);
}
