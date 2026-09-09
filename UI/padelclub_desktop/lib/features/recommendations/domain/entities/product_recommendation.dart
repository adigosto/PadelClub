import 'package:padelclub_desktop/features/product/domain/entities/product.dart';

class ProductRecommendation {
  const ProductRecommendation({
    required this.product,
    required this.score,
    required this.reason,
    required this.strategy,
    required this.isFallback,
    required this.algorithmVersion,
    required this.supportingCustomers,
    this.exposureId,
    this.becauseProductName,
  });

  final Product product;
  final double score;
  final String reason;
  final String strategy;
  final bool isFallback;
  final String algorithmVersion;
  final String? becauseProductName;
  final int supportingCustomers;
  final String? exposureId;

  factory ProductRecommendation.fromJson(Map<String, dynamic> json) {
    final productJson = json['product'];
    if (productJson is! Map<String, dynamic>) {
      throw const FormatException(
        'A recommendation did not contain a product.',
      );
    }

    return ProductRecommendation(
      product: Product.fromJson(productJson),
      score: (json['score'] as num?)?.toDouble() ?? 0,
      reason: json['reason'] as String? ?? '',
      strategy: json['strategy'] as String? ?? '',
      isFallback: json['isFallback'] as bool? ?? false,
      algorithmVersion: json['algorithmVersion'] as String? ?? '',
      exposureId: json['exposureId'] as String?,
      becauseProductName: json['becauseProductName'] as String?,
      supportingCustomers: json['supportingCustomers'] as int? ?? 0,
    );
  }
}
