# Recommendation evaluation protocol

PadelClub's product recommender is an online, deterministic item-to-item
collaborative filter. This document explains the reproducible offline backtest
added for the exam-readiness phase. It evaluates historical ranking behavior; it
does not turn the feature into a separately trained or persisted ML model.

## Endpoints and stored evidence

An administrator can run a fixed historical backtest from the desktop
**Recommendation evaluation evidence** panel on the Management overview, through
Swagger, or directly through the transient preview:

```text
GET /Operations/recommendations/evaluation?cutoffUtc=<ISO-8601-UTC>&endUtc=<ISO-8601-UTC>&k=6
```

The administrator can also persist and retrieve aggregate-only evidence:

```text
POST /Operations/recommendations/evaluation/runs
GET  /Operations/recommendations/evaluation/runs/latest
GET  /Operations/recommendations/evaluation/runs/{runId}
```

Before selecting dates, an administrator can inspect aggregate operational
collection progress without exposing customer rows:

```text
GET /Operations/recommendations/cohort-readiness
```

The response is an **operational collection preflight**, not a metric result.
It counts only active-user `CustomerCheckout` and `VerifiedImport` orders,
reports the explicitly excluded demo/legacy/test/admin totals, and shows whether
delivery timestamps, approved/refunded return-resolution timestamps, basic
volume/diversity collection targets, and calendar maturity are present. It also
shows the latest possible return-matured end date and the earliest *time-only*
date at which the first delivery could support the configured 90-day pre-fold
history, 28-day holdout, and 30-day return-maturity period.

`ReadyForWindowValidation` does **not** mean qualified recommendation evidence.
It means only that aggregate collection preflight checks are met. Training and
holdout signals, warm evaluable users, metric availability, and the final
`Diagnostic`/`Qualified` evidence tier remain split-specific checks performed by
the explicit evaluator request. A fresh local demo database must correctly show
`NoEligibleCohort`; seeded baskets never become operational evidence. The
endpoint neither changes provenance nor backfills timestamps: a missing
`DeliveredAt` must be verified from a fulfilment record or remain excluded, and
`CreatedAt` is never substituted. The same rule applies to a missing return
`ResolvedAt` timestamp.

The request requires:

- an explicit UTC cutoff;
- an explicit UTC end time after the cutoff, no more than 366 days later and
  not in the future;
- a value of `k` from 1 through 12.

Explicit dates make the result reproducible for the same input snapshot. All
endpoints are administrator-only because they are evidence/operations
functionality, not player-facing recommendation requests. A persisted run saves
the admin ID, execution time, protocol and algorithm versions, configuration
SHA-256, input SHA-256, aggregate report, and cohort totals. It is append-only
through the application; this is not a claim of protection from a database
administrator. Raw customer interaction tuples and PII are not stored in the
run.

The desktop panel exposes the same UTC cutoff, end, and `k` inputs; it can record
a snapshot and displays the latest stored one. It renders the protocol,
algorithm version, fingerprints, cohort counts, returned limitations, explicit
data-sufficiency gates, and the collaborative-filtering versus popularity
comparison. Its initial range leaves a 30-day return-maturity buffer and then
holds out 28 days. If `isAvailable` is false, it shows the API's unavailable
reason and deliberately hides the metric table rather than substituting zeroes.

## Operational collection and online interaction monitoring

The Management overview also contains an **Operational recommendation
readiness** panel. It keeps two evidence tracks separate:

1. The cohort card calls `GET /Operations/recommendations/cohort-readiness` and
   reports only aggregate operational collection progress. It is not an offline
   quality result.
2. The online-monitoring card calls the administrator-only endpoint below for a
   return-matured window:

   ```text
   GET /Operations/recommendations/impact?fromUtc=<ISO-8601-UTC>&toUtc=<ISO-8601-UTC>
   ```

When `GET /Recommendations/products` returns a ranked product, the API creates
a server-side `RecommendationExposure` and returns its opaque `exposureId` with
that item. At the same write, the server immutably stamps a telemetry source:
only a **Production**, active, email-verified `Player` session without the
`Administrator` role **and with prior server-recorded `CustomerCheckout` or
`VerifiedImport` history** is `OperationalCustomer`. That additional history
guard keeps a seeded or merely verified account from being relabelled as a real
customer. Development/demo, integration-test, administrator,
unqualified-account, other non-production, and pre-provenance rows are
aggregate-excluded. The client never submits this classification, and the
migration leaves historic rows as `Unverified` rather than backfilling a
customer claim.

The desktop shop reports an intentional open/add interaction through
`POST /Recommendations/products/{exposureId}/click`. A new click is accepted
only from its owner within seven days of serving; an expired identifier is
ignored without changing the stored row. A repeat of an already valid click is
idempotent. The report also revalidates the stored timestamp, so a malformed
historical click outside the serving-to-seven-day interval cannot change a
closed CTR retroactively. If that same authenticated player later checks out
the **same product**, the optional exposure ID is accepted only when its source
is operational, it was validly clicked, belongs to the player, is unused, and
is within the same seven-day attribution window. The order remains valid even
if a stale, missing, or forged tracking value is supplied; that value is simply
not attributed.

The aggregate impact report discloses operational impressions, players, valid
clicks, attributed checkouts, delivered/cancelled attributed orders, and
delivered revenue, plus aggregate counts excluded for non-operational source or
invalid click timing. One order is counted once even if it contained multiple
exposed products. Its `Collecting` tier remains until the selected window
contains at least 100 **operational** server-recorded exposures, 30 distinct
players, 14 observation days, and ends at least seven days ago. A `Descriptive`
report only means those collection gates passed. It has no randomized control
group, does not estimate lift, and must never be described as causal impact or
a PadelClub customer result before genuine traffic matures. Exposure rows
record no raw historical input tuples or PII beyond existing relational keys.

## Prospective causal-impact collection

The descriptive impact endpoint above remains descriptive forever: historic
exposures were not randomized and cannot be retrofitted into an A/B result. To
collect future causal evidence without inventing a PadelClub customer cohort,
the application now has one deliberately fixed experiment:

```text
product-recommendation-cf-vs-popularity-v1
```

Its server-owned protocol is `sticky-user-ab-cf-vs-popularity-v1`:

1. A player explicitly grants or revokes recommendation-analytics consent at
   `GET`/`PUT /Recommendations/analytics-consent`. This is separate from email
   and push notification preferences. Revocation stops future assignment; it
   does not rewrite already recorded evidence.
2. Only a production, active, email-verified, non-administrator `Player` that
   already qualifies as `OperationalCustomer` can be considered. Demo, test,
   admin, non-production, unverified, and historic rows cannot be assigned.
3. An administrator creates and starts the one immutable definition at
   `POST /Operations/recommendations/experiments` and
   `POST /Operations/recommendations/experiments/{id}/start`. Its 50/50 arm is
   cryptographically randomized once per eligible user and persisted with a
   unique `(ExperimentId, UserId)` constraint. A later request reloads the same
   assignment rather than switching the player between arms.
4. Treatment serves the current item-to-item collaborative filter. Control
   serves a full deterministic distinct-buyer popularity ranking for every
   eligible slot, rather than the old sparse-history fallback alone. Response
   strategy metadata identifies the ranking; this is not a blinded experiment.
5. Each new exposure carries the immutable assignment foreign key. Pre-existing
   exposures remain null and are excluded from experiment analysis. Click and
   checkout attribution retain the existing owner/product/seven-day checks.
6. An administrator closes serving with
   `POST /Operations/recommendations/experiments/{id}/close`, views the
   aggregate report at `GET .../{id}/impact`, and may preserve an immutable,
   aggregate-only snapshot with `POST .../{id}/analysis-runs`.

The pre-registered primary outcome is **the assigned, consented operational
player having at least one server-attributed checkout for a clicked recommended
product within seven days of a served exposure**. Analysis is user-level, not
exposure-level, so repeated sessions cannot dominate an arm. All assigned users
remain in the outcome denominator, including empty/failed serving requests.
The report leaves
`absoluteLift`, `relativeLift`, and its Newcombe/Wilson 95% interval `null` and
uses `Collecting` until all of these gates pass:

- the experiment is closed and its final attribution window is mature;
- each arm has at least 50 distinct mature served users and 100 mature
  server-recorded exposures;
- actual mature serving timestamps span at least 14 days (waiting after closure
  cannot increase this coverage); and
- every included exposure has the server-owned operational provenance and
  immutable experiment assignment above.

The interval uses the uncorrected Newcombe/Wilson difference method documented
in [statsmodels](https://www.statsmodels.org/stable/_modules/statsmodels/stats/proportion.html#confint_proportions_2indep).
The input fingerprint hashes canonical assignment/exposure facts and lifecycle
metadata, independently of the report generation timestamp.

Only then does the endpoint return `CausalEstimate`. Minimum-volume gates are
not a power calculation or proof of significance. This is an exploratory
randomized estimate; optional stopping, consent withdrawal, privacy deletion,
changing purchase histories, and instrumentation losses require review before
claiming an effect. That label is limited to
this pre-registered, bounded checkout-attribution outcome; it is not evidence
of customer satisfaction, retention, recipient delivery, return-adjusted
revenue, or a mature PadelClub result until real traffic has accrued. Privacy
export includes a player's consent, assignments, and exposures; scheduled
deletion removes those user-level rows while retaining no raw tuples in prior
aggregate analysis snapshots.

## Offline evaluation availability

For the offline evaluation endpoint, `isAvailable` only means that metrics could be calculated. The separate
`quality` object labels a calculable but undersized operational cohort as a
**diagnostic**, not a general quality result. Its thresholds are visible to the
administrator: a 28-day window, a 30-day return-maturity period after the
holdout, 100 delivered orders, 30 distinct customers, 500 training signals, 100
holdout signals, 20 candidate products, 10 products with at least two distinct
buyers, 50 warm evaluable users, and 90 historical-observation days. These are
data-sufficiency gates, not proof that legacy non-demo orders have a verified
customer provenance or recommendation-analytics consent.

The desktop client parses this response as a strict evidence contract: required
fields and explicit null metric values must be present, and contradictory
available/unavailable states are rejected as a load error. A malformed response
therefore cannot be presented as a plausible "not enough data" outcome.

## Protocol

The API reports `global-temporal-future-basket-v1`.

1. Training purchases use only lines on `Delivered` orders where `DeliveredAt`
   is present and before `cutoffUtc`. `CreatedAt` is never a fallback.
2. Holdout labels use only those same provenance-eligible lines where
   `cutoffUtc <= DeliveredAt < endUtc`.
3. An operational row must be active-user data with `Origin` equal to
   `CustomerCheckout` or `VerifiedImport` and `IsSeededForDemo == false`.
   Seeded demo, integration-test, administrator-created, unverified legacy, and
   missing-delivery rows are excluded and reported separately. The local demo
   baskets remain useful for showing the player-facing recommender, but cannot
   contribute to an operational quality claim.
4. Training signals subtract only approved/refunded returns resolved before the
   cutoff. This prevents future return outcomes from rewriting the historical
   training view.
5. Holdout labels subtract approved/refunded returns resolved before
   `endUtc + 30 days`. This gives an older selected holdout time for a return to
   settle; a fully returned item is not treated as a successful future purchase.
   Approved/refunded outcomes without `ResolvedAt` are disclosed and fail the
   operational quality gate. A window that ended less than 30 days before
   evaluation remains diagnostic, even if the API can calculate its metrics.
6. A user is evaluated only when they have retained training history and at
   least one new retained holdout product. Products already retained before the
   cutoff are excluded from that user's labels, matching the serving endpoint's
   owned-product exclusion.
7. The item-to-item ranker receives training signals only and uses the cutoff as
   its recency reference time. No wall-clock time or post-cutoff peer purchase
   may affect the ranking.

The candidate catalog contains products with pre-cutoff purchase evidence. This
is a deliberately conservative historical catalog: the database has no complete
stock/active/product-state history, so the evaluator does not misuse present-day
availability fields as if they were historical facts.

## Compared methods and metrics

The response compares two deterministic methods using only training data:

- **item-to-item collaborative filtering** — the same cosine/support-shrinkage
  ranker used by the player recommendation endpoint;
- **distinct-buyer popularity baseline** — products ranked by the number of
  unique pre-cutoff buyers, with product-ID tie breaking.

Metrics are macro-averaged across the warm evaluable user cohort:

- **Precision@K** — relevant recommendations divided by the number of available
  positions up to K;
- **Recall@K** — future relevant products found in the top K;
- **HitRate@K** — share of evaluated users with at least one hit;
- **MRR@K** — reciprocal rank of the first relevant item;
- **CatalogCoverage@K** — distinct recommended products divided by the
  historical candidate catalog;
- **AverageRecommendationsReturned** and raw hit/user counts.

**NDCG@K** is also returned: it discounts a relevant product by its rank and
normalises the result by the ideal ordering of that user's relevant future
products.

If the selected range has no warm evaluable users, `isAvailable` is false and
metric values are `null`, not fabricated zero-quality scores. `isSmallSample`
is true for fewer than five evaluable users; results from that cohort should be
described as a smoke-level check, not as a general performance claim. The more
strict `quality.isMeaningful` flag governs the administrator-facing operational
data-sufficiency claim.

## External real-transaction benchmark

The repository has no verified non-demo PadelClub purchase corpus. Therefore the
fresh local Compose database must remain unavailable or diagnostic for the
operational evaluator; it would be misleading to present its demo baskets as
real-data quality evidence.

To evaluate the exact ranking algorithm on genuine transaction data without
mixing that data into PadelClub, the repository includes a separate benchmark
for [UCI Online Retail](https://archive.ics.uci.edu/dataset/352/online+retail).
UCI describes it as a de-identified UK non-store retail transaction dataset;
the source is licensed CC BY 4.0 with DOI `10.24432/C5BW33`. The benchmark keeps
the workbook in a temporary directory, never imports it into `Orders`, and
writes only aggregate counts plus the workbook SHA-256 to the JSON evidence.

Run the locked protocol from the repository root:

```powershell
.\scripts\Invoke-UciOnlineRetailBenchmark.ps1
```

The script downloads UCI's official archive only when no `-DatasetPath` is
given. It writes
`artifacts/external-real-data-benchmark/uci-online-retail-rolling-v1.json`.
The benchmark accepts only the canonical UCI workbook with SHA-256
`43465a06f2ccf7c8b5bd2892bc7defb52f97487934fe93b16ae4c3936424676d`; a file
with a different hash is rejected rather than being labelled UCI by filename.
You can pass that previously downloaded workbook and a different output path
without changing the protocol:

```powershell
.\scripts\Invoke-UciOnlineRetailBenchmark.ps1 `
  -DatasetPath 'D:\datasets\Online Retail.xlsx' `
  -OutputPath '.\artifacts\external-real-data-benchmark\uci-online-retail-rolling-v1.json'
```

The benchmark accepts only input/output paths. Its fixed,
non-cherry-pickable configuration is:

1. Keep rows with `CustomerID`, `InvoiceNo`, `StockCode`, and `InvoiceDate`.
   Exclude invalid/non-merchandise purchase rows. UCI cancellation invoices do
   not document a source-invoice foreign key, so the benchmark does **not**
   infer one by stripping `C`. Instead, a cancellation is allocated newest-first
   only to prior purchases of the same de-identified customer and stock code.
   Unmatched cancellation quantity is reported, never imputed across a customer
   or product.
2. Use three consecutive 28-day global temporal holdouts at K=6. The last
   holdout ends 30 days before the archive's final observed day; each holdout's
   labels include matched cancellations observed through its own 30-day maturity
   end. Training uses only cancellations known before its cutoff.
3. Use the same item-to-item cosine/support-shrinkage ranker and the same
   distinct-buyer popularity baseline as PadelClub. Already owned products are
   excluded before scoring.
4. Report each fold and a user-fold-weighted aggregate for user metrics.
   Catalog coverage is explicitly the unweighted mean of fold coverages, because
   it is a fold-level catalog property rather than a user-level measure.
5. Qualify a result only if all 11 transparent archive/history/volume/warm-user,
   return-maturity, and unmatched-cancellation gates pass.

The generated evidence records the canonical source hash above and these
aggregate facts:

- 541,909 source rows; 396,046 eligible purchase rows net to 383,324 retained
  interactions across 4,324 de-identified customers, 3,644 merchandise
  products, and 18,267 invoices;
- 8,534 eligible cancellation rows: 250,548 units matched by the conservative
  same-customer/product prior-time rule, 18,806 units unmatched (6.98% of
  cancellation quantity), and 2,807 purchase rows fully removed. The 6.98%
  disclosure passes the documented maximum of 10.00%; it is a screening guard,
  not a claim that every return is known perfectly;
- three valid matured folds from 2011-08-18 through 2011-11-10, each with a
  30-day label-maturity period and 690-961 warm users;
- 2,527 evaluated user-folds in total;
- collaborative filtering: Precision@6 6.91%, Recall@6 3.04%, HitRate@6
  28.10%, MRR@6 15.42%, NDCG@6 7.76%, and catalog coverage 11.58% (unweighted
  mean of folds);
- popularity baseline: Precision@6 3.60%, Recall@6 1.35%, HitRate@6 18.01%,
  MRR@6 8.12%, NDCG@6 3.74%, and catalog coverage 1.22% (unweighted mean of
  folds);
- CF's aggregate NDCG@6 lift over popularity: **+4.02 percentage points**
  (1,047 versus 546 total top-6 hits).

This is meaningful, reproducible **external algorithm evidence**. It is not
PadelClub operational performance, a conversion result, customer-satisfaction
evidence, or an A/B test. The generated JSON states that boundary directly so a
demo cannot relabel it accidentally.

## Automated evidence

`RecommendationEvaluationTests.cs` includes deterministic, fixed-time tests
that prove:

- collaborative filtering can beat the popularity baseline on a known temporal
  fixture;
- post-cutoff peer purchases cannot influence the result;
- NDCG@K is present for available results and null for unavailable results;
- sparse windows return explicit unavailable metadata rather than fake metrics;
- seed/demo, legacy, test/admin, and missing-delivery rows are excluded by the
  provenance policy while customer-checkout orders remain eligible;
- returns resolved before the cutoff change training ownership, while later
  returns do not leak into training; returns resolved after the selected end but
  within the 30-day maturity period remove fully returned holdout labels.

The isolated Compose smoke also exercises the evaluator through the running
HTTP API. It verifies that anonymous calls receive `401`, player calls receive
`403`, missing bounds and invalid `k` receive `400`, and an unavailable window
has null metrics rather than fabricated values. This is integration-contract
evidence, not a substitute for a meaningful real-data metric result.

`ApiIntegrationTests.cs` adds a focused relational HTTP tier below that smoke
test. It starts a disposable digest-pinned SQL Server through Testcontainers,
applies the real migration chain, seeds a controlled scenario, and verifies the
same evaluator roles, validation, evaluation-run persistence/immutability, and
seeded-demo provenance through the full ASP.NET Core request pipeline. It also
proves that a player checkout is marked `CustomerCheckout` server-side, rather
than trusting client input. Its operational recommendation purchases fall outside
the selected evaluator window, which also guards against reporting post-window
orders as historical cohort input.

The same HTTP tier verifies that a recommendation response gets an exposure ID,
only its owner can record the click, an owned clicked exposure can be associated
with a matching checkout, and the administrator-only impact endpoint remains
`Collecting` rather than claiming causal lift from a tiny sample.

Run the evidence with:

```powershell
dotnet test PadelClub.sln --configuration Release --no-restore
```

## Limits to explain during the exam

- The historical evaluator and UCI benchmark remain non-causal. A separate
  prospective A/B protocol now exists, but the repository has no mature real
  PadelClub participant cohort or causal estimate to report yet.
- No product availability-history table exists, so the evaluation cannot replay
  historical stock or active-state filters exactly.
- Server-recorded impressions, intentional clicks, and a bounded matching
  checkout attribution are now collected. Mature funnel metrics include only
  server-stamped production verified-player traffic; demo/test/admin,
  non-production, unverified, stale-click, and historic unverified rows cannot
  satisfy their gates. The separate experiment adds explicit consent, sticky
  randomized control/treatment assignment, and immutable aggregate analysis,
  but it deliberately remains `Collecting` with null lift until genuine
  production participants meet every gate.
- Development seed baskets are intentionally excluded from evaluator input. A
  fresh local database should therefore show an unavailable quality result until
  verified operational retained-purchase history exists. Current legacy
  non-demo rows default to `UnverifiedLegacy` and cannot be turned into a
  real-data claim by the operational panel.
- The formal exploratory profile is
  [`RECOMMENDATION_DATA_PROFILE.md`](RECOMMENDATION_DATA_PROFILE.md). Its UCI
  charts and counts are external algorithm evidence; it intentionally does not
  invent a PadelClub customer distribution before one exists.
- The UCI benchmark is deliberately external. It demonstrates ranking behavior
  on licensed real transactions but cannot establish PadelClub customer impact.
- A low or unavailable result is information, not a failure to hide. It tells
  the examiner that the selected data window is too sparse for a credible
  quality claim.
