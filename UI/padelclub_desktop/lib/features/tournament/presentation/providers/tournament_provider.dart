import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:padelclub_desktop/core/network/api_config.dart';
import 'package:padelclub_desktop/features/tournament/data/models/tournament_model.dart';
import 'package:padelclub_desktop/features/tournament/domain/entities/tournament.dart';
import 'package:padelclub_desktop/providers/auth_provider.dart';

class TournamentProvider extends ChangeNotifier {
  TournamentProvider({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  List<Tournament> tournaments = const [];
  bool isLoading = false;
  String? errorMessage;

  Future<void> load({String? query}) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/Tournament').replace(
        queryParameters: {
          'PageSize': '100',
          'IncludeTotalCount': 'true',
          if (query?.trim().isNotEmpty == true) 'FTS': query!.trim(),
        },
      );
      final response = await _client.get(
        uri,
        headers: AuthProvider.authenticatedHeaders(),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
          response.statusCode == 401 || response.statusCode == 403
              ? 'You are not authorized to view tournaments.'
              : 'Tournaments could not be loaded.',
        );
      }
      final decoded = jsonDecode(response.body);
      final items = decoded is List<dynamic>
          ? decoded
          : (decoded as Map<String, dynamic>)['items'] as List<dynamic>? ??
                const [];
      tournaments = items
          .map((item) => TournamentModel.fromJson(item as Map<String, dynamic>))
          .toList(growable: false);
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
