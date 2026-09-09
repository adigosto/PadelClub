import 'package:padelclub_mobile/stripe_payment_presenter.dart';
import 'package:padelclub_desktop/features/payments/domain/entities/payment.dart';
import 'package:flutter/material.dart';

import 'package:padelclub_desktop/core/di/injection.dart';
import 'package:padelclub_desktop/main.dart' show PadelClubBootstrap;
import 'package:padelclub_desktop/providers/auth_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  sl.init();
  final payments = StripePaymentPresenter()..start();
  runApp(buildPadelClubMobileApp(paymentSheetPresenter: payments));
}

/// Builds the mobile distribution target around the shared composition root.
///
/// The optional arguments let runner-level tests isolate platform persistence
/// and remote content while keeping the application routing intact.
Widget buildPadelClubMobileApp({
  PaymentSheetPresenter paymentSheetPresenter = const UnavailablePaymentSheet(),
  AuthProvider? authProvider,
  WidgetBuilder? homeRouteBuilder,
}) {
  return PadelClubBootstrap(
    paymentSheetPresenter: paymentSheetPresenter,
    authProvider: authProvider,
    homeRouteBuilder: homeRouteBuilder,
  );
}
