import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import 'package:padelclub_desktop/core/localization/app_localizations.dart';
import 'package:padelclub_desktop/core/theme/app_theme.dart';
import 'package:padelclub_desktop/core/widgets/admin_components.dart';
import 'package:padelclub_desktop/features/notifications/domain/entities/notification_delivery.dart';
import 'package:padelclub_desktop/features/notifications/presentation/providers/notification_delivery_diagnostics_provider.dart';
import 'package:padelclub_desktop/layouts/master_screen.dart';

/// Read-only operations view for persisted email and push delivery attempts.
class NotificationDeliveryDiagnosticsScreen extends StatelessWidget {
  const NotificationDeliveryDiagnosticsScreen({super.key, this.provider});

  /// A test-only override. Production construction uses the live provider.
  final NotificationDeliveryDiagnosticsProvider? provider;

  @override
  Widget build(BuildContext context) {
    final value = provider;
    if (value != null) {
      return ChangeNotifierProvider<
        NotificationDeliveryDiagnosticsProvider
      >.value(value: value, child: const _DeliveryDiagnosticsContent());
    }
    return ChangeNotifierProvider<NotificationDeliveryDiagnosticsProvider>(
      create: (_) => NotificationDeliveryDiagnosticsProvider.live(),
      child: const _DeliveryDiagnosticsContent(),
    );
  }
}

class _DeliveryDiagnosticsContent extends StatefulWidget {
  const _DeliveryDiagnosticsContent();

  @override
  State<_DeliveryDiagnosticsContent> createState() =>
      _DeliveryDiagnosticsContentState();
}

class _DeliveryDiagnosticsContentState
    extends State<_DeliveryDiagnosticsContent> {
  static const _statuses = [
    'All',
    'Pending',
    'Retry',
    'Sent',
    'Failed',
    'Skipped',
  ];

  String _status = 'All';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<NotificationDeliveryDiagnosticsProvider>().load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationDeliveryDiagnosticsProvider>();
    return MasterScreen(
      title: context.tr("Delivery Diagnostics"),
      section: AppSection.notifications,
      showBackButton: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminPageHeader(
            title: context.tr("Delivery Diagnostics"),
            subtitle: context.tr(
              "Inspect the latest server-recorded email and push delivery attempts (up to 200 records).",
            ),
            action: Wrap(
              spacing: PadelSpacing.sm,
              runSpacing: PadelSpacing.sm,
              children: [
                OutlinedButton.icon(
                  onPressed: () => Navigator.maybePop(context),
                  icon: const Icon(Icons.notifications_outlined, size: 18),
                  label: Text(context.tr("Notifications")),
                ),
                FilledButton.icon(
                  key: const Key('delivery-diagnostics-refresh-button'),
                  onPressed: provider.isLoading ? null : _loadCurrentStatus,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(context.tr("Refresh")),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              PadelSpacing.lg,
              PadelSpacing.md,
              PadelSpacing.lg,
              PadelSpacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: PadelSpacing.xs,
                  runSpacing: PadelSpacing.xs,
                  children: _statuses
                      .map(
                        (status) => AdminFilterChip(
                          label: status == 'All'
                              ? context.tr("All attempts")
                              : status,
                          selected: _status == status,
                          onSelected: (_) {
                            if (!provider.isLoading) _setStatus(status);
                          },
                        ),
                      )
                      .toList(growable: false),
                ),
                const SizedBox(height: PadelSpacing.md),
                const _DeliveryDiagnosticsCaveat(),
                const SizedBox(height: PadelSpacing.sm),
                Text(
                  _status == 'All'
                      ? context.tr("Server filter: all delivery statuses.")
                      : context.tr("Server filter: {p1} delivery attempts.", {
                          'p1': _status,
                        }),
                  style: const TextStyle(
                    color: PadelColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                PadelSpacing.lg,
                0,
                PadelSpacing.lg,
                PadelSpacing.lg,
              ),
              child: AdminTableSurface(child: _content(provider)),
            ),
          ),
        ],
      ),
    );
  }

  void _setStatus(String status) {
    setState(() => _status = status);
    _loadCurrentStatus(status: status);
  }

  void _loadCurrentStatus({String? status}) {
    final requestedStatus = status ?? _status;
    context.read<NotificationDeliveryDiagnosticsProvider>().load(
      status: requestedStatus == 'All' ? null : requestedStatus,
    );
  }

  Widget _content(NotificationDeliveryDiagnosticsProvider provider) {
    if (provider.isLoading) {
      return Center(
        child: Semantics(
          label: context.tr("Loading delivery diagnostics"),
          child: const CircularProgressIndicator(),
        ),
      );
    }
    if (provider.errorMessage != null) {
      return _DeliveryDiagnosticsMessage(
        icon: Icons.cloud_off_rounded,
        title: context.tr("Delivery diagnostics are unavailable"),
        message: provider.errorMessage!,
        actionLabel: context.tr("Try again"),
        onAction: _loadCurrentStatus,
      );
    }
    if (provider.deliveries.isEmpty) {
      return _DeliveryDiagnosticsMessage(
        icon: Icons.mark_email_unread_outlined,
        title: context.tr("No delivery attempts found"),
        message: _status == 'All'
            ? context.tr(
                "No notification delivery attempts have been recorded yet.",
              )
            : context.tr(
                "No {p1} delivery attempts are in the current server snapshot.",
                {'p1': _status},
              ),
        actionLabel: _status == 'All' ? null : context.tr("Show all attempts"),
        onAction: _status == 'All' ? null : () => _setStatus(context.tr("All")),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(PadelColors.canvas),
              dataRowMinHeight: 80,
              dataRowMaxHeight: 96,
              columnSpacing: 30,
              columns: [
                DataColumn(label: Text(context.tr("DELIVERY"))),
                DataColumn(label: Text(context.tr("RECIPIENT / CHANNEL"))),
                DataColumn(label: Text(context.tr("ATTEMPTS"))),
                DataColumn(label: Text(context.tr("SCHEDULE"))),
                DataColumn(label: Text(context.tr("STATUS"))),
                DataColumn(label: Text(context.tr("ACTIONS"))),
              ],
              rows: provider.deliveries.map(_row).toList(growable: false),
            ),
          ),
        ),
      ),
    );
  }

  DataRow _row(NotificationDelivery delivery) => DataRow(
    onSelectChanged: (_) => _showDetails(delivery),
    cells: [
      DataCell(
        SizedBox(
          width: 142,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr("Delivery #{p1}", {'p1': delivery.id}),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 3),
              Text(
                context.tr("Notification #{p1}", {
                  'p1': delivery.notificationId,
                }),
                style: const TextStyle(
                  color: PadelColors.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
      DataCell(
        SizedBox(
          width: 174,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr("User #{p1}", {'p1': delivery.userId}),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 3),
              Text(
                delivery.channel.trim().isEmpty
                    ? context.tr("Channel unavailable")
                    : delivery.channel,
                style: const TextStyle(
                  color: PadelColors.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
      DataCell(
        SizedBox(
          width: 210,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr("{p1} attempt{p2}", {
                  'p1': delivery.attemptCount,
                  'p2': delivery.attemptCount == 1 ? '' : 's',
                }),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              if (_hasError(delivery)) ...[
                const SizedBox(height: 3),
                Text(
                  delivery.lastError!.trim(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: PadelColors.danger,
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      DataCell(
        SizedBox(
          width: 168,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (delivery.sentAt != null) ...[
                Text(
                  context.tr("Sent"),
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  _dateTime(delivery.sentAt!),
                  style: const TextStyle(
                    color: PadelColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ] else ...[
                Text(
                  context.tr("Next attempt"),
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  _dateTime(delivery.nextAttemptAt),
                  style: const TextStyle(
                    color: PadelColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      DataCell(
        AdminStatusBadge(
          label: delivery.status,
          tone: _statusTone(delivery.status),
        ),
      ),
      DataCell(
        AdminActionButton(
          icon: Icons.visibility_outlined,
          tooltip: context.tr("View delivery attempt"),
          onPressed: () => _showDetails(delivery),
        ),
      ),
    ],
  );

  void _showDetails(NotificationDelivery delivery) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr("Delivery attempt #{p1}", {'p1': delivery.id})),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _detailRow(
                  context.tr("Notification"),
                  '#${delivery.notificationId}',
                ),
                _detailRow(
                  context.tr("Recipient"),
                  context.tr("User #{p1}", {'p1': delivery.userId}),
                ),
                _detailRow(
                  context.tr("Channel"),
                  delivery.channel.trim().isEmpty
                      ? context.tr("Unavailable")
                      : delivery.channel,
                ),
                _detailRow(context.tr("Status"), delivery.status),
                _detailRow(context.tr("Attempts"), '${delivery.attemptCount}'),
                _detailRow(
                  context.tr("Next attempt (UTC)"),
                  _dateTime(delivery.nextAttemptAt),
                ),
                _detailRow(
                  context.tr("Sent at (UTC)"),
                  delivery.sentAt == null
                      ? context.tr("Not sent by the provider yet.")
                      : _dateTime(delivery.sentAt!),
                ),
                _detailRow(
                  context.tr("Last error"),
                  _hasError(delivery)
                      ? delivery.lastError!.trim()
                      : context.tr("No provider error recorded."),
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

  Widget _detailRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 150,
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

  bool _hasError(NotificationDelivery delivery) =>
      delivery.lastError?.trim().isNotEmpty == true;

  AdminStatusTone _statusTone(String status) => switch (status.toLowerCase()) {
    'sent' => AdminStatusTone.success,
    'pending' => AdminStatusTone.info,
    'retry' => AdminStatusTone.warning,
    'failed' => AdminStatusTone.danger,
    'skipped' => AdminStatusTone.neutral,
    _ => AdminStatusTone.neutral,
  };

  String _dateTime(DateTime value) {
    final utc = value.toUtc();
    return '${utc.year}-${_twoDigits(utc.month)}-${_twoDigits(utc.day)} ${_twoDigits(utc.hour)}:${_twoDigits(utc.minute)} UTC';
  }

  String _twoDigits(int value) => value.toString().padLeft(2, '0');
}

class _DeliveryDiagnosticsCaveat extends StatelessWidget {
  const _DeliveryDiagnosticsCaveat();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(PadelSpacing.sm),
    decoration: BoxDecoration(
      color: PadelColors.warningSoft,
      borderRadius: BorderRadius.circular(PadelRadii.medium),
      border: Border.all(color: const Color(0xFFEED8AC)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline_rounded, color: PadelColors.warning),
        SizedBox(width: PadelSpacing.sm),
        Expanded(
          child: Text(
            context.tr(
              "These are delivery-attempt diagnostics, not recipient read receipts. Local development may intentionally have SMTP and Firebase unconfigured, so Pending, Retry, Failed, or Skipped records can reflect provider configuration. This screen never changes a delivery.",
            ),
            style: TextStyle(
              color: Color(0xFF6E4B00),
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ),
      ],
    ),
  );
}

class _DeliveryDiagnosticsMessage extends StatelessWidget {
  const _DeliveryDiagnosticsMessage({
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
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: Padding(
        padding: const EdgeInsets.all(PadelSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: PadelColors.blue),
            const SizedBox(height: PadelSpacing.sm),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: PadelSpacing.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: PadelColors.textMuted),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: PadelSpacing.md),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    ),
  );
}
