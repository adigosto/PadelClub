import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

import 'package:padelclub_desktop/core/theme/app_theme.dart';
import 'package:padelclub_desktop/features/orders/presentation/providers/order_provider.dart';
import 'package:padelclub_desktop/features/orders/presentation/screens/order_management_screen.dart';
import 'package:padelclub_desktop/features/returns/data/datasources/return_requests_remote_data_source.dart';
import 'package:padelclub_desktop/features/returns/data/repositories/return_requests_repository_impl.dart';
import 'package:padelclub_desktop/features/returns/domain/usecases/create_return_request.dart';
import 'package:padelclub_desktop/features/returns/domain/usecases/get_eligible_return_orders.dart';
import 'package:padelclub_desktop/features/returns/domain/usecases/get_my_return_requests.dart';
import 'package:padelclub_desktop/features/returns/domain/usecases/get_return_requests.dart';
import 'package:padelclub_desktop/features/returns/domain/usecases/resolve_return_request.dart';
import 'package:padelclub_desktop/features/returns/presentation/providers/return_requests_provider.dart';

void main() {
  testWidgets(
    'staff filters and confirms an approved return from order management',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      var wasResolved = false;
      final requests = <String>[];
      final remote = ReturnRequestsRemoteDataSourceImpl(
        baseUrl: 'https://padelclub.test',
        headersProvider: () => const {'Authorization': 'Bearer administrator'},
        client: MockClient((request) async {
          requests.add(
            '${request.method} ${request.url.path}?${request.url.query}',
          );
          if (request.method == 'GET' &&
              request.url.path == '/Commerce/returns') {
            if (wasResolved &&
                request.url.queryParameters['status'] == 'Requested') {
              return http.Response(jsonEncode([]), 200);
            }
            return http.Response(jsonEncode([_requestedReturn()]), 200);
          }
          if (request.method == 'PUT' &&
              request.url.path == '/Commerce/returns/17/resolve') {
            expect(request.headers['Content-Type'], 'application/json');
            expect(jsonDecode(request.body), {
              'approve': true,
              'adminNotes': 'Approved after inspection.',
            });
            wasResolved = true;
            return http.Response('', 204);
          }
          return http.Response('Unexpected request', 404);
        }),
      );
      final repository = ReturnRequestsRepositoryImpl(remote);
      final returnProvider = ReturnRequestsProvider(
        GetEligibleReturnOrders(repository),
        CreateReturnRequest(repository),
        GetMyReturnRequests(repository),
        GetReturnRequests(repository),
        ResolveReturnRequest(repository),
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<OrderProvider>.value(
              value: _NoopOrderProvider(),
            ),
            ChangeNotifierProvider<ReturnRequestsProvider>.value(
              value: returnProvider,
            ),
          ],
          child: MaterialApp(
            theme: PadelTheme.light,
            home: const OrderManagementScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Return requests'));
      await tester.pumpAndSettle();
      expect(find.text('Return #17'), findsOneWidget);
      expect(find.text('The grip arrived damaged.'), findsOneWidget);
      expect(find.byTooltip('Approve return'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilterChip, 'Requested'));
      await tester.pumpAndSettle();
      expect(requests, contains('GET /Commerce/returns?status=Requested'));

      await tester.tap(find.byTooltip('Approve return'));
      await tester.pumpAndSettle();
      expect(find.text('Approve return #17?'), findsOneWidget);
      expect(find.text('Approve and restock'), findsOneWidget);

      await tester.enterText(
        find.byType(TextField),
        'Approved after inspection.',
      );
      await tester.tap(find.text('Approve and restock'));
      await tester.pumpAndSettle();

      expect(wasResolved, isTrue);
      expect(requests, contains('PUT /Commerce/returns/17/resolve?'));
      expect(
        find.text('Return #17 was approved and the work queue was refreshed.'),
        findsOneWidget,
      );
      expect(find.text('No return requests found'), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    },
  );
}

class _NoopOrderProvider extends OrderProvider {
  @override
  Future<void> loadOrders() async {}
}

Map<String, Object?> _requestedReturn() => {
  'id': 17,
  'orderId': 41,
  'userId': 8,
  'reason': 'The grip arrived damaged.',
  'status': 'Requested',
  'refundAmount': 54.5,
  'adminNotes': null,
  'createdAt': '2026-09-03T12:00:00Z',
  'resolvedAt': null,
};
