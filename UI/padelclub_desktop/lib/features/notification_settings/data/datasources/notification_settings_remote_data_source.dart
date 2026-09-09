import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:padelclub_desktop/core/network/api_config.dart';
import 'package:padelclub_desktop/features/notification_settings/data/models/notification_preferences_model.dart';

typedef NotificationSettingsHeadersProvider = Map<String, String> Function();

abstract interface class NotificationSettingsRemoteDataSource {
  Future<NotificationPreferencesModel> getMine();

  Future<NotificationPreferencesModel> saveMine(
    NotificationPreferencesModel preferences,
  );
}

class NotificationSettingsRemoteDataSourceImpl
    implements NotificationSettingsRemoteDataSource {
  NotificationSettingsRemoteDataSourceImpl({
    required this.headersProvider,
    http.Client? client,
    String? baseUrl,
  }) : _client = client ?? http.Client(),
       _baseUrl = baseUrl ?? ApiConfig.baseUrl;

  final NotificationSettingsHeadersProvider headersProvider;
  final http.Client _client;
  final String _baseUrl;

  @override
  Future<NotificationPreferencesModel> getMine() async {
    final response = await _client
        .get(
          Uri.parse('$_baseUrl/NotificationSettings/mine'),
          headers: headersProvider(),
        )
        .timeout(const Duration(seconds: 20));
    return _read(response, 'load notification preferences');
  }

  @override
  Future<NotificationPreferencesModel> saveMine(
    NotificationPreferencesModel preferences,
  ) async {
    final response = await _client
        .put(
          Uri.parse('$_baseUrl/NotificationSettings/mine'),
          headers: {...headersProvider(), 'Content-Type': 'application/json'},
          body: jsonEncode(preferences.toJson()),
        )
        .timeout(const Duration(seconds: 20));
    return _read(response, 'save notification preferences');
  }

  NotificationPreferencesModel _read(http.Response response, String action) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        response.statusCode == 401 || response.statusCode == 403
            ? 'You are not authorized to $action.'
            : 'Could not $action.',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw FormatException('$action returned an invalid response.');
    }
    return NotificationPreferencesModel.fromJson(decoded);
  }
}
