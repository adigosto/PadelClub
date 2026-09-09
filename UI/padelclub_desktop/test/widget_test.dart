import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:padelclub_desktop/core/theme/app_theme.dart';
import 'package:padelclub_desktop/core/widgets/admin_components.dart';
import 'package:padelclub_desktop/dashboard_page.dart';
import 'package:padelclub_desktop/features/operations/presentation/providers/operations_analytics_provider.dart';
import 'package:padelclub_desktop/features/recommendation_evaluation/domain/entities/recommendation_evaluation.dart';
import 'package:padelclub_desktop/features/recommendation_evaluation/domain/repositories/recommendation_evaluation_repository.dart';
import 'package:padelclub_desktop/features/recommendation_evaluation/domain/usecases/create_recommendation_evaluation_run.dart';
import 'package:padelclub_desktop/features/recommendation_evaluation/domain/usecases/get_recommendation_evaluation.dart';
import 'package:padelclub_desktop/features/recommendation_evaluation/domain/usecases/get_latest_recommendation_evaluation_run.dart';
import 'package:padelclub_desktop/features/recommendation_evaluation/presentation/providers/recommendation_evaluation_provider.dart';
import 'package:padelclub_desktop/features/recommendation_evaluation/presentation/providers/recommendation_operational_readiness_provider.dart';
import 'package:padelclub_desktop/layouts/master_screen.dart';
import 'package:padelclub_desktop/main.dart';
import 'package:padelclub_desktop/providers/auth_provider.dart';

void main() {
  testWidgets('shows the login screen', (WidgetTester tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AuthProvider(),
        child: const PadelClubApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
    expect(find.text('Save login information on this device'), findsOneWidget);
    expect(find.text('Continue with Google'), findsNothing);
    expect(find.bySemanticsLabel('PadelClub logo'), findsOneWidget);
    expect(find.byTooltip('Show password'), findsOneWidget);
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantics.dispose();
  });

  testWidgets('mobile shell exposes five player destinations', (
    WidgetTester tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: PadelTheme.light,
        home: const MasterScreen(
          title: 'Home',
          child: Center(child: Text('Player content')),
        ),
      ),
    );

    expect(find.byType(NavigationDestination), findsNWidgets(5));
    expect(find.text('Home'), findsWidgets);
    expect(find.text('Search'), findsOneWidget);
    expect(find.text('Reservations'), findsOneWidget);
    expect(find.text('Shop'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
    expect(tester.takeException(), isNull);
  });

  group('desktop admin UI', () {
    testWidgets('shows the horizontal management navigation', (
      WidgetTester tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: PadelTheme.light,
          home: const MasterScreen(
            title: 'Products',
            section: AppSection.products,
            child: Center(child: Text('Product content')),
          ),
        ),
      );
      debugDefaultTargetPlatformOverride = null;

      expect(find.text('PadelClub Admin'), findsOneWidget);
      expect(find.text('User Management'), findsOneWidget);
      expect(find.text('Product Management'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('Product Management')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('administrator dashboard omits recommendation panels', (
      WidgetTester tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final auth = AuthProvider()..roles = const ['Administrator'];
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: auth),
            ChangeNotifierProvider<OperationsAnalyticsProvider>(
              create: (_) => _NoopOperationsAnalyticsProvider(),
            ),
            ChangeNotifierProvider(
              create: (_) => RecommendationEvaluationProvider(
                GetRecommendationEvaluation(_FailingEvaluationRepository()),
                CreateRecommendationEvaluationRun(
                  _FailingEvaluationRepository(),
                ),
                GetLatestRecommendationEvaluationRun(
                  _FailingEvaluationRepository(),
                ),
              ),
            ),
            ChangeNotifierProvider<RecommendationOperationalReadinessProvider>(
              create: (_) => _NoopRecommendationOperationalReadinessProvider(),
            ),
          ],
          child: MaterialApp(
            theme: PadelTheme.light,
            home: const DashboardPage(),
          ),
        ),
      );
      await tester.pump();
      debugDefaultTargetPlatformOverride = null;

      expect(find.text('Operational recommendation readiness'), findsNothing);
      expect(find.text('Recommendation evaluation evidence'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('admin header stacks its action in a narrow window', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(520, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: PadelTheme.light,
          home: Scaffold(
            body: AdminPageHeader(
              title: 'Court Management',
              subtitle: 'Manage court availability and maintenance.',
              action: FilledButton(
                onPressed: () {},
                child: const Text('Add Court'),
              ),
            ),
          ),
        ),
      );

      final titleTop = tester.getTopLeft(find.text('Court Management')).dy;
      final actionTop = tester.getTopLeft(find.text('Add Court')).dy;
      expect(actionTop, greaterThan(titleTop));
      expect(tester.takeException(), isNull);
    });

    testWidgets('status and action controls expose accessible semantics', (
      WidgetTester tester,
    ) async {
      var pressed = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: PadelTheme.light,
          home: Scaffold(
            body: Row(
              children: [
                const AdminStatusBadge(
                  label: 'Active',
                  tone: AdminStatusTone.success,
                  showDot: true,
                ),
                AdminActionButton(
                  icon: Icons.edit_outlined,
                  tooltip: 'Edit item',
                  onPressed: () => pressed = true,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.bySemanticsLabel('Status: Active'), findsOneWidget);
      expect(find.byTooltip('Edit item'), findsOneWidget);
      expect(tester.getSize(find.byTooltip('Edit item')), const Size(44, 44));
      await tester.tap(find.byTooltip('Edit item'));
      expect(pressed, isTrue);
    });
  });
}

class _FailingEvaluationRepository
    implements RecommendationEvaluationRepository {
  @override
  Future<RecommendationEvaluationRun> createEvaluationRun({
    required DateTime cutoffUtc,
    required DateTime endUtc,
    required int k,
  }) => Future.error(StateError('Evaluation API unavailable in widget test.'));

  @override
  Future<RecommendationEvaluation> getEvaluation({
    required DateTime cutoffUtc,
    required DateTime endUtc,
    required int k,
  }) {
    return Future.error(
      StateError('Evaluation API unavailable in widget test.'),
    );
  }

  @override
  Future<RecommendationEvaluationRun?> getLatestEvaluationRun() =>
      Future.value(null);
}

class _NoopOperationsAnalyticsProvider extends OperationsAnalyticsProvider {
  @override
  Future<void> load() async {}
}

class _NoopRecommendationOperationalReadinessProvider
    extends RecommendationOperationalReadinessProvider {
  @override
  Future<void> load() async {}
}
