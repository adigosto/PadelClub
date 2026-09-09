import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:padelclub_desktop/core/theme/app_theme.dart';
import 'package:padelclub_desktop/features/operations/data/provider_readiness_remote_data_source.dart';
import 'package:padelclub_desktop/features/operations/presentation/providers/provider_readiness_provider.dart';
import 'package:padelclub_desktop/features/operations/presentation/screens/provider_readiness_screen.dart';

void main() {
  test('loads the administrator-only configuration snapshot without a probe', () async {
    Uri? requestedUri;
    final dataSource = ProviderReadinessRemoteDataSourceImpl(
      baseUrl: 'https://padelclub.test/',
      headersProvider: () => const {'Authorization': 'Bearer administrator'},
      client: MockClient((request) async {
        requestedUri = request.url;
        expect(request.method, 'GET');
        expect(request.headers['Authorization'], 'Bearer administrator');
        return http.Response(jsonEncode(_readinessJson()), 200);
      }),
    );

    final readiness = await dataSource.getReadiness();

    expect(requestedUri?.path, '/Operations/provider-readiness');
    expect(requestedUri?.query, isEmpty);
    expect(readiness.assessment, 'ConfigurationOnly');
    expect(readiness.stripe.intentState, 'Configured');
    expect(readiness.smtp.state, 'Mailpit');
    expect(readiness.firebase.state, 'Disabled');
  });

  testWidgets('shows the explicit configuration-only boundary', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final provider = ProviderReadinessProvider(
      ProviderReadinessRemoteDataSourceImpl(
        baseUrl: 'https://padelclub.test',
        headersProvider: () => const {'Authorization': 'Bearer administrator'},
        client: MockClient((_) async => http.Response(jsonEncode(_readinessJson()), 200)),
      ),
    );
    addTearDown(provider.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: PadelTheme.light,
        home: ProviderReadinessScreen(provider: provider),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Stripe payments'), findsOneWidget);
    expect(find.text('SMTP email'), findsOneWidget);
    expect(find.text('Firebase push'), findsOneWidget);
    expect(find.text('Mailpit'), findsOneWidget);
    expect(find.textContaining('does not contact Stripe'), findsOneWidget);
    expect(find.textContaining('No provider secret'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });
}

Map<String, Object?> _readinessJson() => {
  'assessment': 'ConfigurationOnly',
  'caveat':
      'This reports local configuration shape only. It does not contact Stripe, SMTP, or Firebase.',
  'stripe': {
    'mode': 'Test',
    'intentState': 'Configured',
    'webhookState': 'Configured',
    'currency': 'BAM',
  },
  'smtp': {'state': 'Mailpit'},
  'firebase': {'state': 'Disabled'},
};
