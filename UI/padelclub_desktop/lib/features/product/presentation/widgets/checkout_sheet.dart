import 'package:padelclub_desktop/features/payments/domain/entities/payment.dart';
import 'package:padelclub_desktop/features/payments/presentation/screens/payments_screen.dart';
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:padelclub_desktop/core/localization/app_localizations.dart';
import 'package:padelclub_desktop/core/validation/form_validators.dart';
import 'package:padelclub_desktop/core/widgets/validation_message.dart';
import 'package:padelclub_desktop/features/product/presentation/providers/cart_provider.dart';
import 'package:padelclub_desktop/providers/auth_provider.dart';

class CheckoutSheet extends StatefulWidget {
  const CheckoutSheet({super.key});

  @override
  State<CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends State<CheckoutSheet> {
  final _formKey = GlobalKey<FormState>();
  final _recipient = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _postalCode = TextEditingController();
  final _coupon = TextEditingController();
  final _notes = TextEditingController();
  TextEditingController? _activeTextController;
  String? _error;
  late final int _itemCount;
  late final double _total;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    final cart = context.read<CartProvider>();
    _recipient.text = auth.displayName;
    _phone.text = auth.phoneNumber ?? '';
    _itemCount = cart.itemCount;
    _total = cart.total;
  }

  @override
  void dispose() {
    for (final controller in [
      _recipient,
      _phone,
      _address,
      _city,
      _postalCode,
      _coupon,
      _notes,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    final invalid = _formKey.currentState!.validateGranularly();
    if (invalid.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Scrollable.ensureVisible(
            invalid.first.context,
            alignment: 0.15,
            duration: const Duration(milliseconds: 250),
          );
        }
      });
      return;
    }
    FocusScope.of(context).unfocus();
    final cart = context.read<CartProvider>();
    final number = await cart.checkout(
      recipientName: _recipient.text,
      phoneNumber: _phone.text,
      shippingAddress: _address.text,
      city: _city.text,
      postalCode: _postalCode.text,
      couponCode: _coupon.text,
      notes: _notes.text,
    );
    if (!mounted) return;
    if (number != null) {
      if (context.read<PaymentSheetPresenter>().available) {
        await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PaymentsScreen()));
        if (!mounted) return;
      }
      Navigator.pop(context, number);
    } else {
      setState(
        () => _error =
            cart.checkoutError ??
            context.tr("Your cart is empty. Add an item before ordering."),
      );
    }
  }

  Future<void> _openInMaps() async {
    if (_address.text.trim().length < 5 || _city.text.trim().length < 2) {
      _formKey.currentState!.validate();
      setState(
        () => _error = context.tr(
          "Enter the street address and city before opening Maps.",
        ),
      );
      return;
    }
    final query = [
      _address.text.trim(),
      _postalCode.text.trim(),
      _city.text.trim(),
    ].where((part) => part.isNotEmpty).join(', ');
    final uri = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': query,
    });
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
          mounted) {
        setState(
          () => _error = context.tr(
            "Could not open Maps. Check the address and try again.",
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = context.tr(
            "Could not open Maps. Check the address and try again.",
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final enabled = !cart.isCheckingOut;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr("Checkout"),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              Text(
                context.tr("{p1} items · {p2} KM", {
                  'p1': _itemCount,
                  'p2': context.l10n.number(_total, decimalDigits: 2),
                }),
              ),
              const SizedBox(height: 6),
              Text(
                context.tr(
                  "Complete all fields marked *. Optional fields can be left blank.",
                ),
              ),
              const SizedBox(height: 20),
              _BosnianCharacterStrip(onCharacterPressed: _insertCharacter),
              const SizedBox(height: 12),
              _field(
                _recipient,
                label: context.tr("Recipient name"),
                enabled: enabled,
                icon: Icons.person_outline_rounded,
                keyboardType: TextInputType.text,
                minLength: 2,
                maxLength: 150,
                autofillHints: const [AutofillHints.name],
              ),
              const SizedBox(height: 12),
              _field(
                _phone,
                label: context.tr("Phone number"),
                enabled: enabled,
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                maxLength: 30,
                validator: (value) =>
                    FormValidators.phone(value, l10n: context.l10n),
                hint: '+387 61 123 456',
                autofillHints: const [AutofillHints.telephoneNumber],
              ),
              const SizedBox(height: 12),
              _field(
                _address,
                label: context.tr("Street address"),
                enabled: enabled,
                icon: Icons.location_on_outlined,
                keyboardType: TextInputType.text,
                minLength: 5,
                maxLength: 500,
                autofillHints: const [AutofillHints.streetAddressLine1],
              ),
              const SizedBox(height: 12),
              _field(
                _city,
                label: context.tr("City"),
                enabled: enabled,
                minLength: 2,
                maxLength: 100,
                autofillHints: const [AutofillHints.addressCity],
              ),
              const SizedBox(height: 12),
              _field(
                _postalCode,
                label: context.tr("Postal code"),
                enabled: enabled,
                minLength: 3,
                maxLength: 20,
                hint: '71000',
                autofillHints: const [AutofillHints.postalCode],
              ),
              TextButton.icon(
                onPressed: enabled ? _openInMaps : null,
                icon: const Icon(Icons.map_outlined),
                label: Text(context.tr("Check address in Google Maps")),
              ),
              const SizedBox(height: 4),
              TextFormField(
                controller: _coupon,
                enabled: enabled,
                maxLength: 40,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: context.tr("Coupon code (optional)"),
                  prefixIcon: Icon(Icons.local_offer_outlined),
                ),
                onChanged: (_) {
                  _activeTextController = _coupon;
                  setState(() => _error = null);
                },
              ),
              TextFormField(
                controller: _notes,
                enabled: enabled,
                minLines: 2,
                maxLines: 4,
                maxLength: 1000,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: context.tr("Delivery notes (optional)"),
                ),
                onChanged: (_) {
                  _activeTextController = _notes;
                  setState(() => _error = null);
                },
              ),
              if (_error != null) ValidationMessage(_error!),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: enabled ? _submit : null,
                  icon: enabled
                      ? const Icon(Icons.lock_outline_rounded)
                      : const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                  label: Text(
                    enabled
                        ? context.tr("Place order")
                        : context.tr("Submitting…"),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _insertCharacter(String character) {
    final controller = _activeTextController;
    if (controller == null) return;
    final selection = controller.selection;
    final start = selection.isValid ? selection.start : controller.text.length;
    final end = selection.isValid ? selection.end : start;
    controller.value = controller.value.copyWith(
      text: controller.text.replaceRange(start, end, character),
      selection: TextSelection.collapsed(offset: start + character.length),
      composing: TextRange.empty,
    );
    setState(() => _error = null);
  }

  Widget _field(
    TextEditingController controller, {
    required String label,
    required bool enabled,
    IconData? icon,
    TextInputType keyboardType = TextInputType.text,
    int minLength = 1,
    required int maxLength,
    String? hint,
    List<String>? autofillHints,
    String? Function(String?)? validator,
  }) => TextFormField(
    controller: controller,
    enabled: enabled,
    keyboardType: keyboardType,
    textCapitalization: keyboardType == TextInputType.phone
        ? TextCapitalization.none
        : TextCapitalization.sentences,
    textInputAction: TextInputAction.next,
    autofillHints: autofillHints,
    onTap: () => _activeTextController = controller,
    validator:
        validator ??
        (value) => FormValidators.text(
          value,
          l10n: context.l10n,
          label: label.toLowerCase(),
          minLength: minLength,
          maxLength: maxLength,
        ),
    onChanged: (_) {
      _activeTextController = controller;
      setState(() => _error = null);
    },
    decoration: InputDecoration(
      labelText: '$label *',
      hintText: hint,
      prefixIcon: icon == null ? null : Icon(icon),
    ),
  );
}

class _BosnianCharacterStrip extends StatelessWidget {
  const _BosnianCharacterStrip({required this.onCharacterPressed});

  final ValueChanged<String> onCharacterPressed;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 6,
    runSpacing: 4,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      Text(context.tr("Bosnian letters:")),
      for (final character in [
        'č',
        'ć',
        'đ',
        'š',
        'ž',
        'Č',
        'Ć',
        'Đ',
        'Š',
        'Ž',
      ])
        SizedBox(
          width: 36,
          height: 36,
          child: OutlinedButton(
            key: ValueKey('bosnian-character-$character'),
            onPressed: () => onCharacterPressed(character),
            style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
            child: Text(character),
          ),
        ),
    ],
  );
}
