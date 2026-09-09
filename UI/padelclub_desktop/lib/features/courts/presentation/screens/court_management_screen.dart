import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import 'package:padelclub_desktop/core/localization/app_localizations.dart';
import 'package:padelclub_desktop/core/theme/app_theme.dart';
import 'package:padelclub_desktop/core/validation/form_validators.dart';
import 'package:padelclub_desktop/core/widgets/admin_components.dart';
import 'package:padelclub_desktop/features/courts/domain/entities/court.dart';
import 'package:padelclub_desktop/features/courts/presentation/providers/court_provider.dart';
import 'package:padelclub_desktop/layouts/master_screen.dart';

class CourtManagementScreen extends StatefulWidget {
  const CourtManagementScreen({super.key});

  @override
  State<CourtManagementScreen> createState() => _CourtManagementScreenState();
}

class _CourtManagementScreenState extends State<CourtManagementScreen> {
  final _searchController = TextEditingController();
  String _filter = 'All';
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<CourtProvider>().loadCourts(),
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
      title: context.tr("Court Management"),
      section: AppSection.courts,
      child: Consumer<CourtProvider>(
        builder: (context, provider, _) {
          final courts = _filtered(provider.courts);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AdminPageHeader(
                title: context.tr("Court Management"),
                subtitle: context.tr(
                  "Manage padel courts, availability, pricing, and maintenance.",
                ),
                action: FilledButton.icon(
                  onPressed: () => _showCourtForm(),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(context.tr("Add Court")),
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
                          [
                                "All",
                                "Available",
                                "Indoor",
                                "Outdoor",
                                "Maintenance",
                              ]
                              .map(
                                (filter) => AdminFilterChip(
                                  label: filter == 'All'
                                      ? context.tr("All Courts")
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
                          hintText: context.tr("Search courts..."),
                          width: 320,
                          onSubmitted: _setQuery,
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _setQuery(_searchController.text),
                          icon: const Icon(Icons.search_rounded, size: 17),
                          label: Text(context.tr("Search")),
                        ),
                        OutlinedButton.icon(
                          onPressed: provider.loadCourts,
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
                  child: AdminTableSurface(child: _content(provider, courts)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _content(CourtProvider provider, List<Court> courts) {
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (provider.errorMessage != null) {
      return _CourtMessage(
        icon: Icons.cloud_off_rounded,
        title: context.tr("Courts are unavailable"),
        message: provider.errorMessage!,
        onRetry: provider.loadCourts,
      );
    }
    if (courts.isEmpty) {
      return _CourtMessage(
        icon: Icons.stadium_outlined,
        title: context.tr("No courts found"),
        message: context.tr("Adjust the search or court filter."),
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
              dataRowMinHeight: 70,
              dataRowMaxHeight: 80,
              columnSpacing: 36,
              columns: [
                DataColumn(label: Text(context.tr("COURT"))),
                DataColumn(label: Text(context.tr("TYPE"))),
                DataColumn(label: Text(context.tr("RATE"))),
                DataColumn(label: Text(context.tr("STATUS"))),
                DataColumn(label: Text(context.tr("ACTIONS"))),
              ],
              rows: courts.map(_row).toList(growable: false),
            ),
          ),
        ),
      ),
    );
  }

  DataRow _row(Court court) {
    return DataRow(
      cells: [
        DataCell(
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: court.isIndoor
                      ? PadelColors.blueSoft
                      : PadelColors.greenSoft,
                  borderRadius: BorderRadius.circular(PadelRadii.medium),
                ),
                child: Icon(
                  court.isIndoor
                      ? Icons.stadium_rounded
                      : Icons.wb_sunny_outlined,
                  color: court.isIndoor
                      ? PadelColors.blue
                      : PadelColors.greenDark,
                ),
              ),
              const SizedBox(width: PadelSpacing.sm),
              SizedBox(
                width: 280,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      court.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      context.tr("{p1} · Up to {p2} players", {
                        'p1': court.description,
                        'p2': court.maxPlayers,
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
            ],
          ),
        ),
        DataCell(
          AdminStatusBadge(
            label: court.isIndoor
                ? context.tr("Indoor")
                : context.tr("Outdoor"),
            tone: court.isIndoor
                ? AdminStatusTone.info
                : AdminStatusTone.success,
          ),
        ),
        DataCell(
          Text(
            '${context.l10n.number(court.hourlyRate, decimalDigits: 2)} KM/h',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        DataCell(
          AdminStatusBadge(
            label: court.isActive
                ? context.tr("Available")
                : context.tr("Maintenance"),
            tone: court.isActive
                ? AdminStatusTone.success
                : AdminStatusTone.warning,
            showDot: true,
          ),
        ),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AdminActionButton(
                icon: Icons.edit_outlined,
                tooltip: context.tr("Edit court"),
                onPressed: () => _showCourtForm(court),
              ),
              const SizedBox(width: PadelSpacing.xs),
              AdminActionButton(
                icon: Icons.delete_outline_rounded,
                tooltip: context.tr("Delete court"),
                onPressed: () => _confirmDelete(court),
                destructive: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Court> _filtered(List<Court> courts) {
    return courts
        .where((court) {
          final matchesFilter = switch (_filter) {
            'Available' => court.isActive,
            'Indoor' => court.isIndoor,
            'Outdoor' => !court.isIndoor,
            'Maintenance' => !court.isActive,
            _ => true,
          };
          final haystack =
              '${court.name} ${court.description} '
                      '${court.isIndoor ? 'indoor' : 'outdoor'}'
                  .toLowerCase();
          return matchesFilter && (_query.isEmpty || haystack.contains(_query));
        })
        .toList(growable: false);
  }

  void _setQuery(String value) {
    setState(() => _query = value.trim().toLowerCase());
  }

  Future<void> _showCourtForm([Court? court]) async {
    final result = await showDialog<_CourtDraft>(
      context: context,
      builder: (_) => _CourtFormDialog(court: court),
    );
    if (result == null || !mounted) return;
    final provider = context.read<CourtProvider>();
    final saved = await provider.saveCourt(
      id: court?.id,
      name: result.name,
      description: result.description,
      isIndoor: result.isIndoor,
      isActive: result.isActive,
      hourlyRate: result.hourlyRate,
      maxPlayers: result.maxPlayers,
    );
    if (!mounted) return;
    _notice(
      saved
          ? context.tr("Court saved.")
          : provider.errorMessage ?? context.tr("Court could not be saved."),
      isError: !saved,
    );
  }

  Future<void> _confirmDelete(Court court) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr("Delete court?")),
        content: Text(
          context.tr(
            "Delete {p1}? Existing reservation history may prevent this.",
            {'p1': court.name},
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr("Keep court")),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.tr("Delete")),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final provider = context.read<CourtProvider>();
    final deleted = await provider.deleteCourt(court.id);
    if (!mounted) return;
    _notice(
      deleted
          ? context.tr("Court deleted.")
          : provider.errorMessage ?? context.tr("Court could not be deleted."),
      isError: !deleted,
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

class _CourtDraft {
  const _CourtDraft({
    required this.name,
    required this.description,
    required this.isIndoor,
    required this.isActive,
    required this.hourlyRate,
    required this.maxPlayers,
  });

  final String name;
  final String description;
  final bool isIndoor;
  final bool isActive;
  final double hourlyRate;
  final int maxPlayers;
}

class _CourtFormDialog extends StatefulWidget {
  const _CourtFormDialog({this.court});

  final Court? court;

  @override
  State<_CourtFormDialog> createState() => _CourtFormDialogState();
}

class _CourtFormDialogState extends State<_CourtFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _rate;
  late final TextEditingController _players;
  late bool _isIndoor;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    final court = widget.court;
    _name = TextEditingController(text: court?.name ?? '');
    _description = TextEditingController(text: court?.description ?? '');
    _rate = TextEditingController(
      text: court?.hourlyRate.toStringAsFixed(2) ?? '',
    );
    _players = TextEditingController(text: '${court?.maxPlayers ?? 4}');
    _isIndoor = court?.isIndoor ?? true;
    _isActive = court?.isActive ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _rate.dispose();
    _players.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.court == null
            ? context.tr("Add court")
            : context.tr("Edit court"),
      ),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _name,
                  decoration: InputDecoration(
                    labelText: context.tr("Court name"),
                  ),
                  validator: (value) => FormValidators.text(
                    value,
                    l10n: context.l10n,
                    label: 'a court name',
                    maxLength: 100,
                  ),
                ),
                const SizedBox(height: PadelSpacing.sm),
                TextFormField(
                  controller: _description,
                  decoration: InputDecoration(
                    labelText: context.tr("Description"),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: PadelSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _rate,
                        decoration: InputDecoration(
                          labelText: context.tr("Hourly rate (KM)"),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) => FormValidators.decimal(
                          value,
                          l10n: context.l10n,
                          label: 'an hourly rate',
                        ),
                      ),
                    ),
                    const SizedBox(width: PadelSpacing.sm),
                    Expanded(
                      child: TextFormField(
                        controller: _players,
                        decoration: InputDecoration(
                          labelText: context.tr("Max players"),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) => FormValidators.integer(
                          value,
                          l10n: context.l10n,
                          label: 'the maximum players',
                        ),
                      ),
                    ),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.tr("Indoor court")),
                  value: _isIndoor,
                  onChanged: (value) => setState(() => _isIndoor = value),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.tr("Available for booking")),
                  value: _isActive,
                  onChanged: (value) => setState(() => _isActive = value),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.tr("Cancel")),
        ),
        FilledButton(onPressed: _submit, child: Text(context.tr("Save court"))),
      ],
    );
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.pop(
      context,
      _CourtDraft(
        name: _name.text.trim(),
        description: _description.text.trim(),
        isIndoor: _isIndoor,
        isActive: _isActive,
        hourlyRate: FormValidators.decimalValue(_rate.text)!,
        maxPlayers: int.parse(_players.text),
      ),
    );
  }
}

class _CourtMessage extends StatelessWidget {
  const _CourtMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.onRetry,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: PadelColors.blue),
          const SizedBox(height: PadelSpacing.sm),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: PadelSpacing.xs),
          Text(message, style: Theme.of(context).textTheme.bodySmall),
          if (onRetry != null) ...[
            const SizedBox(height: PadelSpacing.md),
            FilledButton(
              onPressed: onRetry,
              child: Text(context.tr("Try again")),
            ),
          ],
        ],
      ),
    );
  }
}
