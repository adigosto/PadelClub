import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:padelclub_desktop/core/network/api_config.dart';
import 'package:padelclub_desktop/features/coupons/domain/entities/admin_coupon.dart';
import 'package:padelclub_desktop/providers/auth_provider.dart';

typedef CouponManagementHeadersProvider = Map<String, String> Function();

abstract interface class CouponManagementRemoteDataSource {
  Future<List<AdminCoupon>> getCoupons();

  Future<void> createCoupon(CouponDraft draft);

  Future<void> updateCoupon({
    required int couponId,
    required CouponDraft draft,
  });
}

class CouponManagementRemoteDataSourceImpl
    implements CouponManagementRemoteDataSource {
  CouponManagementRemoteDataSourceImpl({
    http.Client? client,
    String? baseUrl,
    CouponManagementHeadersProvider? headersProvider,
  }) : _client = client ?? http.Client(),
       _baseUrl = (baseUrl ?? ApiConfig.baseUrl).replaceFirst(
         RegExp(r'/$'),
         '',
       ),
       _headersProvider = headersProvider ?? AuthProvider.authenticatedHeaders;

  final http.Client _client;
  final String _baseUrl;
  final CouponManagementHeadersProvider _headersProvider;

  @override
  Future<List<AdminCoupon>> getCoupons() async {
    final response = await _client
        .get(
          Uri.parse('$_baseUrl/Commerce/coupons'),
          headers: _headersProvider(),
        )
        .timeout(const Duration(seconds: 20));
    _ensureSuccess(response, 'load coupons');

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw const FormatException('Coupon list returned an invalid response.');
    }
    return decoded
        .map((entry) {
          if (entry is! Map) {
            throw const FormatException(
              'Coupon list contains an invalid entry.',
            );
          }
          return _couponFromJson(Map<String, dynamic>.from(entry));
        })
        .toList(growable: false);
  }

  @override
  Future<void> createCoupon(CouponDraft draft) =>
      _write(method: 'POST', path: '/Commerce/coupons', draft: draft);

  @override
  Future<void> updateCoupon({
    required int couponId,
    required CouponDraft draft,
  }) =>
      _write(method: 'PUT', path: '/Commerce/coupons/$couponId', draft: draft);

  Future<void> _write({
    required String method,
    required String path,
    required CouponDraft draft,
  }) async {
    final uri = Uri.parse('$_baseUrl$path');
    final headers = {..._headersProvider(), 'Content-Type': 'application/json'};
    final body = jsonEncode(_draftToJson(draft));
    final response = switch (method) {
      'POST' => await _client.post(uri, headers: headers, body: body),
      'PUT' => await _client.put(uri, headers: headers, body: body),
      _ => throw ArgumentError.value(method, 'method'),
    };
    _ensureSuccess(
      response,
      method == 'POST' ? 'create this coupon' : 'update this coupon',
    );
  }

  AdminCoupon _couponFromJson(Map<String, dynamic> json) {
    int requiredInt(String key) {
      final value = json[key];
      if (value is num) return value.toInt();
      throw FormatException('Coupon contains an invalid $key.');
    }

    int? optionalInt(String key) {
      final value = json[key];
      if (value == null) return null;
      if (value is num) return value.toInt();
      throw FormatException('Coupon contains an invalid $key.');
    }

    double requiredNumber(String key) {
      final value = json[key];
      if (value is num) return value.toDouble();
      throw FormatException('Coupon contains an invalid $key.');
    }

    double? optionalNumber(String key) {
      final value = json[key];
      if (value == null) return null;
      if (value is num) return value.toDouble();
      throw FormatException('Coupon contains an invalid $key.');
    }

    DateTime requiredDate(String key) {
      final value = json[key];
      if (value is! String) {
        throw FormatException('Coupon contains an invalid $key.');
      }
      return DateTime.tryParse(value) ??
          (throw FormatException('Coupon contains an invalid $key.'));
    }

    final code = json['code'];
    final type = json['discountType'];
    final active = json['isActive'];
    if (code is! String || type is! String || active is! bool) {
      throw const FormatException(
        'Coupon contains invalid text or status fields.',
      );
    }

    return AdminCoupon(
      id: requiredInt('id'),
      code: code,
      discountType: couponDiscountTypeFromWire(type),
      value: requiredNumber('value'),
      minimumOrderAmount: requiredNumber('minimumOrderAmount'),
      maximumDiscount: optionalNumber('maximumDiscount'),
      validFrom: requiredDate('validFrom'),
      validUntil: requiredDate('validUntil'),
      usageLimit: optionalInt('usageLimit'),
      usageCount: requiredInt('usageCount'),
      perUserLimit: requiredInt('perUserLimit'),
      isActive: active,
    );
  }

  Map<String, Object?> _draftToJson(CouponDraft draft) => {
    'code': draft.code.trim().toUpperCase(),
    'discountType': draft.discountType.wireName,
    'value': draft.value,
    'minimumOrderAmount': draft.minimumOrderAmount,
    'maximumDiscount': draft.maximumDiscount,
    'validFrom': draft.validFrom.toUtc().toIso8601String(),
    'validUntil': draft.validUntil.toUtc().toIso8601String(),
    'usageLimit': draft.usageLimit,
    'perUserLimit': draft.perUserLimit,
    'isActive': draft.isActive,
  };

  void _ensureSuccess(http.Response response, String action) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;

    final detail = _detail(response.body);
    if (detail != null) throw StateError(detail);
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw StateError('You are not authorized to $action.');
    }
    if (response.statusCode == 404) {
      throw StateError('This coupon no longer exists. Refresh and try again.');
    }
    if (response.statusCode == 409) {
      throw StateError(
        'A coupon with this code already exists. Choose another code.',
      );
    }
    throw StateError('Could not $action. Please try again.');
  }

  String? _detail(String responseBody) {
    final trimmed = responseBody.trim();
    if (trimmed.isEmpty) return null;
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is String && decoded.trim().isNotEmpty) return decoded.trim();
      if (decoded case {
        'detail': String detail,
      } when detail.trim().isNotEmpty) {
        return detail.trim();
      }
      if (decoded case {'title': String title} when title.trim().isNotEmpty) {
        return title.trim();
      }
      if (decoded case {'errors': Map errors}) {
        final messages = errors.values
            .whereType<List>()
            .expand((items) => items.whereType<String>())
            .where((message) => message.trim().isNotEmpty)
            .toList(growable: false);
        if (messages.isNotEmpty) return messages.join(' ');
      }
    } on FormatException {
      // The commerce API returns plain-text validation and conflict details.
    }
    return trimmed.length <= 240 ? trimmed : null;
  }
}
