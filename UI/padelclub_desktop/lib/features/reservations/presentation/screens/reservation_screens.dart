import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import 'package:padelclub_desktop/core/localization/app_localizations.dart';
import 'package:padelclub_desktop/core/theme/app_theme.dart';
import 'package:padelclub_desktop/core/widgets/admin_components.dart';
import 'package:padelclub_desktop/features/courts/domain/entities/court.dart';
import 'package:padelclub_desktop/features/courts/presentation/providers/court_provider.dart';
import 'package:padelclub_desktop/features/reservations/domain/entities/account_credit.dart';
import 'package:padelclub_desktop/features/reservations/domain/entities/court_availability.dart';
import 'package:padelclub_desktop/features/reservations/domain/entities/reservation.dart';
import 'package:padelclub_desktop/features/reservations/domain/entities/waitlist_entry.dart';
import 'package:padelclub_desktop/features/reservations/presentation/providers/reservation_provider.dart';
import 'package:padelclub_desktop/layouts/master_screen.dart';

class MobileReservationsScreen extends StatefulWidget {
  const MobileReservationsScreen({super.key});

  @override
  State<MobileReservationsScreen> createState() =>
      _MobileReservationsScreenState();
}

class _MobileReservationsScreenState extends State<MobileReservationsScreen> {
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  CourtAvailability? _selectedCourt;
  AvailabilitySlot? _selectedSlot;
  int _section = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    final provider = context.read<ReservationProvider>();
    if (_section == 0) {
      await provider.loadAvailability(_selectedDate);
    } else {
      await provider.loadMyBookingActivity();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MasterScreen(
      title: context.tr("Court booking"),
      section: AppSection.reservations,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              color: const Color(0xFF1F7A63),
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    _SectionButton(
                      label: context.tr("Book a court"),
                      selected: _section == 0,
                      onTap: () => _changeSection(0),
                    ),
                    _SectionButton(
                      label: context.tr("My bookings"),
                      selected: _section == 1,
                      onTap: () => _changeSection(1),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: _section == 0 ? _availabilityBody() : _bookingsBody(),
            ),
          ],
        ),
      ),
    );
  }

  void _changeSection(int value) {
    setState(() => _section = value);
    _refresh();
  }

  Widget _availabilityBody() {
    return Consumer<ReservationProvider>(
      builder: (context, provider, _) => Stack(
        children: [
          Scrollbar(
            thumbVisibility: true,
            interactive: true,
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                18,
                18,
                18,
                _selectedSlot == null ? 24 : 142,
              ),
              children: [
                Text(
                  context.tr("Choose your next match"),
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF27423A),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  context.tr("Live availability for every active court."),
                  style: TextStyle(color: Color(0xFF5C6B64)),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.tr("Select a date"),
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: context.tr("Open calendar"),
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_month_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 78,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: 7,
                    separatorBuilder: (_, _) => const SizedBox(width: 9),
                    itemBuilder: (context, index) {
                      final date = DateUtils.dateOnly(
                        DateTime.now().add(Duration(days: index)),
                      );
                      return _DateCard(
                        date: date,
                        selected: DateUtils.isSameDay(date, _selectedDate),
                        onTap: () => _selectDate(date),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 18),
                if (provider.isLoading)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if (!provider.isLoading && provider.errorMessage != null)
                  _ErrorCard(
                    message: provider.errorMessage!,
                    onRetry: _refresh,
                  ),
                if (!provider.isLoading &&
                    provider.errorMessage == null &&
                    provider.availability.isEmpty)
                  _EmptyCard(
                    icon: Icons.stadium_outlined,
                    title: context.tr("No courts available"),
                    message: context.tr(
                      "There are no active courts available for this date.",
                    ),
                  ),
                if (!provider.isLoading && provider.errorMessage == null)
                  ...provider.availability.map(
                    (court) => _CourtAvailabilityCard(
                      court: court,
                      selectedSlot: _selectedCourt?.courtId == court.courtId
                          ? _selectedSlot
                          : null,
                      onSelect: (slot) => setState(() {
                        _selectedCourt = court;
                        _selectedSlot = slot;
                      }),
                      onJoinWaitlist: (slot) => _joinWaitlist(court, slot),
                    ),
                  ),
              ],
            ),
          ),
          if (!provider.isLoading && _selectedSlot != null)
            Positioned(
              left: 18,
              right: 18,
              bottom: 12,
              child: _BookingAction(
                court: _selectedCourt!,
                slot: _selectedSlot!,
                onPressed: () =>
                    _confirmBooking(_selectedCourt!, _selectedSlot!),
              ),
            ),
        ],
      ),
    );
  }

  Widget _bookingsBody() {
    return Consumer<ReservationProvider>(
      builder: (context, provider, _) => Scrollbar(
        thumbVisibility: true,
        interactive: true,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Text(
              context.tr("My bookings"),
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: Color(0xFF27423A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              context.tr(
                "Your court sessions, waitlists, and available booking credits.",
              ),
              style: TextStyle(color: Color(0xFF5C6B64)),
            ),
            const SizedBox(height: 18),
            if (provider.isLoading)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (!provider.isLoading && provider.errorMessage != null)
              _ErrorCard(message: provider.errorMessage!, onRetry: _refresh),
            if (!provider.isLoading &&
                provider.errorMessage == null &&
                provider.reservations.isEmpty &&
                provider.waitlistEntries.isEmpty &&
                provider.accountCredits.isEmpty)
              _EmptyCard(
                icon: Icons.event_available_rounded,
                title: context.tr("No bookings yet"),
                message: context.tr(
                  "Choose “Book a court” to schedule your first match.",
                ),
              ),
            if (!provider.isLoading &&
                provider.errorMessage == null &&
                provider.reservations.isNotEmpty) ...[
              _BookingActivityTitle(
                icon: Icons.calendar_month_rounded,
                title: context.tr("Court sessions"),
              ),
              const SizedBox(height: 10),
              ...provider.reservations.map(
                (reservation) => _MobileReservationCard(
                  reservation: reservation,
                  onCancel: () => _cancel(reservation),
                ),
              ),
            ],
            if (!provider.isLoading &&
                provider.errorMessage == null &&
                provider.waitlistEntries.isNotEmpty) ...[
              const SizedBox(height: 8),
              _BookingActivityTitle(
                icon: Icons.notifications_active_outlined,
                title: context.tr("Waitlist"),
              ),
              const SizedBox(height: 10),
              ...provider.waitlistEntries.map(
                (entry) => _WaitlistEntryCard(entry: entry),
              ),
            ],
            if (!provider.isLoading &&
                provider.errorMessage == null &&
                provider.accountCredits.isNotEmpty) ...[
              const SizedBox(height: 8),
              _BookingActivityTitle(
                icon: Icons.account_balance_wallet_outlined,
                title: context.tr("Booking credit"),
              ),
              const SizedBox(height: 10),
              _AccountCreditSummary(credits: provider.accountCredits),
              const SizedBox(height: 10),
              ...provider.accountCredits.map(
                (credit) => _AccountCreditCard(credit: credit),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );
    if (value == null) return;
    _selectDate(value);
  }

  void _selectDate(DateTime value) {
    setState(() {
      _selectedDate = DateUtils.dateOnly(value);
      _selectedCourt = null;
      _selectedSlot = null;
    });
    _refresh();
  }

  Future<void> _confirmBooking(
    CourtAvailability court,
    AvailabilitySlot slot,
  ) async {
    var weeks = 1;
    final selectedWeeks = await showModalBottomSheet<int>(
      context: context,
      // Let the summary grow beyond the default half-height sheet on phones.
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr("Confirm your court"),
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 16),
                _SummaryRow(
                  icon: Icons.sports_tennis_rounded,
                  label: court.courtName,
                ),
                _SummaryRow(
                  icon: Icons.schedule_rounded,
                  label:
                      '${_dateLabel(context, slot.startTime)} · ${_time(slot.startTime)}–${_time(slot.endTime)}',
                ),
                _SummaryRow(
                  icon: Icons.payments_outlined,
                  label:
                      '${context.l10n.number(slot.price, decimalDigits: 2)} KM',
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  initialValue: weeks,
                  decoration: InputDecoration(
                    labelText: context.tr("Repeat weekly"),
                  ),
                  items: const [1, 2, 4, 8, 12]
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(
                            value == 1
                                ? context.tr("One booking")
                                : context.tr("{p1} weeks", {'p1': value}),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setSheetState(() => weeks = value ?? 1),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: () => Navigator.pop(context, weeks),
                  child: SizedBox(
                    width: double.infinity,
                    child: Center(child: Text(context.tr("Confirm booking"))),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (selectedWeeks == null || !mounted) return;
    final provider = context.read<ReservationProvider>();
    final success = selectedWeeks == 1
        ? await provider.book(courtId: court.courtId, slot: slot)
        : await provider.bookRecurring(
            courtId: court.courtId,
            slot: slot,
            weeks: selectedWeeks,
          );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: success ? null : PadelColors.danger,
        content: Text(
          success
              ? (selectedWeeks == 1
                    ? context.tr("Court booked successfully.")
                    : context.tr("{p1} weekly courts booked successfully.", {
                        'p1': selectedWeeks,
                      }))
              : provider.errorMessage ?? context.tr("Booking failed."),
        ),
      ),
    );
    await provider.loadAvailability(_selectedDate);
    if (mounted) {
      setState(() {
        _selectedCourt = null;
        _selectedSlot = null;
      });
    }
  }

  Future<void> _joinWaitlist(
    CourtAvailability court,
    AvailabilitySlot slot,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr("Join waitlist?")),
        content: Text(
          context.tr(
            "{p1} is currently full on {p2} from {p3} to {p4}. We will notify you if it becomes available.",
            {
              'p1': court.courtName,
              'p2': _dateLabel(context, slot.startTime),
              'p3': _time(slot.startTime),
              'p4': _time(slot.endTime),
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr("Not now")),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.notifications_active_outlined),
            label: Text(context.tr("Join waitlist")),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final provider = context.read<ReservationProvider>();
    final joined = await provider.joinWaitlist(
      courtId: court.courtId,
      slot: slot,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: joined ? null : PadelColors.danger,
        content: Text(
          joined
              ? context.tr(
                  "You are on the waitlist. We will notify you if the court opens.",
                )
              : provider.errorMessage ??
                    context.tr("Could not join the waitlist."),
        ),
      ),
    );
    if (joined) await provider.loadMyBookingActivity();
  }

  Future<void> _cancel(Reservation reservation) async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr("Cancel reservation?")),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr("This court will become available to other players."),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLength: 500,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: context.tr("Cancellation reason"),
                hintText: context.tr("Enter a reason"),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr("Keep booking")),
          ),
          FilledButton(
            onPressed: () {
              final value = reasonController.text.trim();
              if (value.length < 3) return;
              Navigator.pop(context, value);
            },
            child: Text(context.tr("Cancel reservation")),
          ),
        ],
      ),
    );
    reasonController.dispose();
    if (reason == null || !mounted) return;
    final provider = context.read<ReservationProvider>();
    final success = await provider.cancel(reservation.id, reason: reason);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: success ? null : PadelColors.danger,
        content: Text(
          success
              ? context.tr("Reservation cancelled.")
              : provider.errorMessage ?? context.tr("Cancellation failed."),
        ),
      ),
    );
    await provider.loadMyBookingActivity();
  }
}

class ManagementReservationsScreen extends StatefulWidget {
  const ManagementReservationsScreen({super.key});

  @override
  State<ManagementReservationsScreen> createState() =>
      _ManagementReservationsScreenState();
}

class _ManagementReservationsScreenState
    extends State<ManagementReservationsScreen> {
  final _searchController = TextEditingController();
  String _filter = 'All';
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<ReservationProvider>().loadReservations(
        management: true,
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _cancelReservation(int id) async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr("Cancel reservation?")),
        content: TextField(
          controller: reasonController,
          maxLength: 500,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: context.tr("Cancellation reason"),
            hintText: context.tr("Enter a reason"),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr("Keep booking")),
          ),
          FilledButton(
            onPressed: () {
              final value = reasonController.text.trim();
              if (value.length < 3) return;
              Navigator.pop(context, value);
            },
            child: Text(context.tr("Cancel reservation")),
          ),
        ],
      ),
    );
    reasonController.dispose();
    if (reason == null || !mounted) return;
    final provider = context.read<ReservationProvider>();
    final cancelled = await provider.cancel(id, reason: reason);
    if (!mounted) return;
    if (!cancelled) {
      _notice(
        provider.errorMessage ??
            context.tr("Could not cancel this reservation."),
        isError: true,
      );
      return;
    }
    await provider.loadReservations(management: true);
  }

  @override
  Widget build(BuildContext context) {
    return MasterScreen(
      title: context.tr("Reservation management"),
      section: AppSection.reservations,
      child: Consumer<ReservationProvider>(
        builder: (context, provider, _) {
          final reservations = _filtered(provider.reservations);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AdminPageHeader(
                title: context.tr("Reservation Management"),
                subtitle: context.tr(
                  "Manage court bookings, schedules, and player reservations.",
                ),
                action: FilledButton.icon(
                  onPressed: provider.isLoading ? null : _showMaintenanceDialog,
                  icon: const Icon(Icons.build_rounded, size: 18),
                  label: Text(context.tr("Schedule maintenance")),
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
                      children:
                          ["All", "Today", "Confirmed", "Pending", "Cancelled"]
                              .map(
                                (filter) => AdminFilterChip(
                                  label: filter == 'All'
                                      ? context.tr("All Reservations")
                                      : filter,
                                  selected: _filter == filter,
                                  onSelected: (_) =>
                                      setState(() => _filter = filter),
                                ),
                              )
                              .toList(growable: false),
                    ),
                    const SizedBox(height: PadelSpacing.md),
                    Wrap(
                      spacing: PadelSpacing.sm,
                      runSpacing: PadelSpacing.sm,
                      children: [
                        AdminSearchField(
                          controller: _searchController,
                          hintText: context.tr(
                            "Search by player, court, or reservation...",
                          ),
                          width: 320,
                          onSubmitted: (value) => setState(
                            () => _query = value.trim().toLowerCase(),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => setState(
                            () => _query = _searchController.text
                                .trim()
                                .toLowerCase(),
                          ),
                          icon: const Icon(Icons.search_rounded, size: 17),
                          label: Text(context.tr("Search")),
                        ),
                        OutlinedButton.icon(
                          onPressed: () =>
                              provider.loadReservations(management: true),
                          icon: const Icon(Icons.refresh_rounded, size: 17),
                          label: Text(context.tr("Refresh")),
                        ),
                      ],
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
                  child: AdminTableSurface(
                    child: provider.isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : provider.errorMessage != null
                        ? Center(
                            child: _ErrorCard(
                              message: provider.errorMessage!,
                              onRetry: () =>
                                  provider.loadReservations(management: true),
                            ),
                          )
                        : _ManagementTable(
                            reservations: reservations,
                            onMarkNoShow: _confirmNoShow,
                            onCancel: _cancelReservation,
                          ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Reservation> _filtered(List<Reservation> reservations) {
    final today = DateTime.now();
    return reservations
        .where((item) {
          final status = item.status.toLowerCase();
          final matchesFilter = switch (_filter) {
            'Today' =>
              item.startTime.year == today.year &&
                  item.startTime.month == today.month &&
                  item.startTime.day == today.day,
            'Confirmed' => status == 'confirmed',
            'Pending' => status == 'pending',
            'Cancelled' => status == 'cancelled' || status == 'canceled',
            _ => true,
          };
          final haystack = '${item.userName} ${item.courtName} ${item.status}'
              .toLowerCase();
          return matchesFilter && (_query.isEmpty || haystack.contains(_query));
        })
        .toList(growable: false);
  }

  void _notice(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? PadelColors.danger : null,
      ),
    );
  }

  Future<void> _showMaintenanceDialog() async {
    final courts = context.read<CourtProvider>();
    await courts.loadCourts();
    if (!mounted) return;
    if (courts.errorMessage != null) {
      _notice(courts.errorMessage!);
      return;
    }
    final scheduled = await showDialog<bool>(
      context: context,
      builder: (_) => _MaintenanceBlockDialog(
        courts: courts.courts.where((court) => court.isActive).toList(),
      ),
    );
    if (scheduled != true || !mounted) return;

    _notice(context.tr("Maintenance block scheduled."));
    await context.read<ReservationProvider>().loadReservations(
      management: true,
    );
  }

  Future<void> _confirmNoShow(Reservation reservation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr("Mark player as no-show?")),
        content: Text(
          context.tr(
            "The booking for {p1} will be marked as not attended. This action cannot be undone from the reservation screen.",
            {'p1': reservation.courtName},
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr("Keep reservation")),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.person_off_rounded),
            label: Text(context.tr("Mark no-show")),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final provider = context.read<ReservationProvider>();
    final marked = await provider.markNoShow(reservation.id);
    if (!mounted) return;
    if (!marked) {
      _notice(
        provider.errorMessage ?? context.tr("Could not mark the reservation."),
      );
      return;
    }

    _notice(
      context.tr("Booking for {p1} marked as no-show.", {
        'p1': reservation.courtName,
      }),
    );
    await provider.loadReservations(management: true);
  }
}

class _MaintenanceBlockDialog extends StatefulWidget {
  const _MaintenanceBlockDialog({required this.courts});
  final List<Court> courts;

  @override
  State<_MaintenanceBlockDialog> createState() =>
      _MaintenanceBlockDialogState();
}

class _MaintenanceBlockDialogState extends State<_MaintenanceBlockDialog> {
  final _formKey = GlobalKey<FormState>();
  int _selectedCourtId = 0;
  final _reasonController = TextEditingController();
  late DateTime _startTime;
  late DateTime _endTime;
  bool _isSubmitting = false;
  String? _timeError;
  String? _submissionError;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startTime = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
    ).add(const Duration(hours: 1));
    _endTime = _startTime.add(const Duration(hours: 1));
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.tr("Schedule court maintenance")),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr(
                    "Select a court or all active courts for this maintenance block.",
                  ),
                ),
                const SizedBox(height: PadelSpacing.md),
                DropdownButtonFormField<int>(
                  initialValue: _selectedCourtId,
                  decoration: InputDecoration(labelText: context.tr('Court')),
                  items: [
                    DropdownMenuItem(
                      value: 0,
                      child: Text(context.tr('All active courts')),
                    ),
                    ...widget.courts.map(
                      (court) => DropdownMenuItem(
                        value: court.id,
                        child: Text(court.name),
                      ),
                    ),
                  ],
                  onChanged: _isSubmitting
                      ? null
                      : (value) =>
                            setState(() => _selectedCourtId = value ?? 0),
                ),
                const SizedBox(height: PadelSpacing.md),
                _DateTimePickerButton(
                  label: context.tr("Maintenance start"),
                  value: _startTime,
                  enabled: !_isSubmitting,
                  onPressed: () => _pickDateTime(isStart: true),
                ),
                const SizedBox(height: PadelSpacing.sm),
                _DateTimePickerButton(
                  label: context.tr("Maintenance end"),
                  value: _endTime,
                  enabled: !_isSubmitting,
                  onPressed: () => _pickDateTime(isStart: false),
                ),
                if (_timeError != null) ...[
                  const SizedBox(height: PadelSpacing.xs),
                  Semantics(
                    liveRegion: true,
                    label: context.tr("Maintenance interval error: {p1}", {
                      'p1': _timeError,
                    }),
                    child: Text(
                      _timeError!,
                      style: const TextStyle(color: PadelColors.danger),
                    ),
                  ),
                ],
                const SizedBox(height: PadelSpacing.md),
                TextFormField(
                  controller: _reasonController,
                  enabled: !_isSubmitting,
                  decoration: InputDecoration(
                    labelText: context.tr("Maintenance reason"),
                  ),
                  maxLength: 500,
                  maxLines: 2,
                  validator: (value) => value?.trim().isEmpty == true
                      ? context.tr("Enter a maintenance reason")
                      : null,
                ),
                if (_submissionError != null) ...[
                  const SizedBox(height: PadelSpacing.xs),
                  Semantics(
                    liveRegion: true,
                    label: context.tr("Maintenance request failed: {p1}", {
                      'p1': _submissionError,
                    }),
                    child: Text(
                      _submissionError!,
                      style: const TextStyle(color: PadelColors.danger),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: Text(context.tr("Cancel")),
        ),
        FilledButton.icon(
          onPressed: _isSubmitting ? null : _submit,
          icon: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.build_rounded),
          label: Text(
            _isSubmitting
                ? context.tr("Scheduling maintenance...")
                : context.tr("Schedule maintenance"),
          ),
        ),
      ],
    );
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final initial = isStart ? _startTime : _endTime;
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (selectedDate == null || !mounted) return;

    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (selectedTime == null || !mounted) return;

    final selected = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedTime.hour,
      selectedTime.minute,
    );
    setState(() {
      if (isStart) {
        _startTime = selected;
      } else {
        _endTime = selected;
      }
      _timeError = null;
      _submissionError = null;
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_endTime.isAfter(_startTime)) {
      setState(() {
        _timeError = context.tr("Maintenance end must be after its start.");
        _submissionError = null;
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _timeError = null;
      _submissionError = null;
    });
    final saved = await context.read<ReservationProvider>().addMaintenanceBlock(
      courtId: _selectedCourtId == 0 ? null : _selectedCourtId,
      startTime: _startTime,
      endTime: _endTime,
      reason: _reasonController.text,
    );
    if (!mounted) return;
    if (saved) {
      Navigator.pop(context, true);
      return;
    }

    setState(() {
      _isSubmitting = false;
      _submissionError =
          context.read<ReservationProvider>().errorMessage ??
          context.tr("Maintenance could not be scheduled.");
    });
  }
}

class _DateTimePickerButton extends StatelessWidget {
  const _DateTimePickerButton({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final DateTime value;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: context.tr("{p1}: {p2} at {p3}", {
        'p1': label,
        'p2': _dateLabel(context, value),
        'p3': _time(value),
      }),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: enabled ? onPressed : null,
          icon: const Icon(Icons.schedule_rounded),
          label: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              context.tr("{p1}: {p2} at {p3}", {
                'p1': label,
                'p2': _dateLabel(context, value),
                'p3': _time(value),
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _CourtAvailabilityCard extends StatelessWidget {
  const _CourtAvailabilityCard({
    required this.court,
    required this.selectedSlot,
    required this.onSelect,
    required this.onJoinWaitlist,
  });
  final CourtAvailability court;
  final AvailabilitySlot? selectedSlot;
  final ValueChanged<AvailabilitySlot> onSelect;
  final ValueChanged<AvailabilitySlot> onJoinWaitlist;

  @override
  Widget build(BuildContext context) {
    final available = court.slots.where((slot) => slot.isAvailable).toList();
    final occupied = court.slots
        .where((slot) => slot.isWaitlistEligible)
        .toList();
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0E14253A),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F4EF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.stadium_rounded,
                  color: Color(0xFF1F7A63),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      court.courtName,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      context.tr("{p1} · Up to {p2} players", {
                        'p1': court.isIndoor ? 'Indoor' : 'Outdoor',
                        'p2': court.maxPlayers,
                      }),
                      style: const TextStyle(
                        color: Color(0xFF667085),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${context.l10n.number(court.hourlyRate, decimalDigits: 0)} KM',
                style: const TextStyle(
                  color: Color(0xFF1F7A63),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (available.isEmpty && occupied.isEmpty)
            Text(
              context.tr("No times available for this day."),
              style: TextStyle(color: Color(0xFF98A2B3)),
            )
          else if (available.isNotEmpty) ...[
            Text(
              context.tr("Available times"),
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 9),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: available
                  .map(
                    (slot) => ChoiceChip(
                      label: Text(_time(slot.startTime)),
                      selected: identical(slot, selectedSlot),
                      avatar: const Icon(Icons.schedule_rounded, size: 16),
                      onSelected: (_) => onSelect(slot),
                    ),
                  )
                  .toList(),
            ),
          ],
          if (occupied.isNotEmpty) ...[
            if (available.isNotEmpty) const SizedBox(height: 16),
            Text(
              context.tr("Full times"),
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              context.tr(
                "Join the waitlist and we will notify you if a spot opens.",
              ),
              style: TextStyle(color: PadelColors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 9),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: occupied
                  .map(
                    (slot) => ActionChip(
                      avatar: const Icon(
                        Icons.notifications_active_outlined,
                        size: 16,
                      ),
                      label: Text(
                        context.tr("{p1} · Waitlist", {
                          'p1': _time(slot.startTime),
                        }),
                      ),
                      onPressed: () => onJoinWaitlist(slot),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _DateCard extends StatelessWidget {
  const _DateCard({
    required this.date,
    required this.selected,
    required this.onTap,
  });

  final DateTime date;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Semantics(
      button: true,
      selected: selected,
      label: _dateLabel(context, date),
      child: Material(
        color: selected ? PadelColors.greenDark : Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            width: 62,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected ? PadelColors.greenDark : PadelColors.border,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  context.tr(weekdays[date.weekday - 1]),
                  style: TextStyle(
                    color: selected ? Colors.white70 : PadelColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${date.day}',
                  style: TextStyle(
                    color: selected ? Colors.white : PadelColors.text,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BookingAction extends StatelessWidget {
  const _BookingAction({
    required this.court,
    required this.slot,
    required this.onPressed,
  });

  final CourtAvailability court;
  final AvailabilitySlot slot;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PadelColors.greenSoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFBFE2D5)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: PadelColors.greenDark,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      court.courtName,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    Text(
                      '${_time(slot.startTime)}–${_time(slot.endTime)}',
                      style: const TextStyle(color: PadelColors.textMuted),
                    ),
                  ],
                ),
              ),
              Text(
                '${context.l10n.number(slot.price, decimalDigits: 2)} KM',
                style: const TextStyle(
                  color: PadelColors.greenDark,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onPressed,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: Text(context.tr("Continue to booking")),
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileReservationCard extends StatelessWidget {
  const _MobileReservationCard({
    required this.reservation,
    required this.onCancel,
  });
  final Reservation reservation;
  final VoidCallback onCancel;
  @override
  Widget build(BuildContext context) {
    final cancellable =
        reservation.status != 'Cancelled' &&
        reservation.startTime.isAfter(
          DateTime.now().add(const Duration(hours: 2)),
        );
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF1FF),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.sports_tennis_rounded,
                color: Color(0xFF2E6BD7),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _dateLabel(context, reservation.startTime),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    context.tr("{p1}–{p2} · Court {p3}", {
                      'p1': _time(reservation.startTime),
                      'p2': _time(reservation.endTime),
                      'p3': reservation.courtName,
                    }),
                    style: const TextStyle(color: Color(0xFF667085)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${context.l10n.number(reservation.totalPrice, decimalDigits: 2)} KM · ${reservation.status}',
                    style: TextStyle(
                      color: reservation.status == 'Cancelled'
                          ? const Color(0xFFC95C4C)
                          : const Color(0xFF1F7A63),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (cancellable)
              IconButton(
                tooltip: context.tr("Cancel reservation"),
                onPressed: onCancel,
                icon: const Icon(Icons.close_rounded),
              ),
          ],
        ),
      ),
    );
  }
}

class _BookingActivityTitle extends StatelessWidget {
  const _BookingActivityTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: PadelColors.greenDark, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}

class _WaitlistEntryCard extends StatelessWidget {
  const _WaitlistEntryCard({required this.entry});

  final WaitlistEntry entry;

  @override
  Widget build(BuildContext context) {
    final notified = entry.status.toLowerCase() == 'notified';
    final color = notified ? PadelColors.greenDark : PadelColors.blue;
    final background = notified ? PadelColors.greenSoft : PadelColors.blueSoft;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(PadelRadii.medium),
              ),
              child: Icon(Icons.notifications_active_outlined, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr("Court {p1}", {'p1': entry.courtName}),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${_dateLabel(context, entry.startTime)} · ${_time(entry.startTime)}–${_time(entry.endTime)}',
                    style: const TextStyle(
                      color: PadelColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                entry.status,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountCreditSummary extends StatelessWidget {
  const _AccountCreditSummary({required this.credits});

  final List<AccountCredit> credits;

  @override
  Widget build(BuildContext context) {
    final available = credits
        .where((credit) => credit.isAvailable)
        .fold<double>(0, (total, credit) => total + credit.amount);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PadelColors.greenSoft,
        borderRadius: BorderRadius.circular(PadelRadii.large),
        border: Border.all(color: const Color(0xFFBFE2D5)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.account_balance_wallet_rounded,
            color: PadelColors.greenDark,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr("Available balance"),
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 2),
                Text(
                  context.tr("Credit from eligible reservation cancellations."),
                  style: TextStyle(color: PadelColors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            '${context.l10n.number(available, decimalDigits: 2)} KM',
            style: const TextStyle(
              color: PadelColors.greenDark,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountCreditCard extends StatelessWidget {
  const _AccountCreditCard({required this.credit});

  final AccountCredit credit;

  @override
  Widget build(BuildContext context) {
    final available = credit.isAvailable;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: available
              ? PadelColors.greenSoft
              : PadelColors.canvas,
          foregroundColor: available
              ? PadelColors.greenDark
              : PadelColors.textMuted,
          child: Icon(
            available
                ? Icons.add_card_rounded
                : Icons.check_circle_outline_rounded,
          ),
        ),
        title: Text(
          credit.reason,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          available
              ? context.tr("Available since {p1}", {
                  'p1': _dateLabel(context, credit.createdAt),
                })
              : context.tr("Used on {p1}", {
                  'p1': _dateLabel(context, credit.usedAt!),
                }),
        ),
        trailing: Text(
          '${context.l10n.number(credit.amount, decimalDigits: 2)} KM',
          style: TextStyle(
            color: available ? PadelColors.greenDark : PadelColors.textMuted,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _ManagementTable extends StatelessWidget {
  const _ManagementTable({
    required this.reservations,
    required this.onMarkNoShow,
    required this.onCancel,
  });

  final List<Reservation> reservations;
  final ValueChanged<Reservation> onMarkNoShow;
  final ValueChanged<int> onCancel;

  @override
  Widget build(BuildContext context) {
    if (reservations.isEmpty) {
      return Center(child: Text(context.tr("No reservations found.")));
    }
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(PadelColors.canvas),
              dataRowMinHeight: 66,
              dataRowMaxHeight: 74,
              columnSpacing: 32,
              columns: [
                DataColumn(label: Text(context.tr("RESERVATION"))),
                DataColumn(label: Text(context.tr("TIME SLOT"))),
                DataColumn(label: Text(context.tr("DATE"))),
                DataColumn(label: Text(context.tr("AMOUNT"))),
                DataColumn(label: Text(context.tr("STATUS"))),
                DataColumn(label: Text(context.tr("ACTIONS"))),
              ],
              rows: reservations
                  .map((item) {
                    final cancelled = item.status.toLowerCase().contains(
                      'cancel',
                    );
                    final markedNoShow = item.status.toLowerCase() == 'noshow';
                    final canMarkNoShow =
                        !cancelled &&
                        !markedNoShow &&
                        item.endTime.isBefore(DateTime.now());
                    return DataRow(
                      cells: [
                        DataCell(
                          Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: PadelColors.green,
                                  borderRadius: BorderRadius.circular(
                                    PadelRadii.small,
                                  ),
                                ),
                                child: Text(
                                  'P',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: PadelSpacing.sm),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    context.tr("Court {p1}", {
                                      'p1': item.courtName,
                                    }),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    context
                                        .tr("{p1} ? {p2}", {
                                          'p1': _dateLabel(
                                            context,
                                            item.startTime,
                                          ),
                                          'p2': item.userName,
                                        }),
                                    style: const TextStyle(
                                      color: PadelColors.textMuted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        DataCell(
                          Text(
                            '${_time(item.startTime)}–${_time(item.endTime)}',
                          ),
                        ),
                        DataCell(Text(_dateLabel(context, item.startTime))),
                        DataCell(
                          Text(
                            '${context.l10n.number(item.totalPrice, decimalDigits: 2)} KM',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        DataCell(
                          AdminStatusBadge(
                            label: item.status,
                            tone: _reservationTone(item.status),
                          ),
                        ),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AdminActionButton(
                                icon: Icons.person_off_rounded,
                                tooltip: context.tr("Mark player as no-show"),
                                onPressed: canMarkNoShow
                                    ? () => onMarkNoShow(item)
                                    : null,
                                destructive: true,
                              ),
                              const SizedBox(width: PadelSpacing.xs),
                              AdminActionButton(
                                icon: Icons.close_rounded,
                                tooltip: context.tr("Cancel reservation"),
                                onPressed: cancelled
                                    ? null
                                    : () => onCancel(item.id),
                                destructive: true,
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  })
                  .toList(growable: false),
            ),
          ),
        ),
      ),
    );
  }
}

AdminStatusTone _reservationTone(String status) {
  return switch (status.toLowerCase()) {
    'confirmed' || 'completed' => AdminStatusTone.success,
    'pending' => AdminStatusTone.warning,
    'cancelled' || 'canceled' => AdminStatusTone.danger,
    _ => AdminStatusTone.info,
  };
}

/* Obsolete table retained temporarily for migration reference.
class _LegacyManagementTable extends StatelessWidget {
  const _LegacyManagementTable({required this.reservations, required this.onCancel});
  final List<Reservation> reservations;
  final ValueChanged<int> onCancel;
  @override
  Widget build(BuildContext context) {
    if (reservations.isEmpty) return const Center(child: Text('No reservations found.'));
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: SizedBox(
        width: double.infinity,
        child: DataTable(
          columns: const [DataColumn(label: Text('Date')), DataColumn(label: Text('Time')), DataColumn(label: Text('Court')), DataColumn(label: Text('User')), DataColumn(label: Text('Amount')), DataColumn(label: Text('Status')), DataColumn(label: Text('Actions'))],
          rows: reservations.map((item) => DataRow(cells: [DataCell(Text(_dateLabel(context, item.startTime))), DataCell(Text('${_time(item.startTime)}–${_time(item.endTime)}')), DataCell(Text(item.courtName)), DataCell(Text(item.userName)), DataCell(Text('${item.totalPrice.toStringAsFixed(2)} KM')), DataCell(Text(context.tr(item.status))), DataCell(item.status == 'Cancelled' ? const SizedBox.shrink() : TextButton(onPressed: () => onCancel(item.id), child: const Text('Cancel')))])).toList(),
        ),
      ),
    );
  }
}
*/

class _SectionButton extends StatelessWidget {
  const _SectionButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Expanded(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? const Color(0xFF1F7A63) : Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    ),
  );
}

/* Obsolete sidebar item retained temporarily for migration reference.
class _AdminNavItem extends StatelessWidget {
  const _AdminNavItem({required this.icon, required this.label, this.selected = false});
  final IconData icon;
  final String label;
  final bool selected;
  @override
  Widget build(BuildContext context) => Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12), decoration: BoxDecoration(color: selected ? const Color(0xFF2F64E7) : Colors.transparent, borderRadius: BorderRadius.circular(10)), child: Row(children: [Icon(icon, color: Colors.white70, size: 20), const SizedBox(width: 11), Text(label, style: TextStyle(color: Colors.white, fontWeight: selected ? FontWeight.w800 : FontWeight.w500))]));
}
*/

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        Icon(icon, color: const Color(0xFF1F7A63)),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF3F0),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.cloud_off_rounded, color: Color(0xFFC95C4C), size: 34),
        const SizedBox(height: 10),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 10),
        TextButton(onPressed: onRetry, child: Text(context.tr("Try again"))),
      ],
    ),
  );
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.icon,
    required this.title,
    required this.message,
  });
  final IconData icon;
  final String title;
  final String message;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(30),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
    ),
    child: Column(
      children: [
        Icon(icon, size: 50, color: const Color(0xFF1F7A63)),
        const SizedBox(height: 12),
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 5),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF667085)),
        ),
      ],
    ),
  );
}

String _time(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
String _dateLabel(BuildContext context, DateTime value) =>
    context.l10n.date(value);
