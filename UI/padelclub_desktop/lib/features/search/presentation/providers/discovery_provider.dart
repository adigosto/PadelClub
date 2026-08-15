import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:padelclub_desktop/core/network/api_config.dart';
import 'package:padelclub_desktop/features/search/data/models/discovery_models.dart';
import 'package:padelclub_desktop/features/search/domain/entities/discovery_match.dart';
import 'package:padelclub_desktop/features/search/domain/entities/player_ranking.dart';
import 'package:padelclub_desktop/providers/auth_provider.dart';

class DiscoveryProvider extends ChangeNotifier {
  List<DiscoveryMatch> matches = const [];
  List<PlayerRanking> rankings = const [];
  bool isLoading = false;
  String? errorMessage;

  Future<void> load({String query = ''}) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final parameters = query.trim().isEmpty ? null : {'query': query.trim()};
      final responses = await Future.wait([
        http.get(
          Uri.parse(
            '${ApiConfig.baseUrl}/Discovery/matches',
          ).replace(queryParameters: parameters),
          headers: AuthProvider.authenticatedHeaders(),
        ),
        http.get(
          Uri.parse(
            '${ApiConfig.baseUrl}/Discovery/rankings',
          ).replace(queryParameters: parameters),
          headers: AuthProvider.authenticatedHeaders(),
        ),
      ]);
      if (responses.any(
        (response) => response.statusCode < 200 || response.statusCode >= 300,
      )) {
        throw Exception('Club discovery data could not be loaded.');
      }
      matches = (jsonDecode(responses[0].body) as List<dynamic>)
          .map(
            (item) =>
                DiscoveryMatchModel.fromJson(item as Map<String, dynamic>),
          )
          .toList(growable: false);
      rankings = (jsonDecode(responses[1].body) as List<dynamic>)
          .map(
            (item) => PlayerRankingModel.fromJson(item as Map<String, dynamic>),
          )
          .toList(growable: false);
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
