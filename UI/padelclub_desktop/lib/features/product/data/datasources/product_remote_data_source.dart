import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:padelclub_desktop/features/product/data/models/product_model.dart';
import 'package:padelclub_desktop/providers/auth_provider.dart';

abstract class ProductRemoteDataSource {
  Future<List<ProductModel>> getProducts({Map<String, dynamic>? filter});
}

class ProductRemoteDataSourceImpl implements ProductRemoteDataSource {
  final http.Client client;
  final String baseUrl;

  ProductRemoteDataSourceImpl({
    required this.client,
    this.baseUrl = const String.fromEnvironment(
      "baseUrl",
      defaultValue: "http://localhost:5001",
    ),
  });

  @override
  Future<List<ProductModel>> getProducts({Map<String, dynamic>? filter}) async {
    var url = "$baseUrl/Product";

    if (filter != null && filter.isNotEmpty) {
      var queryString = getQueryString(filter);
      url = "$url?$queryString";
    }

    final uri = Uri.parse(url);
    final response = await client.get(uri, headers: createHeaders());
    if (isValidResponse(response)) {
      final data = jsonDecode(response.body) as List<dynamic>;
      return data
          .map((json) => ProductModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception("Something went wrong, please try again later!");
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
        if (value is String) {
          encoded = Uri.encodeComponent(value);
        }
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
    if (response.statusCode <= 299) {
      return true;
    } else if (response.statusCode == 401) {
      throw Exception("Not authorized");
    } else {
      throw Exception("Something went wrong, please try again later!");
    }
  }

  Map<String, String> createHeaders() {
    String basicAuth =
        'Basic ${base64Encode(utf8.encode("${AuthProvider.username}:${AuthProvider.password}"))}';
    return {"Content-Type": "application/json", "Authorization": basicAuth};
  }
}
