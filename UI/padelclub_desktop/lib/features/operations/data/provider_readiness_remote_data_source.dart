import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:padelclub_desktop/core/network/api_config.dart';
import 'package:padelclub_desktop/features/operations/domain/entities/provider_readiness.dart';
import 'package:padelclub_desktop/providers/auth_provider.dart';

typedef ProviderReadinessHeadersProvider = Map<String, String> Function();

abstract interface class ProviderReadinessRemoteDataSource {
  Future<ProviderReadiness> getReadiness();
}

/// Read-only client for the administrator provider-readiness endpoint.
class ProviderReadinessRemoteDataSourceImpl
    implements ProviderReadinessRemoteDataSource {
  ProviderReadinessRemoteDataSourceImpl({
    http.Client? client,
    String? baseUrl,
    ProviderReadinessHeadersProvider? headersProvider,
  }) : _client = client ?? http.Client(),
       _baseUrl = (baseUrl ?? ApiConfig.baseUrl).replaceFirst(
         RegExp(r'/$'),
         '',
       ),
       _headersProvider = headersProvider ?? AuthProvider.authenticatedHeaders;

  final http.Client _client;
  final String _baseUrl;
  final ProviderReadinessHeadersProvider _headersProvider;

  @override
  Future<ProviderReadiness> getReadiness() async {
    final response = await _client
        .get(
          Uri.parse('$_baseUrl/Operations/provider-readiness'),
          headers: _headersProvider(),
        )
        .timeout(const Duration(seconds: 20));
    _ensureSuccess(response);

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const FormatException(
        'Provider readiness returned an invalid response.',
      );
    }
    return ProviderReadiness.fromJson(Map<String, dynamic>.from(decoded));
  }

  void _ensureSuccess(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;

    final detail = _detail(response.body);
    if (detail != null) throw StateError(detail);
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw StateError('You are not authorized to view provider readiness.');
    }
    throw StateError(
      'Provider readiness could not be loaded. Please try again.',
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
      // ASP.NET error responses may be plain text.
    }
    return trimmed.length <= 240 ? trimmed : null;
  }
}
