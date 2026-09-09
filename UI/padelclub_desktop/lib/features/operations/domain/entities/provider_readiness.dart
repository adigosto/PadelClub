/// A server-computed, configuration-only summary of optional providers.
///
/// It intentionally contains no credentials or connection result. The caller
/// must not interpret a `Configured` state as proof of payment or delivery.
class ProviderReadiness {
  const ProviderReadiness({
    required this.assessment,
    required this.caveat,
    required this.stripe,
    required this.smtp,
    required this.firebase,
  });

  final String assessment;
  final String caveat;
  final StripeReadiness stripe;
  final SmtpReadiness smtp;
  final FirebaseReadiness firebase;

  factory ProviderReadiness.fromJson(Map<String, dynamic> json) =>
      ProviderReadiness(
        assessment: _requiredText(json, 'assessment'),
        caveat: _requiredText(json, 'caveat'),
        stripe: StripeReadiness.fromJson(_requiredObject(json, 'stripe')),
        smtp: SmtpReadiness.fromJson(_requiredObject(json, 'smtp')),
        firebase: FirebaseReadiness.fromJson(_requiredObject(json, 'firebase')),
      );
}

class StripeReadiness {
  const StripeReadiness({
    required this.mode,
    required this.intentState,
    required this.webhookState,
    required this.currency,
  });

  final String mode;
  final String intentState;
  final String webhookState;
  final String currency;

  factory StripeReadiness.fromJson(Map<String, dynamic> json) =>
      StripeReadiness(
        mode: _requiredText(json, 'mode'),
        intentState: _requiredText(json, 'intentState'),
        webhookState: _requiredText(json, 'webhookState'),
        currency: _requiredText(json, 'currency'),
      );
}

class SmtpReadiness {
  const SmtpReadiness({required this.state});

  final String state;

  factory SmtpReadiness.fromJson(Map<String, dynamic> json) =>
      SmtpReadiness(state: _requiredText(json, 'state'));
}

class FirebaseReadiness {
  const FirebaseReadiness({required this.state});

  final String state;

  factory FirebaseReadiness.fromJson(Map<String, dynamic> json) =>
      FirebaseReadiness(state: _requiredText(json, 'state'));
}

String _requiredText(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.trim().isNotEmpty) return value;
  throw FormatException('Provider readiness contains an invalid $key.');
}

Map<String, dynamic> _requiredObject(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is Map) return Map<String, dynamic>.from(value);
  throw FormatException('Provider readiness contains an invalid $key object.');
}
