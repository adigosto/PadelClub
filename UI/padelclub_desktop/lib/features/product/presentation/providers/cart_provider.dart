import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:padelclub_desktop/core/network/api_config.dart';
import 'package:padelclub_desktop/features/product/domain/entities/product.dart';
import 'package:padelclub_desktop/providers/auth_provider.dart';

class CartLine {
  const CartLine({required this.product, required this.quantity});

  final Product product;
  final int quantity;

  double get total => product.price * quantity;
}

class CartProvider extends ChangeNotifier {
  final Map<int, CartLine> _lines = {};
  bool isCheckingOut = false;
  String? checkoutError;

  List<CartLine> get lines => _lines.values.toList(growable: false);
  int get itemCount =>
      _lines.values.fold(0, (sum, line) => sum + line.quantity);
  double get total => _lines.values.fold(0, (sum, line) => sum + line.total);

  int quantityFor(Product product) => _lines[product.id]?.quantity ?? 0;

  void add(Product product) {
    final id = product.id;
    if (id == null || product.stockQuantity <= 0) return;
    final current = _lines[id];
    final quantity = (current?.quantity ?? 0) + 1;
    if (quantity > product.stockQuantity) return;
    _lines[id] = CartLine(product: product, quantity: quantity);
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
      _lines[id] = CartLine(product: product, quantity: current.quantity - 1);
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
    String? notes,
  }) async {
    if (_lines.isEmpty || isCheckingOut) return null;
    isCheckingOut = true;
    checkoutError = null;
    notifyListeners();
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/Orders/checkout'),
        headers: AuthProvider.authenticatedHeaders(),
        body: jsonEncode({
          'recipientName': recipientName.trim(),
          'phoneNumber': phoneNumber.trim(),
          'shippingAddress': shippingAddress.trim(),
          'city': city.trim(),
          'postalCode': postalCode.trim(),
          'notes': notes?.trim(),
          'items': _lines.values
              .map(
                (line) => {
                  'productId': line.product.id,
                  'quantity': line.quantity,
                },
              )
              .toList(growable: false),
        }),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
          response.body.trim().isEmpty
              ? 'The order could not be submitted.'
              : response.body.replaceAll('"', ''),
        );
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final orderNumber = data['orderNumber'] as String?;
      _lines.clear();
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
