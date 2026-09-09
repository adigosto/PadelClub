import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:padelclub_desktop/core/network/api_config.dart';
import 'package:padelclub_desktop/features/returns/data/models/return_eligible_order_model.dart';
import 'package:padelclub_desktop/features/returns/data/models/return_request_status_model.dart';
import 'package:padelclub_desktop/features/returns/domain/entities/return_eligible_order.dart';
import 'package:padelclub_desktop/providers/auth_provider.dart';

typedef ReturnRequestsHeadersProvider = Map<String, String> Function();

abstract interface class ReturnRequestsRemoteDataSource {
  Future<List<ReturnEligibleOrderModel>> getEligibleOrders();

  Future<ReturnRequestSubmissionModel> createRequest({
    required int orderId,
    required String reason,
    required List<ReturnRequestLine> items,
  });

  Future<List<ReturnRequestStatusModel>> getMine();

  Future<List<ReturnRequestStatusModel>> getAll({String? status});

  Future<void> resolve({
    required int returnRequestId,
    required bool approve,
    String? adminNotes,
  });
}

class ReturnRequestsRemoteDataSourceImpl
    implements ReturnRequestsRemoteDataSource {
  ReturnRequestsRemoteDataSourceImpl({
    http.Client? client,
    String? baseUrl,
    ReturnRequestsHeadersProvider? headersProvider,
  }) : _client = client ?? http.Client(),
       _baseUrl = (baseUrl ?? ApiConfig.baseUrl).replaceFirst(
         RegExp(r'/$'),
         '',
       ),
       _headersProvider = headersProvider ?? AuthProvider.authenticatedHeaders;

  final http.Client _client;
  final String _baseUrl;
  final ReturnRequestsHeadersProvider _headersProvider;

  @override
  Future<List<ReturnEligibleOrderModel>> getEligibleOrders() async {
    final response = await _client
        .get(
          Uri.parse('$_baseUrl/Commerce/returns/eligible-orders/mine'),
          headers: _headersProvider(),
        )
        .timeout(const Duration(seconds: 20));
    return _readList(
      response,
      'load eligible returns',
      ReturnEligibleOrderModel.fromJson,
    );
  }

  @override
  Future<ReturnRequestSubmissionModel> createRequest({
    required int orderId,
    required String reason,
    required List<ReturnRequestLine> items,
  }) async {
    final response = await _client
        .post(
          Uri.parse('$_baseUrl/Commerce/returns'),
          headers: {..._headersProvider(), 'Content-Type': 'application/json'},
          body: jsonEncode({
            'orderId': orderId,
            'reason': reason,
            'items': items
                .map(
                  (item) => {
                    'orderItemId': item.orderItemId,
                    'quantity': item.quantity,
                  },
                )
                .toList(growable: false),
          }),
        )
        .timeout(const Duration(seconds: 20));
    return ReturnRequestSubmissionModel.fromJson(
      _readMap(response, 'submit this return request'),
    );
  }

  @override
  Future<List<ReturnRequestStatusModel>> getMine() async {
    final response = await _client
        .get(
          Uri.parse('$_baseUrl/Commerce/returns/mine'),
          headers: _headersProvider(),
        )
        .timeout(const Duration(seconds: 20));
    return _readList(
      response,
      'load your return status',
      ReturnRequestStatusModel.fromJson,
    );
  }

  @override
  Future<List<ReturnRequestStatusModel>> getAll({String? status}) async {
    final uri = Uri.parse('$_baseUrl/Commerce/returns').replace(
      queryParameters: status == null || status.trim().isEmpty
          ? null
          : {'status': status.trim()},
    );
    final response = await _client
        .get(uri, headers: _headersProvider())
        .timeout(const Duration(seconds: 20));
    return _readList(
      response,
      'load return requests',
      ReturnRequestStatusModel.fromJson,
    );
  }

  @override
  Future<void> resolve({
    required int returnRequestId,
    required bool approve,
    String? adminNotes,
  }) async {
    final trimmedNotes = adminNotes?.trim();
    final response = await _client
        .put(
          Uri.parse('$_baseUrl/Commerce/returns/$returnRequestId/resolve'),
          headers: {..._headersProvider(), 'Content-Type': 'application/json'},
          body: jsonEncode({
            'approve': approve,
            if (trimmedNotes != null && trimmedNotes.isNotEmpty)
              'adminNotes': trimmedNotes,
          }),
        )
        .timeout(const Duration(seconds: 20));
    _ensureSuccess(response, 'resolve this return request');
  }

  List<T> _readList<T>(
    http.Response response,
    String action,
    T Function(Map<String, dynamic> json) fromJson,
  ) {
    _ensureSuccess(response, action);
    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw FormatException('$action returned an invalid response.');
    }
    return decoded
        .map((entry) {
          if (entry is! Map) {
            throw FormatException('$action returned an invalid entry.');
          }
          return fromJson(Map<String, dynamic>.from(entry));
        })
        .toList(growable: false);
  }

  Map<String, dynamic> _readMap(http.Response response, String action) {
    _ensureSuccess(response, action);
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw FormatException('$action returned an invalid response.');
    }
    return Map<String, dynamic>.from(decoded);
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
        'This return information is no longer available. Refresh and try again.',
      );
    }
    if (response.statusCode == 409) {
      throw StateError(
        'This return changed before it could be completed. Refresh and review the current status.',
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
      // Validation and conflict responses may be plain text.
    }
    return trimmed.length <= 240 ? trimmed : null;
  }
}
