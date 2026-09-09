import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:padelclub_desktop/features/recommendation_evaluation/presentation/providers/recommendation_operational_readiness_provider.dart';

void main() {
  test(
    'loads separate cohort and mature online-monitoring contracts',
    () async {
      final requestedPaths = <String>[];
      final client = MockClient((request) async {
        requestedPaths.add(request.url.path);
        expect(request.headers['Authorization'], 'Bearer readiness-token');
        if (request.url.path.endsWith('/cohort-readiness')) {
          return http.Response(jsonEncode(_cohortJson()), 200);
        }
        expect(request.url.path, '/Operations/recommendations/impact');
        expect(request.url.queryParameters['fromUtc'], isNotEmpty);
        expect(request.url.queryParameters['toUtc'], isNotEmpty);
        return http.Response(jsonEncode(_impactJson()), 200);
      });
      final provider = RecommendationOperationalReadinessProvider(
        client: client,
        baseUrl: 'https://padelclub.example',
        headersProvider: () => const {
          'Authorization': 'Bearer readiness-token',
        },
      );

      await provider.load();

      expect(provider.errorMessage, isNull);
      expect(provider.cohort?.readinessState, 'Collecting');
      expect(provider.cohort?.eligibleDeliveredOrders, 12);
      expect(provider.impact?.evidenceTier, 'Collecting');
      expect(provider.impact?.exposures, 24);
      expect(provider.impact?.attributedDeliveredOrders, 2);
      expect(
        requestedPaths,
        containsAll([
          '/Operations/recommendations/cohort-readiness',
          '/Operations/recommendations/impact',
        ]),
      );
    },
  );
}

Map<String, dynamic> _cohortJson() => {
  'readinessState': 'Collecting',
  'summary': 'More real history is required.',
  'isReadyForWindowValidation': false,
  'cohort': {
    'eligibleDeliveredOrders': 12,
    'maturedEligibleDeliveredOrders': 8,
    'eligibleDistinctCustomers': 7,
    'eligibleRetainedPurchaseSignals': 18,
  },
  'nextActions': ['Collect more provenance-eligible orders.'],
};

Map<String, dynamic> _impactJson() => {
  'evidenceTier': 'Collecting',
  'isMature': false,
  'exposures': 24,
  'distinctUsers': 9,
  'clickedExposures': 5,
  'attributedCheckouts': 3,
  'attributedDeliveredOrders': 2,
  'clickThroughRate': 0.2083,
  'deliveredConversionRate': 0.0833,
  'unmetRequirements': ['At least 100 exposures are required.'],
};
