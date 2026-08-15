import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:padelclub_desktop/core/network/api_config.dart';
import 'package:padelclub_desktop/features/users/data/models/user_model.dart';
import 'package:padelclub_desktop/features/users/domain/entities/user.dart';
import 'package:padelclub_desktop/providers/auth_provider.dart';

class UserProvider extends ChangeNotifier {
  List<User> users = const [];
  bool isLoading = false;
  String? errorMessage;

  Future<void> loadUsers() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/Users').replace(
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
      users = items
          .map((item) => UserModel.fromJson(item as Map<String, dynamic>))
          .toList(growable: false);
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
      throw Exception('You are not authorized to view users.');
    }
    throw Exception(
      response.body.trim().isEmpty
          ? 'Users could not be loaded.'
          : response.body.replaceAll('"', ''),
    );
  }
}
