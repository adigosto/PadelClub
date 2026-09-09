import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import 'package:padelclub_desktop/core/localization/app_localizations.dart';
import 'package:padelclub_desktop/core/theme/app_theme.dart';
import 'package:padelclub_desktop/core/widgets/admin_components.dart';
import 'package:padelclub_desktop/features/operations/domain/entities/provider_readiness.dart';
import 'package:padelclub_desktop/features/operations/presentation/providers/provider_readiness_provider.dart';
import 'package:padelclub_desktop/layouts/master_screen.dart';

/// Read-only administrator view of external-provider configuration shape.
///
/// This is intentionally not a payment form, message sender, delivery retry,
/// or health probe. It lets an examiner distinguish local Mailpit/test setup
/// from a provider configuration without claiming external delivery.
class ProviderReadinessScreen extends StatelessWidget {
  const ProviderReadinessScreen({super.key, this.provider});

  /// Test-only override; production construction uses the live provider.
  final ProviderReadinessProvider? provider;

  @override
  Widget build(BuildContext context) {
    final value = provider;
    if (value != null) {
      return ChangeNotifierProvider<ProviderReadinessProvider>.value(
        value: value,
        child: const _ProviderReadinessContent(),
      );
    }
    return ChangeNotifierProvider<ProviderReadinessProvider>(
      create: (_) => ProviderReadinessProvider.live(),
      child: const _ProviderReadinessContent(),
    );
  }
}

class _ProviderReadinessContent extends StatefulWidget {
  const _ProviderReadinessContent();

  @override
  State<_ProviderReadinessContent> createState() =>
      _ProviderReadinessContentState();
}

class _ProviderReadinessContentState extends State<_ProviderReadinessContent> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ProviderReadinessProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProviderReadinessProvider>();
    return MasterScreen(
      title: context.tr("Provider Readiness"),
      section: AppSection.auditTrail,
      showBackButton: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminPageHeader(
            title: context.tr("Provider Readiness"),
            subtitle: context.tr(
              "Read-only configuration diagnostics for optional Stripe, SMTP, and Firebase integrations.",
            ),
            action: Wrap(
              spacing: PadelSpacing.sm,
              runSpacing: PadelSpacing.sm,
              children: [
                OutlinedButton.icon(
                  onPressed: () => Navigator.maybePop(context),
                  icon: const Icon(Icons.fact_check_outlined, size: 18),
                  label: Text(context.tr("Audit trail")),
                ),
                FilledButton.icon(
                  key: const Key('provider-readiness-refresh-button'),
                  onPressed: provider.isLoading ? null : provider.load,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(context.tr("Refresh")),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: _content(provider)),
        ],
      ),
    );
  }

  Widget _content(ProviderReadinessProvider provider) {
    if (provider.isLoading) {
      return Center(
        child: Semantics(
          label: context.tr("Loading provider readiness"),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (provider.errorMessage != null) {
      return _ProviderReadinessState(
        icon: Icons.cloud_off_rounded,
        title: context.tr("Provider readiness is unavailable"),
        message: provider.errorMessage!,
        actionLabel: context.tr("Try again"),
        onAction: provider.load,
      );
    }
    final readiness = provider.readiness;
    if (readiness == null) {
      return _ProviderReadinessState(
        icon: Icons.settings_ethernet_outlined,
        title: context.tr("No readiness snapshot"),
        message: context.tr(
          "Refresh to request the current server configuration snapshot.",
        ),
        actionLabel: context.tr("Refresh"),
        onAction: provider.load,
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(PadelSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ConfigurationOnlyCaveat(message: readiness.caveat),
          const SizedBox(height: PadelSpacing.lg),
          LayoutBuilder(
            builder: (context, constraints) {
              final cards = [
                _StripeReadinessCard(readiness: readiness.stripe),
                _SimpleReadinessCard(
                  icon: Icons.mark_email_read_outlined,
                  title: 'SMTP email',
                  state: readiness.smtp.state,
                  detail: _smtpDetail(readiness.smtp.state),
                ),
                _SimpleReadinessCard(
                  icon: Icons.notifications_active_outlined,
                  title: 'Firebase push',
                  state: readiness.firebase.state,
                  detail: _firebaseDetail(readiness.firebase.state),
                ),
              ];
              if (constraints.maxWidth < 780) {
                return Column(
                  children: [
                    for (var index = 0; index < cards.length; index++) ...[
                      cards[index],
                      if (index < cards.length - 1)
                        const SizedBox(height: PadelSpacing.md),
                    ],
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var index = 0; index < cards.length; index++) ...[
                    Expanded(child: cards[index]),
                    if (index < cards.length - 1)
                      const SizedBox(width: PadelSpacing.md),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: PadelSpacing.lg),
          const _ReadinessBoundary(),
        ],
      ),
    );
  }
}

class _ConfigurationOnlyCaveat extends StatelessWidget {
  const _ConfigurationOnlyCaveat({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    label: context.tr("Configuration-only readiness caveat: {p1}", {
      'p1': message,
    }),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(PadelSpacing.md),
      decoration: BoxDecoration(
        color: PadelColors.blueSoft,
        borderRadius: BorderRadius.circular(PadelRadii.large),
        border: Border.all(color: const Color(0xFFD3E1FF)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: PadelColors.blue),
          const SizedBox(width: PadelSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF35527C),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _StripeReadinessCard extends StatelessWidget {
  const _StripeReadinessCard({required this.readiness});

  final StripeReadiness readiness;

  @override
  Widget build(BuildContext context) => _ReadinessCard(
    icon: Icons.payments_outlined,
    title: context.tr("Stripe payments"),
    state: readiness.intentState,
    detail: context.tr(_stripeDetail(readiness)),
    children: [
      _ReadinessField(label: context.tr("Key mode"), value: readiness.mode),
      _ReadinessField(
        label: context.tr("Webhook"),
        value: readiness.webhookState,
      ),
      _ReadinessField(label: context.tr("Currency"), value: readiness.currency),
    ],
  );
}

class _SimpleReadinessCard extends StatelessWidget {
  const _SimpleReadinessCard({
    required this.icon,
    required this.title,
    required this.state,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String state;
  final String detail;

  @override
  Widget build(BuildContext context) =>
      _ReadinessCard(icon: icon, title: title, state: state, detail: detail);
}

class _ReadinessCard extends StatelessWidget {
  const _ReadinessCard({
    required this.icon,
    required this.title,
    required this.state,
    required this.detail,
    this.children = const [],
  });

  final IconData icon;
  final String title;
  final String state;
  final String detail;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Semantics(
    label: context.tr("{p1} configuration state: {p2}. {p3}", {
      'p1': context.tr(title),
      'p2': context.tr(state),
      'p3': context.tr(detail),
    }),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(PadelSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(PadelRadii.large),
        border: Border.all(color: PadelColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: PadelColors.blueSoft,
                  borderRadius: BorderRadius.circular(PadelRadii.medium),
                ),
                child: Icon(icon, color: PadelColors.blue),
              ),
              const SizedBox(width: PadelSpacing.sm),
              Expanded(
                child: Text(
                  context.tr(title),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              AdminStatusBadge(label: state, tone: _toneFor(state)),
            ],
          ),
          const SizedBox(height: PadelSpacing.sm),
          Text(
            context.tr(detail),
            style: const TextStyle(
              color: PadelColors.textMuted,
              fontSize: 12,
              height: 1.35,
            ),
          ),
          if (children.isNotEmpty) ...[
            const SizedBox(height: PadelSpacing.sm),
            const Divider(height: 1),
            const SizedBox(height: PadelSpacing.xs),
            ...children,
          ],
        ],
      ),
    ),
  );
}

class _ReadinessField extends StatelessWidget {
  const _ReadinessField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: PadelSpacing.xs),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: PadelColors.textMuted),
          ),
        ),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );
}

class _ReadinessBoundary extends StatelessWidget {
  const _ReadinessBoundary();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(PadelSpacing.md),
    decoration: BoxDecoration(
      color: PadelColors.canvas,
      borderRadius: BorderRadius.circular(PadelRadii.large),
      border: Border.all(color: PadelColors.border),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.visibility_outlined, color: PadelColors.textMuted),
        SizedBox(width: PadelSpacing.sm),
        Expanded(
          child: Text(
            context.tr(
              "No provider secret, host, credential, recipient, payment, or delivery result is shown here. “Configured” is a local configuration shape, not an external connection or a recipient read receipt. Any bounded external rehearsal is a separate default-disabled administrator action with its own confirmation and evidence record.",
            ),
            style: TextStyle(
              color: PadelColors.textMuted,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ),
      ],
    ),
  );
}

class _ProviderReadinessState extends StatelessWidget {
  const _ProviderReadinessState({
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
    child: Semantics(
      liveRegion: true,
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

String _stripeDetail(StripeReadiness readiness) {
  return switch (readiness.intentState) {
    'Configured' =>
      readiness.mode == 'Test'
          ? 'A test-key-shaped value and valid currency are present. No payment was started.'
          : 'A key-shaped value and valid currency are present. No payment was started.',
    'Disabled' => 'No Stripe secret key is configured for this runtime.',
    _ =>
      'The local Stripe configuration has an invalid shape. No provider call was made.',
  };
}

String _smtpDetail(String state) => switch (state) {
  'Mailpit' =>
    'The local Mailpit inbox is selected for development inspection, not external recipient delivery.',
  'Configured' =>
    'SMTP configuration has a valid local shape. No connection or email was sent.',
  'Disabled' => 'SMTP is not configured for this runtime.',
  _ => 'SMTP has an invalid local configuration shape. No connection was made.',
};

String _firebaseDetail(String state) => switch (state) {
  'ServiceAccount' =>
    'A matching service-account-shaped configuration is present. No Firebase request was sent.',
  'AdcRequested' =>
    'Application Default Credentials would be requested when push delivery runs; they were not checked here.',
  'Disabled' => 'Firebase push is not configured for this runtime.',
  _ =>
    'Firebase configuration has an invalid local shape. No push request was sent.',
};

AdminStatusTone _toneFor(String state) => switch (state) {
  'Configured' || 'ServiceAccount' || 'Mailpit' => AdminStatusTone.info,
  'Test' || 'AdcRequested' => AdminStatusTone.warning,
  'Misconfigured' => AdminStatusTone.danger,
  _ => AdminStatusTone.neutral,
};
