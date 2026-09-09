import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:padelclub_desktop/core/network/api_config.dart';
import 'package:padelclub_desktop/features/player_experience/domain/entities/player_city.dart';
import 'package:padelclub_desktop/features/player_experience/domain/repositories/city_repository.dart';
import 'package:padelclub_desktop/providers/auth_provider.dart';

class HttpCityRepository implements CityRepository {
  @override
  Future<List<PlayerCity>> getCities() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/PlayerExperience/cities'),
      headers: AuthProvider.authenticatedHeaders(),
    );
    if (response.statusCode != 200) {
      throw Exception('Cities could not be loaded.');
    }
    return (jsonDecode(response.body) as List<dynamic>)
        .map(
          (item) =>
              PlayerCity(id: item['id'] as int, name: item['name'] as String),
        )
        .toList();
  }
}
