import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:padelclub_desktop/core/theme/app_theme.dart';
import 'package:padelclub_desktop/core/widgets/admin_components.dart';
import 'package:padelclub_desktop/features/reservations/domain/entities/court_availability.dart';
import 'package:padelclub_desktop/features/reservations/domain/entities/reservation.dart';
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
      await provider.loadReservations(management: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MasterScreen(
      title: 'Court booking',
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
                      label: 'Book a court',
                      selected: _section == 0,
                      onTap: () => _changeSection(0),
                    ),
                    _SectionButton(
                      label: 'My bookings',
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
                const Text(
                  'Choose your next match',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF27423A),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Live availability for every active court.',
                  style: TextStyle(color: Color(0xFF5C6B64)),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Select a date',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Open calendar',
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
                  const _EmptyCard(
                    icon: Icons.stadium_outlined,
                    title: 'No courts available',
                    message:
                        'There are no active courts available for this date.',
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
            const Text(
              'My bookings',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: Color(0xFF27423A),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Your upcoming and previous court sessions.',
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
                provider.reservations.isEmpty)
              const _EmptyCard(
                icon: Icons.event_available_rounded,
                title: 'No bookings yet',
                message: 'Choose “Book a court” to schedule your first match.',
              ),
            if (!provider.isLoading && provider.errorMessage == null)
              ...provider.reservations.map(
                (reservation) => _MobileReservationCard(
                  reservation: reservation,
                  onCancel: () => _cancel(reservation),
                ),
              ),
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
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Confirm your court',
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
                    '${_dateLabel(slot.startTime)} · ${_time(slot.startTime)}–${_time(slot.endTime)}',
              ),
              _SummaryRow(
                icon: Icons.payments_outlined,
                label: '${slot.price.toStringAsFixed(2)} KM',
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(
                initialValue: weeks,
                decoration: const InputDecoration(labelText: 'Repeat weekly'),
                items: const [1, 2, 4, 8, 12]
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(
                          value == 1 ? 'One booking' : '$value weeks',
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setSheetState(() => weeks = value ?? 1),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () => Navigator.pop(context, weeks),
                child: const SizedBox(
                  width: double.infinity,
                  child: Center(child: Text('Confirm booking')),
                ),
              ),
            ],
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
        content: Text(
          success
              ? (selectedWeeks == 1
                    ? 'Court booked successfully.'
                    : '$selectedWeeks weekly courts booked successfully.')
              : provider.errorMessage ?? 'Booking failed.',
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

  Future<void> _cancel(Reservation reservation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel reservation?'),
        content: const Text(
          'This court will become available to other players.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep booking'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel reservation'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final provider = context.read<ReservationProvider>();
    final success = await provider.cancel(reservation.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Reservation cancelled.'
              : provider.errorMessage ?? 'Cancellation failed.',
        ),
      ),
    );
    await provider.loadReservations(management: false);
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

  @override
  Widget build(BuildContext context) {
    return MasterScreen(
      title: 'Reservation management',
      section: AppSection.reservations,
      child: Consumer<ReservationProvider>(
        builder: (context, provider, _) {
          final reservations = _filtered(provider.reservations);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AdminPageHeader(
                title: 'Reservation Management',
                subtitle:
                    'Manage court bookings, schedules, and player reservations.',
                action: FilledButton.icon(
                  onPressed: () => _notice(
                    'New reservations are created from the booking flow.',
                  ),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('New Reservation'),
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
                          ['All', 'Today', 'Confirmed', 'Pending', 'Cancelled']
                              .map(
                                (filter) => AdminFilterChip(
                                  label: filter == 'All'
                                      ? 'All Reservations'
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
                          hintText:
                              'Search by player, court, or reservation...',
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
                          label: const Text('Search'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () =>
                              provider.loadReservations(management: true),
                          icon: const Icon(Icons.refresh_rounded, size: 17),
                          label: const Text('Refresh'),
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
                            onEdit: (item) => _notice(
                              'Reservation #${item.id} editing will be connected with the booking form.',
                            ),
                            onCancel: (id) async {
                              await provider.cancel(id);
                              await provider.loadReservations(management: true);
                            },
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
          final haystack =
              '${item.id} ${item.userId} ${item.courtId} ${item.status}'
                  .toLowerCase();
          return matchesFilter && (_query.isEmpty || haystack.contains(_query));
        })
        .toList(growable: false);
  }

  void _notice(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _CourtAvailabilityCard extends StatelessWidget {
  const _CourtAvailabilityCard({
    required this.court,
    required this.selectedSlot,
    required this.onSelect,
  });
  final CourtAvailability court;
  final AvailabilitySlot? selectedSlot;
  final ValueChanged<AvailabilitySlot> onSelect;

  @override
  Widget build(BuildContext context) {
    final available = court.slots.where((slot) => slot.isAvailable).toList();
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
                      '${court.isIndoor ? 'Indoor' : 'Outdoor'} · Up to ${court.maxPlayers} players',
                      style: const TextStyle(
                        color: Color(0xFF667085),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${court.hourlyRate.toStringAsFixed(0)} KM',
                style: const TextStyle(
                  color: Color(0xFF1F7A63),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (available.isEmpty)
            const Text(
              'No times available for this day.',
              style: TextStyle(color: Color(0xFF98A2B3)),
            )
          else
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
      label: _dateLabel(date),
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
                  weekdays[date.weekday - 1],
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
                '${slot.price.toStringAsFixed(2)} KM',
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
              label: const Text('Continue to booking'),
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
                    _dateLabel(reservation.startTime),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${_time(reservation.startTime)}–${_time(reservation.endTime)} · Court ${reservation.courtId}',
                    style: const TextStyle(color: Color(0xFF667085)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${reservation.totalPrice.toStringAsFixed(2)} KM · ${reservation.status}',
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
                tooltip: 'Cancel reservation',
                onPressed: onCancel,
                icon: const Icon(Icons.close_rounded),
              ),
          ],
        ),
      ),
    );
  }
}

class _ManagementTable extends StatelessWidget {
  const _ManagementTable({
    required this.reservations,
    required this.onEdit,
    required this.onCancel,
  });

  final List<Reservation> reservations;
  final ValueChanged<Reservation> onEdit;
  final ValueChanged<int> onCancel;

  @override
  Widget build(BuildContext context) {
    if (reservations.isEmpty) {
      return const Center(child: Text('No reservations found.'));
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
              columns: const [
                DataColumn(label: Text('RESERVATION')),
                DataColumn(label: Text('TIME SLOT')),
                DataColumn(label: Text('DATE')),
                DataColumn(label: Text('AMOUNT')),
                DataColumn(label: Text('STATUS')),
                DataColumn(label: Text('ACTIONS')),
              ],
              rows: reservations
                  .map((item) {
                    final cancelled = item.status.toLowerCase().contains(
                      'cancel',
                    );
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
                                  'C${item.courtId}',
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
                                    'Court ${item.courtId}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Reservation #${item.id} · User #${item.userId}',
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
                        DataCell(Text(_dateLabel(item.startTime))),
                        DataCell(
                          Text(
                            '${item.totalPrice.toStringAsFixed(2)} KM',
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
                                icon: Icons.edit_outlined,
                                tooltip: 'Edit reservation',
                                onPressed: () => onEdit(item),
                              ),
                              const SizedBox(width: PadelSpacing.xs),
                              AdminActionButton(
                                icon: Icons.close_rounded,
                                tooltip: 'Cancel reservation',
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
          rows: reservations.map((item) => DataRow(cells: [DataCell(Text(_dateLabel(item.startTime))), DataCell(Text('${_time(item.startTime)}–${_time(item.endTime)}')), DataCell(Text('#${item.courtId}')), DataCell(Text('#${item.userId}')), DataCell(Text('${item.totalPrice.toStringAsFixed(2)} KM')), DataCell(Text(item.status)), DataCell(item.status == 'Cancelled' ? const SizedBox.shrink() : TextButton(onPressed: () => onCancel(item.id), child: const Text('Cancel')))])).toList(),
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
        TextButton(onPressed: onRetry, child: const Text('Try again')),
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
String _dateLabel(DateTime value) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${value.day} ${months[value.month - 1]} ${value.year}';
}
