import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:padelclub_desktop/features/users/domain/entities/user.dart';
import 'package:padelclub_desktop/features/users/data/models/user_model.dart';
import 'package:padelclub_desktop/providers/auth_provider.dart';

class UserProvider extends ChangeNotifier {
  static String? _baseUrl;

  UserProvider({String? baseUrl}) {
    _baseUrl = baseUrl ?? const String.fromEnvironment('_baseUrl', defaultValue: 'http://localhost:5001/api');
  }

  Future<List<User>> get({Map<String, dynamic>? filter}) async {
    var url = '$_baseUrl/User';
    debugPrint('Filter: $filter');
    if (filter != null && filter.isNotEmpty) {
      var query = getQueryString(filter);
      debugPrint('Query: $query');
      url += query;
    }
    debugPrint('URL: $url');

    final uri = Uri.parse(url);
    final response = await http.get(uri, headers: createHeaders());

    if (isValidResponse(response)) {
        final data = jsonDecode(response.body) as List<dynamic>;
        final items = data
          .map((e) => UserModel.fromJson(e as Map<String, dynamic>))
          .toList();
        return items.map((m) => User(id: m.id, name: m.name)).toList();
    } else {
      throw Exception('Failed to load users');
    }
  }

  String getQueryString(Map<String, dynamic> params, {String prefix = '?', bool inRecursion = false}) {
    String query = '';
    params.forEach((key, value) {
      final effectivePrefix = inRecursion ? '&' : prefix;
      if (value is String || value is int || value is double || value is bool) {
        var encoded = value;
        if (value is String) {
          encoded = Uri.encodeComponent(value);
        }
        query += '$effectivePrefix$key=$encoded';
      } else if (value is DateTime) {
        query += '$effectivePrefix$key=${value.toIso8601String()}';
      } else if (value is List || value is Map) {
        if (value is List) value = value.asMap();
        value.forEach((k, v) {
          query += getQueryString({k: v}, prefix: '&', inRecursion: true);
        });
      }
    });
    return query;
  }

  bool isValidResponse(http.Response response) {
    if (response.statusCode <= 299) {
      return true;
    } else if (response.statusCode == 401) {
      throw Exception('Not authorized');
    } else {
      throw Exception('Something went wrong, please try again later!');
    }
  }

  Map<String, String> createHeaders() {
    final basicAuth = 'Basic ${base64Encode(utf8.encode('${AuthProvider.username}: ${AuthProvider.password}'))}';
    return {
      'Content-Type': 'application/json',
      'Authorization': basicAuth,
    };
  }
}
