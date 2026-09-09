import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:padelclub_desktop/features/recommendation_evaluation/domain/entities/recommendation_evaluation.dart';
import 'package:padelclub_desktop/features/recommendation_evaluation/presentation/providers/recommendation_evaluation_provider.dart';

/// Administrator-facing evidence for the historical recommender backtest.
///
/// This panel intentionally renders unavailable metric values as a data
/// limitation. It never replaces them with zeroes or a synthetic score.
class RecommendationEvaluationEvidencePanel extends StatefulWidget {
  const RecommendationEvaluationEvidencePanel({super.key});

  @override
  State<RecommendationEvaluationEvidencePanel> createState() =>
      _RecommendationEvaluationEvidencePanelState();
}

class _RecommendationEvaluationEvidencePanelState
    extends State<RecommendationEvaluationEvidencePanel> {
  late DateTime _cutoffUtc;
  late DateTime _endUtc;
  int _k = 6;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now().toUtc();
    final today = DateTime.utc(now.year, now.month, now.day);
    // Leave a maturation buffer for returns, then start with the minimum
    // meaningful holdout duration rather than an arbitrary seven-day slice.
    _endUtc = today.subtract(const Duration(days: 30));
    _cutoffUtc = _endUtc.subtract(const Duration(days: 28));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
      context.read<RecommendationEvaluationProvider>().loadLatestRun();
    });
  }

  Future<void> _load() {
    return context.read<RecommendationEvaluationProvider>().load(
      cutoffUtc: _cutoffUtc,
      endUtc: _endUtc,
      k: _k,
    );
  }

  Future<void> _pickDate({required bool isCutoff}) async {
    final current = isCutoff ? _cutoffUtc : _endUtc;
    final latest = DateTime.now().toUtc();
    final latestDate = DateTime.utc(latest.year, latest.month, latest.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: current.isAfter(latestDate) ? latestDate : current,
      firstDate: DateTime.utc(2020),
      lastDate: latestDate,
      helpText: isCutoff
          ? 'Select evaluation cutoff (UTC)'
          : 'Select evaluation end (UTC)',
    );
    if (picked == null || !mounted) return;

    final selectedUtc = DateTime.utc(picked.year, picked.month, picked.day);
    setState(() {
      if (isCutoff) {
        _cutoffUtc = selectedUtc;
      } else {
        _endUtc = selectedUtc;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RecommendationEvaluationProvider>();
    final evaluation = provider.evaluation;
    final theme = Theme.of(context);

    return Semantics(
      label: 'Recommendation evaluation evidence',
      child: Container(
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF1FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.analytics_outlined,
                    color: Color(0xFF2F64E7),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recommendation evaluation evidence',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Run the administrator-only historical backtest with explicit UTC bounds; the end is exclusive and the default holds out a matured 28-day window.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF667085),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 660;
                final controls = [
                  _UtcDateSelector(
                    label: 'Cutoff UTC',
                    value: _cutoffUtc,
                    onPressed: provider.isLoading
                        ? null
                        : () => _pickDate(isCutoff: true),
                  ),
                  _UtcDateSelector(
                    label: 'End UTC',
                    value: _endUtc,
                    onPressed: provider.isLoading
                        ? null
                        : () => _pickDate(isCutoff: false),
                  ),
                  SizedBox(
                    width: compact ? double.infinity : 130,
                    child: DropdownButtonFormField<int>(
                      initialValue: _k,
                      decoration: const InputDecoration(
                        labelText: 'K',
                        isDense: true,
                      ),
                      items: List.generate(
                        12,
                        (index) => DropdownMenuItem(
                          value: index + 1,
                          child: Text('${index + 1}'),
                        ),
                      ),
                      onChanged: provider.isLoading
                          ? null
                          : (value) {
                              if (value == null) return;
                              setState(() => _k = value);
                            },
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: provider.isLoading ? null : _load,
                    icon: provider.isLoading
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.play_arrow_rounded),
                    label: Text(
                      provider.isLoading ? 'Running…' : 'Run evaluation',
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: provider.isLoading || provider.isSaving
                        ? null
                        : () => provider.saveRun(
                            cutoffUtc: _cutoffUtc,
                            endUtc: _endUtc,
                            k: _k,
                          ),
                    icon: provider.isSaving
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.bookmark_add_outlined),
                    label: Text(
                      provider.isSaving
                          ? 'Saving snapshot…'
                          : 'Record snapshot',
                    ),
                  ),
                ];
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: controls,
                );
              },
            ),
            if (provider.errorMessage != null) ...[
              const SizedBox(height: 16),
              Semantics(
                liveRegion: true,
                child: _EvidenceNotice(
                  title: 'Evaluation could not be loaded',
                  message: provider.errorMessage!,
                  icon: Icons.error_outline_rounded,
                  backgroundColor: const Color(0xFFFFF1EF),
                  foregroundColor: const Color(0xFF9C3E32),
                ),
              ),
            ],
            if (evaluation != null) ...[
              const SizedBox(height: 18),
              _EvaluationDetails(evaluation: evaluation, theme: theme),
            ] else if (provider.isLoading) ...[
              const SizedBox(height: 22),
              const Center(child: CircularProgressIndicator()),
            ],
            if (provider.latestRun != null) ...[
              const SizedBox(height: 18),
              _PersistedRunSummary(run: provider.latestRun!),
            ],
          ],
        ),
      ),
    );
  }
}

class _UtcDateSelector extends StatelessWidget {
  const _UtcDateSelector({
    required this.label,
    required this.value,
    required this.onPressed,
  });

  final String label;
  final DateTime value;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.calendar_today_outlined, size: 18),
      label: Text('$label: ${_formatUtcDate(value)}'),
    );
  }
}

class _EvaluationDetails extends StatelessWidget {
  const _EvaluationDetails({required this.evaluation, required this.theme});

  final RecommendationEvaluation evaluation;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final cohort = evaluation.cohort;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _EvidencePill(label: 'Protocol: ${evaluation.protocol}'),
            _EvidencePill(label: 'Algorithm: ${evaluation.algorithmVersion}'),
            _EvidencePill(label: 'Evidence: ${evaluation.evidenceTier}'),
            _EvidencePill(
              label:
                  '${_formatUtcDate(evaluation.cutoffUtc)} to ${_formatUtcDate(evaluation.endUtc)} · K=${evaluation.k}',
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Returned cohort',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _CohortFact(
              label: 'Delivered orders',
              value: cohort.deliveredOrders,
            ),
            if (cohort.excludedSeededDemoOrders > 0)
              _CohortFact(
                label: 'Excluded demo orders',
                value: cohort.excludedSeededDemoOrders,
              ),
            _CohortFact(label: 'Training orders', value: cohort.trainingOrders),
            _CohortFact(label: 'Holdout orders', value: cohort.holdoutOrders),
            _CohortFact(label: 'Warm users', value: cohort.evaluatedUsers),
            _CohortFact(
              label: 'Cold-start users',
              value: cohort.coldStartUsers,
            ),
            _CohortFact(
              label: 'Candidate products',
              value: cohort.candidateProducts,
            ),
            _CohortFact(
              label: 'Distinct customers',
              value: cohort.distinctCustomers,
            ),
            if (cohort.excludedUnverifiedLegacyOrders > 0)
              _CohortFact(
                label: 'Excluded legacy orders',
                value: cohort.excludedUnverifiedLegacyOrders,
              ),
            if (cohort.excludedNonOperationalOrders > 0)
              _CohortFact(
                label: 'Excluded test/admin orders',
                value: cohort.excludedNonOperationalOrders,
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (!evaluation.isAvailable)
          Semantics(
            liveRegion: true,
            child: _EvidenceNotice(
              key: const Key('recommendation-evaluation-unavailable'),
              title: 'Not enough historical data for a quality result',
              message:
                  evaluation.unavailableReason ??
                  'The selected window has no warm evaluable users. No recommendation-quality score is shown.',
              icon: Icons.info_outline_rounded,
              backgroundColor: const Color(0xFFFFF8E8),
              foregroundColor: const Color(0xFF7A5415),
            ),
          )
        else ...[
          if (!evaluation.quality.isMeaningful) ...[
            _EvidenceNotice(
              key: const Key('recommendation-evaluation-diagnostic'),
              title: 'Diagnostic cohort — not a general quality claim',
              message: evaluation.quality.unmetRequirements.join(' '),
              icon: Icons.warning_amber_rounded,
              backgroundColor: const Color(0xFFFFF8E8),
              foregroundColor: const Color(0xFF7A5415),
            ),
            const SizedBox(height: 14),
          ] else ...[
            const _EvidenceNotice(
              key: Key('recommendation-evaluation-meaningful'),
              title: 'Operational data-sufficiency gates passed',
              message:
                  'This historical cohort meets the configured volume and diversity thresholds. It remains an offline ranking evaluation, not causal conversion evidence.',
              icon: Icons.verified_outlined,
              backgroundColor: Color(0xFFE8F4EF),
              foregroundColor: Color(0xFF1F7A63),
            ),
            const SizedBox(height: 14),
          ],
          if (evaluation.isSmallSample) ...[
            const _EvidenceNotice(
              title: 'Small evaluation cohort',
              message:
                  'Treat these values as a limited diagnostic, not a broad quality claim.',
              icon: Icons.warning_amber_rounded,
              backgroundColor: Color(0xFFFFF8E8),
              foregroundColor: Color(0xFF7A5415),
            ),
            const SizedBox(height: 14),
          ],
          _MetricsComparison(evaluation: evaluation),
        ],
        const SizedBox(height: 16),
        _QualityGateSummary(quality: evaluation.quality),
        if (evaluation.limitations.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Returned limitations',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          ...evaluation.limitations.map(
            (limitation) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '• $limitation',
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: Color(0xFF52606D),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _PersistedRunSummary extends StatelessWidget {
  const _PersistedRunSummary({required this.run});

  final RecommendationEvaluationRun run;

  @override
  Widget build(BuildContext context) {
    final qualified = run.evidenceTier == 'Qualified';
    final color = qualified ? const Color(0xFF1F7A63) : const Color(0xFF7A5415);
    final background = qualified
        ? const Color(0xFFE8F4EF)
        : const Color(0xFFFFF8E8);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline_rounded, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Latest immutable evaluation snapshot · ${run.evidenceTier}',
                  style: TextStyle(color: color, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  'Recorded ${_formatUtcDate(run.executedAtUtc)} · run ${_shortHash(run.runId)} · input ${_shortHash(run.inputFingerprintSha256)}',
                  style: TextStyle(color: color, height: 1.35),
                ),
                const SizedBox(height: 3),
                Text(
                  'The stored report is aggregate-only. Later data changes do not alter this recorded evidence.',
                  style: TextStyle(color: color, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QualityGateSummary extends StatelessWidget {
  const _QualityGateSummary({required this.quality});

  final RecommendationEvaluationQuality quality;

  @override
  Widget build(BuildContext context) {
    final passed = quality.gates.where((gate) => gate.passed).length;
    final failed = quality.gates.where((gate) => !gate.passed).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quality gates: $passed/${quality.gates.length} passed',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 5),
        Text(
          'Policy ${quality.policyVersion} · eligible origins: CustomerCheckout and VerifiedImport only.',
          style: const TextStyle(fontSize: 12, color: Color(0xFF667085)),
        ),
        if (failed.isNotEmpty) ...[
          const SizedBox(height: 6),
          ...failed
              .take(3)
              .map(
                (gate) => Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    '• ${gate.name}: ${gate.observed} (requires ${gate.required})',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF7A5415),
                    ),
                  ),
                ),
              ),
        ],
      ],
    );
  }
}

class _MetricsComparison extends StatelessWidget {
  const _MetricsComparison({required this.evaluation});

  final RecommendationEvaluation evaluation;

  @override
  Widget build(BuildContext context) {
    final cf = evaluation.collaborativeFiltering;
    final baseline = evaluation.popularityBaseline;
    final rows = <(String, double?, double?)>[
      ('Precision@K', cf.precisionAtK, baseline.precisionAtK),
      ('Recall@K', cf.recallAtK, baseline.recallAtK),
      ('Hit rate@K', cf.hitRateAtK, baseline.hitRateAtK),
      ('MRR@K', cf.meanReciprocalRankAtK, baseline.meanReciprocalRankAtK),
      (
        'NDCG@K',
        cf.normalizedDiscountedCumulativeGainAtK,
        baseline.normalizedDiscountedCumulativeGainAtK,
      ),
      (
        'Catalog coverage@K',
        cf.catalogCoverageAtK,
        baseline.catalogCoverageAtK,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Collaborative filtering compared with popularity baseline',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: [
              const DataColumn(label: Text('Metric')),
              DataColumn(label: Text(cf.method)),
              DataColumn(label: Text(baseline.method)),
            ],
            rows: rows
                .map(
                  (row) => DataRow(
                    cells: [
                      DataCell(Text(row.$1)),
                      DataCell(Text(_formatPercent(row.$2))),
                      DataCell(Text(_formatPercent(row.$3))),
                    ],
                  ),
                )
                .toList(growable: false),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Average returned: ${_formatAverage(cf.averageRecommendationsReturned)} vs ${_formatAverage(baseline.averageRecommendationsReturned)} · hits: ${cf.totalHits} vs ${baseline.totalHits}',
          style: const TextStyle(fontSize: 12, color: Color(0xFF667085)),
        ),
      ],
    );
  }
}

class _EvidenceNotice extends StatelessWidget {
  const _EvidenceNotice({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String title;
  final String message;
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: foregroundColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: foregroundColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: TextStyle(color: foregroundColor, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CohortFact extends StatelessWidget {
  const _CohortFact({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 118),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F8FC),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$value',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF667085)),
          ),
        ],
      ),
    );
  }
}

class _EvidencePill extends StatelessWidget {
  const _EvidencePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF1FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF2558B5),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

String _formatUtcDate(DateTime value) {
  final utc = value.toUtc();
  final month = utc.month.toString().padLeft(2, '0');
  final day = utc.day.toString().padLeft(2, '0');
  return '${utc.year}-$month-$day UTC';
}

String _formatPercent(double? value) =>
    value == null ? '—' : '${(value * 100).toStringAsFixed(1)}%';

String _formatAverage(double? value) =>
    value == null ? '—' : value.toStringAsFixed(1);

String _shortHash(String value) =>
    value.length <= 12 ? value : '${value.substring(0, 12)}…';
