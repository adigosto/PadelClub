import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import 'package:padelclub_desktop/core/localization/app_localizations.dart';
import 'package:padelclub_desktop/core/theme/app_theme.dart';
import 'package:padelclub_desktop/core/widgets/admin_components.dart';
import 'package:padelclub_desktop/features/memberships/data/admin_membership_remote_data_source.dart';
import 'package:padelclub_desktop/features/memberships/domain/entities/membership.dart';
import 'package:padelclub_desktop/features/memberships/domain/entities/membership_event.dart';
import 'package:padelclub_desktop/features/memberships/presentation/providers/membership_management_provider.dart';
import 'package:padelclub_desktop/layouts/master_screen.dart';

enum _MembershipActivityFilter {
  all('All records', null),
  active('Active', true),
  inactive('Inactive', false);

  const _MembershipActivityFilter(this.label, this.isActive);

  final String label;
  final bool? isActive;
}

/// Administrative membership lifecycle workspace.
///
/// This is intentionally distinct from the player "My memberships" screen.
/// Every mutation uses the staff-only endpoint and immediately refreshes the
/// paged server result.
class MembershipManagementScreen extends StatefulWidget {
  const MembershipManagementScreen({super.key});

  @override
  State<MembershipManagementScreen> createState() =>
      _MembershipManagementScreenState();
}

class _MembershipManagementScreenState
    extends State<MembershipManagementScreen> {
  int? _selectedMembershipTypeReferenceId;
  _MembershipActivityFilter _activityFilter = _MembershipActivityFilter.all;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final provider = context.read<MembershipManagementProvider>();
        provider.loadMembershipTypes();
        provider.load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MasterScreen(
      title: context.tr("Membership Management"),
      section: AppSection.memberships,
      child: Consumer<MembershipManagementProvider>(
        builder: (context, provider, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AdminPageHeader(
              title: context.tr("Membership Management"),
              subtitle: context.tr(
                "Review membership records and apply staff-authorized lifecycle changes.",
              ),
              action: OutlinedButton.icon(
                onPressed: provider.isLoading || provider.isActionInProgress
                    ? null
                    : provider.refresh,
                icon: const Icon(Icons.refresh_rounded, size: 17),
                label: Text(context.tr("Refresh")),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(PadelSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: PadelSpacing.xs,
                    runSpacing: PadelSpacing.xs,
                    children: _MembershipActivityFilter.values
                        .map(
                          (filter) => AdminFilterChip(
                            label: filter.label,
                            selected: _activityFilter == filter,
                            onSelected: (_) => _setActivityFilter(filter),
                          ),
                        )
                        .toList(growable: false),
                  ),
                  const SizedBox(height: PadelSpacing.md),
                  Wrap(
                    spacing: PadelSpacing.sm,
                    runSpacing: PadelSpacing.sm,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: 320,
                        child: DropdownButtonFormField<int?>(
                          initialValue: _selectedMembershipTypeReferenceId,
                          decoration: InputDecoration(
                            labelText: context.tr("Membership type"),
                          ),
                          items: [
                            DropdownMenuItem<int?>(
                              value: null,
                              child: Text(context.tr("All membership types")),
                            ),
                            ...provider.membershipTypes.map(
                              (type) => DropdownMenuItem<int?>(
                                value: type.id,
                                child: Text(type.name),
                              ),
                            ),
                          ],
                          onChanged: provider.isLoading ||
                                  provider.isActionInProgress
                              ? null
                              : (value) => setState(
                                    () => _selectedMembershipTypeReferenceId =
                                        value,
                                  ),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _applyTypeFilter(
                          _selectedMembershipTypeReferenceId,
                        ),
                        icon: const Icon(Icons.search_rounded, size: 17),
                        label: Text(context.tr("Filter")),
                      ),
                      if (provider.membershipTypeReferenceId != null)
                        TextButton.icon(
                          onPressed: _clearTypeFilter,
                          icon: const Icon(Icons.clear_rounded, size: 16),
                          label: Text(context.tr("Clear type filter")),
                        ),
                    ],
                  ),
                  const SizedBox(height: PadelSpacing.sm),
                  const _ManualFulfilmentNotice(),
                  if (provider.errorMessage != null) ...[
                    const SizedBox(height: PadelSpacing.sm),
                    _MembershipErrorNotice(
                      message: provider.errorMessage!,
                      onRetry: provider.isLoading || provider.isActionInProgress
                          ? null
                          : provider.refresh,
                    ),
                  ],
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
      ),
    );
  }

  Widget _content(MembershipManagementProvider provider) {
    if (provider.isLoading && provider.memberships.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (provider.memberships.isEmpty) {
      return _MembershipMessage(
        icon: provider.errorMessage == null
            ? Icons.card_membership_outlined
            : Icons.cloud_off_rounded,
        title: provider.errorMessage == null
            ? context.tr("No membership records found")
            : context.tr("Membership records are unavailable"),
        message: provider.errorMessage == null
            ? context.tr(
                "Adjust the activity or membership-type filter and try again.",
              )
            : context.tr("The latest membership list could not be loaded."),
        actionLabel: provider.errorMessage == null
            ? null
            : context.tr("Try again"),
        onAction: provider.errorMessage == null ? null : provider.refresh,
      );
    }
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(
                      PadelColors.canvas,
                    ),
                    dataRowMinHeight: 78,
                    dataRowMaxHeight: 90,
                    columnSpacing: 28,
                    columns: [
                      DataColumn(label: Text(context.tr("MEMBERSHIP"))),
                      DataColumn(label: Text(context.tr("PERIOD"))),
                      DataColumn(label: Text(context.tr("PRICE"))),
                      DataColumn(label: Text(context.tr("STATUS"))),
                      DataColumn(label: Text(context.tr("RENEWAL"))),
                      DataColumn(label: Text(context.tr("ACTIONS"))),
                    ],
                    rows: provider.memberships
                        .map((membership) => _row(membership, provider))
                        .toList(growable: false),
                  ),
                ),
              ),
            ),
          ),
        ),
        _PaginationBar(
          page: provider.page,
          shownCount: provider.memberships.length,
          totalCount: provider.totalCount,
          canGoPrevious:
              provider.canGoPrevious &&
              !provider.isLoading &&
              !provider.isActionInProgress,
          canGoNext:
              provider.canGoNext &&
              !provider.isLoading &&
              !provider.isActionInProgress,
          onPrevious: provider.previousPage,
          onNext: provider.nextPage,
        ),
      ],
    );
  }

  DataRow _row(Membership membership, MembershipManagementProvider provider) {
    final membershipId = membership.id;
    final busy =
        provider.isActionInProgress || provider.historyMembershipId != null;
    final statusTone = _statusTone(membership.status);
    return DataRow(
      cells: [
        DataCell(
          SizedBox(
            width: 210,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  membership.membershipType,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  context.tr("Membership #{p1} · Customer #{p2}", {
                    'p1': membershipId ?? 'N/A',
                    'p2': membership.userId,
                  }),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
            width: 182,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_date(context, membership.startDate)} – ${_date(context, membership.endDate)}',
                ),
                if (membership.updatedAt != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    context.tr("Updated {p1}", {
                      'p1': _date(context, membership.updatedAt!),
                    }),
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
          Text(
            '${context.l10n.number(membership.price, decimalDigits: 2)} KM',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        DataCell(AdminStatusBadge(label: membership.status, tone: statusTone)),
        DataCell(
          SizedBox(
            width: 168,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  membership.autoRenew
                      ? context.tr("Auto-renew enabled")
                      : context.tr("Manual review"),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
                if (membership.cancelAtPeriodEnd) ...[
                  const SizedBox(height: 3),
                  Text(
                    context.tr("Cancellation scheduled"),
                    style: TextStyle(color: PadelColors.warning, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
        ),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AdminActionButton(
                icon: provider.isLoadingHistory(membershipId ?? -1)
                    ? Icons.more_horiz_rounded
                    : Icons.history_rounded,
                tooltip: context.tr("View membership history"),
                onPressed: membershipId == null || busy
                    ? null
                    : () => _showHistory(membership),
              ),
              const SizedBox(width: PadelSpacing.xs),
              AdminActionButton(
                icon: provider.isActingOn(membershipId ?? -1)
                    ? Icons.sync_rounded
                    : Icons.edit_note_rounded,
                tooltip: context.tr("Change membership status"),
                onPressed: membershipId == null || busy
                    ? null
                    : () => _changeStatus(membership),
              ),
              const SizedBox(width: PadelSpacing.xs),
              AdminActionButton(
                icon: Icons.event_repeat_rounded,
                tooltip: context.tr("Manual membership renewal"),
                onPressed: membershipId == null || busy
                    ? null
                    : () => _renew(membership),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _setActivityFilter(_MembershipActivityFilter filter) {
    if (_activityFilter == filter) return;
    setState(() => _activityFilter = filter);
    _loadFirstPage();
  }

  void _applyTypeFilter(int? referenceId) {
    _selectedMembershipTypeReferenceId = referenceId;
    _loadFirstPage();
  }

  void _clearTypeFilter() {
    setState(() => _selectedMembershipTypeReferenceId = null);
    _loadFirstPage();
  }

  void _loadFirstPage() {
    context.read<MembershipManagementProvider>().load(
      membershipTypeReferenceId: _selectedMembershipTypeReferenceId,
      isActive: _activityFilter.isActive,
    );
  }

  Future<void> _changeStatus(Membership membership) async {
    final membershipId = membership.id;
    if (membershipId == null) return;
    final draft = await showDialog<_MembershipStatusDraft>(
      context: context,
      builder: (_) => _MembershipStatusDialog(membership: membership),
    );
    if (!mounted || draft == null) return;

    final provider = context.read<MembershipManagementProvider>();
    final saved = await provider.changeStatus(
      membershipId: membershipId,
      status: draft.status,
      notes: draft.notes,
    );
    if (!mounted) return;
    _notice(
      saved
          ? provider.lastOperationMessage ??
                context.tr("Membership status updated.")
          : provider.errorMessage ??
                context.tr("The membership status could not be updated."),
      isError: !saved,
    );
  }

  Future<void> _renew(Membership membership) async {
    final membershipId = membership.id;
    if (membershipId == null) return;
    final months = await showDialog<int>(
      context: context,
      builder: (_) => _MembershipRenewalDialog(membership: membership),
    );
    if (!mounted || months == null) return;

    final provider = context.read<MembershipManagementProvider>();
    final saved = await provider.renewMembership(
      membershipId: membershipId,
      months: months,
    );
    if (!mounted) return;
    _notice(
      saved
          ? provider.lastOperationMessage ??
                context.tr("Membership record renewed.")
          : provider.errorMessage ??
                context.tr("The membership record could not be renewed."),
      isError: !saved,
    );
  }

  Future<void> _showHistory(Membership membership) async {
    final membershipId = membership.id;
    if (membershipId == null) return;
    final provider = context.read<MembershipManagementProvider>();
    final events = await provider.loadHistory(membershipId);
    if (!mounted) return;
    if (events == null) {
      _notice(
        provider.errorMessage ??
            context.tr("Membership history could not be loaded."),
        isError: true,
      );
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (_) =>
          _MembershipHistoryDialog(membership: membership, events: events),
    );
  }

  void _notice(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? PadelColors.danger : null,
      ),
    );
  }
}

class _ManualFulfilmentNotice extends StatelessWidget {
  const _ManualFulfilmentNotice();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(PadelSpacing.sm),
    decoration: BoxDecoration(
      color: PadelColors.blueSoft,
      borderRadius: BorderRadius.circular(PadelRadii.small),
      border: Border.all(color: PadelColors.border),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline_rounded, color: PadelColors.blue, size: 18),
        SizedBox(width: PadelSpacing.xs),
        Expanded(
          child: Text(
            context.tr(
              "Manual renewal extends the membership record only. This workspace does not collect card details, create a charge, or claim that payment was taken.",
            ),
            style: TextStyle(color: PadelColors.textMuted, fontSize: 12),
          ),
        ),
      ],
    ),
  );
}

class _MembershipErrorNotice extends StatelessWidget {
  const _MembershipErrorNotice({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(PadelSpacing.sm),
    decoration: BoxDecoration(
      color: PadelColors.dangerSoft,
      borderRadius: BorderRadius.circular(PadelRadii.small),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline_rounded, color: PadelColors.danger),
        const SizedBox(width: PadelSpacing.xs),
        Expanded(
          child: Text(message, style: const TextStyle(color: PadelColors.text)),
        ),
        if (onRetry != null)
          TextButton(onPressed: onRetry, child: Text(context.tr("Retry"))),
      ],
    ),
  );
}

class _MembershipMessage extends StatelessWidget {
  const _MembershipMessage({
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
      padding: const EdgeInsets.all(PadelSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: PadelColors.blue),
          const SizedBox(height: PadelSpacing.sm),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: PadelSpacing.xs),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: PadelColors.textMuted),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: PadelSpacing.md),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    ),
  );
}

class _PaginationBar extends StatelessWidget {
  const _PaginationBar({
    required this.page,
    required this.shownCount,
    required this.totalCount,
    required this.canGoPrevious,
    required this.canGoNext,
    required this.onPrevious,
    required this.onNext,
  });

  final int page;
  final int shownCount;
  final int? totalCount;
  final bool canGoPrevious;
  final bool canGoNext;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final first = shownCount == 0
        ? 0
        : ((page - 1) * MembershipManagementProvider.pageSize) + 1;
    final last = first == 0 ? 0 : first + shownCount - 1;
    final summary = totalCount == null
        ? context.tr("Page {p1} · {p2} records", {'p1': page, 'p2': shownCount})
        : context.tr("Showing {p1}–{p2} of {p3} records", {
            'p1': first,
            'p2': last,
            'p3': totalCount,
          });
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: PadelColors.border)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: PadelSpacing.md,
          vertical: PadelSpacing.sm,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                summary,
                style: const TextStyle(
                  color: PadelColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ),
            IconButton(
              tooltip: context.tr("Previous membership page"),
              onPressed: canGoPrevious ? onPrevious : null,
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Text(
              context.tr("Page {p1}", {'p1': page}),
              style: const TextStyle(fontSize: 12),
            ),
            IconButton(
              tooltip: context.tr("Next membership page"),
              onPressed: canGoNext ? onNext : null,
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _MembershipStatusDraft {
  const _MembershipStatusDraft({required this.status, required this.notes});

  final MembershipLifecycleStatus status;
  final String notes;
}

class _MembershipStatusDialog extends StatefulWidget {
  const _MembershipStatusDialog({required this.membership});

  final Membership membership;

  @override
  State<_MembershipStatusDialog> createState() =>
      _MembershipStatusDialogState();
}

class _MembershipStatusDialogState extends State<_MembershipStatusDialog> {
  late final TextEditingController _notesController;
  late MembershipLifecycleStatus _status;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController();
    _status = MembershipLifecycleStatus.values.firstWhere(
      (status) =>
          status.label.toLowerCase() == widget.membership.status.toLowerCase(),
      orElse: () => MembershipLifecycleStatus.active,
    );
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      context.tr("Change status for {p1}?", {
        'p1': widget.membership.membershipType,
      }),
    ),
    content: SizedBox(
      width: 510,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr("Current status: {p1}", {
                'p1': context.tr(widget.membership.status),
              }),
            ),
            const SizedBox(height: PadelSpacing.md),
            DropdownButtonFormField<MembershipLifecycleStatus>(
              initialValue: _status,
              decoration: InputDecoration(labelText: context.tr("New status")),
              items: MembershipLifecycleStatus.values
                  .map(
                    (status) => DropdownMenuItem(
                      value: status,
                      child: Text(context.tr(status.label)),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value != null) setState(() => _status = value);
              },
            ),
            const SizedBox(height: PadelSpacing.sm),
            TextField(
              controller: _notesController,
              maxLength: 500,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: context.tr("Staff note (optional)"),
                hintText: context.tr(
                  "Reason or operational context for this change",
                ),
              ),
            ),
            const SizedBox(height: PadelSpacing.xs),
            Text(
              context.tr(
                "Cancelled disables automatic renewal. The server validates and records the lifecycle change before it is shown in the work queue.",
              ),
              style: TextStyle(color: PadelColors.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.tr("Cancel")),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(
          context,
          _MembershipStatusDraft(status: _status, notes: _notesController.text),
        ),
        child: Text(context.tr("Set {p1}", {'p1': context.tr(_status.label)})),
      ),
    ],
  );
}

class _MembershipRenewalDialog extends StatefulWidget {
  const _MembershipRenewalDialog({required this.membership});

  final Membership membership;

  @override
  State<_MembershipRenewalDialog> createState() =>
      _MembershipRenewalDialogState();
}

class _MembershipRenewalDialogState extends State<_MembershipRenewalDialog> {
  int _months = 1;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      context.tr("Manual renewal for {p1}?", {
        'p1': widget.membership.membershipType,
      }),
    ),
    content: SizedBox(
      width: 510,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr("Current end date: {p1}", {
              'p1': _date(context, widget.membership.endDate),
            }),
          ),
          const SizedBox(height: PadelSpacing.md),
          DropdownButtonFormField<int>(
            initialValue: _months,
            decoration: InputDecoration(labelText: context.tr("Extend by")),
            items: List<int>.generate(24, (index) => index + 1)
                .map(
                  (months) => DropdownMenuItem(
                    value: months,
                    child: Text(
                      context.tr("{p1} month{p2}", {
                        'p1': months,
                        'p2': months == 1 ? '' : 's',
                      }),
                    ),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) {
              if (value != null) setState(() => _months = value);
            },
          ),
          const SizedBox(height: PadelSpacing.md),
          Text(
            context.tr(
              "This is a membership-record/manual fulfilment action. It extends the recorded period and activates the membership, but does not collect payment details or charge a card.",
            ),
            style: TextStyle(color: PadelColors.textMuted, fontSize: 12),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.tr("Cancel")),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _months),
        child: Text(
          context.tr("Renew for {p1} month{p2}", {
            'p1': _months,
            'p2': _months == 1 ? '' : 's',
          }),
        ),
      ),
    ],
  );
}

class _MembershipHistoryDialog extends StatelessWidget {
  const _MembershipHistoryDialog({
    required this.membership,
    required this.events,
  });

  final Membership membership;
  final List<MembershipEvent> events;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(context.tr("{p1} history", {'p1': membership.membershipType})),
    content: SizedBox(
      width: 620,
      child: events.isEmpty
          ? Text(context.tr("No membership activity has been recorded yet."))
          : ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 440),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: events.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final event = events[index];
                  final note = event.notes?.trim();
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: PadelSpacing.sm,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.eventType,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${_dateTime(context, event.createdAt)}${event.actorUserId == null ? '' : ' · Staff #${event.actorUserId}'}',
                          style: const TextStyle(
                            color: PadelColors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                        if (note != null && note.isNotEmpty) ...[
                          const SizedBox(height: 5),
                          Text(note),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.tr("Close")),
      ),
    ],
  );
}

AdminStatusTone _statusTone(String status) => switch (status.toLowerCase()) {
  'active' => AdminStatusTone.success,
  'suspended' => AdminStatusTone.warning,
  'cancelled' || 'canceled' => AdminStatusTone.danger,
  'renewaldue' => AdminStatusTone.info,
  'expired' => AdminStatusTone.neutral,
  _ => AdminStatusTone.neutral,
};

String _date(BuildContext context, DateTime value) => context.l10n.date(value);

String _dateTime(BuildContext context, DateTime value) {
  final local = value.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${_date(context, local)} $hour:$minute';
}
