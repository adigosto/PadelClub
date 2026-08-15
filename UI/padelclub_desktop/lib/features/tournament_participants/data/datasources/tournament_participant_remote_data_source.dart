import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:padelclub_desktop/features/tournament_participants/data/models/tournament_participant_model.dart';
import 'package:padelclub_desktop/providers/auth_provider.dart';

abstract class TournamentParticipantRemoteDataSource {
  Future<List<TournamentParticipantModel>> getTournamentParticipants({
    Map<String, dynamic>? filter,
  });
}

class TournamentParticipantRemoteDataSourceImpl
    implements TournamentParticipantRemoteDataSource {
  final http.Client client;
  final String baseUrl;

  TournamentParticipantRemoteDataSourceImpl({
    required this.client,
    this.baseUrl = const String.fromEnvironment(
      'baseUrl',
      defaultValue: 'http://localhost:5000',
    ),
  });

  @override
  Future<List<TournamentParticipantModel>> getTournamentParticipants({
    Map<String, dynamic>? filter,
  }) async {
    var url = '$baseUrl/TournamentParticipants';
    if (filter != null && filter.isNotEmpty) {
      var query = getQueryString(filter);
      url = '$url?$query';
    }
    final uri = Uri.parse(url);
    final response = await client.get(uri, headers: createHeaders());
    if (isValidResponse(response)) {
      final data = jsonDecode(response.body) as List<dynamic>;
      return data
          .map(
            (e) =>
                TournamentParticipantModel.fromJson(e as Map<String, dynamic>),
          )
          .toList();
    } else {
      throw Exception('Something went wrong');
    }
  }

  String getQueryString(
    Map params, {
    String prefix = '&',
    bool inRecursion = false,
  }) {
    String query = '';
    params.forEach((key, value) {
      var k = key;
      if (inRecursion) {
        if (k is int) {
          k = '[$k]';
        } else if (value is List || value is Map) {
          k = '.$k';
        } else {
          k = '.$k';
        }
      }
      if (value is String || value is int || value is double || value is bool) {
        var encoded = value;
        if (value is String) encoded = Uri.encodeComponent(value);
        query += '$prefix$k=$encoded';
      } else if (value is DateTime) {
        query += '$prefix$k=${value.toIso8601String()}';
      } else if (value is List || value is Map) {
        if (value is List) value = value.asMap();
        value.forEach((kk, vv) {
          query += getQueryString(
            {kk: vv},
            prefix: '$prefix$k',
            inRecursion: true,
          );
        });
      }
    });
    return query;
  }

  bool isValidResponse(http.Response response) {
    if (response.statusCode <= 299) return true;
    if (response.statusCode == 401) throw Exception('Not authorized');
    throw Exception('Something went wrong');
  }

  Map<String, String> createHeaders() {
    return AuthProvider.authenticatedHeaders();
  }
}
