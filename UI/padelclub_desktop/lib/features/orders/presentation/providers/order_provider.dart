import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:padelclub_desktop/core/network/api_config.dart';
import 'package:padelclub_desktop/features/orders/data/models/order_model.dart';
import 'package:padelclub_desktop/features/orders/domain/entities/order.dart';
import 'package:padelclub_desktop/providers/auth_provider.dart';

/// Provides the staff order work queue and the narrow fulfilment transition
/// supported by the desktop app. The API remains authoritative: successful
/// mutations are always followed by a fresh admin order query.
class OrderProvider extends ChangeNotifier {
  OrderProvider({
    http.Client? client,
    String? baseUrl,
    Map<String, String> Function()? headersProvider,
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null,
       _baseUrl = baseUrl ?? ApiConfig.baseUrl,
       _headersProvider = headersProvider ?? AuthProvider.authenticatedHeaders;

  static const Map<String, List<String>> _nextStatusesByCurrent = {
    'pending': ['Processing', 'Cancelled'],
    'processing': ['Shipped', 'Cancelled'],
    'shipped': ['Delivered'],
    'delivered': [],
    'cancelled': [],
  };

  final http.Client _client;
  final bool _ownsClient;
  final String _baseUrl;
  final Map<String, String> Function() _headersProvider;

  List<Order> orders = const [];
  bool isLoading = false;
  int? updatingOrderId;
  String? errorMessage;

  /// Returns only the next statuses that this UI can submit. Terminal orders
  /// intentionally have no action, and the server repeats all validation.
  static List<String> nextStatusesFor(String currentStatus) {
    final normalized = _normalizeStatus(currentStatus);
    return List.unmodifiable(_nextStatusesByCurrent[normalized] ?? const []);
  }

  bool isUpdating(int orderId) => updatingOrderId == orderId;

  Future<void> loadOrders() async {
    await _load('/Orders');
  }

  Future<void> loadMine() async {
    await _load('/Orders/mine');
  }

  /// Changes one order through the existing full-update API contract.
  ///
  /// `PUT /Orders/{id}` requires fields beyond `status`; this method builds
  /// its payload from the exact order staff selected instead of sending a
  /// partial object that could erase existing values. It returns whether the
  /// server accepted the transition. A follow-up query is attempted before
  /// returning, even when it fails independently.
  Future<bool> updateStatus({
    required Order order,
    required String nextStatus,
  }) async {
    final canonicalStatus = _allowedNextStatus(order.status, nextStatus);
    if (canonicalStatus == null) {
      errorMessage = _transitionError(order.status, nextStatus);
      notifyListeners();
      return false;
    }
    if (updatingOrderId != null || isLoading) {
      errorMessage = 'Wait for the current order operation to finish.';
      notifyListeners();
      return false;
    }

    updatingOrderId = order.id;
    errorMessage = null;
    notifyListeners();
    try {
      final response = await _client.put(
        Uri.parse('$_baseUrl/Orders/${order.id}'),
        headers: {..._headersProvider(), 'Content-Type': 'application/json'},
        body: jsonEncode(
          OrderModel.fromOrder(order).toUpdateJson(status: canonicalStatus),
        ),
      );
      _ensureSuccess(
        response,
        fallback: 'Order status could not be updated.',
        unauthorizedMessage: 'You are not authorized to update orders.',
      );

      _replaceOrder(_responseOrderOrFallback(response, order, canonicalStatus));
      try {
        orders = await _fetch('/Orders');
      } catch (error) {
        // The update response is still authoritative for this order. Surface
        // a separate refresh warning rather than representing a committed
        // change as a failed status transition.
        errorMessage =
            'Order status was updated, but the refreshed work queue could not be loaded: ${_message(error)}';
      }
      return true;
    } catch (error) {
      errorMessage = _message(error);
      return false;
    } finally {
      updatingOrderId = null;
      notifyListeners();
    }
  }

  Future<void> _load(String path) async {
    if (isLoading || updatingOrderId != null) return;
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      orders = await _fetch(path);
    } catch (error) {
      errorMessage = _message(error);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<List<Order>> _fetch(String path) async {
    final uri = Uri.parse('$_baseUrl$path').replace(
      queryParameters: {'PageSize': '200', 'IncludeTotalCount': 'true'},
    );
    final response = await _client.get(uri, headers: _headersProvider());
    _ensureSuccess(
      response,
      fallback: 'Orders could not be loaded.',
      unauthorizedMessage: 'You are not authorized to view orders.',
    );
    final decoded = jsonDecode(response.body);
    final items = decoded is List<dynamic>
        ? decoded
        : (decoded as Map<String, dynamic>)['items'] as List<dynamic>? ??
              const [];
    final parsed =
        items
            .map((item) => OrderModel.fromJson(item as Map<String, dynamic>))
            .toList(growable: false)
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List.unmodifiable(parsed);
  }

  Order _responseOrderOrFallback(
    http.Response response,
    Order original,
    String canonicalStatus,
  ) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return OrderModel.fromJson(decoded);
    } catch (_) {
      // A valid response with an unexpected body is followed by a server read.
    }
    return OrderModel.fromOrder(original, status: canonicalStatus);
  }

  void _replaceOrder(Order updated) {
    final index = orders.indexWhere((order) => order.id == updated.id);
    if (index < 0) return;
    final replacement = List<Order>.of(orders);
    replacement[index] = updated;
    replacement.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    orders = List.unmodifiable(replacement);
  }

  void _ensureSuccess(
    http.Response response, {
    required String fallback,
    required String unauthorizedMessage,
  }) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw Exception(unauthorizedMessage);
    }
    throw Exception(_responseMessage(response, fallback));
  }

  String _responseMessage(http.Response response, String fallback) {
    final body = response.body.trim();
    if (body.isEmpty) return fallback;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        for (final key in ['detail', 'title', 'message']) {
          final value = decoded[key]?.toString().trim();
          if (value != null && value.isNotEmpty) return value;
        }
        // The API's exception filter returns model-state errors as
        // { errors: { validationError: ["..."] } }. Show staff the actual
        // lifecycle conflict instead of a JSON blob inside the dialog.
        final errors = decoded['errors'];
        if (errors is Map) {
          for (final value in errors.values) {
            if (value is Iterable) {
              for (final item in value) {
                final message = item?.toString().trim();
                if (message != null && message.isNotEmpty) return message;
              }
            }
            final message = value?.toString().trim();
            if (message != null && message.isNotEmpty) return message;
          }
        }
      }
    } catch (_) {
      // Plain-text server errors are displayed below.
    }
    return body.replaceAll('"', '');
  }

  String? _allowedNextStatus(String currentStatus, String requestedStatus) {
    final requested = _normalizeStatus(requestedStatus);
    for (final candidate in nextStatusesFor(currentStatus)) {
      if (_normalizeStatus(candidate) == requested) return candidate;
    }
    return null;
  }

  String _transitionError(String currentStatus, String requestedStatus) {
    final allowed = nextStatusesFor(currentStatus);
    if (allowed.isEmpty) {
      return '${_displayStatus(currentStatus)} orders are terminal and cannot be changed.';
    }
    return 'An ${_displayStatus(currentStatus)} order can only move to ${allowed.join(' or ')}.';
  }

  static String _normalizeStatus(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized == 'canceled' ? 'cancelled' : normalized;
  }

  String _displayStatus(String status) {
    final trimmed = status.trim();
    if (trimmed.isEmpty) return 'Unknown';
    return '${trimmed[0].toUpperCase()}${trimmed.substring(1).toLowerCase()}';
  }

  String _message(Object error) =>
      error.toString().replaceFirst('Exception: ', '');

  @override
  void dispose() {
    if (_ownsClient) _client.close();
    super.dispose();
  }
}
