import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

import 'package:padelclub_desktop/core/theme/app_theme.dart';
import 'package:padelclub_desktop/features/recommendation_evaluation/data/datasources/recommendation_evaluation_remote_data_source.dart';
import 'package:padelclub_desktop/features/recommendation_evaluation/data/models/recommendation_evaluation_model.dart';
import 'package:padelclub_desktop/features/recommendation_evaluation/domain/entities/recommendation_evaluation.dart';
import 'package:padelclub_desktop/features/recommendation_evaluation/domain/repositories/recommendation_evaluation_repository.dart';
import 'package:padelclub_desktop/features/recommendation_evaluation/domain/usecases/create_recommendation_evaluation_run.dart';
import 'package:padelclub_desktop/features/recommendation_evaluation/domain/usecases/get_recommendation_evaluation.dart';
import 'package:padelclub_desktop/features/recommendation_evaluation/domain/usecases/get_latest_recommendation_evaluation_run.dart';
import 'package:padelclub_desktop/features/recommendation_evaluation/presentation/providers/recommendation_evaluation_provider.dart';
import 'package:padelclub_desktop/features/recommendation_evaluation/presentation/widgets/recommendation_evaluation_evidence_panel.dart';

void main() {
  group('RecommendationEvaluationModel', () {
    test(
      'keeps unavailable metrics null instead of converting them to zero',
      () {
        final evaluation = RecommendationEvaluationModel.fromJson(
          _evaluationJson(
            isAvailable: false,
            unavailableReason: 'No warm evaluable users were found.',
          ),
        );

        expect(evaluation.isAvailable, isFalse);
        expect(
          evaluation.unavailableReason,
          'No warm evaluable users were found.',
        );
        expect(evaluation.cohort.trainingOrders, 3);
        expect(evaluation.cohort.holdoutOrders, 1);
        expect(evaluation.cohort.evaluatedUsers, 0);
        expect(evaluation.cohort.excludedSeededDemoOrders, 4);
        expect(evaluation.collaborativeFiltering.precisionAtK, isNull);
        expect(evaluation.popularityBaseline.precisionAtK, isNull);
      },
    );

    test('maps available comparative metrics and UTC bounds', () {
      final evaluation = RecommendationEvaluationModel.fromJson(
        _evaluationJson(isAvailable: true),
      );

      expect(evaluation.isAvailable, isTrue);
      expect(evaluation.cutoffUtc, DateTime.utc(2026, 8, 1));
      expect(evaluation.endUtc, DateTime.utc(2026, 8, 8));
      expect(evaluation.collaborativeFiltering.precisionAtK, 0.4);
      expect(
        evaluation.collaborativeFiltering.normalizedDiscountedCumulativeGainAtK,
        0.4,
      );
      expect(evaluation.popularityBaseline.precisionAtK, 0.2);
      expect(evaluation.quality.isMeaningful, isFalse);
    });

    test('rejects a response missing a mandatory field', () {
      final response = _evaluationJson(isAvailable: false)
        ..remove('isAvailable');

      expect(
        () => RecommendationEvaluationModel.fromJson(response),
        throwsFormatException,
      );
    });

    test('rejects contradictory unavailable metrics', () {
      final response = _evaluationJson(isAvailable: false);
      (response['collaborativeFiltering']
              as Map<String, dynamic>)['precisionAtK'] =
          0.4;

      expect(
        () => RecommendationEvaluationModel.fromJson(response),
        throwsFormatException,
      );
    });

    test('rejects a response missing demo-data provenance', () {
      final response = _evaluationJson(isAvailable: false);
      (response['cohort'] as Map<String, dynamic>).remove(
        'excludedSeededDemoOrders',
      );

      expect(
        () => RecommendationEvaluationModel.fromJson(response),
        throwsFormatException,
      );
    });

    test('rejects contradictory quality gates', () {
      final response = _evaluationJson(isAvailable: true);
      final quality = response['quality'] as Map<String, dynamic>;
      quality['isMeaningful'] = true;
      quality['unmetRequirements'] = [
        'A meaningful evaluation cannot have an unmet requirement.',
      ];

      expect(
        () => RecommendationEvaluationModel.fromJson(response),
        throwsFormatException,
      );
    });
  });

  test(
    'data source calls the admin endpoint with UTC bounds and auth',
    () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/Operations/recommendations/evaluation');
        expect(
          request.url.queryParameters['cutoffUtc'],
          '2026-08-01T00:00:00.000Z',
        );
        expect(
          request.url.queryParameters['endUtc'],
          '2026-08-08T00:00:00.000Z',
        );
        expect(request.url.queryParameters['k'], '6');
        expect(request.headers['Authorization'], 'Bearer evaluation-token');
        return http.Response(
          jsonEncode(_evaluationJson(isAvailable: false)),
          200,
        );
      });
      final dataSource = RecommendationEvaluationRemoteDataSourceImpl(
        baseUrl: 'https://padelclub.example',
        client: client,
        headersProvider: () => const {
          'Authorization': 'Bearer evaluation-token',
        },
      );

      final evaluation = await dataSource.getEvaluation(
        cutoffUtc: DateTime.utc(2026, 8, 1),
        endUtc: DateTime.utc(2026, 8, 8),
        k: 6,
      );

      expect(evaluation.protocol, 'global-temporal-future-basket-v1');
      expect(evaluation.isAvailable, isFalse);
    },
  );

  test(
    'provider passes an explicit historical request to its use case',
    () async {
      final repository = _FakeRecommendationEvaluationRepository(
        response: RecommendationEvaluationModel.fromJson(
          _evaluationJson(isAvailable: false),
        ),
      );
      final provider = RecommendationEvaluationProvider(
        GetRecommendationEvaluation(repository),
        CreateRecommendationEvaluationRun(repository),
        GetLatestRecommendationEvaluationRun(repository),
      );
      final cutoff = DateTime.utc(2026, 8, 1);
      final end = DateTime.utc(2026, 8, 8);

      await provider.load(cutoffUtc: cutoff, endUtc: end, k: 6);

      expect(repository.cutoffUtc, cutoff);
      expect(repository.endUtc, end);
      expect(repository.k, 6);
      expect(provider.errorMessage, isNull);
      expect(provider.evaluation?.isAvailable, isFalse);
    },
  );

  test(
    'provider exposes a load error without inventing an evaluation',
    () async {
      final repository = _FakeRecommendationEvaluationRepository(
        error: StateError('API is unavailable.'),
      );
      final provider = RecommendationEvaluationProvider(
        GetRecommendationEvaluation(repository),
        CreateRecommendationEvaluationRun(repository),
        GetLatestRecommendationEvaluationRun(repository),
      );

      await provider.load(
        cutoffUtc: DateTime.utc(2026, 8, 1),
        endUtc: DateTime.utc(2026, 8, 8),
        k: 6,
      );

      expect(provider.evaluation, isNull);
      expect(provider.errorMessage, 'API is unavailable.');
    },
  );

  test('provider clears prior evidence before a failed rerun', () async {
    final repository = _FakeRecommendationEvaluationRepository(
      response: RecommendationEvaluationModel.fromJson(
        _evaluationJson(isAvailable: false),
      ),
    );
    final provider = RecommendationEvaluationProvider(
      GetRecommendationEvaluation(repository),
      CreateRecommendationEvaluationRun(repository),
      GetLatestRecommendationEvaluationRun(repository),
    );
    final cutoff = DateTime.utc(2026, 8, 1);
    final end = DateTime.utc(2026, 8, 8);

    await provider.load(cutoffUtc: cutoff, endUtc: end, k: 6);
    expect(provider.evaluation, isNotNull);

    repository.error = StateError('API is unavailable.');
    await provider.load(cutoffUtc: cutoff, endUtc: end, k: 6);

    expect(provider.evaluation, isNull);
    expect(provider.errorMessage, 'API is unavailable.');
  });

  testWidgets('panel makes an unavailable cohort explicit and hides metrics', (
    tester,
  ) async {
    final repository = _FakeRecommendationEvaluationRepository(
      response: RecommendationEvaluationModel.fromJson(
        _evaluationJson(
          isAvailable: false,
          unavailableReason:
              'No users had retained history before the cutoff and a new purchase in the holdout window.',
        ),
      ),
    );
    final provider = RecommendationEvaluationProvider(
      GetRecommendationEvaluation(repository),
      CreateRecommendationEvaluationRun(repository),
      GetLatestRecommendationEvaluationRun(repository),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(
          theme: PadelTheme.light,
          home: const Scaffold(
            body: SingleChildScrollView(
              child: RecommendationEvaluationEvidencePanel(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('recommendation-evaluation-unavailable')),
      findsOneWidget,
    );
    expect(
      find.text('Not enough historical data for a quality result'),
      findsOneWidget,
    );
    expect(find.text('Excluded demo orders'), findsOneWidget);
    expect(find.text('Precision@K'), findsNothing);
    expect(find.text('0.0%'), findsNothing);
  });

  testWidgets('panel compares methods when the evaluator returns metrics', (
    tester,
  ) async {
    final repository = _FakeRecommendationEvaluationRepository(
      response: RecommendationEvaluationModel.fromJson(
        _evaluationJson(isAvailable: true),
      ),
    );
    final provider = RecommendationEvaluationProvider(
      GetRecommendationEvaluation(repository),
      CreateRecommendationEvaluationRun(repository),
      GetLatestRecommendationEvaluationRun(repository),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(
          theme: PadelTheme.light,
          home: const Scaffold(
            body: SingleChildScrollView(
              child: RecommendationEvaluationEvidencePanel(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Precision@K'), findsOneWidget);
    expect(
      find.byKey(const Key('recommendation-evaluation-diagnostic')),
      findsOneWidget,
    );
    expect(find.text('40.0%'), findsWidgets);
    expect(find.text('20.0%'), findsWidgets);
  });
}

class _FakeRecommendationEvaluationRepository
    implements RecommendationEvaluationRepository {
  _FakeRecommendationEvaluationRepository({
    this.response,
    this.error,
  });

  RecommendationEvaluation? response;
  RecommendationEvaluationRun? latestRun;
  Object? error;
  DateTime? cutoffUtc;
  DateTime? endUtc;
  int? k;

  @override
  Future<RecommendationEvaluation> getEvaluation({
    required DateTime cutoffUtc,
    required DateTime endUtc,
    required int k,
  }) async {
    this.cutoffUtc = cutoffUtc;
    this.endUtc = endUtc;
    this.k = k;
    if (error != null) throw error!;
    return response!;
  }

  @override
  Future<RecommendationEvaluationRun> createEvaluationRun({
    required DateTime cutoffUtc,
    required DateTime endUtc,
    required int k,
  }) async {
    if (error != null) throw error!;
    final evaluation = response!;
    return RecommendationEvaluationRun(
      runId: '11111111-1111-1111-1111-111111111111',
      executedByUserId: 1,
      executedAtUtc: DateTime.utc(2026, 9, 1),
      evidenceSource: evaluation.evidenceSource,
      evidenceTier: evaluation.evidenceTier,
      inputFingerprintSha256: evaluation.inputFingerprintSha256,
      configurationSha256: evaluation.configurationSha256,
      report: evaluation,
    );
  }

  @override
  Future<RecommendationEvaluationRun?> getLatestEvaluationRun() async {
    if (error != null) throw error!;
    return latestRun;
  }
}

Map<String, dynamic> _evaluationJson({
  required bool isAvailable,
  bool isMeaningful = false,
  String? unavailableReason,
}) {
  final metric = isAvailable ? 0.4 : null;
  final baselineMetric = isAvailable ? 0.2 : null;
  return {
    'evidenceSource': 'Operational',
    'evidenceTier': isAvailable
        ? (isMeaningful ? 'Qualified' : 'Diagnostic')
        : 'Unavailable',
    'inputFingerprintSha256':
        '1111111111111111111111111111111111111111111111111111111111111111',
    'configurationSha256':
        '2222222222222222222222222222222222222222222222222222222222222222',
    'isAvailable': isAvailable,
    'isSmallSample': false,
    'unavailableReason':
        unavailableReason ??
        (isAvailable
            ? null
            : 'No warm evaluable users were found for the selected window.'),
    'protocol': 'global-temporal-future-basket-v1',
    'algorithmVersion': 'item-cf-cosine-v1',
    'cutoffUtc': '2026-08-01T00:00:00Z',
    'endUtc': '2026-08-08T00:00:00Z',
    'k': 6,
    'cohort': {
      'deliveredOrders': 4,
      'excludedSeededDemoOrders': isAvailable ? 0 : 4,
      'excludedUnverifiedLegacyOrders': 0,
      'excludedNonOperationalOrders': 0,
      'excludedOrdersWithoutDeliveredAt': 0,
      'unresolvedApprovedOrRefundedReturns': 0,
      'distinctCustomers': 2,
      'candidateProductsWithAtLeastTwoDistinctBuyers': 1,
      'historicalObservationDays': 5,
      'eligibleOrderOrigins': const ['CustomerCheckout', 'VerifiedImport'],
      'trainingOrders': 3,
      'holdoutOrders': 1,
      'trainingSignals': 5,
      'holdoutSignals': 2,
      'candidateProducts': 3,
      'evaluatedUsers': isAvailable ? 2 : 0,
      'coldStartUsers': 1,
      'usersWithoutNovelHoldout': 0,
      'excludedHoldoutProductsWithoutTrainingEvidence': 0,
      'legacyDeliveryTimestampFallbacks': 0,
    },
    'quality': {
      'policyVersion': 'operational-provenance-sufficiency-v3',
      'isMeaningful': isMeaningful,
      'evidenceTier': isAvailable
          ? (isMeaningful ? 'Qualified' : 'Diagnostic')
          : 'Unavailable',
      'minimumHistoricalWindowDays': 28,
      'minimumReturnMaturityDays': 30,
      'minimumDeliveredOrders': 100,
      'minimumTrainingSignals': 500,
      'minimumHoldoutSignals': 100,
      'minimumCandidateProducts': 20,
      'minimumEvaluatedUsers': 50,
      'unmetRequirements': isMeaningful
          ? const []
          : const ['eligible-delivered-orders: observed 4; required >= 100.'],
      'gates': [
        {
          'name': 'metrics-available',
          'passed': isAvailable,
          'observed': isAvailable ? 'available' : 'unavailable',
          'required': 'available',
          'detail': 'A warm user is required.',
        },
      ],
    },
    'collaborativeFiltering': {
      'method': 'item-cf-cosine-v1',
      'precisionAtK': metric,
      'recallAtK': metric,
      'hitRateAtK': metric,
      'meanReciprocalRankAtK': metric,
      'normalizedDiscountedCumulativeGainAtK': metric,
      'catalogCoverageAtK': metric,
      'averageRecommendationsReturned': isAvailable ? 4.0 : null,
      'totalHits': isAvailable ? 2 : 0,
      'usersWithRecommendations': isAvailable ? 2 : 0,
    },
    'popularityBaseline': {
      'method': 'popularity-distinct-buyers-v1',
      'precisionAtK': baselineMetric,
      'recallAtK': baselineMetric,
      'hitRateAtK': baselineMetric,
      'meanReciprocalRankAtK': baselineMetric,
      'normalizedDiscountedCumulativeGainAtK': baselineMetric,
      'catalogCoverageAtK': baselineMetric,
      'averageRecommendationsReturned': isAvailable ? 4.0 : null,
      'totalHits': isAvailable ? 1 : 0,
      'usersWithRecommendations': isAvailable ? 2 : 0,
    },
    'limitations': const [
      'Metrics are unavailable when no warm evaluable users are found.',
    ],
  };
}
