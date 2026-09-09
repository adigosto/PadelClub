import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:padelclub_desktop/core/network/api_config.dart';
import 'package:padelclub_desktop/features/tournament/data/models/tournament_model.dart';
import 'package:padelclub_desktop/features/tournament/domain/entities/tournament.dart';
import 'package:padelclub_desktop/features/tournament_management/domain/entities/tournament_draft.dart';
import 'package:padelclub_desktop/providers/auth_provider.dart';

typedef TournamentManagementHeadersProvider = Map<String, String> Function();

abstract interface class TournamentManagementRemoteDataSource {
  Future<List<Tournament>> getTournaments({String? query});

  Future<void> createTournament(TournamentDraft draft);

  Future<void> updateTournament({
    required int tournamentId,
    required TournamentDraft draft,
  });

  Future<void> deleteTournament(int tournamentId);

  Future<void> generateBracket(int tournamentId);
}

/// Administrator-only client. Player catalogue/registration traffic remains in
/// the existing tournament feature and is not coupled to this CRUD client.
class TournamentManagementRemoteDataSourceImpl
    implements TournamentManagementRemoteDataSource {
  TournamentManagementRemoteDataSourceImpl({
    http.Client? client,
    String? baseUrl,
    TournamentManagementHeadersProvider? headersProvider,
  }) : _client = client ?? http.Client(),
       _baseUrl = (baseUrl ?? ApiConfig.baseUrl).replaceFirst(
         RegExp(r'/$'),
         '',
       ),
       _headersProvider = headersProvider ?? AuthProvider.authenticatedHeaders;

  final http.Client _client;
  final String _baseUrl;
  final TournamentManagementHeadersProvider _headersProvider;

  @override
  Future<List<Tournament>> getTournaments({String? query}) async {
    final search = query?.trim();
    final uri = Uri.parse('$_baseUrl/Tournament').replace(
      queryParameters: {
        'PageSize': '200',
        'IncludeTotalCount': 'true',
        if (search != null && search.isNotEmpty) 'FTS': search,
      },
    );
    final response = await _client
        .get(uri, headers: _headersProvider())
        .timeout(const Duration(seconds: 20));
    _ensureSuccess(response, 'load tournaments');

    final decoded = jsonDecode(response.body);
    final items = switch (decoded) {
      List() => decoded,
      {'items': List items} => items,
      _ => throw const FormatException(
        'Tournament list returned an invalid response.',
      ),
    };
    return items
        .map((entry) {
          if (entry is! Map) {
            throw const FormatException(
              'Tournament list contains an invalid entry.',
            );
          }
          return TournamentModel.fromJson(Map<String, dynamic>.from(entry));
        })
        .toList(growable: false);
  }

  @override
  Future<void> createTournament(TournamentDraft draft) =>
      _write('POST', '/Tournament', draft);

  @override
  Future<void> updateTournament({
    required int tournamentId,
    required TournamentDraft draft,
  }) => _write('PUT', '/Tournament/$tournamentId', draft);

  @override
  Future<void> deleteTournament(int tournamentId) async {
    final response = await _client
        .delete(
          Uri.parse('$_baseUrl/Tournament/$tournamentId'),
          headers: _headersProvider(),
        )
        .timeout(const Duration(seconds: 20));
    _ensureSuccess(response, 'delete this tournament');
    if (response.body.trim().toLowerCase() == 'false') {
      throw StateError(
        'This tournament no longer exists. Refresh and try again.',
      );
    }
  }

  @override
  Future<void> generateBracket(int tournamentId) async {
    final response = await _client
        .post(
          Uri.parse('$_baseUrl/Tournaments/$tournamentId/bracket/generate'),
          headers: _headersProvider(),
        )
        .timeout(const Duration(seconds: 20));
    _ensureSuccess(response, 'generate this bracket');
  }

  Future<void> _write(String method, String path, TournamentDraft draft) async {
    final headers = {..._headersProvider(), 'Content-Type': 'application/json'};
    final uri = Uri.parse('$_baseUrl$path');
    final body = jsonEncode(draft.toJson());
    final response = switch (method) {
      'POST' => await _client.post(uri, headers: headers, body: body),
      'PUT' => await _client.put(uri, headers: headers, body: body),
      _ => throw ArgumentError.value(method, 'method'),
    };
    _ensureSuccess(
      response,
      method == 'POST' ? 'create this tournament' : 'update this tournament',
    );
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
        'This tournament no longer exists. Refresh and try again.',
      );
    }
    if (response.statusCode == 409) {
      throw StateError(
        'The tournament changed or cannot complete this operation. Refresh and review the server state.',
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
        final messages = errors.values
            .whereType<List>()
            .expand((items) => items.whereType<String>())
            .where((message) => message.trim().isNotEmpty)
            .toList(growable: false);
        if (messages.isNotEmpty) return messages.join(' ');
      }
    } on FormatException {
      // Generic CRUD conflicts can be plain text.
    }
    return trimmed.length <= 240 ? trimmed : null;
  }
}
