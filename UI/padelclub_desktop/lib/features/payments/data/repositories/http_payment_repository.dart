import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:padelclub_desktop/core/network/api_config.dart';
import 'package:padelclub_desktop/core/network/api_error.dart';
import 'package:padelclub_desktop/features/payments/domain/entities/payment.dart';
import 'package:padelclub_desktop/features/payments/domain/repositories/payment_repository.dart';
class HttpPaymentRepository implements PaymentRepository {
  HttpPaymentRepository({required this.headers, http.Client? client}) : _client = client ?? http.Client();
  final Map<String, String> Function() headers;
  final http.Client _client;
  Future<dynamic> _request(String method, String path, [Object? body]) async {
    final request = http.Request(method, Uri.parse('${ApiConfig.baseUrl}/StripePayments$path'))..headers.addAll(headers());
    if (body != null) request.body = jsonEncode(body);
    final response = await _client.send(request).then(http.Response.fromStream).timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) throw Exception(apiErrorMessage(response.body));
    return jsonDecode(response.body);
  }
  @override
  Future<List<Payable>> load(String type, int page) async {
    final rows = await _request('GET', '/payables?type=$type&page=$page') as List<dynamic>;
    return rows.map((x) => Payable((x['referenceId'] as num).toInt(), x['referenceType'] as String, x['description'] as String, (x['amount'] as num).toDouble(), x['currency'] as String)).toList();
  }
  @override
  Future<PaymentIntent> create(Payable payable) async {
    final configuration = await _request('GET', '/configuration') as Map<String, dynamic>;
    if (configuration['available'] != true) throw Exception('Card payments are currently unavailable. Please contact the club.');
    final reference = switch (payable.type) { 'Order' => 'orderId', 'Reservation' => 'reservationId', 'Membership' => 'membershipId', _ => throw ArgumentError('Unknown payment type') };
    final data = await _request('POST', '/intent', {reference: payable.id, 'idempotencyKey': 'mobile-${payable.type}-${payable.id}'}) as Map<String, dynamic>;
    return PaymentIntent((data['paymentId'] as num).toInt(), data['clientSecret'] as String, configuration['publishableKey'] as String);
  }
  @override
  Future<String> status(int paymentId) async => (await _request('GET', '/$paymentId/status'))['status'] as String;
  @override
  Future<List<Payment>> getPayments({Map<String, dynamic>? filter}) => throw UnimplementedError();
  @override
  void dispose() => _client.close();
}
