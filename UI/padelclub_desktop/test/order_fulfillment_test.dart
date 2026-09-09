import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

import 'package:padelclub_desktop/core/theme/app_theme.dart';
import 'package:padelclub_desktop/features/orders/domain/entities/order.dart';
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
  test('staff status update preserves the admin PUT contract and refreshes', () async {
    final requests = <String>[];
    var getCalls = 0;
    final client = MockClient((request) async {
      requests.add('${request.method} ${request.url.path}');
      if (request.method == 'GET' && request.url.path == '/Orders') {
        getCalls++;
        return http.Response(
          jsonEncode({
            'items': [_orderJson(getCalls == 1 ? 'Pending' : 'Processing')],
          }),
          200,
        );
      }
      if (request.method == 'PUT' && request.url.path == '/Orders/41') {
        expect(request.headers['Content-Type'], 'application/json');
        expect(jsonDecode(request.body), {
          'userId': 8,
          'orderNumber': 'PC-2401',
          'totalAmount': 73.5,
          'status': 'Processing',
          'shippingAddress': 'Court Street 4',
          'notes': 'Leave at reception.',
        });
        return http.Response(jsonEncode(_orderJson('Processing')), 200);
      }
      return http.Response('Unexpected request', 404);
    });
    final provider = OrderProvider(
      client: client,
      baseUrl: 'https://padelclub.test',
      headersProvider: () => const {'Authorization': 'Bearer staff'},
    );
    addTearDown(provider.dispose);

    await provider.loadOrders();
    final changed = await provider.updateStatus(
      order: provider.orders.single,
      nextStatus: 'Processing',
    );

    expect(changed, isTrue);
    expect(provider.errorMessage, isNull);
    expect(provider.orders.single.status, 'Processing');
    expect(requests, ['GET /Orders', 'PUT /Orders/41', 'GET /Orders']);
  });

  test('terminal and skipped transitions never call the order API', () async {
    var requests = 0;
    final provider = OrderProvider(
      client: MockClient((_) async {
        requests++;
        return http.Response('Unexpected request', 500);
      }),
      baseUrl: 'https://padelclub.test',
      headersProvider: () => const {'Authorization': 'Bearer staff'},
    );
    addTearDown(provider.dispose);

    final changed = await provider.updateStatus(
      order: _order('Delivered'),
      nextStatus: 'Processing',
    );

    expect(changed, isFalse);
    expect(requests, 0);
    expect(
      provider.errorMessage,
      'Delivered orders are terminal and cannot be changed.',
    );
    expect(OrderProvider.nextStatusesFor('Processing'), ['Shipped', 'Cancelled']);
  });

  test('server lifecycle conflicts are shown as a readable staff error', () async {
    final provider = OrderProvider(
      client: MockClient((request) async {
        expect(request.method, 'PUT');
        return http.Response(
          jsonEncode({
            'errors': {
              'validationError': [
                'Orders must progress Pending to Processing before shipping.',
              ],
            },
          }),
          409,
        );
      }),
      baseUrl: 'https://padelclub.test',
      headersProvider: () => const {'Authorization': 'Bearer staff'},
    );
    addTearDown(provider.dispose);

    final changed = await provider.updateStatus(
      order: _order('Pending'),
      nextStatus: 'Processing',
    );

    expect(changed, isFalse);
    expect(
      provider.errorMessage,
      'Orders must progress Pending to Processing before shipping.',
    );
  });

  testWidgets('staff confirms the next allowed fulfillment status', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var isProcessing = false;
    final orderClient = MockClient((request) async {
      if (request.method == 'GET' && request.url.path == '/Orders') {
        return http.Response(
          jsonEncode({'items': [_orderJson(isProcessing ? 'Processing' : 'Pending')]}),
          200,
        );
      }
      if (request.method == 'PUT' && request.url.path == '/Orders/41') {
        expect(jsonDecode(request.body)['status'], 'Processing');
        isProcessing = true;
        return http.Response(jsonEncode(_orderJson('Processing')), 200);
      }
      return http.Response('Unexpected request', 404);
    });
    final orderProvider = OrderProvider(
      client: orderClient,
      baseUrl: 'https://padelclub.test',
      headersProvider: () => const {'Authorization': 'Bearer staff'},
    );
    addTearDown(orderProvider.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<OrderProvider>.value(value: orderProvider),
          ChangeNotifierProvider<ReturnRequestsProvider>.value(
            value: _returnProvider(),
          ),
        ],
        child: MaterialApp(
          theme: PadelTheme.light,
          home: const OrderManagementScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Change fulfillment status'));
    await tester.pumpAndSettle();
    expect(
      find.text('Change fulfillment status for PC-2401?'),
      findsOneWidget,
    );
    expect(find.text('Current status: Pending'), findsOneWidget);
    expect(find.text('Confirm Processing'), findsOneWidget);

    await tester.tap(find.text('Confirm Processing'));
    await tester.pumpAndSettle();

    expect(isProcessing, isTrue);
    expect(find.text('Order PC-2401 is now Processing.'), findsOneWidget);
    expect(find.byTooltip('Change fulfillment status'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });
}

ReturnRequestsProvider _returnProvider() {
  final dataSource = ReturnRequestsRemoteDataSourceImpl(
    baseUrl: 'https://padelclub.test',
    headersProvider: () => const {'Authorization': 'Bearer staff'},
    client: MockClient((_) async => http.Response(jsonEncode([]), 200)),
  );
  final repository = ReturnRequestsRepositoryImpl(dataSource);
  return ReturnRequestsProvider(
    GetEligibleReturnOrders(repository),
    CreateReturnRequest(repository),
    GetMyReturnRequests(repository),
    GetReturnRequests(repository),
    ResolveReturnRequest(repository),
  );
}

Map<String, Object?> _orderJson(String status) => {
  'id': 41,
  'userId': 8,
  'orderNumber': 'PC-2401',
  'totalAmount': 73.5,
  'status': status,
  'recipientName': 'Amina Player',
  'phoneNumber': '+38761111222',
  'shippingAddress': 'Court Street 4',
  'city': 'Sarajevo',
  'postalCode': '71000',
  'createdAt': '2026-09-04T09:00:00Z',
  'notes': 'Leave at reception.',
};

Order _order(String status) {
  return Order(
    id: 41,
    userId: 8,
    orderNumber: 'PC-2401',
    totalAmount: 73.5,
    status: status,
    recipientName: 'Amina Player',
    phoneNumber: '+38761111222',
    shippingAddress: 'Court Street 4',
    city: 'Sarajevo',
    postalCode: '71000',
    createdAt: DateTime.utc(2026, 9, 4, 9),
    notes: 'Leave at reception.',
  );
}
