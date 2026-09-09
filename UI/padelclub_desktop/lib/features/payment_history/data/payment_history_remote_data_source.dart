import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:padelclub_desktop/core/network/api_config.dart';
import 'package:padelclub_desktop/features/payment_history/domain/entities/payment_history_entry.dart';
import 'package:padelclub_desktop/providers/auth_provider.dart';

typedef PaymentHistoryHeadersProvider = Map<String, String> Function();

abstract interface class PaymentHistoryRemoteDataSource {
  Future<PaymentHistoryPage> getMyPayments({int page, int pageSize});
}

/// Read-only owner-scoped client. It intentionally never calls the admin
/// `/Payments` endpoint or any Stripe mutation endpoint.
class PaymentHistoryRemoteDataSourceImpl
    implements PaymentHistoryRemoteDataSource {
  PaymentHistoryRemoteDataSourceImpl({
    http.Client? client,
    String? baseUrl,
    PaymentHistoryHeadersProvider? headersProvider,
  }) : _client = client ?? http.Client(),
       _baseUrl = (baseUrl ?? ApiConfig.baseUrl).replaceFirst(
         RegExp(r'/$'),
         '',
       ),
       _headersProvider = headersProvider ?? AuthProvider.authenticatedHeaders;

  final http.Client _client;
  final String _baseUrl;
  final PaymentHistoryHeadersProvider _headersProvider;

  @override
  Future<PaymentHistoryPage> getMyPayments({
    int page = 1,
    int pageSize = 100,
  }) async {
    final uri = Uri.parse('$_baseUrl/Payments/mine').replace(
      queryParameters: {
        'Page': '${page.clamp(1, 100000)}',
        'PageSize': '${pageSize.clamp(1, 200)}',
        'IncludeTotalCount': 'true',
      },
    );
    final response = await _client
        .get(uri, headers: _headersProvider())
        .timeout(const Duration(seconds: 20));
    _ensureSuccess(response);

    final decoded = jsonDecode(response.body);
    final (items, totalCount) = switch (decoded) {
      {'items': List items, 'totalCount': num totalCount} => (
        items,
        totalCount.toInt(),
      ),
      {'items': List items} => (items, null),
      List items => (items, null),
      _ => throw const FormatException(
        'Payment history returned an invalid response.',
      ),
    };
    return PaymentHistoryPage(
      items: items
          .map((entry) {
            if (entry is! Map) {
              throw const FormatException(
                'Payment history contains an invalid record.',
              );
            }
            return PaymentHistoryEntry.fromJson(
              Map<String, dynamic>.from(entry),
            );
          })
          .toList(growable: false),
      totalCount: totalCount,
    );
  }

  void _ensureSuccess(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    final detail = _detail(response.body);
    if (detail != null) throw StateError(detail);
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw StateError('You are not authorized to view your payment history.');
    }
    throw StateError('Payment history could not be loaded. Please try again.');
  }

  String? _detail(String body) {
    final trimmed = body.trim();
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
      // Some server errors are returned as plain text.
    }
    return trimmed.length <= 240 ? trimmed : null;
  }
}
