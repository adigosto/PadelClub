import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:padelclub_desktop/core/theme/app_theme.dart';
import 'package:padelclub_desktop/features/payment_history/data/payment_history_remote_data_source.dart';
import 'package:padelclub_desktop/features/payment_history/presentation/providers/payment_history_provider.dart';
import 'package:padelclub_desktop/features/payment_history/presentation/screens/payment_history_screen.dart';

void main() {
  test(
    'parses the owner-scoped paged response without client ownership filtering',
    () async {
      Uri? requestedUri;
      final dataSource = PaymentHistoryRemoteDataSourceImpl(
        baseUrl: 'https://padelclub.test/',
        headersProvider: () => const {'Authorization': 'Bearer player-token'},
        client: MockClient((request) async {
          requestedUri = request.url;
          expect(request.method, 'GET');
          expect(request.headers['Authorization'], 'Bearer player-token');
          return http.Response(
            jsonEncode({
              'items': [_paymentJson(userId: 999)],
              'totalCount': 1,
            }),
            200,
          );
        }),
      );
      final provider = PaymentHistoryProvider(dataSource);
      addTearDown(provider.dispose);

      await provider.load();

      expect(requestedUri?.path, '/Payments/mine');
      expect(requestedUri?.queryParameters, {
        'Page': '1',
        'PageSize': '100',
        'IncludeTotalCount': 'true',
      });
      expect(provider.totalCount, 1);
      expect(provider.payments.single.userId, 999);
      expect(provider.payments.single.membershipId, 22);
      expect(provider.payments.single.refundedAmount, 4.5);
      expect(
        provider.payments.single.reconciledAt,
        DateTime.utc(2026, 9, 5, 12),
      );
      expect(provider.errorMessage, isNull);
    },
  );

  test('reports an owner payment-history access failure clearly', () async {
    final dataSource = PaymentHistoryRemoteDataSourceImpl(
      baseUrl: 'https://padelclub.test',
      headersProvider: () => const {'Authorization': 'Bearer expired'},
      client: MockClient((_) async => http.Response('', 403)),
    );
    final provider = PaymentHistoryProvider(dataSource);
    addTearDown(provider.dispose);

    await provider.load();

    expect(provider.payments, isEmpty);
    expect(
      provider.errorMessage,
      'You are not authorized to view your payment history.',
    );
  });

  testWidgets('shows historical diagnostics and opens all payment details', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final provider = PaymentHistoryProvider(
      PaymentHistoryRemoteDataSourceImpl(
        baseUrl: 'https://padelclub.test',
        headersProvider: () => const {'Authorization': 'Bearer player-token'},
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'items': [_paymentJson()],
              'totalCount': 1,
            }),
            200,
          ),
        ),
      ),
    );
    addTearDown(provider.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: PadelTheme.light,
        home: PaymentHistoryScreen(provider: provider),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Membership'), findsOneWidget);
    expect(find.text('24.50 BAM'), findsOneWidget);
    expect(find.textContaining('does not collect card data'), findsOneWidget);
    expect(find.text('Card - Monthly membership'), findsOneWidget);

    await tester.tap(find.text('Membership'));
    await tester.pumpAndSettle();

    expect(find.text('Payment details'), findsOneWidget);
    expect(find.text('Transaction ID'), findsOneWidget);
    expect(find.text('pi_example'), findsOneWidget);
    expect(find.text('Receipt URL'), findsOneWidget);
    expect(find.text('https://receipt.example/41'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });
}

Map<String, Object?> _paymentJson({int userId = 12}) => {
  'id': 41,
  'userId': userId,
  'paymentType': 'Membership',
  'referenceDescription': 'Monthly membership',
  'reservationId': null,
  'membershipId': 22,
  'orderId': null,
  'amount': 24.5,
  'paymentMethod': 'Card',
  'status': 'PartiallyRefunded',
  'transactionId': 'pi_example',
  'paymentDate': '2026-09-05T10:00:00Z',
  'createdAt': '2026-09-05T09:59:00Z',
  'provider': 'Stripe',
  'currency': 'BAM',
  'refundedAmount': 4.5,
  'receiptUrl': 'https://receipt.example/41',
  'failureMessage': null,
  'reconciledAt': '2026-09-05T12:00:00Z',
};
