import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:padelclub_desktop/features/recommendation_evaluation/presentation/providers/recommendation_operational_readiness_provider.dart';

/// Administrator-facing preflight for the two distinct real-world evidence
/// tracks: operational cohort collection and descriptive online monitoring.
class RecommendationOperationalReadinessPanel extends StatefulWidget {
  const RecommendationOperationalReadinessPanel({super.key});

  @override
  State<RecommendationOperationalReadinessPanel> createState() =>
      _RecommendationOperationalReadinessPanelState();
}

class _RecommendationOperationalReadinessPanelState
    extends State<RecommendationOperationalReadinessPanel> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RecommendationOperationalReadinessProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context
        .watch<RecommendationOperationalReadinessProvider>();
    final cohort = provider.cohort;
    final impact = provider.impact;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.fact_check_outlined,
                  color: Color(0xFF1F7A63),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Operational recommendation readiness',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Live aggregate collection and mature online telemetry. Neither card is an offline quality score or causal lift result.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF667085)),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Refresh readiness',
                onPressed: provider.isLoading ? null : provider.load,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          if (provider.isLoading && cohort == null && impact == null) ...[
            const SizedBox(height: 20),
            const Center(child: CircularProgressIndicator()),
          ] else if (provider.errorMessage != null) ...[
            const SizedBox(height: 16),
            _Notice(
              title: 'Readiness could not be loaded',
              message: provider.errorMessage!,
              color: const Color(0xFF9C3E32),
              background: const Color(0xFFFFF1EF),
            ),
          ] else if (cohort != null && impact != null) ...[
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 720;
                final cards = [
                  Expanded(child: _CohortCard(cohort: cohort)),
                  Expanded(child: _ImpactCard(impact: impact)),
                ];
                return compact
                    ? Column(
                        children: [
                          _CohortCard(cohort: cohort),
                          const SizedBox(height: 12),
                          _ImpactCard(impact: impact),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          cards[0],
                          const SizedBox(width: 12),
                          cards[1],
                        ],
                      );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _CohortCard extends StatelessWidget {
  const _CohortCard({required this.cohort});

  final RecommendationCohortReadinessSummary cohort;

  @override
  Widget build(BuildContext context) {
    final ready = cohort.isReadyForWindowValidation;
    final color = ready ? const Color(0xFF1F7A63) : const Color(0xFF7A5415);
    final background = ready
        ? const Color(0xFFE8F4EF)
        : const Color(0xFFFFF8E8);
    return _CardShell(
      title: 'Customer cohort collection',
      badge: cohort.readinessState,
      color: color,
      background: background,
      facts: [
        ('Delivered', cohort.eligibleDeliveredOrders),
        ('Return-matured', cohort.maturedEligibleDeliveredOrders),
        ('Customers', cohort.eligibleDistinctCustomers),
        ('Retained signals', cohort.eligibleRetainedPurchaseSignals),
      ],
      message: cohort.summary,
      footer: cohort.nextActions.isEmpty
          ? 'Collection preflight has no immediate action.'
          : cohort.nextActions.first,
    );
  }
}

class _ImpactCard extends StatelessWidget {
  const _ImpactCard({required this.impact});

  final RecommendationImpactSummary impact;

  @override
  Widget build(BuildContext context) {
    final mature = impact.isMature;
    final color = mature ? const Color(0xFF1F7A63) : const Color(0xFF2558B5);
    final background = mature
        ? const Color(0xFFE8F4EF)
        : const Color(0xFFEAF1FF);
    return _CardShell(
      title: 'Online interaction monitoring',
      badge: impact.evidenceTier,
      color: color,
      background: background,
      facts: [
        ('Exposures', impact.exposures),
        ('Players', impact.distinctUsers),
        ('Clicks', impact.clickedExposures),
        ('Delivered orders', impact.attributedDeliveredOrders),
      ],
      message:
          'CTR ${_percent(impact.clickThroughRate)} · delivered conversion ${_percent(impact.deliveredConversionRate)} · ${impact.attributedCheckouts} attributed checkout(s).',
      footer: impact.unmetRequirements.isEmpty
          ? 'Descriptive telemetry is mature; it still has no randomized control group.'
          : impact.unmetRequirements.first,
    );
  }
}

class _CardShell extends StatelessWidget {
  const _CardShell({
    required this.title,
    required this.badge,
    required this.color,
    required this.background,
    required this.facts,
    required this.message,
    required this.footer,
  });

  final String title;
  final String badge;
  final Color color;
  final Color background;
  final List<(String, int)> facts;
  final String message;
  final String footer;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(color: color, fontWeight: FontWeight.w900),
              ),
            ),
            _Badge(label: badge, color: color),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: facts
              .map(
                (fact) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${fact.$2}',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(fact.$1, style: TextStyle(color: color, fontSize: 11)),
                  ],
                ),
              )
              .toList(growable: false),
        ),
        const SizedBox(height: 10),
        Text(message, style: TextStyle(color: color, height: 1.35)),
        const SizedBox(height: 8),
        Text(footer, style: TextStyle(color: color, fontSize: 12, height: 1.3)),
      ],
    ),
  );
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      border: Border.all(color: color.withValues(alpha: 0.35)),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800),
    ),
  );
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.title,
    required this.message,
    required this.color,
    required this.background,
  });

  final String title;
  final String message;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(color: color, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 3),
        Text(message, style: TextStyle(color: color)),
      ],
    ),
  );
}

String _percent(double? value) =>
    value == null ? '—' : '${(value * 100).toStringAsFixed(1)}%';
