# Recommendation data profile and exploratory analysis

## Purpose and evidence boundary

This is the formal data-profile artifact for the PadelClub product recommender.
It has two deliberately separate tracks:

1. **External benchmark profile** — reproducible, de-identified public retail
   transactions used to test the ranking algorithm at realistic scale.
2. **PadelClub operational profile** — future authenticated-checkout or
   verified-import orders only. Seed, test, administrator-created, and legacy
   orders are explicitly excluded from quality evidence.

The external profile is evidence about the algorithm, not PadelClub customer
conversion, satisfaction, or production performance. The current local demo
database has no qualified operational cohort and must be shown as such.

## Profile artifact

The aggregate-only source artifact is
[`uci-online-retail-rolling-v1.json`](../artifacts/external-real-data-benchmark/uci-online-retail-rolling-v1.json).
It was generated on 2026-09-01 by the repository's benchmark runner against
the canonical UCI Online Retail workbook:

- Dataset: [UCI Online Retail](https://archive.ics.uci.edu/dataset/352/online+retail)
- License: CC BY 4.0; DOI `10.24432/C5BW33`
- Canonical workbook SHA-256:
  `43465a06f2ccf7c8b5bd2892bc7defb52f97487934fe93b16ae4c3936424676d`
- Raw workbook policy: it remains outside the repository and PadelClub
  database; this artifact contains only aggregate counts, configuration, and
  hashes.

Recreate the profile and benchmark with:

```powershell
pwsh -File .\scripts\Invoke-UciOnlineRetailBenchmark.ps1
```

The runner refuses a workbook whose SHA-256 differs from the canonical source.

## External transaction profile

| Stage | Observed rows/signals | Treatment |
|---|---:|---|
| Raw source rows | 541,909 | Original public transaction rows |
| Missing required fields | 135,080 | Removed before modelling: invoice, stock code, customer ID, and invoice time are all required |
| Eligible positive purchase rows | 396,046 | Positive quantity and unit price, regular merchandise code, required fields present |
| Cancellation rows | 8,534 | Matched only to a prior same-customer, same-product retained purchase |
| Non-positive/invalid unit price | 33 | Removed |
| Non-merchandise stock codes | 2,216 | Removed |
| Matched cancellation quantity | 250,548 | Netted newest-first against eligible prior purchases |
| Unmatched cancellation quantity | 18,806 | Explicitly disclosed; never assigned heuristically |
| Signals removed by cancellation netting | 2,807 | Fully netted purchase rows removed |
| Final retained interactions | 383,324 | Input to temporal evaluation |

Final retained data contains **4,324 de-identified customers**, **3,644
merchandise products**, and **18,267 invoices**. The unmatched cancellation
rate is **698 basis points (6.98%)**, below the benchmark's disclosed 10.00%
screen but still a limitation to state during the presentation.

## Feature and label construction

The recommender uses implicit purchase feedback, not a rating label:

```text
customer + invoice + product + quantity + invoice timestamp
   -> clean and cancellation-net
   -> retained purchase interaction
   -> item-to-item collaborative ranking input
```

- Product codes must match the regular-merchandise pattern `^\d{5}[A-Z]?$`.
- A cancellation is matched only when it is later in time than a retained prior
  purchase of the same customer and product. Quantity is allocated newest-first.
- Returns/cancellations not safely matched remain unmatched rather than being
  silently imputed.
- For each temporal holdout, training interactions use only outcomes known by
  the cutoff. Holdout labels use outcomes known through the end plus 30 days of
  return maturity.
- Candidate products are limited to products seen before that fold's cutoff.
  Already owned products are excluded from recommendations.

No raw name, address, email, or PadelClub customer history is written into the
profile or evaluation records.

## Temporal coverage and evaluation readiness

The locked public protocol uses `K=6`, three consecutive 28-day holdouts, and
30-day return maturity:

| Fold | Training cutoff (UTC) | Holdout end (UTC) | Mature through (UTC) | Training signals | Holdout signals | Warm users | Candidate products |
|---|---|---|---|---:|---:|---:|---:|
| 1 | 2011-08-18 | 2011-09-15 | 2011-10-15 | 207,842 | 27,448 | 690 | 3,357 |
| 2 | 2011-09-15 | 2011-10-13 | 2011-11-12 | 235,238 | 41,250 | 876 | 3,437 |
| 3 | 2011-10-13 | 2011-11-10 | 2011-12-10 | 276,453 | 45,757 | 961 | 3,529 |

All eleven benchmark gates passed: retained interactions, customer/product
volume, history, three available folds, warm-user and holdout volume, candidate
coverage, maturity, and unmatched-cancellation disclosure. The aggregate has
2,527 evaluable user-folds.

## Operational PadelClub profile contract

The live evaluator and saved-run API provide the operational profile at the
time a run is recorded. A row is eligible only when all of these are true:

- `Status == Delivered` and the user is active;
- `Origin` is `CustomerCheckout` or `VerifiedImport`;
- `IsSeededForDemo == false`;
- `DeliveredAt` is present; `CreatedAt` is never a substitute;
- approved/refunded return outcomes have `ResolvedAt`.

Every response exposes counts for excluded seed/demo, legacy, test/admin, and
missing-delivery records, plus distinct customers, retained signals, candidate
support, observation history, fingerprint hashes, and all quality gates.
`POST /Operations/recommendations/evaluation/runs` stores that aggregate-only
snapshot immutably; `GET /Operations/recommendations/evaluation` remains a
live exploratory preview.

Until a real, sufficiently mature operational cohort exists, its tier remains
`Unavailable` or `Diagnostic`. Do not reclassify old rows to satisfy a gate.

## EDA conclusions and limitations

1. The public dataset is large and temporally deep enough to exercise sparse
   item-to-item ranking, return netting, and a popularity baseline without
   synthetic interactions.
2. The profile demonstrates data cleaning and leakage control, but it is a UK
   non-store retailer rather than a padel club. It validates ranking mechanics,
   not PadelClub product-market behaviour.
3. PadelClub's origin model now protects future evidence from contamination,
   but it does not certify the origin of historic rows. Existing local demo
   data remains available for a user-interface demonstration only.
4. A formal distribution chart for real PadelClub customers will be added only
   after a privacy-approved operational cohort exists. Until then, the honest
   formal profile is the qualified public benchmark plus the live zero/limited
   cohort gates—not invented customer analytics.
