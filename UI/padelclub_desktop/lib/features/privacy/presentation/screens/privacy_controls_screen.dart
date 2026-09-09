import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import 'package:padelclub_desktop/core/localization/app_localizations.dart';
import 'package:padelclub_desktop/core/theme/app_theme.dart';
import 'package:padelclub_desktop/features/privacy/domain/entities/privacy_deletion_status.dart';
import 'package:padelclub_desktop/features/privacy/presentation/providers/privacy_controls_provider.dart';
import 'package:padelclub_desktop/layouts/master_screen.dart';

class PrivacyControlsScreen extends StatefulWidget {
  const PrivacyControlsScreen({super.key});

  @override
  State<PrivacyControlsScreen> createState() => _PrivacyControlsScreenState();
}

class _PrivacyControlsScreenState extends State<PrivacyControlsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<PrivacyControlsProvider>().loadDeletionStatus(),
    );
  }

  Future<void> _viewExport(PrivacyControlsProvider provider) async {
    final export = await provider.viewExport();
    if (!mounted || export == null) return;
    await showDialog<void>(
      context: context,
      builder: (_) => _PrivacyExportDialog(export: export),
    );
  }

  Future<void> _requestDeletion(PrivacyControlsProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr("Schedule account deletion?")),
        content: Text(
          context.tr(
            "This does not delete your account immediately. PadelClub will schedule deletion for 30 days from now, and you can cancel it before the scheduled date.",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.tr("Keep my account")),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: PadelColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.tr("Schedule deletion")),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final scheduled = await provider.requestDeletion();
    if (!mounted || !scheduled) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.tr(
            "Account deletion has been scheduled. You can cancel it before the scheduled date.",
          ),
        ),
      ),
    );
  }

  Future<void> _cancelDeletion(PrivacyControlsProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr("Cancel scheduled deletion?")),
        content: Text(
          context.tr(
            "Your account and its scheduled deletion request will remain active only until you explicitly request deletion again.",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.tr("Keep deletion scheduled")),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.tr("Cancel deletion")),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final cancelled = await provider.cancelDeletion();
    if (!mounted || !cancelled) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.tr("Scheduled account deletion cancelled.")),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MasterScreen(
      title: context.tr("Privacy and security"),
      section: AppSection.profile,
      showBackButton: true,
      child: Consumer<PrivacyControlsProvider>(
        builder: (context, provider, _) => Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 34),
              children: [
                Text(
                  context.tr("Privacy controls"),
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: PadelColors.text,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  context.tr(
                    "Review your account data and manage a scheduled account deletion.",
                  ),
                  style: TextStyle(color: PadelColors.textMuted, height: 1.4),
                ),
                const SizedBox(height: 20),
                if (provider.errorMessage != null) ...[
                  _PrivacyNotice(
                    message: provider.errorMessage!,
                    onRetry:
                        provider.isLoadingStatus || provider.isMutatingDeletion
                        ? null
                        : provider.loadDeletionStatus,
                  ),
                  const SizedBox(height: 14),
                ],
                _DataExportCard(
                  isLoading: provider.isLoadingExport,
                  onView: provider.isLoadingExport
                      ? null
                      : () => _viewExport(provider),
                ),
                const SizedBox(height: 16),
                _DeletionStatusCard(
                  status: provider.deletionStatus,
                  isLoading: provider.isLoadingStatus,
                  isRequesting: provider.isRequestingDeletion,
                  isCancelling: provider.isCancellingDeletion,
                  onRequest:
                      provider.isLoadingStatus || provider.isMutatingDeletion
                      ? null
                      : () => _requestDeletion(provider),
                  onCancel:
                      provider.isLoadingStatus || provider.isMutatingDeletion
                      ? null
                      : () => _cancelDeletion(provider),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: PadelColors.blueSoft,
                    borderRadius: BorderRadius.circular(PadelRadii.large),
                    border: Border.all(color: const Color(0xFFD3E1FF)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.shield_outlined, color: PadelColors.blue),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          context.tr(
                            "Only request deletion from a device you trust. Export data can include account, booking, order, membership, payment, and notification records.",
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
                ),
              ],
            ),
            if (provider.isLoadingStatus)
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }
}

class _DataExportCard extends StatelessWidget {
  const _DataExportCard({required this.isLoading, required this.onView});

  final bool isLoading;
  final VoidCallback? onView;

  @override
  Widget build(BuildContext context) {
    return _PrivacyCard(
      icon: Icons.data_object_rounded,
      title: context.tr("Your data export"),
      subtitle: context.tr(
        "View the information PadelClub returns for your account as JSON.",
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr(
              "This opens a private, in-app JSON view. It does not download a file or copy data to your clipboard.",
            ),
            style: TextStyle(color: PadelColors.textMuted, height: 1.4),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onView,
            icon: isLoading
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.visibility_outlined),
            label: Text(
              isLoading
                  ? context.tr("Preparing JSON view...")
                  : context.tr("View your data export (JSON)"),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeletionStatusCard extends StatelessWidget {
  const _DeletionStatusCard({
    required this.status,
    required this.isLoading,
    required this.isRequesting,
    required this.isCancelling,
    required this.onRequest,
    required this.onCancel,
  });

  final PrivacyDeletionStatus? status;
  final bool isLoading;
  final bool isRequesting;
  final bool isCancelling;
  final VoidCallback? onRequest;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final state = _deletionCopy(context, status);
    final scheduled = status?.isScheduled == true;
    return _PrivacyCard(
      icon: scheduled
          ? Icons.event_busy_outlined
          : Icons.delete_outline_rounded,
      iconColor: scheduled ? PadelColors.danger : PadelColors.greenDark,
      title: state.title,
      subtitle: state.subtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (status?.requestedAt case final requestedAt?) ...[
            Text(
              context.tr("Latest request: {p1}", {
                'p1': _formatDate(context, requestedAt),
              }),
              style: const TextStyle(
                color: PadelColors.textMuted,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 14),
          ],
          if (scheduled)
            OutlinedButton.icon(
              onPressed: onCancel,
              style: OutlinedButton.styleFrom(
                foregroundColor: PadelColors.danger,
                side: const BorderSide(color: Color(0xFFF0C9C3)),
              ),
              icon: isCancelling
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.undo_rounded),
              label: Text(
                isCancelling
                    ? context.tr("Cancelling scheduled deletion...")
                    : context.tr("Cancel scheduled deletion"),
              ),
            )
          else
            FilledButton.icon(
              onPressed: onRequest,
              style: FilledButton.styleFrom(
                backgroundColor: PadelColors.danger,
                foregroundColor: Colors.white,
              ),
              icon: isRequesting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.delete_forever_outlined),
              label: Text(
                isRequesting
                    ? context.tr("Scheduling deletion...")
                    : isLoading
                    ? context.tr("Checking deletion status...")
                    : context.tr("Schedule account deletion"),
              ),
            ),
        ],
      ),
    );
  }

  _DeletionCopy _deletionCopy(
    BuildContext context,
    PrivacyDeletionStatus? current,
  ) {
    if (current == null) {
      return _DeletionCopy(
        context.tr("Your account is active"),
        context.tr(
          "No account deletion is scheduled. A deletion request is scheduled for 30 days from the time you confirm it.",
        ),
      );
    }
    if (current.isScheduled) {
      final scheduledFor = current.scheduledFor;
      return _DeletionCopy(
        context.tr("Account deletion scheduled"),
        scheduledFor == null
            ? context.tr(
                "Your account deletion request is scheduled. You can cancel it before it is processed.",
              )
            : context.tr(
                "Your account is scheduled for deletion on {p1}. You can cancel it before that date.",
                {'p1': _formatDate(context, scheduledFor)},
              ),
      );
    }
    if (current.isCancelled) {
      return _DeletionCopy(
        context.tr("Deletion request cancelled"),
        context.tr(
          "Your latest account-deletion request was cancelled. Your account remains active.",
        ),
      );
    }
    if (current.isCompleted) {
      return _DeletionCopy(
        context.tr("Deletion request completed"),
        context.tr(
          "Your latest account-deletion request is marked completed. Contact the club if you need help.",
        ),
      );
    }
    return _DeletionCopy(
      context.tr("Deletion status: {p1}", {'p1': context.tr(current.status)}),
      context.tr(
        "This is the latest account-deletion status returned by PadelClub. Contact the club if you need help.",
      ),
    );
  }
}

class _DeletionCopy {
  const _DeletionCopy(this.title, this.subtitle);

  final String title;
  final String subtitle;
}

class _PrivacyCard extends StatelessWidget {
  const _PrivacyCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
    this.iconColor = PadelColors.greenDark,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(PadelRadii.large),
        border: Border.all(color: PadelColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(PadelRadii.medium),
                ),
                child: Icon(icon, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: PadelColors.textMuted,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _PrivacyNotice extends StatelessWidget {
  const _PrivacyNotice({required this.message, required this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PadelColors.dangerSoft,
        borderRadius: BorderRadius.circular(PadelRadii.medium),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.cloud_off_rounded, color: PadelColors.danger),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
          if (onRetry != null)
            IconButton(
              tooltip: context.tr("Retry deletion status"),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
            ),
        ],
      ),
    );
  }
}

class _PrivacyExportDialog extends StatelessWidget {
  const _PrivacyExportDialog({required this.export});

  final Map<String, dynamic> export;

  @override
  Widget build(BuildContext context) {
    final encoded = const JsonEncoder.withIndent('  ').convert(export);
    return AlertDialog(
      title: Text(context.tr("Your data export (JSON)")),
      content: SizedBox(
        width: 720,
        height: 440,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr(
                "This is a private, in-app JSON view. Closing it removes the view from this screen; no file is downloaded and no data is copied to your clipboard.",
              ),
              style: TextStyle(color: PadelColors.textMuted, height: 1.4),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F8FA),
                  borderRadius: BorderRadius.circular(PadelRadii.medium),
                  border: Border.all(color: PadelColors.border),
                ),
                child: Scrollbar(
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(right: 8),
                    child: Semantics(
                      label: context.tr("Private JSON data export"),
                      child: SelectableText(
                        encoded,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.tr("Close private view")),
        ),
      ],
    );
  }
}

String _formatDate(BuildContext context, DateTime value) {
  return MaterialLocalizations.of(context).formatFullDate(value.toLocal());
}
