import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:padelclub_desktop/core/network/api_config.dart';
import 'package:padelclub_desktop/features/orders/data/models/order_model.dart';
import 'package:padelclub_desktop/features/orders/domain/entities/order.dart';
import 'package:padelclub_desktop/providers/auth_provider.dart';

class OrderProvider extends ChangeNotifier {
  List<Order> orders = const [];
  bool isLoading = false;
  String? errorMessage;

  Future<void> loadOrders() async {
    await _load('/Orders');
  }

  Future<void> loadMine() async {
    await _load('/Orders/mine');
  }

  Future<void> _load(String path) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}$path').replace(
        queryParameters: {'PageSize': '200', 'IncludeTotalCount': 'true'},
      );
      final response = await http.get(
        uri,
        headers: AuthProvider.authenticatedHeaders(),
      );
      _ensureSuccess(response);
      final decoded = jsonDecode(response.body);
      final items = decoded is List<dynamic>
          ? decoded
          : (decoded as Map<String, dynamic>)['items'] as List<dynamic>? ??
                const [];
      orders =
          items
              .map((item) => OrderModel.fromJson(item as Map<String, dynamic>))
              .toList(growable: false)
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void _ensureSuccess(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw Exception('You are not authorized to view orders.');
    }
    throw Exception(
      response.body.trim().isEmpty
          ? 'Orders could not be loaded.'
          : response.body.replaceAll('"', ''),
    );
  }
}
