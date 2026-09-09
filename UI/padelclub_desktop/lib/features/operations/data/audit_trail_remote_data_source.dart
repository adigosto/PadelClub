import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:padelclub_desktop/core/network/api_config.dart';
import 'package:padelclub_desktop/features/operations/domain/entities/audit_log_entry.dart';
import 'package:padelclub_desktop/features/operations/domain/entities/audit_trail_filter.dart';
import 'package:padelclub_desktop/providers/auth_provider.dart';

typedef AuditTrailHeadersProvider = Map<String, String> Function();

abstract interface class AuditTrailRemoteDataSource {
  Future<List<AuditLogEntry>> getAuditEntries({
    AuditTrailFilter filter = const AuditTrailFilter(),
  });
}

/// Read-only client for the administrator audit evidence endpoint.
class AuditTrailRemoteDataSourceImpl implements AuditTrailRemoteDataSource {
  AuditTrailRemoteDataSourceImpl({
    http.Client? client,
    String? baseUrl,
    AuditTrailHeadersProvider? headersProvider,
  }) : _client = client ?? http.Client(),
       _baseUrl = (baseUrl ?? ApiConfig.baseUrl).replaceFirst(
         RegExp(r'/$'),
         '',
       ),
       _headersProvider = headersProvider ?? AuthProvider.authenticatedHeaders;

  final http.Client _client;
  final String _baseUrl;
  final AuditTrailHeadersProvider _headersProvider;

  @override
  Future<List<AuditLogEntry>> getAuditEntries({
    AuditTrailFilter filter = const AuditTrailFilter(),
  }) async {
    final queryParameters = filter.toQueryParameters();
    final uri = Uri.parse('$_baseUrl/Operations/audit').replace(
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    );
    final response = await _client
        .get(uri, headers: _headersProvider())
        .timeout(const Duration(seconds: 20));
    _ensureSuccess(response);

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw const FormatException('Audit trail returned an invalid response.');
    }
    return decoded
        .map((entry) {
          if (entry is! Map) {
            throw const FormatException(
              'Audit trail contains an invalid event.',
            );
          }
          return AuditLogEntry.fromJson(Map<String, dynamic>.from(entry));
        })
        .toList(growable: false);
  }

  void _ensureSuccess(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;

    final detail = _detail(response.body);
    if (detail != null) throw StateError(detail);
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw StateError('You are not authorized to view the audit trail.');
    }
    throw StateError('Audit trail could not be loaded. Please try again.');
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
      // Some ASP.NET error responses are plain text.
    }
    return trimmed.length <= 240 ? trimmed : null;
  }
}
