# PadelClub exam demonstration guide

Use this guide as a short, honest walkthrough. It focuses on features with a
visible user outcome and direct source/test evidence. Do not present an API-only
endpoint, static dashboard preview, or unconfigured external provider as a
finished client feature.

## Before the demonstration

From the repository root, prepare a clean local stack. This recreates services
defined by Compose, so stop any previous local stack only when it is safe to do
so.

For a rehearsal that does not disturb the normal local stack, use the isolated
clean-volume verifier first:

```powershell
.\scripts\Invoke-CleanComposeSmoke.ps1 -Cleanup
```

It starts a separate project on API port `5100`, verifies the fresh database
bootstrap and the API-to-RabbitMQ-to-worker path, then removes only that
project's test resources. The normal demonstration stack still uses port `5000`.

```powershell
Copy-Item .env.example .env
docker compose up --build --detach
docker compose ps
```

Wait for the API and RabbitMQ to be healthy. Useful local addresses are:

- Swagger/API: `http://localhost:5000/swagger`
- Mailpit: `http://localhost:8025`
- RabbitMQ management: `http://localhost:15672`

Development credentials are created only when demo seeding is explicitly enabled.
Set `Database__DemoPassword` yourself; both `admin` and `player1` use that value.
They are demo-only credentials. Start the Windows
desktop management client with:

```powershell
Set-Location UI/padelclub_desktop
flutter pub get
flutter run -d windows --dart-define=baseUrl=http://localhost:5000
```

The Windows runner presents the management shell. The mobile runner uses the same
shared player workflows, including Shop, Search, and Player Hub:

```powershell
Set-Location UI/padelclub_mobile
flutter pub get
flutter run --dart-define=baseUrl=http://10.0.2.2:5000
```

For an iOS simulator, replace that emulator address with `http://localhost:5000`;
see the root README for physical-device guidance.

## Suggested 8-10 minute walkthrough

### 1. Establish the application boundary (about 1 minute)

Open the running client and Swagger. Explain that PadelClub is an ASP.NET Core
API with a shared Flutter client, SQL Server, local Mailpit, and a separate
RabbitMQ subscriber. Show `docker compose ps` rather than merely asserting that
the services exist.

### 2. Player workflows and recommendation (about 3 minutes)

1. In the mobile runner, sign in as `player1`.
2. Open the shop/products screen.
3. Point out the **Recommended for you** section and its per-item reason.
4. Explain the data path: delivered orders -> order items -> retained purchase
   signals -> item-to-item cosine ranking -> authenticated API -> Flutter UI.
5. Point out that already owned, unavailable, inactive, or deactivated products
   are excluded. If there is too little history, explain the visible fallback
   label rather than calling it personalised.

The seed contains a reproducible example: `player1` has the Control Racket and
other demo players have ordered that racket together with balls or shoes. The
balls should rank above shoes because they have stronger co-purchase support.

For a second visible player journey, open **Search** and select **Open player
hub**. This is an authenticated client workflow, not just an API surface:

1. Complete or edit the player profile, including discoverability, then search
   for and invite a partner.
2. Register an upcoming tournament with a partner from its Search card. In
   **My tournaments**, respond to an invitation, withdraw before the server
   rules close registration, or view the returned bracket.
3. In **Personal matches**, report a score as one team or confirm the opposing
   team's report. The UI only offers confirmation to the non-reporting side.

Some fresh local databases will not contain a suitable partner, tournament, or
match. In that case, show the empty state and explain that the client does not
fabricate a lifecycle record; prepare suitable records before the demonstration
if this is the journey you want to show.

Two further player-facing workflows are available when the account has suitable
server data:

1. Open **My orders** in the shop. Under **Returns**, select eligible delivered
   items, choose quantities, provide a reason, and submit the request. The
   screen then shows the server-returned status, amount, resolution date, and
   any club note. It does not let the player set a refund amount or resolve the
   request locally.
2. In **Profile**, open **My memberships**. Show the server-returned membership
   status and activity history, then toggle automatic renewal or schedule
   cancellation at the end of the current period. Be explicit that these update
   membership settings only: this client does not collect card details, charge a
   payment, or prove that a renewal was collected.
3. In **Profile**, open **Payment history**. Inspect a returned record and its
   status, provider, reference, refunded amount, and reconciliation details.
   It calls only the owner-scoped history endpoint: it cannot take a card,
   initiate/refund a payment, or prove that Stripe is configured locally.

### 3. Administrator, staff, and account workflows (about 2 minutes)

1. Sign in as `admin` and open the dashboard.
2. Show that the four headline values load from `GET /Operations/analytics` for
   the last 30 days. Use Refresh to show the request can be repeated.
3. State the actual meaning of the values: orders, order revenue, reservations,
   active memberships, and low-stock information.
4. Explicitly label the schedule and court-status cards as example layout
   previews, not live scheduling widgets.

If time permits, demonstrate one of these additional client-complete workflows
instead of treating its endpoint as the feature:

1. In reservation management, use **Schedule maintenance** to create a dated
   court block with a reason, or mark an eligible reservation **no-show**. The
   client refreshes the server-authoritative schedule afterwards.
2. In product management, use **Adjust stock** with a signed quantity and an
   audit reason, then open **Stock history** to show the returned movement
   record. Do not describe the row as manually edited local state.
3. In the player's **Profile**, open **Privacy controls** to view the private
   JSON account-data export and inspect or cancel a scheduled account-deletion
   request. The export is an in-app JSON view, not a claimed file download, and
   a request is scheduled for processing rather than immediate erasure.
4. In **Order Management**, open **Return requests**. Filter the
   server-authoritative work queue, inspect a request, and approve (with a club
   note) or reject it. The client refreshes the returned status after the
   server-side action. A Stripe-backed approval becomes `RefundPending` and
   first commits a durable refund operation; only confirmed provider settlement
   restores stock. It does not require or claim a live Stripe configuration in
   the default local setup.
5. In **Product Management**, select **Manage coupons**. Create or edit a
   percentage/fixed discount rule with validity, amount, and usage limits, or
   disable an existing coupon. The displayed usage and status are refreshed from
   the server; do not describe it as a local mock discount.
6. In **Order Management**, open **Orders** and select an order's next
   fulfilment action. Explain that the client only offers the next legal status
   (`Pending -> Processing -> Shipped -> Delivered`, or early cancellation),
   while the server revalidates it, records the real delivery timestamp, and
   rejects skipped or terminal-state changes.
7. Open **Memberships** in the desktop management navigation. Filter the
   server-paged work queue, change a status or inspect its history, then show a
   one-to-24-month renewal. State the exact boundary: this is a recorded/manual
   membership fulfilment action, not a card-payment form or proof that a charge
   was collected.
8. Open **Tournament Management**. Create or edit a server-backed tournament,
   then show the explicit confirmation before asking the server to generate its
   bracket. State that it is one-way: the server requires complete confirmed
   teams and an active court, and rejects repeat generation. If demonstrating
   delete, call it what the current API does: a confirmed hard delete, not an
   archive.
9. Open **Audit Trail** and apply a user, HTTP-method, or UTC start-date filter.
   Inspect a returned entry to show its correlation ID, actor/IP, request path,
   response status, and duration. It is a read-only server audit view; it does
   not edit or export the record.
10. From **Audit Trail**, select **Provider readiness**. Explain that its
    Stripe, SMTP, and Firebase states are configuration-only diagnostics: the
    endpoint makes no external calls and exposes no credentials, so it proves
    neither a charge nor external message delivery.
    If asked how external proof is collected, show the documented
    administrator-only `POST /Operations/provider-verification/{provider}`
    contract in Swagger rather than inventing a result: it is default-disabled,
    requires `confirmExternalCall: true`, and uses fixed deployment targets.
    A successful SMTP/FCM rehearsal means provider acceptance only; Stripe is
    restricted to a read of a configured test-mode PaymentIntent. Do not invoke
    it without the owner's explicit test credentials/recipient/device and an
    observed external result.
11. In **Notifications**, open **Delivery diagnostics**. Filter the latest
   server-recorded attempts by status and inspect an error or schedule. Explain
   that this is a read-only operational diagnostic, not a retry action or a
   recipient read receipt. Pending, retry, failed, or skipped states can be
   expected when local SMTP/Firebase configuration is intentionally absent.

For a return approval, say what the application actually proves: the server
serializes the local return state, commits an immutable refund operation before
Stripe I/O, and uses a recoverable lease/reconciliation flow to settle Stripe,
payment, return, and inventory state. Do not claim a live Stripe payment
integration in the default setup or call the flow a distributed transaction.

### 4. RabbitMQ worker path (about 2 minutes)

In a second terminal, observe the independently deployed worker:

```powershell
docker compose logs --follow padelclub-subscriber
```

In Swagger, authenticate as `admin`, use `GET /Product` to identify a product in
`DraftProductState` (the seeded starter racket, balls, and shoes are suitable on
a fresh local database), then issue `PUT /Product/{id}` with the valid request
body shown by Swagger. If the existing database has no draft product, create one
with `POST /Product` first: new products start in `DraftProductState`. The worker
should log the received event ID, product ID, and name.

Say precisely what this proves: the API commits the product update and its
`ProductUpdated` publication intent to the SQL outbox atomically, then a hosted
publisher relays that durable intent through RabbitMQ to a separately deployable
.NET 8 consumer. Do not say it proves exactly-once delivery or notification
delivery. Delivery is at least once; publishers use expiring SQL leases and the
consumer stores a durable `(Consumer, EventId)` inbox receipt before its log
side effect, so duplicate delivery is ignored.

### 5. Operational readiness and historical evaluation evidence (about 1 minute)

Still authenticated as `admin`, use the **Recommendation evaluation evidence**
and the **Operational recommendation readiness** panel on the desktop
Management overview. First show that a fresh local database reports no eligible
customer cohort and collecting online telemetry rather than inventing a result.
The cohort card is collection progress only; the impact card is descriptive
impression/click/checkout monitoring with no control group. Then select explicit UTC cutoff/end dates
and `k`, then run the same historical endpoint that Swagger exposes. Use
**Record snapshot** to persist the aggregate-only, append-only evidence record;
the panel also loads the latest saved run. Use Swagger only if you want to show
the raw JSON response. On a fresh local development
database, the panel should show **Excluded demo orders** and an unavailable
result: the seeded baskets intentionally power the player recommender demo but
are never used as recommendation-quality evidence. If verified operational
history exists, choose a range with retained operational purchases both before
and after the cutoff. A calculable but undersized result is explicitly marked
**Diagnostic cohort**, rather than being presented as a general quality claim.

Explain the response, not just a number:

1. It uses a global temporal split, so future peer purchases cannot affect the
   training ranker.
2. It compares item-to-item collaborative filtering with a distinct-buyer
   popularity baseline.
3. It reports Precision@K, Recall@K, HitRate@K, MRR@K, NDCG@K, catalog coverage,
   cohort counts, explicit quality gates, and clear limitations.
4. If the panel says **Not enough historical data** or the response is
   `isSmallSample`, say that the selected data is insufficient for a broad
   quality claim. Do not hide that result.
5. If demo or legacy/test/admin orders are shown as excluded, say this is a
   deliberate provenance safeguard, not a failed evaluation: local seed data
   must not become a claimed real-data metric.

See [the evaluation protocol](RECOMMENDATION_EVALUATION.md) for the exact
semantics.

### External real-data algorithm benchmark (about 1 minute)

Show the generated aggregate evidence file:

```powershell
Get-Content artifacts\external-real-data-benchmark\uci-online-retail-rolling-v1.json
```

If the artifact needs to be regenerated, run:

```powershell
.\scripts\Invoke-UciOnlineRetailBenchmark.ps1
```

Explain the boundary before discussing the result: this uses UCI's licensed,
de-identified Online Retail transactions and is **not** PadelClub customer data.
The workbook stays outside the repository and database; the report contains the
source SHA-256 and aggregate counts only. The runner rejects a workbook whose
hash differs from the canonical UCI source. Its locked protocol uses three
consecutive 28-day temporal folds at K=6, a 30-day return-maturity period, and
the same item-to-item ranker against popularity. UCI cancellations are matched
only to prior purchases of the same de-identified customer and product; unmatched
return quantity is disclosed rather than guessed.

The current result passed all 11 gates with 2,527 warm user-folds. Its aggregate
NDCG@6 was 7.76% for collaborative filtering versus 3.74% for the popularity
baseline (+4.02 percentage points); total top-6 hits were 1,047 versus 546.
The unmatched cancellation quantity was 6.98%, below the documented 10.00%
screening threshold, and remains visible in the artifact. Describe this as
reproducible external evidence that the algorithm beats the stated baseline on
that dataset. Do not describe it as PadelClub conversion, customer satisfaction,
or operational performance.

### 6. Quality evidence (about 1 minute)

Show the verification commands and results recorded during this implementation
pass:

```powershell
# Requires Docker Desktop: the .NET suite starts a disposable SQL Server
# container for the relational HTTP integration tests.
dotnet test PadelClub.sln --configuration Release

Set-Location UI/padelclub_desktop
flutter analyze
flutter test --no-pub

Set-Location ../padelclub_mobile
flutter analyze
flutter test --no-pub
flutter build apk --debug
```

Recorded result for the prospective-evidence pass: 102/102 .NET Release tests
passed, including Docker-backed SQL Server migration/HTTP tests for the new
consent, experiment lifecycle, analysis snapshots, and disabled-provider routes.
All 62 desktop/shared Flutter tests passed and desktop analysis was clean.
EF Core reported no pending model changes and both Compose configurations parse.
The mobile runner test and clean mobile analysis were verified in the earlier
pass. The earlier hardened isolated fresh-volume Compose rehearsal also
passed; its saved evidence is
`artifacts/clean-compose-membershipfinal/clean-compose-smoke.json`. It records SQL
bootstrap/seed, readiness, administrator/player authentication, recommendation
and evaluation contracts, draft-product RabbitMQ delivery to the worker log,
diagnostic capture, and verified cleanup of its uniquely labelled resources.
CI is configured to run the corresponding .NET, external-benchmark build,
Flutter, mobile test/build, Compose, container-image, and isolated clean-stack
smoke checks; the smoke job also verifies API authorization, evaluator
validation, recommendation schema/exclusions, and product-update permissions
before uploading its JSON result and Compose diagnostics. When evidence is
requested, the runner requires both diagnostic capture and a post-cleanup check
that its uniquely labelled Docker resources are gone.

## Questions an examiner may ask

### Is this a real recommendation system?

Yes, it ranks real product candidates from delivered purchase interactions using
item-to-item collaborative filtering. It is not a static list or a name-based
lookup. It is also not a trained ML.NET model; its ranking is calculated online
from the available order history.

### How do returns and invalid candidates affect recommendations?

Approved/refunded return quantities are subtracted before a purchase becomes a
signal. Products already retained by the player, inactive/deactivated products,
and out-of-stock products are removed before results are returned.

### How is cold start handled?

The response reports an explicit popular or new-arrival fallback when there is
insufficient collaborative evidence. It does not pretend fallback items are
personalised predictions.

### How is the messaging flow reliable?

Compose waits for RabbitMQ's actual AMQP listener and the subscriber retries a
transient initial subscription failure with bounded backoff, so startup timing
does not leave the worker silently unsubscribed. The product update and its
outbox row are one SQL transaction; a hosted publisher retries pending rows
with bounded exponential backoff. The correct answer is that this is
at-least-once delivery, not exactly once. Publishers atomically claim rows with
an expiring SQL lease, and the consumer has an inbox/deduplication record keyed
by its subscription ID and event ID. The current business side effect is only a
log entry; future external effects still need their own idempotent persistence.

### What remains after this implementation pass?

The external benchmark, formal data profile, provenance gates, and immutable
evaluation-run snapshots are complete. The recommender now also has explicit
analytics consent, a fixed prospective CF-versus-popularity control/treatment
protocol, sticky server assignment, and immutable aggregate analysis runs. The
remaining work is collecting a genuine mature PadelClub customer cohort through
that protocol; until every closed/matured per-arm gate passes, its report is
honestly `Collecting` with null lift rather than a causal result. Historic
online telemetry remains descriptive only.
Do not turn unverified legacy rows or development seed data into operational
recommender quality evidence. The Player Hub, customer return request/status
tracking, membership self-service, staff reservation and return-resolution
actions, membership self-service and owner-scoped payment history, staff
membership/order-fulfilment lifecycle actions, coupon management, inventory
adjustment/history, administrator tournament management/one-way bracket
generation, read-only audit/delivery-attempt diagnostics, and privacy
export/deletion controls are client-complete. Other Phase 3-8 endpoints remain
API-led until a visible, tested client workflow exists. Stripe and Firebase,
and credentials for any third-party SMTP provider, are unconfigured in the
default local setup; local Mailpit is development-only and not a live provider
 integration. Stripe refunds now use durable provider-refund recording, SQL
 leases, Stripe metadata/idempotency reconciliation, and final owner-checked
 SQL settlement. This closes the earlier untracked provider-accepted/SQL-crash
 window, but it remains a recoverable saga rather than a distributed commit.

## Do not overclaim

- Do not call the recommender a separately trained, saved ML model.
- Do not call the dashboard preview cards live data.
- Do not call local Mailpit or absent third-party Stripe, Firebase, or SMTP
  credentials a live integration.
- Do not claim RabbitMQ delivery or subscriber side effects are exactly-once or
  transactionally coupled to SQL Server.
- Do not call the durable Stripe-refund reconciliation flow a distributed
  transaction or live-provider proof without actual Stripe credentials and an
  observed provider result.
- Do not call a successful bounded provider rehearsal a recipient read receipt,
  a customer payment, a live production integration, or a distributed
  transaction.
- Do not call the prospective recommender experiment a PadelClub impact result
  until it has real consented production participants, a closed/matured window,
  and every server-reported per-arm gate.
- Do not call the external UCI benchmark a measurement of PadelClub customers.
- Do not rely solely on seed data: have the stack running and the worker log
  visible before the examiner arrives.
