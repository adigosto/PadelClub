import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:padelclub_desktop/core/theme/app_theme.dart';
import 'package:padelclub_desktop/features/notifications/data/notification_delivery_remote_data_source.dart';
import 'package:padelclub_desktop/features/notifications/presentation/providers/notification_delivery_diagnostics_provider.dart';
import 'package:padelclub_desktop/features/notifications/presentation/screens/notification_delivery_diagnostics_screen.dart';

void main() {
  test('loads delivery diagnostics through the server status filter', () async {
    Uri? requestedUri;
    final dataSource = NotificationDeliveryRemoteDataSourceImpl(
      baseUrl: 'https://padelclub.test/',
      headersProvider: () => const {'Authorization': 'Bearer administrator'},
      client: MockClient((request) async {
        requestedUri = request.url;
        expect(request.method, 'GET');
        expect(request.headers['Authorization'], 'Bearer administrator');
        return http.Response(jsonEncode([_deliveryJson(status: 'Retry')]), 200);
      }),
    );
    final provider = NotificationDeliveryDiagnosticsProvider(dataSource);
    addTearDown(provider.dispose);

    await provider.load(status: ' Retry ');

    expect(requestedUri?.path, '/NotificationSettings/deliveries');
    expect(requestedUri?.queryParameters, {'status': 'Retry'});
    expect(provider.activeStatus, 'Retry');
    expect(provider.deliveries, hasLength(1));
    expect(provider.deliveries.single.channel, 'Email');
    expect(provider.deliveries.single.lastError, 'SMTP host is not configured.');
    expect(provider.errorMessage, isNull);
  });

  test('shows a readable administrator access error', () async {
    final dataSource = NotificationDeliveryRemoteDataSourceImpl(
      baseUrl: 'https://padelclub.test',
      headersProvider: () => const {'Authorization': 'Bearer player'},
      client: MockClient((_) async => http.Response('', 403)),
    );
    final provider = NotificationDeliveryDiagnosticsProvider(dataSource);
    addTearDown(provider.dispose);

    await provider.load();

    expect(provider.deliveries, isEmpty);
    expect(
      provider.errorMessage,
      'You are not authorized to view delivery diagnostics.',
    );
    expect(provider.isLoading, isFalse);
  });

  testWidgets('filters server delivery attempts and opens their detail', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final requestedStatuses = <String?>[];
    final provider = NotificationDeliveryDiagnosticsProvider(
      NotificationDeliveryRemoteDataSourceImpl(
        baseUrl: 'https://padelclub.test',
        headersProvider: () => const {'Authorization': 'Bearer administrator'},
        client: MockClient((request) async {
          requestedStatuses.add(request.url.queryParameters['status']);
          final isRetry = request.url.queryParameters['status'] == 'Retry';
          return http.Response(
            jsonEncode([
              _deliveryJson(
                id: isRetry ? 102 : 101,
                status: isRetry ? 'Retry' : 'Sent',
                sentAt: isRetry ? null : '2026-09-05T10:31:00Z',
              ),
            ]),
            200,
          );
        }),
      ),
    );
    addTearDown(provider.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: PadelTheme.light,
        home: NotificationDeliveryDiagnosticsScreen(provider: provider),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Delivery #101'), findsOneWidget);
    expect(find.textContaining('SMTP and Firebase'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(requestedStatuses, [null, 'Retry']);
    expect(find.text('Delivery #102'), findsOneWidget);
    expect(find.text('SMTP host is not configured.'), findsOneWidget);

    await tester.tap(find.byTooltip('View delivery attempt'));
    await tester.pumpAndSettle();

    expect(find.text('Delivery attempt #102'), findsOneWidget);
    expect(find.text('Last error'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });
}

Map<String, Object?> _deliveryJson({
  int id = 101,
  required String status,
  String? sentAt,
}) => {
  'id': id,
  'notificationId': 17,
  'userId': 42,
  'channel': 'Email',
  'status': status,
  'attemptCount': status == 'Sent' ? 1 : 2,
  'nextAttemptAt': '2026-09-05T10:35:00Z',
  'sentAt': sentAt,
  'lastError': status == 'Sent' ? null : 'SMTP host is not configured.',
};
