import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import 'package:padelclub_desktop/core/localization/app_localizations.dart';
import 'package:padelclub_desktop/core/theme/app_theme.dart';
import 'package:padelclub_desktop/core/widgets/admin_components.dart';
import 'package:padelclub_desktop/features/payment_history/domain/entities/payment_history_entry.dart';
import 'package:padelclub_desktop/features/payment_history/presentation/providers/payment_history_provider.dart';
import 'package:padelclub_desktop/layouts/master_screen.dart';

/// Player-facing history only: it has no card entry, payment, refund, or claim
/// controls and never infers that Stripe is configured for the local runtime.
class PaymentHistoryScreen extends StatelessWidget {
  const PaymentHistoryScreen({super.key, this.provider});

  final PaymentHistoryProvider? provider;

  @override
  Widget build(BuildContext context) {
    final value = provider;
    if (value != null) {
      return ChangeNotifierProvider<PaymentHistoryProvider>.value(
        value: value,
        child: const _PaymentHistoryContent(),
      );
    }
    return ChangeNotifierProvider<PaymentHistoryProvider>(
      create: (_) => PaymentHistoryProvider.live(),
      child: const _PaymentHistoryContent(),
    );
  }
}

class _PaymentHistoryContent extends StatefulWidget {
  const _PaymentHistoryContent();

  @override
  State<_PaymentHistoryContent> createState() => _PaymentHistoryContentState();
}

class _PaymentHistoryContentState extends State<_PaymentHistoryContent> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<PaymentHistoryProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PaymentHistoryProvider>();
    return MasterScreen(
      title: context.tr("Payment history"),
      section: AppSection.profile,
      showBackButton: true,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr("Payment history"),
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: PadelColors.text,
                          ),
                        ),
                        SizedBox(height: 5),
                        Text(
                          context.tr(
                            "Your server-recorded payment history and reconciliation details.",
                          ),
                          style: TextStyle(
                            color: PadelColors.textMuted,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    key: const Key('payment-history-refresh'),
                    tooltip: context.tr("Refresh payment history"),
                    onPressed: provider.isLoading ? null : provider.load,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18),
              child: _PaymentHistoryNotice(),
            ),
            const SizedBox(height: 12),
            Expanded(child: _content(provider)),
          ],
        ),
      ),
    );
  }

  Widget _content(PaymentHistoryProvider provider) {
    if (provider.isLoading) {
      return Center(
        child: Semantics(
          label: context.tr("Loading payment history"),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (provider.errorMessage != null) {
      return _PaymentHistoryState(
        icon: Icons.cloud_off_rounded,
        title: context.tr("Payment history is unavailable"),
        message: provider.errorMessage!,
        actionLabel: context.tr("Try again"),
        onAction: provider.load,
      );
    }
    if (provider.payments.isEmpty) {
      return _PaymentHistoryState(
        icon: Icons.receipt_long_outlined,
        title: context.tr("No payment records yet"),
        message: context.tr(
          "Historical payment records will appear here when the server has recorded them.",
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(18, 2, 18, 34),
      itemCount: provider.payments.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index == 0) {
          final count = provider.totalCount ?? provider.payments.length;
          return Text(
            context.tr("{p1} historical payment record{p2}", {
              'p1': count,
              'p2': count == 1 ? '' : 's',
            }),
            style: const TextStyle(color: PadelColors.textMuted, fontSize: 12),
          );
        }
        final payment = provider.payments[index - 1];
        return _PaymentHistoryCard(
          payment: payment,
          onTap: () => _showDetails(payment),
        );
      },
    );
  }

  void _showDetails(PaymentHistoryEntry payment) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('Payment details')),
        content: SizedBox(
          width: 580,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _detail(context.tr("Payment type"), payment.paymentType),
                _detail(context.tr("Status"), payment.status),
                _detail(context.tr("Amount"), _amount(payment)),
                _detail(context.tr("Refunded amount"), _refundAmount(payment)),
                _detail(context.tr("Payment method"), payment.paymentMethod),
                _detail(context.tr("Provider"), payment.provider),
                _detail(
                  context.tr("Payment date (UTC)"),
                  _dateTime(payment.paymentDate),
                ),
                _detail(
                  context.tr("Created at (UTC)"),
                  _dateTime(payment.createdAt),
                ),
                _detail(
                  context.tr('Payment for'),
                  payment.referenceDescription.isEmpty
                      ? context.tr(payment.paymentType)
                      : payment.referenceDescription,
                ),
                _detail(
                  context.tr("Transaction ID"),
                  _optional(payment.transactionId),
                ),
                _detail(
                  context.tr("Receipt URL"),
                  _optional(payment.receiptUrl),
                ),
                _detail(
                  context.tr("Failure message"),
                  _optional(payment.failureMessage),
                ),
                _detail(
                  context.tr("Reconciled at (UTC)"),
                  payment.reconciledAt == null
                      ? context.tr("Not reconciled")
                      : _dateTime(payment.reconciledAt!),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.tr("Close")),
          ),
        ],
      ),
    );
  }

  Widget _detail(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 165,
          child: Text(
            label,
            style: const TextStyle(
              color: PadelColors.textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(child: SelectableText(value)),
      ],
    ),
  );

  String _amount(PaymentHistoryEntry payment) =>
      '${context.l10n.number(payment.amount, decimalDigits: 2)} ${payment.currency}';

  String _refundAmount(PaymentHistoryEntry payment) =>
      '${context.l10n.number(payment.refundedAmount, decimalDigits: 2)} ${payment.currency}';

  String _optional(String? value) => value?.trim().isEmpty == false
      ? value!.trim()
      : context.tr("Not recorded");

  String _dateTime(DateTime value) {
    final utc = value.toUtc();
    return '${utc.year}-${_two(utc.month)}-${_two(utc.day)} ${_two(utc.hour)}:${_two(utc.minute)}';
  }

  String _two(int value) => value.toString().padLeft(2, '0');
}

class _PaymentHistoryNotice extends StatelessWidget {
  const _PaymentHistoryNotice();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: PadelColors.blueSoft,
      borderRadius: BorderRadius.circular(PadelRadii.large),
      border: Border.all(color: const Color(0xFFD3E1FF)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline_rounded, color: PadelColors.blue),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            context.tr(
              "These records are historical and diagnostic only. This screen does not collect card data, start a payment, issue a refund, or imply that Stripe is configured in this local environment.",
            ),
            style: TextStyle(
              color: Color(0xFF35527C),
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ),
      ],
    ),
  );
}

class _PaymentHistoryCard extends StatelessWidget {
  const _PaymentHistoryCard({required this.payment, required this.onTap});

  final PaymentHistoryEntry payment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(PadelRadii.large),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(PadelRadii.large),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(PadelRadii.large),
          border: Border.all(color: PadelColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _toneSurface(_statusTone(payment.status)),
                borderRadius: BorderRadius.circular(PadelRadii.medium),
              ),
              child: Icon(
                Icons.receipt_long_outlined,
                color: _toneColor(_statusTone(payment.status)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    payment.paymentType,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${payment.paymentMethod} - ${_referenceLabel(context, payment)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: PadelColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${context.l10n.number(payment.amount, decimalDigits: 2)} ${payment.currency}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                _StatusPill(status: payment.status),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  String _referenceLabel(BuildContext context, PaymentHistoryEntry payment) {
    return payment.referenceDescription.isNotEmpty
        ? payment.referenceDescription
        : context.tr(payment.paymentType);
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final tone = _statusTone(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _toneSurface(tone),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        context.tr(status),
        style: TextStyle(
          color: _toneColor(tone),
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _PaymentHistoryState extends StatelessWidget {
  const _PaymentHistoryState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 46, color: PadelColors.blue),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(message, textAlign: TextAlign.center),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 14),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    ),
  );
}

AdminStatusTone _statusTone(String status) => switch (status.toLowerCase()) {
  'completed' || 'paid' => AdminStatusTone.success,
  'pending' || 'processing' => AdminStatusTone.info,
  'partiallyrefunded' => AdminStatusTone.warning,
  'refunded' || 'failed' || 'cancelled' => AdminStatusTone.danger,
  _ => AdminStatusTone.neutral,
};

Color _toneColor(AdminStatusTone tone) => switch (tone) {
  AdminStatusTone.success => PadelColors.greenDark,
  AdminStatusTone.info => PadelColors.blue,
  AdminStatusTone.warning => PadelColors.warning,
  AdminStatusTone.danger => PadelColors.danger,
  AdminStatusTone.neutral => PadelColors.textMuted,
};

Color _toneSurface(AdminStatusTone tone) => switch (tone) {
  AdminStatusTone.success => PadelColors.greenSoft,
  AdminStatusTone.info => PadelColors.blueSoft,
  AdminStatusTone.warning => PadelColors.warningSoft,
  AdminStatusTone.danger => PadelColors.dangerSoft,
  AdminStatusTone.neutral => PadelColors.canvas,
};
