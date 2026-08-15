import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:padelclub_desktop/features/memberships/domain/entities/membership.dart';
import 'package:padelclub_desktop/features/memberships/data/models/membership_model.dart';
import 'package:padelclub_desktop/providers/auth_provider.dart';

class MembershipProvider extends ChangeNotifier {
  static String? _baseUrl;

  MembershipProvider({String? baseUrl}) {
    _baseUrl =
        baseUrl ??
        const String.fromEnvironment(
          'baseUrl',
          defaultValue: 'http://localhost:5000',
        );
  }

  Future<List<Membership>> get({Map<String, dynamic>? filter}) async {
    var url =
        '$_baseUrl/Memberships${AuthProvider.currentUserIsAdministrator ? '' : '/mine'}';
    if (filter != null && filter.isNotEmpty) {
      var query = getQueryString(filter);
      url += query;
    }

    final uri = Uri.parse(url);
    final response = await http.get(uri, headers: createHeaders());

    if (isValidResponse(response)) {
      final data = jsonDecode(response.body) as List<dynamic>;
      final items = data
          .map((e) => MembershipModel.fromJson(e as Map<String, dynamic>))
          .toList();
      return items
          .map(
            (m) => Membership(
              id: m.id,
              userId: m.userId,
              membershipType: m.membershipType,
              startDate: m.startDate,
              endDate: m.endDate,
              price: m.price,
              isActive: m.isActive,
              createdAt: m.createdAt,
              updatedAt: m.updatedAt,
            ),
          )
          .toList();
    } else {
      throw Exception('Failed to load memberships');
    }
  }

  String getQueryString(
    Map<String, dynamic> params, {
    String prefix = '?',
    bool inRecursion = false,
  }) {
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
    return AuthProvider.authenticatedHeaders();
  }
}
