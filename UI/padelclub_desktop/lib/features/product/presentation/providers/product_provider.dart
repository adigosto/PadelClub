import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:padelclub_desktop/features/product/data/models/search_result.dart';
import 'package:padelclub_desktop/features/product/domain/entities/product.dart';
import 'package:padelclub_desktop/providers/auth_provider.dart';

class ProductProvider extends ChangeNotifier {
  static String? _baseUrl;

  ProductProvider({String? baseUrl}) {
    const configuredUrl = String.fromEnvironment('baseUrl');
    _baseUrl =
        baseUrl ??
        (configuredUrl.isNotEmpty ? configuredUrl : _defaultBaseUrl());
  }

  static String _defaultBaseUrl() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:5001';
    }
    return 'http://localhost:5001';
  }

  Future<SearchResult<Product>> get({Map<String, dynamic>? filter}) async {
    var url = '$_baseUrl/Product';
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
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final items = (data['items'] as List<dynamic>? ?? <dynamic>[])
          .map((e) => Product.fromJson(e as Map<String, dynamic>))
          .toList();
      final searchResult = SearchResult<Product>(
        items: items,
        totalCount: data['totalCount'] as int?,
      );

      return searchResult;
    } else {
      throw Exception('Failed to load products');
    }
  }

  String getQueryString(
    Map<String, dynamic> params, {
    String prefix = '?',
    bool inRecursion = false,
  }) {
    final queryParameters = <String, String>{};
    params.forEach((key, value) {
      if (value != null) {
        queryParameters[key] = value is DateTime
            ? value.toIso8601String()
            : value.toString();
      }
    });
    if (queryParameters.isEmpty) return '';
    return '$prefix${Uri(queryParameters: queryParameters).query}';
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
    final basicAuth =
        'Basic ${base64Encode(utf8.encode('${AuthProvider.username}:${AuthProvider.password}'))}';
    return {'Content-Type': 'application/json', 'Authorization': basicAuth};
  }
}
