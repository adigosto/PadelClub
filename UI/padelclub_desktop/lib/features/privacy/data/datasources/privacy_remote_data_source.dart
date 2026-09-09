import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:padelclub_desktop/core/network/api_config.dart';
import 'package:padelclub_desktop/features/privacy/data/models/privacy_deletion_status_model.dart';

typedef PrivacyHeadersProvider = Map<String, String> Function();

abstract interface class PrivacyRemoteDataSource {
  Future<Map<String, dynamic>> exportMine();

  Future<PrivacyDeletionStatusModel?> getDeletionStatus();

  Future<PrivacyDeletionStatusModel> requestDeletion();

  Future<void> cancelDeletion();
}

class PrivacyRemoteDataSourceImpl implements PrivacyRemoteDataSource {
  PrivacyRemoteDataSourceImpl({
    required this.headersProvider,
    http.Client? client,
    String? baseUrl,
  }) : _client = client ?? http.Client(),
       _baseUrl = baseUrl ?? ApiConfig.baseUrl;

  final PrivacyHeadersProvider headersProvider;
  final http.Client _client;
  final String _baseUrl;

  @override
  Future<Map<String, dynamic>> exportMine() async {
    final response = await _client
        .get(Uri.parse('$_baseUrl/Privacy/export'), headers: headersProvider())
        .timeout(const Duration(seconds: 20));
    return _readMap(response, 'view your data export');
  }

  @override
  Future<PrivacyDeletionStatusModel?> getDeletionStatus() async {
    final response = await _client
        .get(
          Uri.parse('$_baseUrl/Privacy/deletion'),
          headers: headersProvider(),
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode == 204) return null;
    return PrivacyDeletionStatusModel.fromJson(
      _readMap(response, 'load account-deletion status'),
    );
  }

  @override
  Future<PrivacyDeletionStatusModel> requestDeletion() async {
    final response = await _client
        .post(
          Uri.parse('$_baseUrl/Privacy/deletion'),
          headers: headersProvider(),
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode == 409) {
      throw StateError('Account deletion is already scheduled.');
    }
    return PrivacyDeletionStatusModel.fromJson(
      _readMap(response, 'schedule account deletion'),
    );
  }

  @override
  Future<void> cancelDeletion() async {
    final response = await _client
        .delete(
          Uri.parse('$_baseUrl/Privacy/deletion'),
          headers: headersProvider(),
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode == 404) {
      throw StateError('There is no scheduled account deletion to cancel.');
    }
    _ensureSuccess(response, 'cancel scheduled account deletion');
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
    throw StateError(
      response.statusCode == 401 || response.statusCode == 403
          ? 'You are not authorized to $action.'
          : 'Could not $action.',
    );
  }
}
