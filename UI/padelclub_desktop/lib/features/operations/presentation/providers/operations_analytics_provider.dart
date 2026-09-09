import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:padelclub_desktop/core/network/api_config.dart';
import 'package:padelclub_desktop/providers/auth_provider.dart';

/// Live, administrator-only values returned by GET /Operations/analytics.
class OperationsAnalytics {
  const OperationsAnalytics({
    required this.orders,
    required this.orderRevenue,
    required this.reservations,
    required this.cancelledReservations,
    required this.activeMemberships,
    required this.lowStockProducts,
  });

  final int orders;
  final double orderRevenue;
  final int reservations;
  final int cancelledReservations;
  final int activeMemberships;
  final int lowStockProducts;

  factory OperationsAnalytics.fromJson(Map<String, dynamic> json) {
    int asInt(Object? value) => value is num ? value.toInt() : 0;
    double asDouble(Object? value) => value is num ? value.toDouble() : 0;

    return OperationsAnalytics(
      orders: asInt(json['orders']),
      orderRevenue: asDouble(json['orderRevenue']),
      reservations: asInt(json['reservations']),
      cancelledReservations: asInt(json['cancelledReservations']),
      activeMemberships: asInt(json['activeMemberships']),
      lowStockProducts: asInt(json['lowStockProducts']),
    );
  }
}

class OperationsAnalyticsProvider extends ChangeNotifier {
  OperationsAnalytics? _analytics;
  bool _isLoading = false;
  String? _errorMessage;

  OperationsAnalytics? get analytics => _analytics;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> load() async {
    if (_isLoading) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/Operations/analytics'),
        headers: AuthProvider.authenticatedHeaders(),
      );
      if (response.statusCode != 200) {
        throw StateError(
          'Operations analytics returned ${response.statusCode}.',
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException(
          'Operations analytics returned an invalid response.',
        );
      }

      _analytics = OperationsAnalytics.fromJson(decoded);
    } catch (error) {
      _analytics = null;
      _errorMessage = 'Live operations data could not be loaded.';
      debugPrint('Operations analytics request failed: $error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
