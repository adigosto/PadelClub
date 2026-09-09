import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:padelclub_desktop/core/network/api_error.dart';
import 'package:padelclub_desktop/core/network/api_config.dart';
import 'package:padelclub_desktop/features/product/domain/entities/product.dart';
import 'package:padelclub_desktop/providers/auth_provider.dart';

class CartLine {
  const CartLine({
    required this.product,
    required this.quantity,
    this.recommendationExposureId,
  });

  final Product product;
  final int quantity;
  final String? recommendationExposureId;

  double get total => product.price * quantity;
}

class CartProvider extends ChangeNotifier {
  CartProvider({http.Client? client}) : _client = client ?? http.Client();

  final Map<int, CartLine> _lines = {};
  final http.Client _client;
  bool isCheckingOut = false;
  String? checkoutError;
  String? _checkoutIdempotencyKey;

  List<CartLine> get lines => _lines.values.toList(growable: false);
  int get itemCount =>
      _lines.values.fold(0, (sum, line) => sum + line.quantity);
  double get total => _lines.values.fold(0, (sum, line) => sum + line.total);

  int quantityFor(Product product) => _lines[product.id]?.quantity ?? 0;

  void add(Product product, {String? recommendationExposureId}) {
    final id = product.id;
    if (id == null || product.stockQuantity <= 0) return;
    final current = _lines[id];
    final quantity = (current?.quantity ?? 0) + 1;
    if (quantity > product.stockQuantity) return;
    _lines[id] = CartLine(
      product: product,
      quantity: quantity,
      // Keep an existing attribution, but allow a recommendation card to
      // enrich a product that was first added from regular catalog browsing.
      recommendationExposureId:
          current?.recommendationExposureId ?? recommendationExposureId,
    );
    notifyListeners();
  }

  void decrement(Product product) {
    final id = product.id;
    if (id == null) return;
    final current = _lines[id];
    if (current == null) return;
    if (current.quantity <= 1) {
      _lines.remove(id);
    } else {
      _lines[id] = CartLine(
        product: product,
        quantity: current.quantity - 1,
        recommendationExposureId: current.recommendationExposureId,
      );
    }
    notifyListeners();
  }

  void remove(Product product) {
    if (_lines.remove(product.id) != null) notifyListeners();
  }

  void clear() {
    if (_lines.isEmpty) return;
    _lines.clear();
    notifyListeners();
  }

  Future<String?> checkout({
    required String recipientName,
    required String phoneNumber,
    required String shippingAddress,
    required String city,
    required String postalCode,
    String? couponCode,
    String? notes,
  }) async {
    if (_lines.isEmpty || isCheckingOut) return null;
    isCheckingOut = true;
    checkoutError = null;
    final idempotencyKey = _checkoutIdempotencyKey ??=
        'checkout-${DateTime.now().microsecondsSinceEpoch}';
    notifyListeners();
    try {
      final response = await _client.post(
        Uri.parse('${ApiConfig.baseUrl}/Orders/checkout'),
        headers: AuthProvider.authenticatedHeaders(),
        body: jsonEncode({
          'idempotencyKey': idempotencyKey,
          'recipientName': recipientName.trim(),
          'phoneNumber': phoneNumber.trim(),
          'shippingAddress': shippingAddress.trim(),
          'city': city.trim(),
          'postalCode': postalCode.trim(),
          'couponCode': couponCode?.trim().isEmpty ?? true
              ? null
              : couponCode!.trim(),
          'notes': notes?.trim(),
          'items': _lines.values
              .map(
                (line) => {
                  'productId': line.product.id,
                  'quantity': line.quantity,
                  if (line.recommendationExposureId != null)
                    'recommendationExposureId': line.recommendationExposureId,
                },
              )
              .toList(growable: false),
        }),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
          response.body.trim().isEmpty
              ? 'The order could not be submitted.'
              : apiErrorMessage(response.body),
        );
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final orderNumber = data['orderNumber'] as String?;
      _lines.clear();
      _checkoutIdempotencyKey = null;
      return orderNumber;
    } catch (error) {
      checkoutError = error.toString().replaceFirst('Exception: ', '');
      return null;
    } finally {
      isCheckingOut = false;
      notifyListeners();
    }
  }
}
