import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:padelclub_desktop/features/reservations/domain/entities/court_availability.dart';
import 'package:padelclub_desktop/features/reservations/presentation/providers/reservation_provider.dart';

void main() {
  test('loads bookings, waitlist entries, and credits together', () async {
    final requestedPaths = <String>[];
    final provider = ReservationProvider(
      client: MockClient((request) async {
        requestedPaths.add(request.url.path);
        switch (request.url.path) {
          case '/Reservations/mine':
            return http.Response(
              jsonEncode({
                'items': [
                  {
                    'id': 9,
                    'courtId': 2,
                    'userId': 12,
                    'startTime': '2026-09-03T18:00:00Z',
                    'endTime': '2026-09-03T19:30:00Z',
                    'totalPrice': 28.5,
                    'status': 'Confirmed',
                    'notes': null,
                  },
                ],
              }),
              200,
            );
          case '/Reservations/waitlist/mine':
            return http.Response(
              jsonEncode([
                {
                  'id': 4,
                  'courtId': 3,
                  'startTimeUtc': '2026-09-04T17:00:00Z',
                  'endTimeUtc': '2026-09-04T18:00:00Z',
                  'status': 'Waiting',
                  'createdAt': '2026-09-02T10:00:00Z',
                },
              ]),
              200,
            );
          case '/Reservations/credits/mine':
            return http.Response(
              jsonEncode([
                {
                  'id': 7,
                  'reservationId': 8,
                  'amount': 19.0,
                  'reason': 'Timely reservation cancellation',
                  'createdAt': '2026-09-01T10:00:00Z',
                  'usedAt': null,
                },
              ]),
              200,
            );
          default:
            return http.Response('Unexpected request', 404);
        }
      }),
      baseUrl: 'http://padelclub.test',
      headersProvider: () => const {'Authorization': 'Bearer test'},
    );

    await provider.loadMyBookingActivity();

    expect(
      requestedPaths,
      containsAll([
        '/Reservations/mine',
        '/Reservations/waitlist/mine',
        '/Reservations/credits/mine',
      ]),
    );
    expect(provider.reservations.single.id, 9);
    expect(provider.waitlistEntries.single.status, 'Waiting');
    expect(provider.accountCredits.single.amount, 19);
    expect(provider.accountCredits.single.isAvailable, isTrue);
    expect(provider.errorMessage, isNull);
  });

  test(
    'booking sends only player-controlled court and interval fields',
    () async {
      final provider = ReservationProvider(
        client: MockClient((request) async {
          expect(request.url.path, '/Reservations');
          expect(jsonDecode(request.body), {
            'courtId': 3,
            'startTime': '2027-09-04T17:00:00.000Z',
            'endTime': '2027-09-04T18:00:00.000Z',
          });
          return http.Response('{}', 200);
        }),
        baseUrl: 'http://padelclub.test',
        headersProvider: () => {},
      );
      expect(
        await provider.book(
          courtId: 3,
          slot: AvailabilitySlot(
            startTime: DateTime.utc(2027, 9, 4, 17),
            endTime: DateTime.utc(2027, 9, 4, 18),
            price: 99,
            isAvailable: true,
            isWaitlistEligible: false,
          ),
        ),
        isTrue,
      );
    },
  );

  test('waitlist request submits the occupied court interval', () async {
    final provider = ReservationProvider(
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/Reservations/waitlist');
        expect(jsonDecode(request.body), {
          'courtId': 3,
          'startTime': '2026-09-04T17:00:00.000Z',
          'endTime': '2026-09-04T18:30:00.000Z',
        });
        return http.Response('{}', 200);
      }),
      baseUrl: 'http://padelclub.test',
      headersProvider: () => const {'Authorization': 'Bearer test'},
    );

    final joined = await provider.joinWaitlist(
      courtId: 3,
      slot: AvailabilitySlot(
        startTime: DateTime.utc(2026, 9, 4, 17),
        endTime: DateTime.utc(2026, 9, 4, 18, 30),
        price: 20,
        isAvailable: false,
        isWaitlistEligible: true,
      ),
    );

    expect(joined, isTrue);
    expect(provider.errorMessage, isNull);
  });
}
