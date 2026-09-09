import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:padelclub_desktop/core/network/api_config.dart';
import 'package:padelclub_desktop/providers/auth_provider.dart';

class RecommendationCohortReadinessSummary {
  const RecommendationCohortReadinessSummary({
    required this.readinessState,
    required this.summary,
    required this.isReadyForWindowValidation,
    required this.eligibleDeliveredOrders,
    required this.maturedEligibleDeliveredOrders,
    required this.eligibleDistinctCustomers,
    required this.eligibleRetainedPurchaseSignals,
    required this.nextActions,
  });

  final String readinessState;
  final String summary;
  final bool isReadyForWindowValidation;
  final int eligibleDeliveredOrders;
  final int maturedEligibleDeliveredOrders;
  final int eligibleDistinctCustomers;
  final int eligibleRetainedPurchaseSignals;
  final List<String> nextActions;

  factory RecommendationCohortReadinessSummary.fromJson(
    Map<String, dynamic> json,
  ) {
    final cohort = json['cohort'];
    if (cohort is! Map<String, dynamic>) {
      throw const FormatException('Cohort readiness did not contain counts.');
    }
    int asInt(Object? value) => value is num ? value.toInt() : 0;
    List<String> strings(Object? value) => value is List
        ? value.whereType<String>().toList(growable: false)
        : const [];
    return RecommendationCohortReadinessSummary(
      readinessState: json['readinessState'] as String? ?? 'Unavailable',
      summary: json['summary'] as String? ?? 'No collection summary returned.',
      isReadyForWindowValidation:
          json['isReadyForWindowValidation'] as bool? ?? false,
      eligibleDeliveredOrders: asInt(cohort['eligibleDeliveredOrders']),
      maturedEligibleDeliveredOrders: asInt(
        cohort['maturedEligibleDeliveredOrders'],
      ),
      eligibleDistinctCustomers: asInt(cohort['eligibleDistinctCustomers']),
      eligibleRetainedPurchaseSignals: asInt(
        cohort['eligibleRetainedPurchaseSignals'],
      ),
      nextActions: strings(json['nextActions']),
    );
  }
}

class RecommendationImpactSummary {
  const RecommendationImpactSummary({
    required this.evidenceTier,
    required this.isMature,
    required this.exposures,
    required this.distinctUsers,
    required this.clickedExposures,
    required this.attributedCheckouts,
    required this.attributedDeliveredOrders,
    required this.clickThroughRate,
    required this.deliveredConversionRate,
    required this.unmetRequirements,
  });

  final String evidenceTier;
  final bool isMature;
  final int exposures;
  final int distinctUsers;
  final int clickedExposures;
  final int attributedCheckouts;
  final int attributedDeliveredOrders;
  final double? clickThroughRate;
  final double? deliveredConversionRate;
  final List<String> unmetRequirements;

  factory RecommendationImpactSummary.fromJson(Map<String, dynamic> json) {
    int asInt(Object? value) => value is num ? value.toInt() : 0;
    double? asDouble(Object? value) => value is num ? value.toDouble() : null;
    List<String> strings(Object? value) => value is List
        ? value.whereType<String>().toList(growable: false)
        : const [];
    return RecommendationImpactSummary(
      evidenceTier: json['evidenceTier'] as String? ?? 'Collecting',
      isMature: json['isMature'] as bool? ?? false,
      exposures: asInt(json['exposures']),
      distinctUsers: asInt(json['distinctUsers']),
      clickedExposures: asInt(json['clickedExposures']),
      attributedCheckouts: asInt(json['attributedCheckouts']),
      attributedDeliveredOrders: asInt(json['attributedDeliveredOrders']),
      clickThroughRate: asDouble(json['clickThroughRate']),
      deliveredConversionRate: asDouble(json['deliveredConversionRate']),
      unmetRequirements: strings(json['unmetRequirements']),
    );
  }
}

/// Loads only aggregate evidence collection and mature, descriptive online
/// interaction summaries. It never turns missing data into a success metric.
class RecommendationOperationalReadinessProvider extends ChangeNotifier {
  RecommendationOperationalReadinessProvider({
    http.Client? client,
    String? baseUrl,
    Map<String, String> Function()? headersProvider,
  }) : _client = client ?? http.Client(),
       _baseUrl = baseUrl ?? ApiConfig.baseUrl,
       _headersProvider = headersProvider ?? AuthProvider.authenticatedHeaders;

  final http.Client _client;
  final String _baseUrl;
  final Map<String, String> Function() _headersProvider;

  RecommendationCohortReadinessSummary? cohort;
  RecommendationImpactSummary? impact;
  bool isLoading = false;
  String? errorMessage;

  Future<void> load() async {
    if (isLoading) return;
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      // End the online window at the attribution horizon, otherwise a fresh
      // page view would look like an immature non-conversion by design.
      final impactEnd = DateTime.now().toUtc().subtract(
        const Duration(days: 7),
      );
      final impactStart = impactEnd.subtract(const Duration(days: 30));
      final results = await Future.wait([
        _getObject('$_baseUrl/Operations/recommendations/cohort-readiness'),
        _getObject(
          Uri.parse('$_baseUrl/Operations/recommendations/impact')
              .replace(
                queryParameters: {
                  'fromUtc': impactStart.toIso8601String(),
                  'toUtc': impactEnd.toIso8601String(),
                },
              )
              .toString(),
        ),
      ]);
      cohort = RecommendationCohortReadinessSummary.fromJson(results[0]);
      impact = RecommendationImpactSummary.fromJson(results[1]);
    } catch (error) {
      cohort = null;
      impact = null;
      errorMessage = error.toString().replaceFirst('Bad state: ', '');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> _getObject(String path) async {
    final response = await _client
        .get(Uri.parse(path), headers: _headersProvider())
        .timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        response.statusCode == 401 || response.statusCode == 403
            ? 'You are not authorized to view recommendation readiness.'
            : 'Recommendation readiness could not be loaded.',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Recommendation readiness returned invalid data.',
      );
    }
    return decoded;
  }
}
