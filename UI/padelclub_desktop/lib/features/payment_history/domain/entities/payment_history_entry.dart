/// Immutable owner-scoped payment record returned by `GET /Payments/mine`.
class PaymentHistoryEntry {
  const PaymentHistoryEntry({
    this.referenceDescription = '',
    required this.id,
    required this.userId,
    required this.paymentType,
    required this.reservationId,
    required this.membershipId,
    required this.orderId,
    required this.amount,
    required this.paymentMethod,
    required this.status,
    required this.transactionId,
    required this.paymentDate,
    required this.createdAt,
    required this.provider,
    required this.currency,
    required this.refundedAmount,
    required this.receiptUrl,
    required this.failureMessage,
    required this.reconciledAt,
  });

  final String referenceDescription;
  final int id;
  final int userId;
  final String paymentType;
  final int? reservationId;
  final int? membershipId;
  final int? orderId;
  final double amount;
  final String paymentMethod;
  final String status;
  final String? transactionId;
  final DateTime paymentDate;
  final DateTime createdAt;
  final String provider;
  final String currency;
  final double refundedAmount;
  final String? receiptUrl;
  final String? failureMessage;
  final DateTime? reconciledAt;

  factory PaymentHistoryEntry.fromJson(Map<String, dynamic> json) {
    int requiredInt(String key) {
      final value = json[key];
      if (value is num) return value.toInt();
      throw FormatException('Payment record contains an invalid $key.');
    }

    int? optionalInt(String key) {
      final value = json[key];
      if (value == null) return null;
      if (value is num) return value.toInt();
      throw FormatException('Payment record contains an invalid $key.');
    }

    double requiredNumber(String key) {
      final value = json[key];
      if (value is num) return value.toDouble();
      throw FormatException('Payment record contains an invalid $key.');
    }

    String requiredText(String key) {
      final value = json[key];
      if (value is String) return value;
      throw FormatException('Payment record contains an invalid $key.');
    }

    String? optionalText(String key) {
      final value = json[key];
      if (value == null) return null;
      if (value is String) return value;
      throw FormatException('Payment record contains an invalid $key.');
    }

    DateTime requiredDate(String key) {
      final value = DateTime.tryParse(requiredText(key));
      return value ??
          (throw FormatException('Payment record contains an invalid $key.'));
    }

    DateTime? optionalDate(String key) {
      final raw = json[key];
      if (raw == null) return null;
      if (raw is! String) {
        throw FormatException('Payment record contains an invalid $key.');
      }
      return DateTime.tryParse(raw) ??
          (throw FormatException('Payment record contains an invalid $key.'));
    }

    return PaymentHistoryEntry(
      referenceDescription: json['referenceDescription'] as String? ?? '',
      id: requiredInt('id'),
      userId: requiredInt('userId'),
      paymentType: requiredText('paymentType'),
      reservationId: optionalInt('reservationId'),
      membershipId: optionalInt('membershipId'),
      orderId: optionalInt('orderId'),
      amount: requiredNumber('amount'),
      paymentMethod: requiredText('paymentMethod'),
      status: requiredText('status'),
      transactionId: optionalText('transactionId'),
      paymentDate: requiredDate('paymentDate'),
      createdAt: requiredDate('createdAt'),
      provider: requiredText('provider'),
      currency: requiredText('currency'),
      refundedAmount: requiredNumber('refundedAmount'),
      receiptUrl: optionalText('receiptUrl'),
      failureMessage: optionalText('failureMessage'),
      reconciledAt: optionalDate('reconciledAt'),
    );
  }
}

class PaymentHistoryPage {
  const PaymentHistoryPage({required this.items, required this.totalCount});

  final List<PaymentHistoryEntry> items;
  final int? totalCount;
}
