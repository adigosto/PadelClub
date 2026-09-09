import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:padelclub_desktop/core/theme/app_theme.dart';
import 'package:padelclub_desktop/features/operations/data/audit_trail_remote_data_source.dart';
import 'package:padelclub_desktop/features/operations/domain/entities/audit_trail_filter.dart';
import 'package:padelclub_desktop/features/operations/presentation/providers/audit_trail_provider.dart';
import 'package:padelclub_desktop/features/operations/presentation/screens/audit_trail_screen.dart';

void main() {
  test(
    'loads the immutable audit snapshot with normalized server filters',
    () async {
      Uri? requestedUri;
      final dataSource = AuditTrailRemoteDataSourceImpl(
        baseUrl: 'https://padelclub.test/',
        headersProvider: () => const {'Authorization': 'Bearer administrator'},
        client: MockClient((request) async {
          requestedUri = request.url;
          expect(request.method, 'GET');
          expect(request.headers['Authorization'], 'Bearer administrator');
          return http.Response(jsonEncode([_auditJson()]), 200);
        }),
      );
      final provider = AuditTrailProvider(dataSource);
      addTearDown(provider.dispose);

      await provider.load(
        filter: AuditTrailFilter(
          userId: 42,
          method: 'post',
          from: DateTime.utc(2026, 9, 5),
        ),
      );

      expect(requestedUri?.path, '/Operations/audit');
      expect(requestedUri?.queryParameters, {
        'userId': '42',
        'method': 'POST',
        'from': '2026-09-05T00:00:00.000Z',
      });
      expect(provider.entries, hasLength(1));
      expect(provider.entries.single.id, 91);
      expect(provider.entries.single.userId, 42);
      expect(provider.entries.single.durationMs, 14);
      expect(provider.activeFilter.method, 'POST');
      expect(provider.errorMessage, isNull);
    },
  );

  test(
    'exposes a readable access error without retaining stale audit data',
    () async {
      final dataSource = AuditTrailRemoteDataSourceImpl(
        baseUrl: 'https://padelclub.test',
        headersProvider: () => const {'Authorization': 'Bearer player'},
        client: MockClient((_) async => http.Response('', 403)),
      );
      final provider = AuditTrailProvider(dataSource);
      addTearDown(provider.dispose);

      await provider.load();

      expect(provider.entries, isEmpty);
      expect(
        provider.errorMessage,
        'You are not authorized to view the audit trail.',
      );
      expect(provider.isLoading, isFalse);
    },
  );

  testWidgets('shows an audit row and its read-only detail dialog', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final provider = AuditTrailProvider(
      AuditTrailRemoteDataSourceImpl(
        baseUrl: 'https://padelclub.test',
        headersProvider: () => const {'Authorization': 'Bearer administrator'},
        client: MockClient(
          (_) async => http.Response(jsonEncode([_auditJson()]), 200),
        ),
      ),
    );
    addTearDown(provider.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: PadelTheme.light,
        home: AuditTrailScreen(provider: provider),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('POST'), findsOneWidget);
    expect(find.text('/Commerce/returns/17/resolve'), findsOneWidget);
    expect(find.text('HTTP 204'), findsOneWidget);
    expect(find.text('amina'), findsOneWidget);

    await tester.tap(find.byTooltip('View audit event'));
    await tester.pumpAndSettle();

    expect(find.text('Audit event #91'), findsOneWidget);
    expect(find.text('Correlation ID'), findsOneWidget);
    expect(find.text('trace-abc'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });
}

Map<String, Object?> _auditJson() => {
  'id': 91,
  'userId': 42,
  'userName': 'amina',
  'method': 'POST',
  'path': '/Commerce/returns/17/resolve',
  'statusCode': 204,
  'ipAddress': '127.0.0.1',
  'correlationId': 'trace-abc',
  'durationMs': 14,
  'createdAt': '2026-09-05T10:30:45Z',
};
