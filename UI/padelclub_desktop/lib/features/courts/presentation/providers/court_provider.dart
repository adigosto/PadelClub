import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:padelclub_desktop/core/network/api_config.dart';
import 'package:padelclub_desktop/features/courts/data/models/court_model.dart';
import 'package:padelclub_desktop/features/courts/domain/entities/court.dart';
import 'package:padelclub_desktop/providers/auth_provider.dart';

class CourtProvider extends ChangeNotifier {
  List<Court> courts = const [];
  bool isLoading = false;
  String? errorMessage;

  Future<void> loadCourts() async {
    await _run(() async {
      final uri = Uri.parse('${ApiConfig.baseUrl}/Courts').replace(
        queryParameters: {'PageSize': '200', 'IncludeTotalCount': 'true'},
      );
      final response = await http.get(
        uri,
        headers: AuthProvider.authenticatedHeaders(),
      );
      _ensureSuccess(response);
      final decoded = jsonDecode(response.body);
      final items = decoded is List<dynamic>
          ? decoded
          : (decoded as Map<String, dynamic>)['items'] as List<dynamic>? ??
                const [];
      courts = items
          .map((item) => CourtModel.fromJson(item as Map<String, dynamic>))
          .toList(growable: false);
    });
  }

  Future<bool> saveCourt({
    int? id,
    required String name,
    required String description,
    required bool isIndoor,
    required bool isActive,
    required double hourlyRate,
    required int maxPlayers,
  }) async {
    var success = false;
    await _run(() async {
      final uri = Uri.parse(
        '${ApiConfig.baseUrl}/Courts${id == null ? '' : '/$id'}',
      );
      final body = jsonEncode({
        'name': name,
        'description': description,
        'isIndoor': isIndoor,
        'isActive': isActive,
        'hourlyRate': hourlyRate,
        'maxPlayers': maxPlayers,
      });
      final response = id == null
          ? await http.post(
              uri,
              headers: AuthProvider.authenticatedHeaders(),
              body: body,
            )
          : await http.put(
              uri,
              headers: AuthProvider.authenticatedHeaders(),
              body: body,
            );
      _ensureSuccess(response);
      success = true;
    });
    if (success) await loadCourts();
    return success;
  }

  Future<bool> deleteCourt(int id) async {
    var success = false;
    await _run(() async {
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/Courts/$id'),
        headers: AuthProvider.authenticatedHeaders(),
      );
      _ensureSuccess(response);
      success = true;
    });
    if (success) await loadCourts();
    return success;
  }

  Future<void> _run(Future<void> Function() operation) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      await operation();
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void _ensureSuccess(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw Exception('Administrator access is required for this action.');
    }
    throw Exception(
      response.body.trim().isEmpty
          ? 'The court request could not be completed.'
          : response.body.replaceAll('"', ''),
    );
  }
}
