import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:padelclub_desktop/providers/auth_provider.dart';

class ProductProvider {
  static String? _baseUrl;

  ProductProvider() {
    _baseUrl = const String.fromEnvironment("baseUrl", defaultValue: "https://localhost:5001/api");
  }

  Future<dynamic> get() async {
    var url = "$_baseUrl/Product";
    debugPrint("Url: $url");
    var uri = Uri.parse(url);
    var response = await http.get(uri, headers: createHeaders());
    if (isValidResponse(response)){
      var data = jsonDecode(response.body);
      return data;
    }
    else{
      throw Exception("Something went wrong, please try again later!");
    }
  }
}

bool isValidResponse(http.Response response){
  if (response.statusCode <= 299){
    return true;
  }
  else if (response.statusCode == 401){
    throw Exception("Not authorized");
  }
  else{
    throw Exception("Something went wrong, please try again later!");
  }
}

Map<String, String> createHeaders() {
  String basicAuth =
      'Basic ${base64Encode(utf8.encode("${AuthProvider.username}: ${AuthProvider.password}"))}';
  var headers = {"Content-Type": "application/json", "Authorization": basicAuth};
  return headers;
}