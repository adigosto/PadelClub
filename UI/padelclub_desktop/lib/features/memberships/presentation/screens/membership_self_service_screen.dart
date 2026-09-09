import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import 'package:padelclub_desktop/core/localization/app_localizations.dart';
import 'package:padelclub_desktop/core/theme/app_theme.dart';
import 'package:padelclub_desktop/features/memberships/domain/entities/membership.dart';
import 'package:padelclub_desktop/features/memberships/domain/entities/membership_event.dart';
import 'package:padelclub_desktop/features/memberships/presentation/providers/membership_provider.dart';
import 'package:padelclub_desktop/layouts/master_screen.dart';

class MembershipSelfServiceScreen extends StatefulWidget {
  const MembershipSelfServiceScreen({super.key});

  @override
  State<MembershipSelfServiceScreen> createState() =>
      _MembershipSelfServiceScreenState();
}

class _MembershipSelfServiceScreenState
    extends State<MembershipSelfServiceScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<MembershipProvider>().load(),
    );
  }

  Future<void> _scheduleCancellation(
    MembershipProvider provider,
    Membership membership,
  ) async {
    final id = membership.id;
    if (id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr("Schedule cancellation?")),
        content: Text(
          context.tr(
            "Your {p1} membership will remain in its current state until {p2}. This sends a cancellation-at-period-end request to PadelClub; it does not issue a refund or charge a payment in this app.",
            {
              'p1': membership.membershipType,
              'p2': _date(dialogContext, membership.endDate),
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.tr("Keep membership")),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: PadelColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.tr("Schedule cancellation")),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final changed = await provider.scheduleCancellation(id);
    if (!mounted || !changed) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.tr("Cancellation scheduled for the end of the period."),
        ),
      ),
    );
  }

  Future<void> _changeAutoRenew(
    MembershipProvider provider,
    Membership membership,
    bool enabled,
  ) async {
    final id = membership.id;
    if (id == null) return;
    final restoringScheduledCancellation =
        enabled && membership.cancelAtPeriodEnd;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          enabled
              ? context.tr("Enable automatic renewal?")
              : context.tr("Turn off automatic renewal?"),
        ),
        content: Text(
          enabled
              ? restoringScheduledCancellation
                    ? context.tr(
                        "This will ask PadelClub to restore automatic renewal and clear the scheduled end-of-period cancellation. This app does not create or charge a payment.",
                      )
                    : context.tr(
                        "This will ask PadelClub to mark this membership for automatic renewal. This app does not create or charge a payment.",
                      )
              : context.tr(
                  "This will ask PadelClub to turn off automatic renewal. Your membership remains subject to the dates and policy returned by PadelClub.",
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.tr("Keep current setting")),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              enabled
                  ? context.tr("Enable renewal")
                  : context.tr("Turn off renewal"),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final changed = await provider.updateAutoRenew(
      membershipId: id,
      enabled: enabled,
    );
    if (!mounted || !changed) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          enabled
              ? context.tr("Automatic renewal setting updated.")
              : context.tr("Automatic renewal setting turned off."),
        ),
      ),
    );
  }

  Future<void> _showHistory(
    MembershipProvider provider,
    Membership membership,
  ) async {
    final id = membership.id;
    if (id == null) return;
    final events = await provider.loadHistory(id);
    if (!mounted || events == null) return;
    await showDialog<void>(
      context: context,
      builder: (_) => _MembershipHistoryDialog(
        membershipName: membership.membershipType,
        events: events,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => MasterScreen(
    title: context.tr("My memberships"),
    section: AppSection.profile,
    showBackButton: true,
    child: Consumer<MembershipProvider>(
      builder: (context, provider, _) => Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 34),
            children: [
              Text(
                context.tr("Memberships"),
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: PadelColors.text,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                context.tr(
                  "Review the membership records and lifecycle settings returned for your account.",
                ),
                style: TextStyle(color: PadelColors.textMuted, height: 1.4),
              ),
              const SizedBox(height: 18),
              if (provider.totalCount != null) ...[
                _MembershipPageSummary(
                  shown: provider.memberships.length,
                  total: provider.totalCount!,
                  hasMore: provider.hasMoreMemberships,
                ),
                const SizedBox(height: 14),
              ],
              if (provider.errorMessage != null) ...[
                _MembershipNotice(
                  message: provider.errorMessage!,
                  onRetry: provider.isLoading || provider.isActionInProgress
                      ? null
                      : provider.load,
                ),
                const SizedBox(height: 14),
              ],
              if (!provider.isLoading && provider.memberships.isEmpty)
                const _EmptyMembershipsCard()
              else
                for (final membership in provider.memberships) ...[
                  _MembershipCard(
                    membership: membership,
                    isUpdating: provider.isActionInProgress,
                    isLoadingHistory:
                        membership.id != null &&
                        provider.isLoadingHistory(membership.id!),
                    onCancelAtPeriodEnd:
                        membership.id == null || provider.isActionInProgress
                        ? null
                        : () => _scheduleCancellation(provider, membership),
                    onAutoRenewChanged:
                        membership.id == null || provider.isActionInProgress
                        ? null
                        : (enabled) =>
                              _changeAutoRenew(provider, membership, enabled),
                    onViewHistory:
                        membership.id == null ||
                            provider.isActionInProgress ||
                            provider.isLoadingHistory(membership.id!)
                        ? null
                        : () => _showHistory(provider, membership),
                  ),
                  const SizedBox(height: 14),
                ],
              const SizedBox(height: 2),
              const _MembershipBillingNotice(),
            ],
          ),
          if (provider.isLoading)
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

class _MembershipCard extends StatelessWidget {
  const _MembershipCard({
    required this.membership,
    required this.isUpdating,
    required this.isLoadingHistory,
    required this.onCancelAtPeriodEnd,
    required this.onAutoRenewChanged,
    required this.onViewHistory,
  });

  final Membership membership;
  final bool isUpdating;
  final bool isLoadingHistory;
  final VoidCallback? onCancelAtPeriodEnd;
  final ValueChanged<bool>? onAutoRenewChanged;
  final VoidCallback? onViewHistory;

  @override
  Widget build(BuildContext context) {
    final status = _statusStyle(membership.status);
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
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: status.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(PadelRadii.medium),
                ),
                child: Icon(status.icon, color: status.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      membership.membershipType,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    _StatusPill(label: membership.status, color: status.color),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _MembershipDetail(
            label: context.tr("Current period"),
            value:
                '${_date(context, membership.startDate)} – ${_date(context, membership.endDate)}',
          ),
          const SizedBox(height: 8),
          _MembershipDetail(
            label: context.tr("Listed price"),
            value: membership.price.toStringAsFixed(2),
          ),
          if (membership.updatedAt != null) ...[
            const SizedBox(height: 8),
            _MembershipDetail(
              label: context.tr("Last updated"),
              value: _date(context, membership.updatedAt!),
            ),
          ],
          if (membership.suspendedAt != null) ...[
            const SizedBox(height: 8),
            _MembershipDetail(
              label: context.tr("Suspended on"),
              value: _date(context, membership.suspendedAt!),
            ),
          ],
          if (membership.cancelledAt != null) ...[
            const SizedBox(height: 8),
            _MembershipDetail(
              label: context.tr("Cancelled on"),
              value: _date(context, membership.cancelledAt!),
            ),
          ],
          const SizedBox(height: 14),
          _LifecycleDescription(membership: membership),
          if (membership.canChangeAutoRenew) ...[
            const Divider(height: 28),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: membership.autoRenew,
              onChanged: isUpdating ? null : onAutoRenewChanged,
              title: Text(
                context.tr("Automatic renewal"),
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                membership.cancelAtPeriodEnd
                    ? context.tr(
                        "Turning this on asks PadelClub to clear the scheduled cancellation.",
                      )
                    : context.tr(
                        "This setting is controlled by PadelClub and does not charge a payment in this app.",
                      ),
                style: const TextStyle(
                  color: PadelColors.textMuted,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ),
          ],
          const SizedBox(height: 6),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: onViewHistory,
                icon: isLoadingHistory
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.history_rounded),
                label: Text(
                  isLoadingHistory
                      ? context.tr("Loading activity...")
                      : context.tr("View activity"),
                ),
              ),
              if (membership.canScheduleCancellation)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: PadelColors.danger,
                    side: const BorderSide(color: Color(0xFFF0C9C3)),
                  ),
                  onPressed: onCancelAtPeriodEnd,
                  icon: isUpdating
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.event_busy_outlined),
                  label: Text(context.tr("Cancel at period end")),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LifecycleDescription extends StatelessWidget {
  const _LifecycleDescription({required this.membership});

  final Membership membership;

  @override
  Widget build(BuildContext context) {
    final message = switch (membership.status) {
      'Active' when membership.cancelAtPeriodEnd => context.tr(
        "Cancellation is scheduled. The membership remains active until {p1} unless PadelClub changes its status.",
        {'p1': _date(context, membership.endDate)},
      ),
      'Active' when membership.autoRenew => context.tr(
        "Automatic renewal is enabled on the membership record.",
      ),
      'Active' => context.tr(
        "Automatic renewal is off. The membership remains active through the listed period unless PadelClub changes its status.",
      ),
      'Suspended' => context.tr(
        "This membership is suspended. Contact the club if you need a status change.",
      ),
      'Cancelled' => context.tr(
        "This membership is marked cancelled by PadelClub.",
      ),
      _ => context.tr("This is the lifecycle state returned by PadelClub."),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PadelColors.canvas,
        borderRadius: BorderRadius.circular(PadelRadii.medium),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: PadelColors.textMuted,
          fontSize: 12,
          height: 1.4,
        ),
      ),
    );
  }
}

class _MembershipDetail extends StatelessWidget {
  const _MembershipDetail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(
        width: 106,
        child: Text(
          label,
          style: const TextStyle(color: PadelColors.textMuted, fontSize: 12),
        ),
      ),
      Expanded(
        child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    ],
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label.isEmpty ? context.tr("Unknown") : context.tr(label),
      style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 11),
    ),
  );
}

class _MembershipNotice extends StatelessWidget {
  const _MembershipNotice({required this.message, required this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Container(
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
            tooltip: context.tr("Retry memberships"),
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
          ),
      ],
    ),
  );
}

class _MembershipPageSummary extends StatelessWidget {
  const _MembershipPageSummary({
    required this.shown,
    required this.total,
    required this.hasMore,
  });

  final int shown;
  final int total;
  final bool hasMore;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: PadelColors.blueSoft,
      borderRadius: BorderRadius.circular(PadelRadii.medium),
    ),
    child: Text(
      hasMore
          ? context.tr(
              "Showing the first {p1} of {p2} membership records. This screen currently displays the first page returned by PadelClub.",
              {'p1': shown, 'p2': total},
            )
          : context.tr("{p1} membership record{p2} returned by PadelClub.", {
              'p1': shown,
              'p2': shown == 1 ? '' : 's',
            }),
      style: const TextStyle(
        color: Color(0xFF35527C),
        fontSize: 12,
        height: 1.4,
      ),
    ),
  );
}

class _EmptyMembershipsCard extends StatelessWidget {
  const _EmptyMembershipsCard();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(PadelRadii.large),
      border: Border.all(color: PadelColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.card_membership_outlined, color: PadelColors.greenDark),
        SizedBox(height: 12),
        Text(
          context.tr("No membership records found"),
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        SizedBox(height: 4),
        Text(
          context.tr(
            "PadelClub has not returned a membership record for this account.",
          ),
          style: TextStyle(color: PadelColors.textMuted, height: 1.4),
        ),
      ],
    ),
  );
}

class _MembershipBillingNotice extends StatelessWidget {
  const _MembershipBillingNotice();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: PadelColors.blueSoft,
      borderRadius: BorderRadius.circular(PadelRadii.large),
      border: Border.all(color: const Color(0xFFD3E1FF)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline_rounded, color: PadelColors.blue),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            context.tr(
              "Membership actions update the server-side membership record. This desktop screen does not collect card details, create a payment, or guarantee a renewal charge.",
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

class _MembershipHistoryDialog extends StatelessWidget {
  const _MembershipHistoryDialog({
    required this.membershipName,
    required this.events,
  });

  final String membershipName;
  final List<MembershipEvent> events;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(context.tr("{p1} activity", {'p1': membershipName})),
    content: SizedBox(
      width: 620,
      height: 360,
      child: events.isEmpty
          ? Center(
              child: Text(
                context.tr(
                  "PadelClub has not returned activity for this membership.",
                ),
              ),
            )
          : Scrollbar(
              thumbVisibility: true,
              child: ListView.separated(
                itemCount: events.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final event = events[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    leading: const Icon(Icons.history_rounded),
                    title: Text(
                      event.eventType,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      [
                        if (event.notes?.trim().isNotEmpty == true)
                          event.notes!.trim(),
                        _date(context, event.createdAt),
                      ].join('\n'),
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

_MembershipStatusStyle _statusStyle(String status) => switch (status) {
  'Active' => const _MembershipStatusStyle(
    color: PadelColors.greenDark,
    icon: Icons.verified_rounded,
  ),
  'Suspended' => const _MembershipStatusStyle(
    color: PadelColors.blue,
    icon: Icons.pause_circle_outline_rounded,
  ),
  'Cancelled' => const _MembershipStatusStyle(
    color: PadelColors.danger,
    icon: Icons.cancel_outlined,
  ),
  _ => const _MembershipStatusStyle(
    color: PadelColors.textMuted,
    icon: Icons.help_outline_rounded,
  ),
};

class _MembershipStatusStyle {
  const _MembershipStatusStyle({required this.color, required this.icon});

  final Color color;
  final IconData icon;
}

String _date(BuildContext context, DateTime value) =>
    MaterialLocalizations.of(context).formatMediumDate(value.toLocal());
