# PadelClub

PadelClub is a padel-club management platform developed for the RS2 project. The system
contains a player-facing mobile/desktop Flutter client, a desktop administration panel, an
ASP.NET Core REST API, SQL Server persistence, RabbitMQ messaging, and a separate subscriber
worker for asynchronous product-update events.

**Project:** PadelClub
**Academic year:** 2025/26
**Platform:** Windows desktop, Android/iOS client, ASP.NET Core backend

---

## Table of Contents

1. [Technology Stack](#technology-stack)
2. [System Architecture](#system-architecture)
3. [Implemented Features](#implemented-features)
4. [Database and Seeding](#database-and-seeding)
5. [Testing Access](#testing-access)
6. [Configuration](#configuration)
7. [Running the System](#running-the-system)
8. [API and Swagger](#api-and-swagger)
9. [Recommendation System](#recommendation-system)
10. [Testing and Verification](#testing-and-verification)
11. [Build and Release](#build-and-release)
12. [Security and Production Boundaries](#security-and-production-boundaries)

---

## Technology Stack

### Backend and Worker

- **Framework:** .NET 8 and ASP.NET Core Web API
- **Persistence:** Entity Framework Core 8, Code First migrations
- **Database:** Microsoft SQL Server 2022
- **Authentication:** JWT access tokens, refresh-token rotation, revocation and role policies
- **Messaging:** RabbitMQ with a transactional SQL outbox
- **Background processing:** .NET hosted workers and a separate subscriber service
- **Payments:** Stripe integration boundary with durable refund reconciliation
- **Notifications:** SMTP adapter, Mailpit for local development, optional Firebase Cloud Messaging

### Desktop and Mobile Applications

- **Framework:** Flutter and Dart
- **Desktop:** Windows administration and player application
- **Mobile:** Android/iOS runner sharing the player-facing implementation
- **Networking:** REST API integration with authenticated requests
- **UI:** Material 3 and shared Flutter feature modules

### Development and Operations

- Docker Desktop and Docker Compose
- Swagger/OpenAPI
- xUnit and ASP.NET integration tests with SQL Server Testcontainers
- Flutter widget tests and static analysis
- GitHub Actions CI for .NET, Flutter and container verification

---

## System Architecture

The local system is composed of the following services defined in
[docker-compose.yml](docker-compose.yml):

1. **`padelclub-api`** - ASP.NET Core REST API for authentication, bookings, commerce,
  memberships, tournaments, notifications, privacy and administration.
2. **`padelclub-subscriber`** - independent .NET worker that consumes product-update events
  from RabbitMQ and records them through a durable SQL inbox.
3. **`padelclub-sql`** - SQL Server 2022 database used by the API and subscriber.
4. **`padelclub-rabbitmq`** - RabbitMQ broker for asynchronous product-update delivery.
5. **`padelclub-mailpit`** - local SMTP catcher and browser inbox for development email.
6. **Flutter clients** - `UI/padelclub_desktop` contains the shared implementation and Windows
  runner; `UI/padelclub_mobile` provides the Android/iOS runner.

The product update flow is transactional on the application side: the product change and its
outbox record are committed together in SQL. Delivery is intentionally at-least-once; the
subscriber's durable `(Consumer, EventId)` inbox prevents duplicate processing of the same event.

---

## Implemented Features

- JWT login, refresh-token rotation, email-verification and password-recovery endpoints.
- Courts, availability and reservation workflows with server-side booking rules.
- Products, cart, orders, stock-aware catalogue, and an explainable item-to-item product recommender.
- A shared player-facing Flutter experience for desktop and mobile runners: player-profile
  onboarding, partner invitations, tournament registration/response/withdrawal/bracket viewing,
  match-result reporting/confirmation, owner-scoped product-return requests and status tracking,
  membership self-service, read-only owner-scoped payment history, and privacy
  export/deletion-request controls.
- Desktop administration, including an administrator-only recommendation-evaluation evidence
  panel with immutable snapshots, staff maintenance/no-show reservation actions, return-resolution
  work queue, constrained order-fulfilment transitions, staff membership lifecycle management,
  coupon management, stock adjustment with auditable inventory history, tournament CRUD with
  one-way bracket generation, a read-only audit trail, and read-only notification-delivery
  diagnostics.
- A transactional SQL outbox for product-update events and a separately deployable .NET 8 subscriber worker.

The recommender is application-side collaborative filtering over delivered order history. It
does not claim to be a separately trained ML model; see [RECOMMENDATION_SYSTEM.md](RECOMMENDATION_SYSTEM.md)
for its data, ranking, fallback, and test boundaries.

Development purchase baskets are explicitly marked as seeded demo data. Order provenance also
distinguishes integration-test, administrator-created, authenticated-checkout, verified-import,
and unverified legacy rows. The historical evaluator accepts only eligible checkout/import rows
with a real delivery timestamp and reports all exclusions, so local demo or legacy rows can
never be presented as operational quality evidence.

Administrators can use `GET /Operations/recommendations/cohort-readiness` to see
aggregate-only collection progress for future genuine checkout history (delivery
and return timestamp gaps, volume/diversity progress, and calendar maturity).
It is a preflight, never a quality score: only a later explicit temporal
evaluation can produce a diagnostic or qualified evidence tier.

The repository also contains a separate, reproducible benchmark on UCI's licensed external
Online Retail transactions. It is real-data evidence for the ranking algorithm only: it never
imports public records into PadelClub and must not be described as PadelClub customer performance.

### Recommendation System

The production recommender is application-side item-to-item collaborative filtering over eligible
delivered order history. It provides explainable ranking reasons and uses labelled fallbacks when
there is not enough history. It is not presented as a separately trained machine-learning model.

The repository also contains a reproducible external UCI Online Retail benchmark. That benchmark
evaluates the ranking algorithm only and never imports public records into the PadelClub database.
See [RECOMMENDATION_SYSTEM.md](RECOMMENDATION_SYSTEM.md) and the
[evaluation protocol](docs/RECOMMENDATION_EVALUATION.md) for the data, ranking, fallback,
leakage and evidence boundaries.

For the assessed walkthrough, use [the exam demo guide](docs/EXAM_DEMO_GUIDE.md).
The runtime, recommendation, messaging, and dashboard boundaries are documented
in [the architecture guide](docs/ARCHITECTURE.md).
The recommendation's leakage-aware historical backtest is documented in
[the evaluation protocol](docs/RECOMMENDATION_EVALUATION.md), with its formal
[data profile and exploratory analysis](docs/RECOMMENDATION_DATA_PROFILE.md).

---

## Database and Seeding

The API uses SQL Server 2022 with Entity Framework Core migrations. The Compose stack starts
SQL Server as `padelclub-sql`, applies the application database bootstrap, and stores data in
the named `PadelClub` database. SQL Server data is persisted in the `sql_data` Docker volume.

Demo data is opt-in. To enable it for a local walkthrough, set the following values in `.env`
before starting the API:

```dotenv
SEED_DEMO_DATA=true
DEMO_PASSWORD=<local-demo-password-at-least-12-characters>
```

The seed creates the development accounts `admin` and `player1`, both using the configured
`DEMO_PASSWORD`. These accounts and seeded orders are for demonstration only. Demo seeding must
be disabled in production, and the password must never be stored in source control.

The project also includes SQL backup and verification scripts in `scripts/`. Production backups
must be encrypted, stored off-host, retained according to policy, and periodically restored in a
separate environment.

---

## Testing Access

There are no checked-in default production credentials. For a local demonstration, enable the
development seed as described above and use:

| Role | Username | Password | Purpose |
| --- | --- | --- | --- |
| Administrator | `admin` | value of `DEMO_PASSWORD` | Desktop administration and operational workflows |
| Player | `player1` | value of `DEMO_PASSWORD` | Player/mobile workflows |

These credentials are generated only when `Database:SeedDemoData` is enabled. They must not be
used or enabled in a production deployment.

## Prerequisites

- Docker Desktop with Docker Compose
- .NET SDK 8 (for local API/worker builds and tests)
- Flutter SDK (for desktop or mobile client development)

## One-command local stack

Copy the local-only environment template, set a local signing key, then start the stack
from the repository root:

```powershell
Copy-Item .env.example .env
$env:AUTH_SIGNING_KEY = "local-development-signing-key-at-least-32-chars"
docker compose up --build --detach
docker compose ps
```

The key must be supplied through `.env` or the current process environment because Compose
requires `AUTH_SIGNING_KEY` and will stop startup when it is missing or shorter than 32
characters. Use a different random value for every environment. The `.env` file is local-only
and must not be committed.

The local Compose stack exposes:

- API and Swagger: `http://localhost:5000/swagger`
- Mailpit inbox: `http://localhost:8025`
- RabbitMQ management: `http://localhost:15672`
- SQL Server: `localhost,1433`

## Isolated clean exam rehearsal

Before the exam, you can prove a fresh bootstrap without stopping or reusing the
normal local `padelclub` stack:

```powershell
.\scripts\Invoke-CleanComposeSmoke.ps1 -Cleanup
```

The script creates a separately named Compose project with fresh SQL, RabbitMQ,
and data-protection volumes. It exposes only its API on `http://localhost:5100`,
checks database bootstrap, readiness, admin/player login, recommendations, the
evaluation endpoint, and the RabbitMQ worker delivery, then removes only those
isolated resources. Use `-ProjectName` to choose another project name if a
previous interrupted rehearsal exists.

It also verifies the HTTP contract on the real API: anonymous recommendation
requests are rejected, players cannot use administrator-only evaluation or
product-update routes, invalid evaluation requests return validation errors, and
the recommendation response contains unique, complete items while excluding
`player1`'s retained Control Racket. On a fresh development stack it also proves
that seeded demo orders are excluded from the evaluator rather than producing a
fabricated quality result.

To retain the same compact result and diagnostics locally, add
`-EvidenceDirectory artifacts/clean-compose-smoke`; that directory is ignored
by Git and is the artifact layout used in CI. With evidence enabled, the runner
fails if it cannot capture Compose diagnostics or verify that no resources with
its unique Compose-project label remain after cleanup.

When demo seeding is explicitly enabled with `Database:SeedDemoData=true`, the API creates these development accounts. Set the same secret in `Database:DemoPassword`; there is no checked-in default password:

| User | Password | Intended role |
| --- | --- | --- |
| `admin` | value of `Database:DemoPassword` | Desktop administrator |
| `player1` | value of `Database:DemoPassword` | Player/mobile experience |

These credentials are for local demonstration only and must never be enabled in production.

## Flutter clients

The desktop package contains the shared feature implementation. The mobile package supplies
the Android/iOS runners and imports that shared package intentionally.

Desktop on the host:

```powershell
Set-Location UI/padelclub_desktop
flutter pub get
flutter run -d windows --dart-define=baseUrl=http://localhost:5000
```

Android emulator:

```powershell
Set-Location UI/padelclub_mobile
flutter pub get
flutter run --dart-define=baseUrl=http://10.0.2.2:5000
```

For an iOS simulator use `http://localhost:5000`. For a physical device, provide a
reachable LAN address, for example `--dart-define=baseUrl=http://192.168.x.x:5000`.

## Local API instead of the API container

Run either the Compose API service or the local API profile, not both on port 5000. To run
the API from the .NET SDK while using Compose dependencies:

```powershell
docker compose up --detach padelclub-sql padelclub-rabbitmq padelclub-mailpit
dotnet run --project PadelClub.WebAPI --launch-profile http
```

The local launch profile listens on HTTP `5000` and HTTPS `5001`. The appsettings files use
Windows-integrated SQL Server for this mode; override `ConnectionStrings__DefaultConnection`
if your local SQL Server uses different credentials.

## API and Swagger

When the local Compose stack is running, Swagger UI is available at
[http://localhost:5000/swagger](http://localhost:5000/swagger). The API also exposes:

- `GET /health/live` for process liveness
- `GET /health/ready` for SQL Server readiness
- authentication, refresh-token and account recovery endpoints
- court availability and reservation endpoints
- catalogue, cart, checkout, order, return and inventory endpoints
- membership, tournament, player-experience and review endpoints
- privacy export/deletion and administrator operations endpoints
- recommendation serving, readiness and evaluation endpoints

Swagger is the source of truth for the complete route and schema list. API authorization is
enforced server-side; hiding a client control is not considered a security boundary.

## Configuration

`.env.example` is the canonical, safe configuration template for the Compose stack. Copy it
to `.env`, replace development placeholders where necessary, and keep the copied `.env` local;
it is ignored by Git. The following values are supported:

| Group | Variables | Purpose |
| --- | --- | --- |
| SQL Server | `MSSQL_SA_PASSWORD` | Local SQL Server administrator password. |
| Authentication | `AUTH_SIGNING_KEY` | JWT signing key; required and at least 32 characters. |
| RabbitMQ | `RABBITMQ_DEFAULT_USER`, `RABBITMQ_DEFAULT_PASS` | Broker credentials used by the API and subscriber. |
| Payments | `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`, `STRIPE_CURRENCY` | Optional Stripe integration and currency. |
| Notifications | `SMTP_HOST`, `SMTP_PORT`, `SMTP_STARTTLS`, `SMTP_USERNAME`, `SMTP_PASSWORD`, `SMTP_FROM_ADDRESS`, `SMTP_FROM_NAME` | SMTP delivery settings. |
| Push notifications | `FIREBASE_PROJECT_ID`, `FIREBASE_SERVICE_ACCOUNT_JSON` | Optional Firebase Cloud Messaging configuration. |
| Provider verification | `PROVIDER_VERIFICATION_*` | Explicitly disabled, bounded provider-readiness rehearsals. |
| Demo data | `SEED_DEMO_DATA`, `DEMO_PASSWORD` | Opt-in development seed accounts and data. Never enable in production. |

For a local demo, the default SMTP values target Mailpit. This captures messages in the local
Mailpit inbox and does not send real email. Stripe, Firebase, and external SMTP are intentionally
empty by default.

### Production secrets and environment

Before production startup, set real values in the deployment platform's secret store or process
environment. The following PowerShell names show the required contract only:

```powershell
$env:ASPNETCORE_ENVIRONMENT = "Production"
$env:AUTH_SIGNING_KEY = "<random-production-key-at-least-32-characters>"
$env:SMTP_HOST = "<real-smtp-host>"
$env:SMTP_PORT = "587"
$env:SMTP_STARTTLS = "true"
$env:SMTP_USERNAME = "<real-smtp-user>"
$env:SMTP_PASSWORD = "<secret-from-secret-store>"
$env:SMTP_FROM_ADDRESS = "noreply@<production-domain>"
```

The production signing key, SMTP password, Firebase service-account JSON, Stripe keys, database
password, and RabbitMQ password must never be committed to `docker-compose.yml`, `.env.example`,
the README, or any other source-controlled file. Set `SEED_DEMO_DATA=false` or leave it unset in
production. Production deployments must also use production-specific database, broker, SMTP,
Stripe, Firebase, HTTPS, backup, logging, and monitoring configuration.

The API and worker read `ConnectionStrings:RabbitMq`. Compose overrides it to point both
containers at `padelclub-rabbitmq` using a non-guest account. RabbitMQ's `guest` account is
not suitable for container-to-container communication. The subscriber also reads
`ConnectionStrings:DefaultConnection` so its durable inbox is stored in the same
SQL Server database as the outbox.

## Messaging demo

`DraftProductState.UpdateAsync()` writes a `ProductUpdated` payload to the SQL
outbox in the same EF Core save operation as a draft-product update. The hosted
publisher atomically leases due rows before dispatching them to RabbitMQ, so
multiple API replicas do not intentionally publish the same row concurrently.
The `padelclub-subscriber` worker consumes that shared message contract, records
its named `EventId` receipt in SQL, and only then writes its structured log line.
This demonstrates an independently deployable broker/worker path without losing
a committed update merely because RabbitMQ is temporarily unavailable.

Compose waits for RabbitMQ's actual AMQP listener before starting dependent services, and the
subscriber retries transient initial-subscription failures with bounded backoff.
The publisher retries durable pending rows with bounded exponential backoff.
This makes the clean-stack rehearsal resilient to normal broker startup timing
and broker recovery.

The SQL outbox is transactional for the product update plus its publication
intent, but broker delivery is deliberately **at least once**, not exactly once.
Leases expire and are safely reclaimed after a publisher crash; a crash after
broker publication can still re-send the stable outbox ID as `EventId`. The
subscriber's durable `(Consumer, EventId)` inbox ignores repeated delivery. Its
current business side effect remains a structured log, so any future external
side effect must be committed with its own idempotent business record rather
than being described as exactly once.

## Testing and Verification

```powershell
dotnet build PadelClub.sln --configuration Release
dotnet test PadelClub.sln --configuration Release --no-build

# Optional focused run: starts a disposable SQL Server container and applies
# the real EF Core migrations before exercising HTTP contracts.
dotnet test PadelClub.WebAPI.Tests/PadelClub.WebAPI.Tests.csproj --configuration Release --no-build --filter FullyQualifiedName~ApiIntegrationTests

Set-Location UI/padelclub_desktop
flutter analyze
flutter test

Set-Location ../padelclub_mobile
flutter analyze
flutter test
flutter build apk --debug

# Downloads UCI's public workbook to a temporary directory and writes
# aggregate/hash-only external recommendation evidence. It does not import it
# into the PadelClub database.
Set-Location ../..
.\scripts\Invoke-UciOnlineRetailBenchmark.ps1
```

The .NET suite includes a SQL Server Testcontainers HTTP slice. It uses a
digest-pinned disposable database, applies the production EF Core migrations,
then verifies real login/JWT handling, recommendation authorization and ranking,
evaluator role/validation/provenance behavior, and an administrator inventory
transaction. Docker Desktop is therefore required for the .NET test command.

### Submission verification checklist

Before submitting the project, run the checks relevant to the environment and keep the output
as evidence for the defense:

1. Copy `.env.example` to `.env`, provide a local signing key, and start the Compose stack.
2. Confirm `http://localhost:5000/swagger`, `/health/live`, `/health/ready`, Mailpit, and
   RabbitMQ management are reachable.
3. Run the Release .NET build and test suite, then run Flutter analysis and tests for both
   desktop/shared and mobile projects.
4. Run `./scripts/Invoke-CleanComposeSmoke.ps1 -Cleanup` to verify a fresh database, API
   authorization, recommendation contracts, and outbox/subscriber delivery.
5. Confirm that `.env`, production secrets, database backups containing sensitive data, and
   generated artifacts are not included in the submitted source archive.
6. For production deployment, verify that secrets come from the deployment secret store, that
   demo seeding is disabled, and that backup/restore, HTTPS, monitoring, retention, and rollback
   procedures are defined by the target environment.

## Build and Release

### Backend and containers

```powershell
dotnet restore PadelClub.sln
dotnet build PadelClub.sln --configuration Release
docker compose build
```

The solution includes the API, services, shared model, tests and subscriber worker. The
subscriber has its own Dockerfile and is deployed separately from the API container while using
the shared RabbitMQ and SQL Server services.

### Desktop application

```powershell
Set-Location UI/padelclub_desktop
flutter pub get
flutter analyze
flutter test
flutter build windows --release
```

The Windows release is produced under
`UI/padelclub_desktop/build/windows/x64/runner/Release/`.

### Mobile application

```powershell
Set-Location UI/padelclub_mobile
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

The Android release APK is produced under
`UI/padelclub_mobile/build/app/outputs/flutter-apk/`.

For a real production release, publish only after configuring HTTPS, the secret store, database
migrations, backup and restore, monitoring, provider credentials, retention rules and a rollback
procedure for the selected deployment platform.

## Security and production boundaries

- Authentication uses JWT access tokens, refresh-token rotation, revocation, role policies,
  email verification, password recovery, and rate limiting.
- Authorization is enforced server-side; client visibility is not treated as a security control.
- Privacy export and scheduled deletion are owner-scoped and preserve legally relevant financial
  records in anonymized form. Retention periods still require a deployment-specific legal review.
- SQL Server backups must be encrypted, copied off-host, retained according to policy, and tested
  with both verification and periodic full restore.
- RabbitMQ delivery is at-least-once. The subscriber uses a durable inbox to deduplicate event
  IDs; the system does not claim exactly-once distributed processing.
- Mailpit is a development mail catcher. Provider acceptance is not proof of recipient delivery.
- Membership renewal and payment-history screens do not collect card details or prove that a live
  payment occurred. Stripe and Firebase are optional integrations and require real credentials,
  provider configuration, webhook handling, and deployment monitoring.
- Automated tests and CI do not replace manual accessibility, legal, infrastructure, migration,
  rollback, and live-provider verification before a real production launch.

The prospective-evidence implementation pass verified 102/102 .NET Release
tests, including Docker-backed SQL Server HTTP/refund tests and the new
consent, experiment lifecycle, stored-analysis, and disabled-provider routes.
All 62 desktop/shared Flutter tests passed and desktop analysis was clean.
EF Core reported no pending model changes; both Compose configurations parse.
The earlier pass verified the 1/1 mobile runner test and clean mobile analysis.
The earlier hardened isolated fresh-volume Compose rehearsal also passed; its
compact result and diagnostics are available locally under
`artifacts/clean-compose-membershipfinal/`.

CI restores/builds/tests the .NET solution (including that relational HTTP slice),
pins Flutter 3.44.5, analyzes/tests both Flutter runners, checks the Compose
configuration, and builds the API and subscriber images. Its
`compose-smoke` job then runs the same isolated fresh-volume rehearsal and
uploads a JSON result plus Compose diagnostics. The job uses a unique project
name, checks the API authorization/validation/recommendation contracts, and
verifies that no namespaced resources remain after cleanup.

The external benchmark enforces the canonical UCI workbook SHA-256 and uses a
locked three-fold temporal protocol at K=6 with 30-day return maturity. It
records cleaning/netting counts, fold metrics, quality gates, and a
popularity-baseline comparison in
`artifacts/external-real-data-benchmark/uci-online-retail-rolling-v1.json`.
The latest run passed all 11 gates with 2,527 evaluated user-folds and NDCG@6 of
7.76% for collaborative filtering versus 3.74% for popularity. See
[the evaluation protocol](docs/RECOMMENDATION_EVALUATION.md) for the mandatory
external-versus-operational evidence boundary.

## Current scope boundaries

The following Phase 3-8 workflows have complete, visible Flutter paths: the Player Hub
(profile, partner invitations, tournament registration/invitation response/withdrawal/bracket,
and match reporting/confirmation); owner-scoped product-return request/status tracking;
membership status/activity, automatic-renewal settings, and end-of-period cancellation;
read-only owner-scoped payment history;
staff reservation maintenance/no-show and return-resolution actions; administrator coupon
create/edit/enable/disable management; administrator stock adjustments and inventory history;
administrator tournament create/edit/hard-delete and server-validated bracket generation;
read-only administrator audit-trail and notification-delivery diagnostics; and account-data
export plus scheduled deletion controls. They still rely on server-side authorization and
validation.

Other advanced endpoints remain deliberately API-led unless a corresponding client screen is
present. Membership self-service changes the server-side membership record; it does not collect
card details, create a payment, or prove that a renewal charge occurred. Stripe and Firebase,
and credentials for any third-party SMTP provider, remain unconfigured in the default local
setup; local Mailpit only captures development mail and is not a live provider integration. When
Stripe is configured, return approval uses a durable `ProviderRefundOperation`: SQL commits the
refund intent first, a leased worker reconciles Stripe metadata/idempotency, and a final SQL
transaction records the refund and restores stock once. This closes the prior untracked
provider-accepted/SQL-crash window, but it is a recoverable saga—not a distributed transaction
or evidence of a live Stripe integration. **Audit Trail -> Provider readiness** offers a
credential-free configuration-only snapshot for Stripe, SMTP, and Firebase and explicitly makes
no provider calls. A separate default-deny administrator verification endpoint can persist an
observed, bounded rehearsal only after explicit confirmation and configured fixed targets: Stripe
is test-mode read-only, while SMTP/FCM success means provider acceptance rather than recipient
receipt. It does not make the default setup a live provider integration. The recommendation system
now has explicit analytics consent plus a fixed prospective 50/50 collaborative-filtering versus
popularity experiment with immutable assignment and analysis snapshots. It still has no mature
production PadelClub participant cohort or causal online-impact result; historic/descriptive
telemetry cannot be relabelled as an experiment outcome. See the bounded
[provider-verification protocol](docs/PROVIDER_VERIFICATION.md) and the
[recommendation evaluation protocol](docs/RECOMMENDATION_EVALUATION.md) for
the exact evidence boundaries.
The delivery-diagnostics screen is deliberately inspection-only: it shows persisted delivery
attempts, not recipient read receipts, and it neither retries a message nor proves that a provider
is configured locally.
Tournament deletion follows the current generic API and is a confirmed hard delete. Bracket
generation is deliberately separate and one-way: it is only accepted when the server finds
complete confirmed teams and an active court, and an existing bracket cannot be regenerated.
Payment history is also read-only and owner-scoped. It displays persisted server records and
their reconciliation/refund metadata; it neither collects payment data nor proves a local Stripe
or other payment-provider configuration.

## Project structure

```text
PadelClub/
|- PadelClub.Model/                 Shared DTOs, requests, responses and message contracts
|- PadelClub.Services/              EF Core persistence and business services
|- PadelClub.WebAPI/                ASP.NET Core controllers, workers and API configuration
|  `- PadelClub.Subscriber/         .NET 8 RabbitMQ product-update worker
|- PadelClub.WebAPI.Tests/          Unit and contract-oriented tests
|- tools/PadelClub.RecommendationBenchmark/
|                                   External real-transaction evaluator (aggregate evidence only)
|- UI/padelclub_desktop/            Desktop runner and shared Flutter features
|- UI/padelclub_mobile/             Android/iOS runner
|- docker-compose.yml               Local SQL Server, API, Mailpit, RabbitMQ and worker stack
`- scripts/                         Database backup verification scripts
```
