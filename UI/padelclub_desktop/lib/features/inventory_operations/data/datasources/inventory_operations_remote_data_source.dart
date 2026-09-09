import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:padelclub_desktop/core/network/api_config.dart';
import 'package:padelclub_desktop/features/inventory_operations/data/models/inventory_movement_model.dart';
import 'package:padelclub_desktop/providers/auth_provider.dart';

typedef InventoryOperationsHeadersProvider = Map<String, String> Function();

abstract interface class InventoryOperationsRemoteDataSource {
  Future<void> adjustStock({
    required int productId,
    required int quantityChange,
    required String reason,
  });

  Future<List<InventoryMovementModel>> getHistory(int productId);
}

class InventoryOperationsRemoteDataSourceImpl
    implements InventoryOperationsRemoteDataSource {
  InventoryOperationsRemoteDataSourceImpl({
    http.Client? client,
    String? baseUrl,
    InventoryOperationsHeadersProvider? headersProvider,
  }) : _client = client ?? http.Client(),
       _baseUrl = (baseUrl ?? ApiConfig.baseUrl).replaceFirst(
         RegExp(r'/$'),
         '',
       ),
       _headersProvider = headersProvider ?? AuthProvider.authenticatedHeaders;

  final http.Client _client;
  final String _baseUrl;
  final InventoryOperationsHeadersProvider _headersProvider;

  @override
  Future<void> adjustStock({
    required int productId,
    required int quantityChange,
    required String reason,
  }) async {
    final response = await _client
        .post(
          Uri.parse('$_baseUrl/Commerce/inventory/$productId/adjust'),
          headers: {..._headersProvider(), 'Content-Type': 'application/json'},
          body: jsonEncode({
            'quantityChange': quantityChange,
            'reason': reason,
          }),
        )
        .timeout(const Duration(seconds: 20));
    _ensureSuccess(response, 'adjust stock');
  }

  @override
  Future<List<InventoryMovementModel>> getHistory(int productId) async {
    final response = await _client
        .get(
          Uri.parse('$_baseUrl/Commerce/inventory/$productId/history'),
          headers: _headersProvider(),
        )
        .timeout(const Duration(seconds: 20));
    _ensureSuccess(response, 'load inventory history');

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw const FormatException(
        'Inventory history returned an invalid response.',
      );
    }
    return decoded
        .map((entry) {
          if (entry is! Map<String, dynamic>) {
            throw const FormatException(
              'Inventory history contains an invalid entry.',
            );
          }
          return InventoryMovementModel.fromJson(entry);
        })
        .toList(growable: false);
  }

  void _ensureSuccess(http.Response response, String action) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;

    final detail = _detail(response.body);
    if (detail != null) throw StateError(detail);
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw StateError('You are not authorized to $action.');
    }
    if (response.statusCode == 404) {
      throw StateError(
        'This product is no longer available. Refresh the list.',
      );
    }
    if (response.statusCode == 409) {
      throw StateError(
        'Stock changed before this adjustment. Refresh and try again.',
      );
    }
    throw StateError('Could not $action. Please try again.');
  }

  String? _detail(String responseBody) {
    final trimmed = responseBody.trim();
    if (trimmed.isEmpty) return null;

    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is String && decoded.trim().isNotEmpty) return decoded.trim();
      if (decoded case {
        'detail': String detail,
      } when detail.trim().isNotEmpty) {
        return detail.trim();
      }
      if (decoded case {'title': String title} when title.trim().isNotEmpty) {
        return title.trim();
      }
    } on FormatException {
      // The API's validation and conflict responses are plain text.
    }
    return trimmed.length <= 240 ? trimmed : null;
  }
}
