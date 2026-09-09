import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:padelclub_desktop/core/network/api_config.dart';
import 'package:padelclub_desktop/features/recommendations/domain/entities/product_recommendation.dart';
import 'package:padelclub_desktop/providers/auth_provider.dart';

class ProductRecommendationProvider extends ChangeNotifier {
  List<ProductRecommendation> items = const [];
  bool isLoading = false;
  String? errorMessage;

  Future<void> load({int limit = 6}) async {
    if (isLoading) return;

    isLoading = true;
    errorMessage = null;
    items = const [];
    notifyListeners();

    try {
      final safeLimit = limit.clamp(1, 12);
      final uri = Uri.parse(
        '${ApiConfig.baseUrl}/Recommendations/products',
      ).replace(queryParameters: {'limit': '$safeLimit'});
      final response = await http.get(
        uri,
        headers: AuthProvider.authenticatedHeaders(),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
          response.statusCode == 401 || response.statusCode == 403
              ? 'You are not authorized to view product recommendations.'
              : 'Product recommendations could not be loaded.',
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! List<dynamic>) {
        throw const FormatException(
          'Unexpected product recommendation response.',
        );
      }
      items = decoded
          .map(
            (item) =>
                ProductRecommendation.fromJson(item as Map<String, dynamic>),
          )
          .toList(growable: false);
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Best-effort interaction telemetry. A failed analytics request must never
  /// stop a player from opening or buying a product.
  Future<void> recordClick(String? exposureId) async {
    if (exposureId == null || exposureId.trim().isEmpty) return;

    try {
      final response = await http.post(
        Uri.parse(
          '${ApiConfig.baseUrl}/Recommendations/products/$exposureId/click',
        ),
        headers: AuthProvider.authenticatedHeaders(),
      );
      // 404 is intentionally silent too: exposure identifiers can expire or
      // belong to a prior authenticated session after a refresh.
      if (response.statusCode < 200 || response.statusCode >= 300) return;
    } catch (_) {
      // Telemetry is intentionally non-blocking for the shop experience.
    }
  }
}
