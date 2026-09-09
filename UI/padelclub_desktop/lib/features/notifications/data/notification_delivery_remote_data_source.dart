import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:padelclub_desktop/core/network/api_config.dart';
import 'package:padelclub_desktop/features/notifications/domain/entities/notification_delivery.dart';
import 'package:padelclub_desktop/providers/auth_provider.dart';

typedef NotificationDeliveryHeadersProvider = Map<String, String> Function();

abstract interface class NotificationDeliveryRemoteDataSource {
  Future<List<NotificationDelivery>> getDeliveries({String? status});
}

/// Read-only administrator client for persisted delivery-attempt diagnostics.
class NotificationDeliveryRemoteDataSourceImpl
    implements NotificationDeliveryRemoteDataSource {
  NotificationDeliveryRemoteDataSourceImpl({
    http.Client? client,
    String? baseUrl,
    NotificationDeliveryHeadersProvider? headersProvider,
  }) : _client = client ?? http.Client(),
       _baseUrl = (baseUrl ?? ApiConfig.baseUrl).replaceFirst(
         RegExp(r'/$'),
         '',
       ),
       _headersProvider = headersProvider ?? AuthProvider.authenticatedHeaders;

  final http.Client _client;
  final String _baseUrl;
  final NotificationDeliveryHeadersProvider _headersProvider;

  @override
  Future<List<NotificationDelivery>> getDeliveries({String? status}) async {
    final normalizedStatus = status?.trim();
    final uri = Uri.parse('$_baseUrl/NotificationSettings/deliveries').replace(
      queryParameters: normalizedStatus == null || normalizedStatus.isEmpty
          ? null
          : {'status': normalizedStatus},
    );
    final response = await _client
        .get(uri, headers: _headersProvider())
        .timeout(const Duration(seconds: 20));
    _ensureSuccess(response);

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw const FormatException(
        'Delivery diagnostics returned an invalid response.',
      );
    }
    return decoded
        .map((entry) {
          if (entry is! Map) {
            throw const FormatException(
              'Delivery diagnostics contain an invalid record.',
            );
          }
          return NotificationDelivery.fromJson(
            Map<String, dynamic>.from(entry),
          );
        })
        .toList(growable: false);
  }

  void _ensureSuccess(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;

    final detail = _detail(response.body);
    if (detail != null) throw StateError(detail);
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw StateError('You are not authorized to view delivery diagnostics.');
    }
    throw StateError(
      'Delivery diagnostics could not be loaded. Please try again.',
    );
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
      // ASP.NET can return plain-text error details.
    }
    return trimmed.length <= 240 ? trimmed : null;
  }
}
