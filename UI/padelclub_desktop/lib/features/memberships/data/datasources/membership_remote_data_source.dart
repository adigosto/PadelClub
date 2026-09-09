import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:padelclub_desktop/core/network/api_error.dart';
import 'package:padelclub_desktop/core/network/api_config.dart';
import 'package:padelclub_desktop/features/memberships/data/models/membership_event_model.dart';
import 'package:padelclub_desktop/features/memberships/data/models/membership_model.dart';
import 'package:padelclub_desktop/features/memberships/domain/entities/membership_event.dart';
import 'package:padelclub_desktop/features/memberships/domain/entities/membership_page.dart';
import 'package:padelclub_desktop/providers/auth_provider.dart';

typedef MembershipHeadersProvider = Map<String, String> Function();

abstract interface class MembershipRemoteDataSource {
  Future<MembershipPage> getMine({Map<String, dynamic>? filter});

  Future<void> cancelAtPeriodEnd(int membershipId);

  Future<void> setAutoRenew(int membershipId, bool enabled);

  Future<List<MembershipEvent>> getHistory(int membershipId);
}

/// Authenticated, player-scoped membership API client.
///
/// It deliberately only calls `/Memberships/mine`; a desktop player must never
/// receive the administrative membership collection just because their account
/// happens to have an administrative role.
class MembershipRemoteDataSourceImpl implements MembershipRemoteDataSource {
  MembershipRemoteDataSourceImpl({
    http.Client? client,
    String? baseUrl,
    MembershipHeadersProvider? headersProvider,
  }) : _client = client ?? http.Client(),
       _baseUrl = baseUrl ?? ApiConfig.baseUrl,
       _headersProvider = headersProvider ?? AuthProvider.authenticatedHeaders;

  final http.Client _client;
  final String _baseUrl;
  final MembershipHeadersProvider _headersProvider;

  @override
  Future<MembershipPage> getMine({Map<String, dynamic>? filter}) async {
    final uri = Uri.parse(
      '$_baseUrl/Memberships/mine',
    ).replace(queryParameters: _queryParameters(filter));
    final response = await _client
        .get(uri, headers: _headersProvider())
        .timeout(const Duration(seconds: 20));
    _requireSuccess(response, 'load your memberships');

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Memberships returned an invalid paged response.',
      );
    }
    final rawItems = decoded['items'];
    if (rawItems is! List<dynamic>) {
      throw const FormatException(
        'Memberships response did not contain an items list.',
      );
    }
    final items = <MembershipModel>[];
    for (final rawItem in rawItems) {
      if (rawItem is! Map<String, dynamic>) {
        throw const FormatException(
          'Memberships response contained an invalid membership record.',
        );
      }
      items.add(MembershipModel.fromJson(rawItem));
    }
    final rawTotalCount = decoded['totalCount'];
    if (rawTotalCount != null && rawTotalCount is! int) {
      throw const FormatException(
        'Memberships response contained an invalid total count.',
      );
    }
    return MembershipPage(items: items, totalCount: rawTotalCount);
  }

  @override
  Future<void> cancelAtPeriodEnd(int membershipId) async {
    final response = await _client
        .put(
          Uri.parse('$_baseUrl/Memberships/$membershipId/cancel-at-period-end'),
          headers: _headersProvider(),
        )
        .timeout(const Duration(seconds: 20));
    _requireSuccess(response, 'schedule the membership cancellation');
  }

  @override
  Future<void> setAutoRenew(int membershipId, bool enabled) async {
    final response = await _client
        .put(
          Uri.parse('$_baseUrl/Memberships/$membershipId/auto-renew'),
          headers: {..._headersProvider(), 'Content-Type': 'application/json'},
          body: jsonEncode({'enabled': enabled}),
        )
        .timeout(const Duration(seconds: 20));
    _requireSuccess(response, 'change automatic renewal');
  }

  @override
  Future<List<MembershipEvent>> getHistory(int membershipId) async {
    final response = await _client
        .get(
          Uri.parse('$_baseUrl/Memberships/$membershipId/history'),
          headers: _headersProvider(),
        )
        .timeout(const Duration(seconds: 20));
    _requireSuccess(response, 'load membership activity');
    final decoded = jsonDecode(response.body);
    if (decoded is! List<dynamic>) {
      throw const FormatException(
        'Membership activity returned an invalid response.',
      );
    }
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(MembershipEventModel.fromJson)
        .toList(growable: false);
  }

  static Map<String, String>? _queryParameters(Map<String, dynamic>? filter) {
    if (filter == null || filter.isEmpty) return null;
    final parameters = <String, String>{};
    filter.forEach((key, value) {
      if (value == null) return;
      parameters[key] = value is DateTime
          ? value.toIso8601String()
          : value.toString();
    });
    return parameters.isEmpty ? null : parameters;
  }

  static void _requireSuccess(http.Response response, String action) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    throw StateError(_responseMessage(response, action));
  }

  static String _responseMessage(http.Response response, String action) {
    return apiErrorMessage(response.body, fallback: 'Could not $action. Please try again.');
  }
}
