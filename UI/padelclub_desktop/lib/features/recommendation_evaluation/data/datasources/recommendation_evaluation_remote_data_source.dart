import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:padelclub_desktop/core/network/api_config.dart';
import 'package:padelclub_desktop/features/recommendation_evaluation/data/models/recommendation_evaluation_model.dart';

typedef AuthHeadersProvider = Map<String, String> Function();

abstract interface class RecommendationEvaluationRemoteDataSource {
  Future<RecommendationEvaluationModel> getEvaluation({
    required DateTime cutoffUtc,
    required DateTime endUtc,
    required int k,
  });

  Future<RecommendationEvaluationRunModel> createEvaluationRun({
    required DateTime cutoffUtc,
    required DateTime endUtc,
    required int k,
  });

  Future<RecommendationEvaluationRunModel?> getLatestEvaluationRun();
}

class RecommendationEvaluationRemoteDataSourceImpl
    implements RecommendationEvaluationRemoteDataSource {
  RecommendationEvaluationRemoteDataSourceImpl({
    required this.headersProvider,
    http.Client? client,
    String? baseUrl,
  }) : _client = client ?? http.Client(),
       _baseUrl = baseUrl ?? ApiConfig.baseUrl;

  final AuthHeadersProvider headersProvider;
  final http.Client _client;
  final String _baseUrl;

  @override
  Future<RecommendationEvaluationModel> getEvaluation({
    required DateTime cutoffUtc,
    required DateTime endUtc,
    required int k,
  }) async {
    final uri = Uri.parse('$_baseUrl/Operations/recommendations/evaluation')
        .replace(
          queryParameters: {
            'cutoffUtc': cutoffUtc.toUtc().toIso8601String(),
            'endUtc': endUtc.toUtc().toIso8601String(),
            'k': '$k',
          },
        );
    final response = await _client
        .get(uri, headers: headersProvider())
        .timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        response.statusCode == 401 || response.statusCode == 403
            ? 'You are not authorized to view recommendation evaluation evidence.'
            : 'Recommendation evaluation could not be loaded.',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Recommendation evaluation returned an invalid response.',
      );
    }
    return RecommendationEvaluationModel.fromJson(decoded);
  }

  @override
  Future<RecommendationEvaluationRunModel> createEvaluationRun({
    required DateTime cutoffUtc,
    required DateTime endUtc,
    required int k,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/Operations/recommendations/evaluation/runs',
    );
    final response = await _client
        .post(
          uri,
          headers: {...headersProvider(), 'Content-Type': 'application/json'},
          body: jsonEncode({
            'cutoffUtc': cutoffUtc.toUtc().toIso8601String(),
            'endUtc': endUtc.toUtc().toIso8601String(),
            'k': k,
          }),
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        response.statusCode == 401 || response.statusCode == 403
            ? 'You are not authorized to record recommendation evaluation evidence.'
            : 'Recommendation evaluation evidence could not be recorded.',
      );
    }
    return RecommendationEvaluationRunModel.fromJson(
      _decodeObject(response.body, 'recorded recommendation evaluation'),
    );
  }

  @override
  Future<RecommendationEvaluationRunModel?> getLatestEvaluationRun() async {
    final uri = Uri.parse(
      '$_baseUrl/Operations/recommendations/evaluation/runs/latest',
    );
    final response = await _client
        .get(uri, headers: headersProvider())
        .timeout(const Duration(seconds: 20));
    if (response.statusCode == 404) return null;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        response.statusCode == 401 || response.statusCode == 403
            ? 'You are not authorized to view recorded recommendation evidence.'
            : 'Recorded recommendation evidence could not be loaded.',
      );
    }
    return RecommendationEvaluationRunModel.fromJson(
      _decodeObject(response.body, 'recorded recommendation evaluation'),
    );
  }

  Map<String, dynamic> _decodeObject(String body, String subject) {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    throw FormatException('$subject returned an invalid response.');
  }
}
