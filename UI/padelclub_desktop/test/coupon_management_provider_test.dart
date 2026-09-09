import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:padelclub_desktop/features/coupons/data/coupon_management_remote_data_source.dart';
import 'package:padelclub_desktop/features/coupons/domain/entities/admin_coupon.dart';
import 'package:padelclub_desktop/features/coupons/presentation/providers/coupon_management_provider.dart';

void main() {
  test('lists, creates, and updates coupons through the admin contract', () async {
    final requests = <String>[];
    final listSnapshots = <List<Map<String, Object?>>>[
      [_coupon(id: 7, code: 'WELCOME10', usageCount: 2)],
      [_coupon(id: 8, code: 'CLUB15', usageCount: 0)],
      [_coupon(id: 8, code: 'CLUB20', usageCount: 4, isActive: false)],
    ];
    final remote = CouponManagementRemoteDataSourceImpl(
      baseUrl: 'https://padelclub.test',
      headersProvider: () => const {'Authorization': 'Bearer administrator'},
      client: MockClient((request) async {
        requests.add('${request.method} ${request.url.path}');
        expect(request.headers['Authorization'], 'Bearer administrator');

        if (request.method == 'GET') {
          return http.Response(jsonEncode(listSnapshots.removeAt(0)), 200);
        }

        expect(request.headers['Content-Type'], 'application/json');
        final body = Map<String, dynamic>.from(jsonDecode(request.body) as Map);
        expect(body, {
          'code': request.method == 'POST' ? 'CLUB15' : 'CLUB20',
          'discountType': 'Percentage',
          'value': request.method == 'POST' ? 15.0 : 20.0,
          'minimumOrderAmount': 25.0,
          'maximumDiscount': 40.0,
          'validFrom': '2026-09-01T00:00:00.000Z',
          'validUntil': '2026-10-01T00:00:00.000Z',
          'usageLimit': 100,
          'perUserLimit': 1,
          'isActive': request.method == 'POST',
        });
        return http.Response(
          request.method == 'POST' ? '{"id":8,"code":"CLUB15"}' : '',
          request.method == 'POST' ? 200 : 204,
        );
      }),
    );
    final provider = CouponManagementProvider(remote);

    await provider.load();
    final created = await provider.create(_draft(code: 'club15', value: 15));
    final updated = await provider.update(
      couponId: 8,
      draft: _draft(code: 'club20', value: 20, isActive: false),
    );

    expect(created, isTrue);
    expect(updated, isTrue);
    expect(requests, [
      'GET /Commerce/coupons',
      'POST /Commerce/coupons',
      'GET /Commerce/coupons',
      'PUT /Commerce/coupons/8',
      'GET /Commerce/coupons',
    ]);
    expect(provider.coupons.single.code, 'CLUB20');
    expect(provider.coupons.single.isActive, isFalse);
    expect(provider.coupons.single.usageCount, 4);
    expect(provider.lastOperationMessage, contains('refreshed from the server'));
    expect(provider.errorMessage, isNull);
  });

  test('surfaces server coupon-code conflicts without changing the list', () async {
    final remote = CouponManagementRemoteDataSourceImpl(
      baseUrl: 'https://padelclub.test',
      headersProvider: () => const {'Authorization': 'Bearer administrator'},
      client: MockClient((request) async {
        expect(request.method, 'POST');
        return http.Response('"Coupon code already exists."', 409);
      }),
    );
    final provider = CouponManagementProvider(remote);

    final saved = await provider.create(_draft(code: 'duplicate', value: 15));

    expect(saved, isFalse);
    expect(provider.coupons, isEmpty);
    expect(provider.errorMessage, 'Coupon code already exists.');
  });
}

CouponDraft _draft({
  required String code,
  required double value,
  bool isActive = true,
}) => CouponDraft(
  code: code,
  discountType: CouponDiscountType.percentage,
  value: value,
  minimumOrderAmount: 25,
  maximumDiscount: 40,
  validFrom: DateTime.utc(2026, 9, 1),
  validUntil: DateTime.utc(2026, 10, 1),
  usageLimit: 100,
  perUserLimit: 1,
  isActive: isActive,
);

Map<String, Object?> _coupon({
  required int id,
  required String code,
  required int usageCount,
  bool isActive = true,
}) => {
  'id': id,
  'code': code,
  'discountType': 'Percentage',
  'value': 15,
  'minimumOrderAmount': 25,
  'maximumDiscount': 40,
  'validFrom': '2026-09-01T00:00:00Z',
  'validUntil': '2026-10-01T00:00:00Z',
  'usageLimit': 100,
  'usageCount': usageCount,
  'perUserLimit': 1,
  'isActive': isActive,
};
