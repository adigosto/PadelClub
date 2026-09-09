import 'package:padelclub_desktop/features/courts/domain/entities/court.dart';
import 'package:padelclub_desktop/features/courts/presentation/providers/court_provider.dart';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

import 'package:padelclub_desktop/core/theme/app_theme.dart';
import 'package:padelclub_desktop/features/reservations/presentation/providers/reservation_provider.dart';
import 'package:padelclub_desktop/features/reservations/presentation/screens/reservation_screens.dart';

void main() {
  test(
    'submits an administrator maintenance block with a UTC interval',
    () async {
      final provider = ReservationProvider(
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/Reservations/maintenance');
          expect(request.headers['authorization'], 'Bearer administrator');
          expect(jsonDecode(request.body), {
            'courtId': 3,
            'startTimeUtc': '2026-09-05T08:00:00.000Z',
            'endTimeUtc': '2026-09-05T09:30:00.000Z',
            'reason': 'Replace the court net',
          });
          return http.Response('17', 200);
        }),
        baseUrl: 'http://padelclub.test',
        headersProvider: () => const {'Authorization': 'Bearer administrator'},
      );

      final scheduled = await provider.addMaintenanceBlock(
        courtId: 3,
        startTime: DateTime.utc(2026, 9, 5, 8),
        endTime: DateTime.utc(2026, 9, 5, 9, 30),
        reason: '  Replace the court net  ',
      );

      expect(scheduled, isTrue);
      expect(provider.isLoading, isFalse);
      expect(provider.errorMessage, isNull);
    },
  );

  test('marks a reservation as no-show and surfaces API failures', () async {
    var requestCount = 0;
    final provider = ReservationProvider(
      client: MockClient((request) async {
        requestCount++;
        expect(request.method, 'PUT');
        expect(request.url.path, '/Reservations/42/no-show');
        if (requestCount == 1) return http.Response('', 204);
        return http.Response('Reservation no longer exists.', 404);
      }),
      baseUrl: 'http://padelclub.test',
      headersProvider: () => const {'Authorization': 'Bearer administrator'},
    );

    expect(await provider.markNoShow(42), isTrue);
    expect(provider.errorMessage, isNull);

    expect(await provider.markNoShow(42), isFalse);
    expect(provider.isLoading, isFalse);
    expect(provider.errorMessage, 'Reservation no longer exists.');
  });

  testWidgets(
    'admin reservation operations expose maintenance and no-show controls',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final requests = <String>[];
      final provider = ReservationProvider(
        client: MockClient((request) async {
          requests.add('${request.method} ${request.url.path}');
          if (request.method == 'GET' && request.url.path == '/Reservations') {
            final start = DateTime.now().toUtc().subtract(
              const Duration(hours: 2),
            );
            final end = DateTime.now().toUtc().subtract(
              const Duration(hours: 1),
            );
            return http.Response(
              jsonEncode({
                'items': [
                  {
                    'id': 42,
                    'courtId': 3,
                    'courtName': 'Garden court',
                    'userName': 'Amina',
                    'userId': 7,
                    'startTime': start.toIso8601String(),
                    'endTime': end.toIso8601String(),
                    'totalPrice': 25,
                    'status': 'Confirmed',
                  },
                ],
              }),
              200,
            );
          }
          if (request.method == 'PUT' &&
              request.url.path == '/Reservations/42/no-show') {
            return http.Response('', 204);
          }
          return http.Response('Unexpected request', 404);
        }),
        baseUrl: 'http://padelclub.test',
        headersProvider: () => const {'Authorization': 'Bearer administrator'},
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: provider),
            ChangeNotifierProvider<CourtProvider>(create: (_) => _TestCourts()),
          ],
          child: MaterialApp(
            theme: PadelTheme.light,
            home: const ManagementReservationsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Schedule maintenance'), findsOneWidget);
      expect(find.byTooltip('Mark player as no-show'), findsOneWidget);

      await tester.tap(find.text('Schedule maintenance'));
      await tester.pumpAndSettle();
      expect(find.text('Schedule court maintenance'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Maintenance start:')), findsWidgets);
      expect(find.byType(DropdownButtonFormField<int>), findsOneWidget);
      expect(find.text('All active courts'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Mark player as no-show'));
      await tester.pumpAndSettle();
      expect(find.text('Mark player as no-show?'), findsOneWidget);

      await tester.tap(find.text('Mark no-show'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(requests, contains('PUT /Reservations/42/no-show'));
      expect(
        find.text('Booking for Garden court marked as no-show.'),
        findsOneWidget,
      );
      debugDefaultTargetPlatformOverride = null;
    },
  );
}

class _TestCourts extends CourtProvider {
  @override
  Future<void> loadCourts() async {
    courts = [
      Court(
        id: 3,
        name: 'Garden court',
        description: '',
        isIndoor: false,
        isActive: true,
        hourlyRate: 25,
        maxPlayers: 4,
        createdAt: DateTime(2026),
      ),
    ];
  }
}
