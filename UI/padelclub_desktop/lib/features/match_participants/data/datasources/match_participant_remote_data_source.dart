import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:padelclub_desktop/features/match_participants/data/models/match_participant_model.dart';
import 'package:padelclub_desktop/providers/auth_provider.dart';

abstract class MatchParticipantRemoteDataSource {
  Future<List<MatchParticipantModel>> getMatchParticipants({
    Map<String, dynamic>? filter,
  });
}

class MatchParticipantRemoteDataSourceImpl
    implements MatchParticipantRemoteDataSource {
  final http.Client client;
  final String baseUrl;

  MatchParticipantRemoteDataSourceImpl({
    required this.client,
    this.baseUrl = const String.fromEnvironment(
      'baseUrl',
      defaultValue: 'http://localhost:5000',
    ),
  });

  @override
  Future<List<MatchParticipantModel>> getMatchParticipants({
    Map<String, dynamic>? filter,
  }) async {
    var url = '$baseUrl/MatchParticipants';
    if (filter != null && filter.isNotEmpty) {
      var query = getQueryString(filter);
      url = '$url?$query';
    }
    final uri = Uri.parse(url);
    final response = await client.get(uri, headers: createHeaders());
    if (isValidResponse(response)) {
      final data = jsonDecode(response.body) as List<dynamic>;
      return data
          .map((e) => MatchParticipantModel.fromJson(e as Map<String, dynamic>))
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
      if (inRecursion) {
        if (key is int) {
          key = '[$key]';
        } else if (value is List || value is Map) {
          key = '.$key';
        } else {
          key = '.$key';
        }
      }
      if (value is String || value is int || value is double || value is bool) {
        var encoded = value;
        if (value is String) encoded = Uri.encodeComponent(value);
        query += '$prefix$key=$encoded';
      } else if (value is DateTime) {
        query += '$prefix$key=${value.toIso8601String()}';
      } else if (value is List || value is Map) {
        if (value is List) value = value.asMap();
        value.forEach((k, v) {
          query += getQueryString(
            {k: v},
            prefix: '$prefix$key',
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
