import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:padelclub_desktop/core/network/api_config.dart';
import 'package:padelclub_desktop/features/memberships/data/models/membership_event_model.dart';
import 'package:padelclub_desktop/features/memberships/data/models/membership_model.dart';
import 'package:padelclub_desktop/features/memberships/domain/entities/membership_event.dart';
import 'package:padelclub_desktop/features/memberships/domain/entities/membership_page.dart';
import 'package:padelclub_desktop/features/memberships/domain/entities/membership_type_reference.dart';
import 'package:padelclub_desktop/providers/auth_provider.dart';

typedef AdminMembershipHeadersProvider = Map<String, String> Function();

/// The only lifecycle states a staff member can select in the desktop UI.
///
/// The API remains authoritative, including for legacy lifecycle values such as
/// `Expired` or `RenewalDue` that can be produced by the scheduled worker.
enum MembershipLifecycleStatus {
  active('Active'),
  suspended('Suspended'),
  cancelled('Cancelled');

  const MembershipLifecycleStatus(this.label);

  final String label;
}

/// A narrowly scoped administrative membership API contract.
///
/// It is deliberately separate from the player-scoped membership client so a
/// player-facing screen cannot accidentally start querying `/Memberships`.
abstract interface class AdminMembershipRemoteDataSource {
  Future<MembershipPage> getMemberships({
    required int page,
    required int pageSize,
    String? membershipType,
    int? membershipTypeReferenceId,
    bool? isActive,
  });

  Future<List<MembershipTypeReference>> getMembershipTypes();

  Future<void> changeStatus({
    required int membershipId,
    required MembershipLifecycleStatus status,
    String? notes,
  });

  /// Extends a membership record. It does not take payment information.
  Future<void> renewMembership({
    required int membershipId,
    required int months,
  });

  Future<List<MembershipEvent>> getHistory(int membershipId);
}

class AdminMembershipRemoteDataSourceImpl
    implements AdminMembershipRemoteDataSource {
  AdminMembershipRemoteDataSourceImpl({
    http.Client? client,
    String? baseUrl,
    AdminMembershipHeadersProvider? headersProvider,
  }) : _client = client ?? http.Client(),
       _baseUrl = (baseUrl ?? ApiConfig.baseUrl).replaceFirst(
         RegExp(r'/$'),
         '',
       ),
       _headersProvider = headersProvider ?? AuthProvider.authenticatedHeaders;

  final http.Client _client;
  final String _baseUrl;
  final AdminMembershipHeadersProvider _headersProvider;

  @override
  Future<MembershipPage> getMemberships({
    required int page,
    required int pageSize,
    String? membershipType,
    int? membershipTypeReferenceId,
    bool? isActive,
  }) async {
    if (page < 1) throw ArgumentError.value(page, 'page');
    if (pageSize < 1 || pageSize > 100) {
      throw ArgumentError.value(pageSize, 'pageSize');
    }

    final type = membershipType?.trim();
    final query = <String, String>{
      'Page': page.toString(),
      'PageSize': pageSize.toString(),
      'IncludeTotalCount': 'true',
      if (type != null && type.isNotEmpty) 'MembershipType': type,
      if (membershipTypeReferenceId != null)
        'MembershipTypeReferenceId': membershipTypeReferenceId.toString(),
      if (isActive != null) 'IsActive': isActive.toString(),
    };
    final response = await _client
        .get(
          Uri.parse('$_baseUrl/Memberships').replace(queryParameters: query),
          headers: _headersProvider(),
        )
        .timeout(const Duration(seconds: 20));
    _ensureSuccess(response, 'load memberships');
    return _membershipPage(response.body);
  }

  @override
  Future<List<MembershipTypeReference>> getMembershipTypes() async {
    final response = await _client
        .get(
          Uri.parse('$_baseUrl/Memberships/types'),
          headers: _headersProvider(),
        )
        .timeout(const Duration(seconds: 20));
    _ensureSuccess(response, 'load membership types');
    final values = jsonDecode(response.body) as List<dynamic>;
    return values
        .whereType<Map<String, dynamic>>()
        .map(
          (json) => MembershipTypeReference(
            id: json['id'] as int,
            name: json['name'] as String,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> changeStatus({
    required int membershipId,
    required MembershipLifecycleStatus status,
    String? notes,
  }) => _write(
    method: 'PUT',
    path: '/Memberships/$membershipId/status',
    action: 'change this membership status',
    body: {'status': status.label, 'notes': notes?.trim() ?? ''},
  );

  @override
  Future<void> renewMembership({
    required int membershipId,
    required int months,
  }) {
    if (months < 1 || months > 24) {
      throw ArgumentError.value(months, 'months', 'must be between 1 and 24');
    }
    return _write(
      method: 'POST',
      path: '/Memberships/$membershipId/renew',
      action: 'renew this membership record',
      body: {'months': months},
    );
  }

  @override
  Future<List<MembershipEvent>> getHistory(int membershipId) async {
    final response = await _client
        .get(
          Uri.parse('$_baseUrl/Memberships/$membershipId/history'),
          headers: _headersProvider(),
        )
        .timeout(const Duration(seconds: 20));
    _ensureSuccess(response, 'load membership history');

    final decoded = jsonDecode(response.body);
    if (decoded is! List<dynamic>) {
      throw const FormatException(
        'Membership history returned an invalid response.',
      );
    }
    return decoded
        .map((entry) {
          if (entry is! Map) {
            throw const FormatException(
              'Membership history contains an invalid entry.',
            );
          }
          return MembershipEventModel.fromJson(
            Map<String, dynamic>.from(entry),
          );
        })
        .toList(growable: false);
  }

  Future<void> _write({
    required String method,
    required String path,
    required String action,
    required Map<String, Object?> body,
  }) async {
    final uri = Uri.parse('$_baseUrl$path');
    final headers = {..._headersProvider(), 'Content-Type': 'application/json'};
    final encoded = jsonEncode(body);
    final response = switch (method) {
      'PUT' => await _client.put(uri, headers: headers, body: encoded),
      'POST' => await _client.post(uri, headers: headers, body: encoded),
      _ => throw ArgumentError.value(method, 'method'),
    };
    _ensureSuccess(response, action);
  }

  MembershipPage _membershipPage(String responseBody) {
    final decoded = jsonDecode(responseBody);
    if (decoded is! Map) {
      throw const FormatException(
        'Memberships returned an invalid paged response.',
      );
    }
    final map = Map<String, dynamic>.from(decoded);
    final rawItems = map['items'];
    if (rawItems is! List<dynamic>) {
      throw const FormatException(
        'Memberships response did not contain an items list.',
      );
    }
    final items = rawItems
        .map((entry) {
          if (entry is! Map) {
            throw const FormatException(
              'Memberships response contains an invalid record.',
            );
          }
          return MembershipModel.fromJson(Map<String, dynamic>.from(entry));
        })
        .toList(growable: false);
    final rawTotalCount = map['totalCount'];
    if (rawTotalCount != null && rawTotalCount is! num) {
      throw const FormatException(
        'Memberships response contains an invalid total count.',
      );
    }
    return MembershipPage(items: items, totalCount: rawTotalCount?.toInt());
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
        'This membership no longer exists. Refresh and try again.',
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
      if (decoded case {'errors': Map errors}) {
        for (final values in errors.values) {
          if (values is Iterable) {
            for (final value in values) {
              final message = value?.toString().trim();
              if (message != null && message.isNotEmpty) return message;
            }
          }
        }
      }
    } on FormatException {
      // A valid API error can be plain text rather than JSON.
    }
    return trimmed.length <= 300 ? trimmed.replaceAll('"', '') : null;
  }
}
