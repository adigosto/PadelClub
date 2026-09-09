import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import 'package:padelclub_desktop/core/localization/app_localizations.dart';
import 'package:padelclub_desktop/core/theme/app_theme.dart';
import 'package:padelclub_desktop/core/validation/form_validators.dart';
import 'package:padelclub_desktop/core/widgets/admin_components.dart';
import 'package:padelclub_desktop/features/tournament/domain/entities/tournament.dart';
import 'package:padelclub_desktop/features/tournament_management/domain/entities/tournament_draft.dart';
import 'package:padelclub_desktop/features/tournament_management/presentation/providers/tournament_management_provider.dart';
import 'package:padelclub_desktop/layouts/master_screen.dart';

/// Administrator CRUD workspace. It intentionally owns a separate provider so
/// player tournament search, registration, and bracket viewing remain intact.
class TournamentManagementScreen extends StatelessWidget {
  const TournamentManagementScreen({super.key, this.provider});

  final TournamentManagementProvider? provider;

  @override
  Widget build(BuildContext context) {
    final value = provider;
    if (value != null) {
      return ChangeNotifierProvider<TournamentManagementProvider>.value(
        value: value,
        child: const _TournamentManagementContent(),
      );
    }
    return ChangeNotifierProvider<TournamentManagementProvider>(
      create: (_) => TournamentManagementProvider.live(),
      child: const _TournamentManagementContent(),
    );
  }
}

class _TournamentManagementContent extends StatefulWidget {
  const _TournamentManagementContent();

  @override
  State<_TournamentManagementContent> createState() =>
      _TournamentManagementContentState();
}

class _TournamentManagementContentState
    extends State<_TournamentManagementContent> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<TournamentManagementProvider>().load();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TournamentManagementProvider>();
    return MasterScreen(
      title: context.tr("Tournament Management"),
      section: AppSection.tournaments,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminPageHeader(
            title: context.tr("Tournament Management"),
            subtitle: context.tr(
              "Create, update, and permanently delete tournaments. Player registration remains in the player experience.",
            ),
            action: FilledButton.icon(
              key: const Key('create-tournament-button'),
              onPressed: provider.isSaving ? null : _createTournament,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(context.tr("Create tournament")),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(PadelSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: PadelSpacing.sm,
                  runSpacing: PadelSpacing.sm,
                  children: [
                    AdminSearchField(
                      controller: _searchController,
                      hintText: context.tr("Search tournaments..."),
                      width: 320,
                      onSubmitted: _setQuery,
                    ),
                    OutlinedButton.icon(
                      onPressed: provider.isSaving
                          ? null
                          : () => _setQuery(_searchController.text),
                      icon: const Icon(Icons.search_rounded, size: 17),
                      label: Text(context.tr("Search")),
                    ),
                    OutlinedButton.icon(
                      onPressed: provider.isLoading || provider.isSaving
                          ? null
                          : () => provider.load(query: _query),
                      icon: const Icon(Icons.refresh_rounded, size: 17),
                      label: Text(context.tr("Refresh")),
                    ),
                  ],
                ),
                const SizedBox(height: PadelSpacing.md),
                const _BracketWarning(),
                if (provider.errorMessage != null) ...[
                  const SizedBox(height: PadelSpacing.sm),
                  _InlineError(
                    message: provider.errorMessage!,
                    onRetry: provider.isLoading || provider.isSaving
                        ? null
                        : () => provider.load(query: _query),
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
    );
  }

  void _setQuery(String value) {
    setState(() => _query = value.trim());
    context.read<TournamentManagementProvider>().load(query: value);
  }

  Widget _content(TournamentManagementProvider provider) {
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (provider.errorMessage != null && provider.tournaments.isEmpty) {
      return _TournamentMessage(
        icon: Icons.cloud_off_rounded,
        title: context.tr("Tournaments are unavailable"),
        message: provider.errorMessage!,
        actionLabel: context.tr("Try again"),
        onAction: () => provider.load(query: _query),
      );
    }
    if (provider.tournaments.isEmpty) {
      return _TournamentMessage(
        icon: Icons.emoji_events_outlined,
        title: context.tr("No tournaments found"),
        message: _query.isEmpty
            ? context.tr(
                "Create a tournament to publish it in the player catalogue.",
              )
            : context.tr("No server tournaments match the current search."),
        actionLabel: _query.isEmpty
            ? context.tr("Create tournament")
            : context.tr("Clear search"),
        onAction: _query.isEmpty
            ? _createTournament
            : () {
                _searchController.clear();
                _setQuery('');
              },
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
              dataRowMinHeight: 86,
              dataRowMaxHeight: 104,
              columnSpacing: 30,
              columns: [
                DataColumn(label: Text(context.tr("TOURNAMENT"))),
                DataColumn(label: Text(context.tr("SCHEDULE (UTC)"))),
                DataColumn(label: Text(context.tr("REGISTRATION"))),
                DataColumn(label: Text(context.tr("CAPACITY / FEE"))),
                DataColumn(label: Text(context.tr("STATUS"))),
                DataColumn(label: Text(context.tr("ACTIONS"))),
              ],
              rows: provider.tournaments
                  .map((tournament) => _row(tournament, provider))
                  .toList(growable: false),
            ),
          ),
        ),
      ),
    );
  }

  DataRow _row(Tournament tournament, TournamentManagementProvider provider) {
    final id = tournament.id;
    final busy = provider.isSaving;
    return DataRow(
      onSelectChanged: (_) => _showDetails(tournament),
      cells: [
        DataCell(
          SizedBox(
            width: 260,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tournament.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  tournament.description.isEmpty
                      ? context.tr("No description provided.")
                      : tournament.description,
                  maxLines: 2,
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
            width: 150,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_date(tournament.startDate)),
                const SizedBox(height: 3),
                Text(
                  context.tr("to {p1}", {'p1': _date(tournament.endDate)}),
                  style: const TextStyle(
                    color: PadelColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
        DataCell(Text(_date(tournament.registrationDeadline))),
        DataCell(
          SizedBox(
            width: 120,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr("{p1} players", {
                    'p1': tournament.maxParticipants,
                  }),
                ),
                const SizedBox(height: 3),
                Text(
                  '${context.l10n.number(tournament.entryFee, decimalDigits: 2)} KM',
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
          AdminStatusBadge(
            label: tournament.status,
            tone: _statusTone(tournament.status),
          ),
        ),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AdminActionButton(
                icon: Icons.visibility_outlined,
                tooltip: context.tr("View tournament"),
                onPressed: () => _showDetails(tournament),
              ),
              const SizedBox(width: PadelSpacing.xs),
              AdminActionButton(
                icon: Icons.edit_outlined,
                tooltip: context.tr("Edit tournament"),
                onPressed: busy || id == null
                    ? null
                    : () => _editTournament(tournament),
              ),
              const SizedBox(width: PadelSpacing.xs),
              AdminActionButton(
                icon: provider.isProcessing(id ?? -1)
                    ? Icons.sync_rounded
                    : Icons.account_tree_outlined,
                tooltip: context.tr("Generate one-way bracket"),
                onPressed: busy || id == null
                    ? null
                    : () => _confirmGenerate(tournament),
              ),
              const SizedBox(width: PadelSpacing.xs),
              AdminActionButton(
                icon: Icons.delete_outline_rounded,
                tooltip: context.tr("Permanently delete tournament"),
                destructive: true,
                onPressed: busy || id == null
                    ? null
                    : () => _confirmDelete(tournament),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _createTournament() async {
    final draft = await showDialog<TournamentDraft>(
      context: context,
      builder: (_) => const _TournamentEditorDialog(),
    );
    if (!mounted || draft == null) return;
    final provider = context.read<TournamentManagementProvider>();
    final saved = await provider.create(draft);
    if (!mounted) return;
    _showOperationResult(provider, saved);
  }

  Future<void> _editTournament(Tournament tournament) async {
    final id = tournament.id;
    if (id == null) return;
    final draft = await showDialog<TournamentDraft>(
      context: context,
      builder: (_) => _TournamentEditorDialog(tournament: tournament),
    );
    if (!mounted || draft == null) return;
    final provider = context.read<TournamentManagementProvider>();
    final saved = await provider.update(tournamentId: id, draft: draft);
    if (!mounted) return;
    _showOperationResult(provider, saved);
  }

  Future<void> _confirmGenerate(Tournament tournament) async {
    final id = tournament.id;
    if (id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr("Generate tournament bracket?")),
        content: Text(
          context.tr(
            "Generate the bracket for \"{p1}\"? This is a one-way server operation: it creates the bracket matches, and the server will reject another generation attempt. Confirmed complete teams and an active court are required.",
            {'p1': tournament.name},
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.tr("Cancel")),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.account_tree_outlined),
            label: Text(context.tr("Generate bracket")),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    final provider = context.read<TournamentManagementProvider>();
    final saved = await provider.generateBracket(id);
    if (!mounted) return;
    _showOperationResult(provider, saved);
  }

  Future<void> _confirmDelete(Tournament tournament) async {
    final id = tournament.id;
    if (id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr("Permanently delete tournament?")),
        content: Text(
          context.tr(
            "Delete \"{p1}\" from the server? The available API performs a hard delete; this cannot be undone.",
            {'p1': tournament.name},
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.tr("Cancel")),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: PadelColors.danger),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.tr("Delete tournament")),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    final provider = context.read<TournamentManagementProvider>();
    final saved = await provider.delete(id);
    if (!mounted) return;
    _showOperationResult(provider, saved);
  }

  void _showOperationResult(TournamentManagementProvider provider, bool saved) {
    final message = saved
        ? provider.lastOperationMessage ??
              context.tr("Tournament operation completed.")
        : provider.errorMessage ??
              context.tr("Tournament operation could not be completed.");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: saved ? null : PadelColors.danger,
      ),
    );
  }

  void _showDetails(Tournament tournament) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tournament.name),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _detailRow(
                  context.tr("Description"),
                  tournament.description.isEmpty
                      ? context.tr("No description provided.")
                      : tournament.description,
                ),
                _detailRow(context.tr("Status"), tournament.status),
                _detailRow(
                  context.tr("Start (UTC)"),
                  _date(tournament.startDate),
                ),
                _detailRow(context.tr("End (UTC)"), _date(tournament.endDate)),
                _detailRow(
                  context.tr("Registration deadline"),
                  _date(tournament.registrationDeadline),
                ),
                _detailRow(
                  context.tr("Capacity"),
                  context.tr("{p1} players", {
                    'p1': tournament.maxParticipants,
                  }),
                ),
                _detailRow(
                  context.tr("Entry fee"),
                  '${context.l10n.number(tournament.entryFee, decimalDigits: 2)} KM',
                ),
                _detailRow(
                  context.tr("Prize information"),
                  tournament.prizeInfo?.trim().isEmpty == false
                      ? tournament.prizeInfo!.trim()
                      : context.tr("No prize information provided."),
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

  AdminStatusTone _statusTone(String status) => switch (status.toLowerCase()) {
    'upcoming' => AdminStatusTone.info,
    'ongoing' => AdminStatusTone.success,
    'completed' => AdminStatusTone.neutral,
    'cancelled' => AdminStatusTone.danger,
    _ => AdminStatusTone.neutral,
  };

  String _date(DateTime value) {
    final utc = value.toUtc();
    return '${utc.year}-${_two(utc.month)}-${_two(utc.day)} ${_two(utc.hour)}:${_two(utc.minute)}';
  }

  String _two(int value) => value.toString().padLeft(2, '0');
}

class _BracketWarning extends StatelessWidget {
  const _BracketWarning();

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
        Icon(Icons.warning_amber_rounded, color: PadelColors.warning),
        SizedBox(width: PadelSpacing.sm),
        Expanded(
          child: Text(
            context.tr(
              "Bracket generation is one-way. It creates server-side bracket matches; the server validates confirmed full teams and an active court, and returns a conflict if a bracket already exists.",
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

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Icon(
        Icons.error_outline_rounded,
        color: PadelColors.danger,
        size: 18,
      ),
      const SizedBox(width: PadelSpacing.xs),
      Expanded(
        child: Text(message, style: const TextStyle(color: PadelColors.danger)),
      ),
      if (onRetry != null)
        TextButton(onPressed: onRetry, child: Text(context.tr("Retry"))),
    ],
  );
}

class _TournamentMessage extends StatelessWidget {
  const _TournamentMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 430),
      child: Padding(
        padding: const EdgeInsets.all(PadelSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: PadelColors.blue),
            const SizedBox(height: PadelSpacing.sm),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: PadelSpacing.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: PadelColors.textMuted),
            ),
            const SizedBox(height: PadelSpacing.md),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    ),
  );
}

class _TournamentEditorDialog extends StatefulWidget {
  const _TournamentEditorDialog({this.tournament});

  final Tournament? tournament;

  @override
  State<_TournamentEditorDialog> createState() =>
      _TournamentEditorDialogState();
}

class _TournamentEditorDialogState extends State<_TournamentEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _capacity;
  late final TextEditingController _fee;
  late final TextEditingController _prize;
  late DateTime _startDate;
  late DateTime _endDate;
  late DateTime _deadline;
  String? _dateError;

  bool get _editing => widget.tournament != null;

  @override
  void initState() {
    super.initState();
    final tournament = widget.tournament;
    final now = DateTime.now().toUtc();
    _name = TextEditingController(text: tournament?.name ?? '');
    _description = TextEditingController(text: tournament?.description ?? '');
    _capacity = TextEditingController(
      text: '${tournament?.maxParticipants ?? 16}',
    );
    _fee = TextEditingController(text: '${tournament?.entryFee ?? 0}');
    _prize = TextEditingController(text: tournament?.prizeInfo ?? '');
    _startDate = tournament?.startDate ?? now.add(const Duration(days: 14));
    _endDate = tournament?.endDate ?? now.add(const Duration(days: 15));
    _deadline =
        tournament?.registrationDeadline ?? now.add(const Duration(days: 13));
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _capacity.dispose();
    _fee.dispose();
    _prize.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      _editing
          ? context.tr("Edit tournament")
          : context.tr("Create tournament"),
    ),
    content: SizedBox(
      width: 560,
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                decoration: InputDecoration(
                  labelText: context.tr("Tournament name"),
                ),
                maxLength: 160,
                validator: (value) => (value?.trim().length ?? 0) < 3
                    ? context.tr("Enter at least 3 characters.")
                    : null,
              ),
              TextFormField(
                controller: _description,
                decoration: InputDecoration(
                  labelText: context.tr("Description"),
                ),
                maxLength: 2000,
                maxLines: 3,
                validator: (value) => value?.trim().isEmpty == true
                    ? context.tr("Enter a description.")
                    : null,
              ),
              const SizedBox(height: PadelSpacing.sm),
              _DateControl(
                label: context.tr("Registration deadline (UTC)"),
                value: _deadline,
                onPick: () => _pickDate(_DateField.deadline),
              ),
              const SizedBox(height: PadelSpacing.sm),
              _DateControl(
                label: context.tr("Start date (UTC)"),
                value: _startDate,
                onPick: () => _pickDate(_DateField.start),
              ),
              const SizedBox(height: PadelSpacing.sm),
              _DateControl(
                label: context.tr("End date (UTC)"),
                value: _endDate,
                onPick: () => _pickDate(_DateField.end),
              ),
              if (_dateError != null) ...[
                const SizedBox(height: PadelSpacing.xs),
                Text(
                  _dateError!,
                  style: const TextStyle(
                    color: PadelColors.danger,
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: PadelSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _capacity,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: context.tr("Maximum players"),
                      ),
                      validator: (value) => FormValidators.integer(
                        value,
                        l10n: context.l10n,
                        label: 'the maximum players',
                        minimum: 2,
                      ),
                    ),
                  ),
                  const SizedBox(width: PadelSpacing.sm),
                  Expanded(
                    child: TextFormField(
                      controller: _fee,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: context.tr("Entry fee (KM)"),
                      ),
                      validator: (value) => FormValidators.decimal(
                        value,
                        l10n: context.l10n,
                        label: 'an entry fee',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: PadelSpacing.sm),
              TextFormField(
                controller: _prize,
                decoration: InputDecoration(
                  labelText: context.tr("Prize information (optional)"),
                ),
                maxLength: 500,
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(context.tr("Cancel")),
      ),
      FilledButton(
        onPressed: _submit,
        child: Text(
          _editing
              ? context.tr("Save changes")
              : context.tr("Create tournament"),
        ),
      ),
    ],
  );

  Future<void> _pickDate(_DateField field) async {
    final initial = switch (field) {
      _DateField.deadline => _deadline,
      _DateField.start => _startDate,
      _DateField.end => _endDate,
    };
    final selected = await showDatePicker(
      context: context,
      initialDate: initial.toLocal(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (selected == null || !mounted) return;
    setState(() {
      final value = DateTime.utc(selected.year, selected.month, selected.day);
      switch (field) {
        case _DateField.deadline:
          _deadline = value;
          break;
        case _DateField.start:
          _startDate = value;
          break;
        case _DateField.end:
          _endDate = value;
          break;
      }
      _dateError = null;
    });
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_deadline.isAfter(_startDate)) {
      setState(
        () => _dateError = context.tr(
          "Registration deadline must be on or before the start date.",
        ),
      );
      return;
    }
    if (_endDate.isBefore(_startDate)) {
      setState(
        () => _dateError = context.tr(
          "End date must be on or after the start date.",
        ),
      );
      return;
    }
    Navigator.of(context).pop(
      TournamentDraft(
        name: _name.text,
        description: _description.text,
        startDate: _startDate,
        endDate: _endDate,
        registrationDeadline: _deadline,
        maxParticipants: int.parse(_capacity.text.trim()),
        entryFee: FormValidators.decimalValue(_fee.text)!,
        prizeInfo: _prize.text,
      ),
    );
  }
}

class _DateControl extends StatelessWidget {
  const _DateControl({
    required this.label,
    required this.value,
    required this.onPick,
  });

  final String label;
  final DateTime value;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final utc = value.toUtc();
    final text =
        '${utc.year}-${utc.month.toString().padLeft(2, '0')}-${utc.day.toString().padLeft(2, '0')}';
    return OutlinedButton.icon(
      onPressed: onPick,
      icon: const Icon(Icons.calendar_today_outlined, size: 17),
      label: Align(
        alignment: Alignment.centerLeft,
        child: Text('$label: $text'),
      ),
    );
  }
}

enum _DateField { deadline, start, end }
