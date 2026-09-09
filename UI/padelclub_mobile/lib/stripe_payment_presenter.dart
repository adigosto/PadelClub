import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:padelclub_desktop/features/payments/domain/entities/payment.dart' as domain;

class StripePaymentPresenter implements domain.PaymentSheetPresenter {
  StreamSubscription<Uri>? _links;
  @override
  bool get available => !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  void start() {
    if (!available) return;
    _links ??= AppLinks().uriLinkStream.listen((uri) {
      if (uri.scheme == 'padelclub' && uri.host == 'stripe-redirect') {
        unawaited(Stripe.instance.handleURLCallback(uri.toString()).catchError((Object _) => false));
      }
    });
  }
  @override
  Future<void> present(domain.PaymentIntent intent) async {
    if (!available) throw StateError('Card payments require Android or iOS.');
    Stripe.publishableKey = intent.publishableKey;
    Stripe.urlScheme = 'padelclub';
    await Stripe.instance.applySettings();
    try {
      await Stripe.instance.initPaymentSheet(paymentSheetParameters: SetupPaymentSheetParameters(
        paymentIntentClientSecret: intent.clientSecret,
        merchantDisplayName: 'PadelClub',
        returnURL: 'padelclub://stripe-redirect',
      ));
      await Stripe.instance.presentPaymentSheet();
    } on StripeException catch (error) {
      throw Exception(error.error.code == FailureCode.Canceled ? 'Payment cancelled. You can try again later.' : 'Payment could not be completed. Please try again.');
    }
  }
  Future<void> dispose() async { await _links?.cancel(); }
}
