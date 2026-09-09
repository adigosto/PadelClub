import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:padelclub_desktop/core/localization/app_localizations.dart';
import 'package:padelclub_desktop/features/payments/domain/entities/payment.dart';
import 'package:padelclub_desktop/features/payments/domain/repositories/payment_repository.dart';
import 'package:padelclub_desktop/features/payments/domain/usecases/pay_invoice.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});
  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}
class _PaymentsScreenState extends State<PaymentsScreen> {
  List<Payable> _items = const [];
  String _type = 'Order';
  int _page = 1;
  bool _loading = true, _paying = false;
  String? _message;
  @override
  void initState() { super.initState(); Future.microtask(_load); }
  Future<void> _load() async {
    if (!mounted) return;
    setState(() { _loading = true; _message = null; });
    try {
      final items = await LoadPayables(context.read<PaymentRepository>())(_type, _page);
      if (mounted) setState(() => _items = items);
    } catch (error) {
      if (mounted) setState(() => _message = error.toString().replaceFirst('Exception: ', ''));
    } finally { if (mounted) setState(() => _loading = false); }
  }
  Future<void> _pay(Payable payable) async {
    final confirmed = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: Text(context.tr('Confirm payment')),
      content: Text('${payable.description}\n${payable.amount.toStringAsFixed(2)} ${payable.currency.toUpperCase()}'),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: Text(context.tr('Cancel'))), FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(context.tr('Pay')))],
    ));
    if (confirmed != true || !mounted) return;
    setState(() { _paying = true; _message = null; });
    String message;
    try {
      final state = await PayInvoice(context.read<PaymentRepository>(), context.read<PaymentSheetPresenter>())(payable, cancelled: () => !mounted);
      message = state == 'Completed' ? 'Payment confirmed.' : state == 'Pending' ? 'Payment confirmation is pending. You can safely return later; do not create another order.' : 'Payment status: $state';
    } catch (error) { message = error.toString().replaceFirst('Exception: ', ''); }
    if (!mounted) return;
    await _load();
    if (mounted) setState(() { _paying = false; _message = message; });
  }
  @override
  Widget build(BuildContext context) {
    final available = context.read<PaymentSheetPresenter>().available;
    return PopScope(canPop: !_paying, child: Scaffold(
      appBar: AppBar(title: Text(context.tr('Payments'))),
      body: SafeArea(child: ListView(padding: const EdgeInsets.all(20), children: [
        Text(context.tr('Choose an outstanding order, reservation or membership to pay securely.')),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(initialValue: _type, items: ['Order', 'Reservation', 'Membership'].map((t) => DropdownMenuItem(value: t, child: Text(context.tr(t)))).toList(), onChanged: _paying || _loading ? null : (value) { _type = value!; _page = 1; _load(); }),
        if (!available) Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Text(context.tr('Use the Android or iOS app to pay by card.'))),
        if (_loading || _paying) const Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator()),
        if (_message != null) Padding(padding: const EdgeInsets.all(12), child: Text(context.tr(_message!))),
        if (!_loading && _items.isEmpty) Padding(padding: const EdgeInsets.all(16), child: Text(context.tr('No outstanding payments on this page.'))),
        ..._items.map((p) => Card(child: ListTile(title: Text(p.description), subtitle: Text('${p.amount.toStringAsFixed(2)} ${p.currency.toUpperCase()}'), trailing: Tooltip(message: available ? context.tr('Pay securely') : context.tr('Use the mobile app to pay.'), child: FilledButton(onPressed: !available || _paying || _loading ? null : () => _pay(p), child: Text(context.tr('Pay'))))))),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          TextButton(onPressed: _page <= 1 || _loading || _paying ? null : () { _page--; _load(); }, child: Text(context.tr('Previous'))),
          Text('$_page'),
          TextButton(onPressed: _items.length < 50 || _loading || _paying ? null : () { _page++; _load(); }, child: Text(context.tr('Next'))),
        ])
      ])),
    ));
  }
}
