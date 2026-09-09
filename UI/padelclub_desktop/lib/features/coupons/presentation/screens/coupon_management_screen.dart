import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:provider/provider.dart';

import 'package:padelclub_desktop/core/localization/app_localizations.dart';
import 'package:padelclub_desktop/core/theme/app_theme.dart';
import 'package:padelclub_desktop/core/widgets/admin_components.dart';
import 'package:padelclub_desktop/features/coupons/domain/entities/admin_coupon.dart';
import 'package:padelclub_desktop/features/coupons/presentation/providers/coupon_management_provider.dart';
import 'package:padelclub_desktop/layouts/master_screen.dart';

/// Administrator UI for the existing `/Commerce/coupons` contract.
///
/// It only displays the last server snapshot and refetches it after each
/// create/edit action. Redemption and checkout eligibility remain backend
/// authority.
class CouponManagementScreen extends StatelessWidget {
  const CouponManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<CouponManagementProvider>(
      create: (_) => CouponManagementProvider.live(),
      child: const _CouponManagementContent(),
    );
  }
}

class _CouponManagementContent extends StatefulWidget {
  const _CouponManagementContent();

  @override
  State<_CouponManagementContent> createState() =>
      _CouponManagementContentState();
}

class _CouponManagementContentState extends State<_CouponManagementContent> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<CouponManagementProvider>().load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CouponManagementProvider>();
    return MasterScreen(
      title: context.tr("Coupon Management"),
      section: AppSection.products,
      showBackButton: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminPageHeader(
            title: context.tr("Coupon Management"),
            subtitle: context.tr(
              "Create and maintain checkout discount rules. Usage and validity are refreshed from the server after every change.",
            ),
            action: Wrap(
              spacing: PadelSpacing.sm,
              runSpacing: PadelSpacing.sm,
              children: [
                OutlinedButton.icon(
                  onPressed: provider.isSaving
                      ? null
                      : () => Navigator.maybePop(context),
                  icon: const Icon(Icons.inventory_2_outlined, size: 18),
                  label: Text(context.tr("Products")),
                ),
                FilledButton.icon(
                  onPressed: provider.isSaving ? null : _createCoupon,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(context.tr("Create coupon")),
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
            child: Wrap(
              spacing: PadelSpacing.sm,
              runSpacing: PadelSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  context.tr("Server coupon snapshot"),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  context.tr("{p1} coupon{p2}", {
                    'p1': provider.coupons.length,
                    'p2': provider.coupons.length == 1 ? '' : 's',
                  }),
                  style: const TextStyle(color: PadelColors.textMuted),
                ),
                OutlinedButton.icon(
                  onPressed: provider.isLoading || provider.isSaving
                      ? null
                      : () => provider.load(),
                  icon: const Icon(Icons.refresh_rounded, size: 17),
                  label: Text(context.tr("Refresh")),
                ),
                if (provider.isSaving)
                  Semantics(
                    label: context.tr(
                      "Saving coupon and refreshing server snapshot",
                    ),
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                PadelSpacing.lg,
                PadelSpacing.xs,
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

  Widget _content(CouponManagementProvider provider) {
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (provider.errorMessage != null) {
      return _CouponMessage(
        icon: Icons.cloud_off_rounded,
        title: context.tr("Coupons are unavailable"),
        message: provider.errorMessage!,
        actionLabel: context.tr("Try again"),
        onAction: provider.load,
      );
    }
    if (provider.coupons.isEmpty) {
      return _CouponMessage(
        icon: Icons.local_offer_outlined,
        title: context.tr("No coupons configured"),
        message: context.tr(
          "Create a coupon to make an administrator-managed discount available at checkout.",
        ),
        actionLabel: context.tr("Create coupon"),
        onAction: _createCoupon,
      );
    }

    final nowUtc = DateTime.now().toUtc();
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(PadelColors.canvas),
              dataRowMinHeight: 82,
              dataRowMaxHeight: 96,
              columnSpacing: 30,
              columns: [
                DataColumn(label: Text(context.tr("CODE"))),
                DataColumn(label: Text(context.tr("DISCOUNT RULE"))),
                DataColumn(label: Text(context.tr("VALIDITY (UTC)"))),
                DataColumn(label: Text(context.tr("USAGE"))),
                DataColumn(label: Text(context.tr("STATUS"))),
                DataColumn(label: Text(context.tr("ACTIONS"))),
              ],
              rows: provider.coupons
                  .map((coupon) => _row(coupon, nowUtc, provider.isSaving))
                  .toList(growable: false),
            ),
          ),
        ),
      ),
    );
  }

  DataRow _row(AdminCoupon coupon, DateTime nowUtc, bool isSaving) {
    final status = coupon.displayStatusAt(nowUtc);
    return DataRow(
      cells: [
        DataCell(
          Semantics(
            label: context.tr("Coupon code {p1}", {'p1': coupon.code}),
            child: Text(
              coupon.code,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
        DataCell(
          SizedBox(
            width: 190,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _discountLabel(context, coupon),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  _ruleDetails(context, coupon),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: PadelColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
        DataCell(
          SizedBox(
            width: 170,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr("From {p1}", {'p1': _utcDate(coupon.validFrom)}),
                ),
                const SizedBox(height: 3),
                Text(
                  context.tr("Until {p1}", {'p1': _utcDate(coupon.validUntil)}),
                  style: const TextStyle(
                    fontSize: 11,
                    color: PadelColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
        DataCell(
          SizedBox(
            width: 132,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_usageLabel(context, coupon)),
                const SizedBox(height: 3),
                Text(
                  context.tr("Per player: {p1}", {'p1': coupon.perUserLimit}),
                  style: const TextStyle(
                    fontSize: 11,
                    color: PadelColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
        DataCell(
          AdminStatusBadge(
            label: status.label,
            tone: _statusTone(status),
            showDot: true,
          ),
        ),
        DataCell(
          AdminActionButton(
            icon: Icons.edit_outlined,
            tooltip: context.tr("Edit coupon {p1}", {'p1': coupon.code}),
            onPressed: isSaving ? null : () => _editCoupon(coupon),
          ),
        ),
      ],
    );
  }

  Future<void> _createCoupon() => _openEditor();

  Future<void> _editCoupon(AdminCoupon coupon) => _openEditor(coupon: coupon);

  Future<void> _openEditor({AdminCoupon? coupon}) async {
    final draft = await showDialog<CouponDraft>(
      context: context,
      builder: (_) => _CouponEditorDialog(coupon: coupon),
    );
    if (draft == null || !mounted) return;

    final provider = context.read<CouponManagementProvider>();
    final saved = coupon == null
        ? await provider.create(draft)
        : await provider.update(couponId: coupon.id, draft: draft);
    if (!mounted) return;
    _notice(
      saved
          ? provider.lastOperationMessage ?? context.tr("Coupon saved.")
          : provider.errorMessage ??
                context.tr("The coupon could not be saved."),
      isError: !saved,
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

class _CouponEditorDialog extends StatefulWidget {
  const _CouponEditorDialog({this.coupon});

  final AdminCoupon? coupon;

  @override
  State<_CouponEditorDialog> createState() => _CouponEditorDialogState();
}

class _CouponEditorDialogState extends State<_CouponEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _code;
  late final TextEditingController _value;
  late final TextEditingController _minimumOrderAmount;
  late final TextEditingController _maximumDiscount;
  late final TextEditingController _usageLimit;
  late final TextEditingController _perUserLimit;
  late CouponDiscountType _discountType;
  late DateTime _validFrom;
  late DateTime _validUntil;
  late bool _isActive;
  String? _dateError;

  bool get _isEditing => widget.coupon != null;

  @override
  void initState() {
    super.initState();
    final coupon = widget.coupon;
    final now = DateTime.now().toUtc();
    final startOfToday = DateTime.utc(now.year, now.month, now.day);
    _code = TextEditingController(text: coupon?.code ?? '');
    _value = TextEditingController(text: _number(coupon?.value));
    _minimumOrderAmount = TextEditingController(
      text: _number(coupon?.minimumOrderAmount),
    );
    _maximumDiscount = TextEditingController(
      text: _number(coupon?.maximumDiscount),
    );
    _usageLimit = TextEditingController(
      text: coupon?.usageLimit?.toString() ?? '',
    );
    _perUserLimit = TextEditingController(
      text: (coupon?.perUserLimit ?? 1).toString(),
    );
    _discountType = coupon?.discountType ?? CouponDiscountType.percentage;
    _validFrom = coupon?.validFrom.toUtc() ?? startOfToday;
    _validUntil =
        coupon?.validUntil.toUtc() ??
        startOfToday.add(const Duration(days: 30));
    _isActive = coupon?.isActive ?? true;
  }

  @override
  void dispose() {
    _code.dispose();
    _value.dispose();
    _minimumOrderAmount.dispose();
    _maximumDiscount.dispose();
    _usageLimit.dispose();
    _perUserLimit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        _isEditing ? context.tr("Edit coupon") : context.tr("Create coupon"),
      ),
      content: SizedBox(
        width: 660,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr(
                    "All limits and dates are submitted to the server for final validation.",
                  ),
                  style: TextStyle(color: PadelColors.textMuted),
                ),
                const SizedBox(height: PadelSpacing.md),
                TextFormField(
                  controller: _code,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 40,
                  decoration: InputDecoration(
                    labelText: context.tr("Coupon code"),
                    hintText: context.tr("Example: CLUB10"),
                  ),
                  validator: (value) {
                    final length = value?.trim().length ?? 0;
                    if (length < 3 || length > 40) {
                      return context.tr(
                        "Use a code between 3 and 40 characters.",
                      );
                    }
                    return null;
                  },
                ),
                const SizedBox(height: PadelSpacing.sm),
                DropdownButtonFormField<CouponDiscountType>(
                  initialValue: _discountType,
                  decoration: InputDecoration(
                    labelText: context.tr("Discount type"),
                  ),
                  items: CouponDiscountType.values
                      .map(
                        (type) => DropdownMenuItem(
                          value: type,
                          child: Text(context.tr(type.label)),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value != null) setState(() => _discountType = value);
                  },
                ),
                const SizedBox(height: PadelSpacing.sm),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final stacked = constraints.maxWidth < 500;
                    final fields = [
                      _decimalField(
                        controller: _value,
                        label: _discountType == CouponDiscountType.percentage
                            ? 'Discount percentage'
                            : 'Discount amount (KM)',
                        validator: (parsed) {
                          if (parsed == null || parsed <= 0) {
                            return context.tr(
                              "Enter a value greater than zero.",
                            );
                          }
                          if (_discountType == CouponDiscountType.percentage &&
                              parsed > 100) {
                            return context.tr("Percentage cannot exceed 100.");
                          }
                          return null;
                        },
                      ),
                      _decimalField(
                        controller: _minimumOrderAmount,
                        label: 'Minimum order (KM)',
                        validator: (parsed) => parsed == null || parsed < 0
                            ? context.tr("Enter zero or a positive amount.")
                            : null,
                      ),
                    ];
                    if (stacked) {
                      return Column(
                        children: [
                          fields.first,
                          const SizedBox(height: PadelSpacing.sm),
                          fields.last,
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: fields.first),
                        const SizedBox(width: PadelSpacing.sm),
                        Expanded(child: fields.last),
                      ],
                    );
                  },
                ),
                const SizedBox(height: PadelSpacing.sm),
                _decimalField(
                  controller: _maximumDiscount,
                  label: context.tr("Maximum discount (KM, optional)"),
                  validator: (parsed) {
                    if (_maximumDiscount.text.trim().isEmpty) return null;
                    return parsed == null || parsed <= 0
                        ? context.tr(
                            "Enter a positive cap or leave this blank.",
                          )
                        : null;
                  },
                ),
                const SizedBox(height: PadelSpacing.md),
                Text(
                  context.tr("Validity window (UTC)"),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: PadelSpacing.xs),
                Text(
                  context.tr(
                    "A selected calendar day is sent as 00:00 UTC. “Until” must be later than “From”.",
                  ),
                  style: TextStyle(fontSize: 12, color: PadelColors.textMuted),
                ),
                const SizedBox(height: PadelSpacing.sm),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final start = _dateButton(
                      label: context.tr("Valid from"),
                      value: _validFrom,
                      onPressed: () => _pickDate(isStart: true),
                    );
                    final end = _dateButton(
                      label: context.tr("Valid until"),
                      value: _validUntil,
                      onPressed: () => _pickDate(isStart: false),
                    );
                    if (constraints.maxWidth < 500) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          start,
                          const SizedBox(height: PadelSpacing.sm),
                          end,
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: start),
                        const SizedBox(width: PadelSpacing.sm),
                        Expanded(child: end),
                      ],
                    );
                  },
                ),
                if (_dateError != null) ...[
                  const SizedBox(height: PadelSpacing.xs),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _dateError!,
                      style: const TextStyle(
                        color: PadelColors.danger,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: PadelSpacing.md),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final usage = _wholeNumberField(
                      controller: _usageLimit,
                      label: context.tr("Overall usage limit (optional)"),
                      hint: context.tr("Leave blank for no overall cap"),
                      allowBlank: true,
                    );
                    final perUser = _wholeNumberField(
                      controller: _perUserLimit,
                      label: context.tr("Per-player limit"),
                      hint: context.tr("At least 1"),
                    );
                    if (constraints.maxWidth < 500) {
                      return Column(
                        children: [
                          usage,
                          const SizedBox(height: PadelSpacing.sm),
                          perUser,
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: usage),
                        const SizedBox(width: PadelSpacing.sm),
                        Expanded(child: perUser),
                      ],
                    );
                  },
                ),
                const SizedBox(height: PadelSpacing.sm),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _isActive,
                  onChanged: (value) =>
                      setState(() => _isActive = value ?? false),
                  title: Text(context.tr("Enable this coupon")),
                  subtitle: Text(
                    context.tr(
                      "Disabling preserves the coupon record but prevents its use at checkout.",
                    ),
                  ),
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
        FilledButton(
          onPressed: _submit,
          child: Text(
            _isEditing
                ? context.tr("Save changes")
                : context.tr("Create coupon"),
          ),
        ),
      ],
    );
  }

  Widget _decimalField({
    required TextEditingController controller,
    required String label,
    required String? Function(double? parsed) validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      decoration: InputDecoration(labelText: label),
      validator: (value) => validator(_decimal(value)),
    );
  }

  Widget _wholeNumberField({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool allowBlank = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(labelText: label, hintText: hint),
      validator: (value) {
        final trimmed = value?.trim() ?? '';
        if (allowBlank && trimmed.isEmpty) return null;
        final parsed = int.tryParse(trimmed);
        return parsed == null || parsed < 1
            ? context.tr("Enter a whole number of at least 1.")
            : null;
      },
    );
  }

  Widget _dateButton({
    required String label,
    required DateTime value,
    required VoidCallback onPressed,
  }) {
    final utcValue = value.toUtc();
    final description = '$label ${_utcDate(utcValue)}';
    return Semantics(
      button: true,
      label: context.tr("Select {p1}", {'p1': description}),
      child: OutlinedButton(
        onPressed: onPressed,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 3),
              Text(
                _utcDate(utcValue),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate({required bool isStart}) async {
    final current = isStart ? _validFrom : _validUntil;
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.utc(current.year, current.month, current.day),
      firstDate: DateTime.utc(2020),
      lastDate: DateTime.utc(2100),
      helpText: isStart
          ? context.tr("Select valid from date (UTC)")
          : context.tr("Select valid until date (UTC)"),
    );
    if (picked == null || !mounted) return;
    setState(() {
      final selected = DateTime.utc(picked.year, picked.month, picked.day);
      if (isStart) {
        _validFrom = selected;
      } else {
        _validUntil = selected;
      }
      _dateError = null;
    });
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) return;
    if (!_validUntil.isAfter(_validFrom)) {
      setState(() {
        _dateError = context.tr("Valid until must be later than valid from.");
      });
      return;
    }
    Navigator.pop(
      context,
      CouponDraft(
        code: _code.text.trim(),
        discountType: _discountType,
        value: _decimal(_value.text)!,
        minimumOrderAmount: _decimal(_minimumOrderAmount.text)!,
        maximumDiscount: _maximumDiscount.text.trim().isEmpty
            ? null
            : _decimal(_maximumDiscount.text),
        validFrom: _validFrom,
        validUntil: _validUntil,
        usageLimit: _usageLimit.text.trim().isEmpty
            ? null
            : int.parse(_usageLimit.text.trim()),
        perUserLimit: int.parse(_perUserLimit.text.trim()),
        isActive: _isActive,
      ),
    );
  }

  double? _decimal(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    return double.tryParse(trimmed.replaceAll(',', '.'));
  }

  static String _number(double? value) {
    if (value == null) return '';
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toString();
  }
}

class _CouponMessage extends StatelessWidget {
  const _CouponMessage({
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
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Center(
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
              const SizedBox(height: PadelSpacing.md),
              FilledButton(onPressed: onAction, child: Text(actionLabel)),
            ],
          ),
        ),
      ),
    );
  }
}

String _discountLabel(BuildContext context, AdminCoupon coupon) {
  final value = coupon.value == coupon.value.roundToDouble()
      ? coupon.value.toInt().toString()
      : coupon.value.toStringAsFixed(2);
  return coupon.discountType == CouponDiscountType.percentage
      ? context.tr("{p1}% off", {'p1': value})
      : context.tr("{p1} KM off", {'p1': value});
}

String _ruleDetails(BuildContext context, AdminCoupon coupon) {
  final parts = <String>[
    'Min. order ${context.l10n.number(coupon.minimumOrderAmount, decimalDigits: 2)} KM',
  ];
  if (coupon.maximumDiscount != null) {
    parts.add(
      context.tr("Cap {p1} KM", {
        'p1': context.l10n.number(coupon.maximumDiscount!, decimalDigits: 2),
      }),
    );
  }
  return parts.join(' | ');
}

String _usageLabel(BuildContext context, AdminCoupon coupon) =>
    coupon.usageLimit == null
    ? context.tr("{p1} used | no cap", {'p1': coupon.usageCount})
    : context.tr("{p1} / {p2} used", {
        'p1': coupon.usageCount,
        'p2': coupon.usageLimit,
      });

String _utcDate(DateTime value) {
  final utc = value.toUtc();
  final month = utc.month.toString().padLeft(2, '0');
  final day = utc.day.toString().padLeft(2, '0');
  return '${utc.year}-$month-$day UTC';
}

AdminStatusTone _statusTone(CouponDisplayStatus status) => switch (status) {
  CouponDisplayStatus.available => AdminStatusTone.success,
  CouponDisplayStatus.scheduled => AdminStatusTone.info,
  CouponDisplayStatus.inactive => AdminStatusTone.neutral,
  CouponDisplayStatus.expired ||
  CouponDisplayStatus.usageLimitReached => AdminStatusTone.warning,
};
