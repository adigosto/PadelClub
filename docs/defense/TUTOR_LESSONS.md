# Tutor lessons: study one stage at a time

Use [the screen map](PROJECT_MAP.md) for the navigation, data, endpoint, handler, entity, validation, action, edge case and demonstration details of each screen. Use [the database guide](DATABASE.md) for exact entity/relationship examples. This document explains how to reason about those facts.

## Stage 1 — The system and its architecture

### What it is

PadelClub is one club-management system with two client distributions. Staff manage club operations on desktop. Players book courts, shop and manage activity on mobile. Both clients call one ASP.NET Core API, which stores the shared records in SQL Server.

### Why it exists

Desktop and mobile need different interfaces, but the same price, stock, booking and identity rules. Centralizing persistent data and authoritative rules lets both interfaces work with the same club records.

### How it works

The mobile runner imports the shared Flutter package and starts PadelClubBootstrap. MaterialApp defines routes and MultiProvider provides shared state objects. The platform chooses the shell; the account role controls management access. HTTP requests carry JSON and an Authorization header. Backend DI creates controllers/services with the database context. A separate worker consumes product events.

### Important code

`UI/padelclub_mobile/lib/main.dart`; shared `lib/main.dart`, `layouts/master_screen.dart`, `core/di/injection.dart`; `PadelClub.WebAPI/Program.cs`; `PadelClub.Services/Database/PadelClubContext.cs`; `docker-compose.yml`.

### Request/data flow

Read example: `ProductListScreen._loadProducts → LoggedProductProvider.get → ProductProvider.get → GET /Product → inherited BaseController.Get → ProductService/BaseService.GetAsync → ApplyFilter → CountAsync if requested → OrderBy/Skip/Take → ToListAsync → Mapster ProductResponse → JSON → Product.fromJson/SearchResult → setState`.

The order of filtering/paging matters: filtering defines eligible rows first; paging selects a slice. The app does not download SQL tables directly. Some providers use repository/use-case chains, but this product path directly performs HTTP.

### What I should demonstrate

Open the two pubspec/main files to prove code sharing. Open Program's registrations and the context. Trace the product GET above without jumping from the screen straight to SQL.

### What I should say

“The desktop and mobile distributions reuse a Flutter package and call a shared .NET 8 API. SQL Server holds the club records. The backend uses services and EF Core, with some workflow logic directly in controllers. RabbitMQ delivers durable product-update events to a separate subscriber.”

### What the professor could ask

Why does the mobile package depend on a package named desktop? Are the clients directly connected? Is this uniformly Clean Architecture? Where does the actual HTTP call happen?

### What I absolutely need to understand

Folder names do not establish runtime boundaries. A provider changes local UI state; SQL persists shared state. Reloading data is what makes another client see a committed change. A service interface is not a separate network service.

## Stage 2 — Authentication before demonstrating desktop

### What it is

Authentication establishes who the caller is. Authorization decides whether that caller can perform a specific action on a particular resource.

### Why it exists

The API must reject unauthorized manual requests even if a user bypasses Flutter. Owner scoping prevents an authenticated player from using someone else's private records.

### How it works

LoginPage validates inputs and AuthProvider posts username/password to `/Users/login`. AuthService delegates to UserService.AuthenticateAsync, which loads the user plus roles and verifies the password. Inactive users fail login. Success returns a signed JWT, opaque refresh token and user response.

The active algorithm is PBKDF2-HMAC-SHA256 with 100,000 iterations, 16-byte random salt and 32-byte key. UserService supports its separate legacy hash/salt fields and the newer dot-separated `iterations.salt.key` format through PasswordHasher. Do not call the algorithm BCrypt just because the package is referenced. Passwords are verified by deriving/comparing a hash, not decrypted.

The JWT contains caller ID/name/roles/email-verified claim and expiry, signed with HMAC-SHA256. JWT bearer middleware validates signature, issuer, audience and lifetime with 30-second skew. Refresh tokens are random opaque secrets; only their SHA-256 hashes are stored. Rotation atomically consumes a token; reuse of an already consumed token revokes its family. Logout revokes the submitted refresh token; it does not instantly invalidate an already issued access JWT.

Remember-me stores username/refresh token using secure storage. The displayed password placeholder is not a recovered plaintext password. Access token lives in static provider state; a fixed 12-minute timer attempts refresh. Recovery and email-verification endpoints have purpose-specific, expiring, one-use opaque tokens; recovery responses avoid revealing whether an email exists.

### Important code

`UsersController`, `Authentication/AuthService`, `Authentication/AuthOptions`, `UserService.AuthenticateAsync/VerifyPassword`, `PasswordHasher`, `Program.cs` JWT/policy registration, `AuthProvider.login/_restoreSession/logout/authenticatedHeaders`.

### Request/data flow

`credentials → login endpoint → database user/roles → password verification → session tokens → client → Bearer JWT → middleware → policy → ownership check → operation`.

### What I should demonstrate

Wrong password → 401; valid admin → desktop; player on desktop → management access denied. In Swagger, player token GET `/Product` succeeds; player token PUT `/Product/{id}/activate` fails with 403. Without token, protected request fails with 401. Use `/Users/me` to prove current identity.

### What I should say

“Hiding a button is only a usability measure. Admin mutations have the AdminOnly policy, which requires the Administrator claim established by a validated JWT. Private self-service actions also derive the owner ID from the authenticated caller.”

### What the professor could ask

What is the difference between 401 and 403? Why hash refresh tokens? What happens after a role is removed while an old JWT remains valid? Does VerifiedPlayer require the Player role? Where is ownership missing today?

### What I absolutely need to understand

JWT payloads are signed, not secret/encrypted by default. Refresh-token revocation and access-token expiry are different. Exact backend role spelling matters. The inherited reservation GET-by-ID ownership gap must be acknowledged. See [Microsoft's role authorization documentation](https://learn.microsoft.com/en-us/aspnet/core/security/authorization/roles?view=aspnetcore-8.0) for policy/role checks.

## Stage 3 — Desktop CRUD and list behavior

### What it is

CRUD means create/read/update/delete persisted records. Workflow actions such as cancel, activate or approve are more constrained than generic CRUD.

### Why it exists

Staff maintain users/courts/catalogue and operate orders/memberships/tournaments. Reusable base classes reduce repetition, while overrides enforce domain-specific behavior.

### How it works

For ordinary court creation, the form builds a JSON body; CourtProvider posts `/Courts`; the admin-only override calls BaseCRUDController.Create; BaseCRUDService creates/maps the entity, calls BeforeInsert, adds it to the context and awaits SaveChangesAsync; the response returns and provider reloads. Update finds an existing entity, maps into it, invokes BeforeUpdate, saves and returns it. Delete invokes BeforeDelete then removes/saves. A missing generic DELETE returns false rather than universally returning 404.

User creation additionally checks uniqueness, hashes the password, assigns valid roles and creates a notification. Product creation/update use the State pattern and bypass parts of that generic hook path. Do not explain every feature as if it uses the unchanged base implementation.

### Important code

User/Court/Product management screens and providers; BaseCRUDController, BaseCRUDService, UserService, CourtService, ProductService; each corresponding request/search/response class.

### Request/data flow

`Save form → JSON insert/update request → role policy → controller → virtual service method/hooks → tracked entity → SaveChangesAsync → response DTO → provider reload → screen`.

### What I should demonstrate

Visit User Management, Court Management, Product Management, Memberships, Order Management, Reservation Management, Tournament Management, Notifications and Audit Trail in that order during study. For each screen use its entry in PROJECT_MAP: perform its visible operation, locate its API and explain the database row. During the short final demo select only the strongest examples.

### What I should say

“The common CRUD implementation persists entities through EF Core, and concrete services add specialized checks. A lifecycle operation may use a different method and transaction because a simple field update is insufficient.”

### What the professor could ask

Which hooks run for product create? Why does deleting a used court fail? Why return a DTO? Are the list filters SQL queries or Dart list filtering?

### What I absolutely need to understand

BaseService defaults to Page 1/PageSize 10; Page below 1 is clamped, TotalCount is optional, and nonpositive PageSize bypasses Take. It orders by integer Id before paging. User/court/product/order/notification screens commonly fetch capped snapshots and filter locally. Membership Management uses server paging. Shop requests server pages but omits the total-count flag needed by its next-page UI. These are distinct behaviors, not one universal pagination implementation.

## Stage 4 — Mobile walkthrough and authoritative booking

### What it is

The player shell groups club updates, discovery, booking, shop and account features into five destinations.

### Why it exists

Players need simple actions while the backend prevents conflicting bookings and computes prices consistently for every client.

### How it works

Start at Login → Home: Home concurrently loads own bookings, notifications and reviews. Search loads discovery and links to Player Hub. Reservations loads date-based court slots. Shop loads products/recommendations and opens details/cart/My orders. Profile exposes contact/password/verification, memberships/payments/preferences/privacy and logout.

For booking, controller overwrites UserId from JWT, status to Confirmed and the submitted total. ReservationService validates interval, time-zone schedule, active references, overlap and maintenance inside a serializable transaction. Price is hourly rate times duration, rounded to two decimals. Reservation and notification records are committed. Another screen then reloads the same records.

### Important code

MobileHomeScreen; SearchScreen/PlayerHubScreen; MobileReservationsScreen; ReservationProvider.book/loadAvailability; ReservationsController.Create/GetMine/Cancel; ReservationService.CreateAsync/ValidateReservationAsync/GetAvailabilityAsync; BookingOptions.

### Request/data flow

`date selector → availability GET → court + reservation + maintenance queries → slot response → selected slot → reservation POST → identity/price normalization → serializable checks/save → notification → commit → own booking reload`.

### What I should demonstrate

Use a future club-local date, select a free slot, book and note the returned ID. Rebook the same slot through Swagger: it must fail. Open desktop and find it; cancel there; revisit mobile Reservations and refresh. Then study recurrence, waitlist and credits as separate extensions.

### What I should say

“The availability display is a snapshot. The backend rechecks the interval when saving because another player could book after I opened the screen. It derives my identity and calculates the price instead of trusting those fields from Flutter.”

### What the professor could ask

Why compare `existing.StartTime < requested.EndTime && existing.EndTime > requested.StartTime`? Can adjacent reservations coexist? Why a transaction? Is waitlist notification itself a booking? Does cancellation always issue credit?

### What I absolutely need to understand

The strict overlap inequalities permit adjacent slots. A transaction's isolation is part of concurrency protection; checking first in Flutter is insufficient. Confirmed booking is not the same as Completed payment. UTC/local conversion and the club time zone are different from a user's arbitrary phone time zone.

## Stage 5 — Shop, orders, stock and returns

### What it is

Cart is temporary client state. Checkout creates a durable order and line-price snapshots. Fulfillment and returns change business state and inventory.

### Why it exists

Prices/stock/coupon eligibility can change after a product is displayed. The server must calculate and save a consistent result.

### How it works

Checkout validates shipping/contact/cart, combines repeated ProductIds, validates aggregate quantities and current products/stock, computes subtotal and coupon discount, then transactionally saves Pending order/items and stock movements, coupon redemption and recommendation attribution. A notification follows commit. No card collection occurs in this UI checkout path.

Staff fulfillment uses a serializable transaction plus SQL `UPDLOCK,HOLDLOCK` on the order. It accepts Pending→Processing→Shipped→Delivered, or cancellation before dispatch. Same-state updates are allowed; stock restoration occurs only on a status change to Cancelled. DeliveredAt is set by the server when delivery actually happens.

Customer return requests validate owner, Delivered status and actual delivery timestamp within 30 days, line membership, remaining quantities and bounded proportional refund amount. Staff resolve only Requested records under an update lock. Ordinary approval restores stock and records Approved; Stripe-backed approval durably queues a refund and returns 202/RefundPending. A separate worker reconciles provider acceptance and settles stock/refund status using stable idempotency and SQL leases.

### Important code

CartProvider.checkout; ProductListScreen checkout/My orders/return dialogs; OrdersController.Checkout; OrderService.CheckoutAsync/UpdateAsync/IsAllowedTransition; CommerceCalculator; CommerceOperationsController.RequestReturn/ResolveReturn; ReturnEligibilityPolicy; ProviderRefundOperationService/Processor/Worker.

### Request/data flow

`cart quantities/address → /Orders/checkout → current prices/stock/coupon → SQL transaction → order/items/movements → desktop fulfillment → DeliveredAt → player return → staff resolution → local stock update OR durable provider refund → eventual reconciled result`.

### What I should demonstrate

Buy one low-cost demo item, show new order on desktop, advance through valid steps, refresh My orders. Show SQL order lines and inventory history. Then submit a return for an eligible delivered line and resolve it. Use local/non-Stripe demo records unless provider verification was separately rehearsed.

### What I should say

“An order is not a payment. This checkout stores an order and reserves stock. Provider refunds use a durable multi-step workflow because a database transaction cannot atomically commit Stripe's external state.”

### What the professor could ask

Can I submit my own cheaper unit price? What if two staff cancel simultaneously? Why store UnitPrice on OrderItem? Does a repeated request duplicate the refund? What if Stripe accepts and SQL fails?

### What I absolutely need to understand

Transactions cover specified SQL work, not the entire world. A saga achieves recoverable eventual consistency, not distributed ACID. The case-sensitive deactivated-product checkout check and generic admin CRUD gaps must not be disguised as complete enforcement.

## Stage 6 — Backend contracts, DTOs, mapping, validation and errors

### What it is

Controllers define HTTP contracts. Request DTOs describe inputs, response DTOs describe output, search objects describe query options. EF entities describe persistence.

### Why it exists

Different contracts avoid exposing password fields/navigation graphs and keep client expectations independent of database details. They can also prevent callers choosing fields such as identity, price and timestamps—when the controller/service enforces that boundary.

### How it works

Mapster maps matching fields in BaseCRUDService and product states; existing-entity update maps into the tracked object. UserService manually maps roles and verification state. NotificationService computes recipient-specific read state. Workflow controllers frequently Select anonymous response objects or declare local request records.

Fewer DTO fields normally means fewer mapped fields; it does not delete omitted entity properties. But a property that exists in an update DTO with null/default can overwrite an entity value. ProductService's draft-update normalization preserves omitted nullable category/type IDs specifically. Mapster is mapping convenience, not authorization or validation.

UI validators stop common mistakes early. ApiController runs model binding/DataAnnotations where present. Services check business rules. Database constraints enforce required values/unique relationships/FKs. ProductInsertRequest's lack of range/required attributes illustrates why merely saying “we use DTOs” is insufficient proof of validation.

### Important code

Model/Requests, Responses, SearchObjects; BaseController/BaseCRUDController; BaseService/BaseCRUDService; ProductService.NormalizeUpdateReferencesAsync; UserService.MapUserToResponse; NotificationService.MapToResponse; ExceptionFilter.

### Request/data flow

`JSON → model binding/DTO validation → policy/controller normalization → service rules → EF constraints → saved entity → mapped/projected response → JSON parse → UI error/success`.

### What I should demonstrate

Swagger: missing/invalid request fields, invalid ID, duplicate username, occupied booking and invalid active-product edit. Record actual status/body, not an assumed universal convention. Compare a Product response with Product entity and a User response with private storage fields.

### What I should say

“UI validation helps the user, but the API must validate independently. DTOs define a smaller contract; service checks implement the business invariants, and SQL constraints provide another enforcement layer.”

### What the professor could ask

Why not return EF entities? What happens when a DTO property is absent? Why a 409 in one endpoint and a 400 in another? Does [ApiController] reject a negative price without a Range attribute?

### What I absolutely need to understand

Actual response codes: 200 for many reads/creates; 204 for successful bodyless actions; 202 for queued refunds/recovery acknowledgments; 400 for selected validation/invalid operations; 401 unauthenticated; 403 policy denial; 404 explicit missing-resource paths; 409 controller conflicts/DB collisions; 429 auth/recovery limiter; 500 unexpected errors with correlation ID. 201 conventionally means created, but base CRUD returns 200 here. Missing generic GET can return a null/no-content result rather than an explicit 404, and generic DELETE may return 200 false.

ExceptionFilter maps UserException/ArgumentException/InvalidOperationException to 400 unless a controller catches first; KeyNotFoundException to 404; DbUpdateException to 409; unexpected errors to 500. Base CRUD catches InvalidOperationException as 409. Study the actual selected action before predicting its response.

## Stage 7 — Database and EF Core

### What it is

EF Core maps C# entities and relationships to SQL Server. DbContext is a scoped query/change-tracking unit of work; migrations version the schema.

### Why it exists

Services can express database operations in C#/LINQ while SQL preserves relational integrity and transactions. Explicit mapping controls keys, decimal types, indexes, uniqueness and delete behavior.

### How it works

Start with User→Reservation←Court, then Order→OrderItem←Product, then Payment's three optional payable links. Follow the detailed entity catalogue and SQL exercises in DATABASE.md. Examine one migration's Up, then the snapshot, then __EFMigrationsHistory in a running database.

### Important code

PadelClubContext.OnModelCreating/configuration/SaveChanges guards; ServiceCollectionExtensions.AddDatabaseServices; migrations; UserService Include/ThenInclude; BaseService pagination; OrderService transaction and SQL row claim.

### Request/data flow

`IQueryable predicates → translated SQL → materialized tracked entity or projection → mapping → response`; for writes, `tracked changes → SaveChangesAsync → SQL commands/transaction → commit`.

### What I should demonstrate

Show the exact new reservation row and joined user/court, then its cancelled status. Show order/items/stock. Show a one-to-many, a join-based many-to-many and an optional one-to-one using configuration and actual keys.

### What I should say

“The FK maintains the relationship in SQL, while the navigation property lets C# traverse it. Delete behavior is configured per relationship, so deletion can cascade, be restricted or preserve a nullable reference.”

### What the professor could ask

Why Include? What does SingleOrDefault do when two rows match? When does LINQ execute? Does SaveChanges persist an AsNoTracking mutation? Why nullable CourtId in maintenance?

### What I absolutely need to understand

An Id-named scalar is not automatically an FK. Entity navigation and serialized response are different. AsNoTracking is a query behavior; database writes/transactions remain possible. Multiple saves require an explicit transaction for all-or-nothing semantics. Do not run simultaneous EF operations on the same DbContext.

## Stage 8 — Product State pattern: high priority

### What it is

ProductState stores the class name used to select a behavior object. Each class overrides allowed operations; base methods reject operations with UserException("Not allowed.").

### Why it exists

It keeps operation permissions and transition behavior with the state rather than scattering every rule across screens and controller switches. An enum alone labels a value; it still needs behavior/transition checks somewhere.

### How it works

- InitialProductState.Create → persist DraftProductState.
- Draft.Update → map fields, save draft and ProductUpdated outbox event; remains Draft.
- Draft.Activate → ActiveProductState.
- Active.Deactivate → DeactivatedProductState. ProductService's public deactivate currently performs its own equivalent Active check/write.
- Deactivated.Activate → ActiveProductState.
- Deactivated.Update → DraftProductState; it does not apply that request's field changes.
- Active.Update, Draft.Deactivate, repeated Active.Activate and unimplemented operations fail. Initial is a creation behavior, not a long-lived persisted stage in normal creation.

### Important code

BaseProductState.GetProductState and rejecting methods; Initial/Draft/Active/DeactivatedProductState; ProductService.CreateAsync/UpdateAsync/ActivateAsync/DeactivateAsync; ProductController policies/actions.

### Request/data flow

`PUT /Product/id → ProductService finds entity → stored state name → DI-resolved state object → permitted override or base rejection → SaveChanges → ProductResponse`.

### What I should demonstrate

Create draft with valid category/type IDs, edit name, activate, repeat edit through Swagger and show refusal. Deactivate; PUT returns to draft; PUT again actually edits; activate again. Query ProductState after each step. DELETE is generic and is not governed by these state methods.

### What I should say

“The state object determines which operations are implemented. Unsupported operations inherit rejection from BaseProductState, so an invalid edit is blocked in the backend even when I call it through Swagger.”

### What the professor could ask

Why not an enum? Where is the invalid transition rejected? What does an update to a deactivated product actually change? Can delete bypass the pattern? Does ProductState equal IsActive?

### What I absolutely need to understand

Follow the override actually invoked; do not infer behavior from method name. There is no Archived state. State pattern is an implementation technique, not a claim every product invariant is covered.

## Stage 9 — RabbitMQ, SQL outbox and durable inbox: high priority

### What it is

An asynchronous product-update event path. The API is producer-side; a separate worker is consumer-side. RabbitMQ routes messages between them.

### Why it exists

A broker outage should not lose the publication intent associated with an already committed product edit. The HTTP operation should not depend on the consumer being online.

### How it works

DraftProductState.UpdateAsync adds OutboxMessage in the same SaveChanges as the edit. OutboxPublisherWorker polls every three seconds, claims up to 25 due records using SQL leases, renews before sending, awaits EasyNetQ PublishAsync, and marks published only while still owning the lease. Publish has a 90-second deadline inside a two-minute lease. Failures persist retry/error metadata with bounded exponential backoff.

ProductUpdated contains stable EventId and ProductResponse. Subscriber uses stable subscription ID `padelclub.product-update-worker.v1`, retries startup subscription, and records a unique (Consumer,EventId) inbox receipt before writing a structured log. Duplicate deliveries are recognized. The consumer currently does not update inventory, send notifications or push UI changes.

### Important code

DraftProductState; Model/Messages/ProductUpdated; OutboxPublisherWorker; SqlServerOutboxLeaseService; OutboxMessage; ProductUpdatedSubscriber; InboxDeduplicationService; InboxMessage; API/subscriber Program and Compose.

### Request/data flow

`draft PUT → product+outbox transaction → response → publisher SQL lease → RabbitMQ → subscriber → inbox receipt → log`.

### What I should demonstrate

Edit a draft and correlate EventId between outbox, inbox and worker logs. In an isolated rehearsal, establish the subscription first, stop only subscriber, edit, inspect its queue, restart and observe delivery. For broker outage, edit while the outbox retains pending publication, then restore the broker. Do not stop shared services during an unrelated user's work.

### What I should say

“The database records what must be published, then a background publisher retries delivery. The subscriber uses a durable inbox to recognize duplicates. The design is at-least-once delivery with deduplication.”

### What the professor could ask

What if the consumer is offline? What if the API crashes after publishing but before marking PublishedAtUtc? Is PublishAsync awaited? Why isn't it exactly once?

### What I absolutely need to understand

The worker awaits publishing, but the original product request does not wait for consumer processing. A crash at the broker/SQL acknowledgment boundary can produce duplicates. A never-before-declared subscription queue is different from an established durable queue with an offline consumer. Persistent messages, durable queues and publisher/consumer acknowledgments have distinct roles; verify actual broker topology rather than inventing queue names. See [RabbitMQ's reliability guide](https://www.rabbitmq.com/docs/reliability).

## Stage 10 — Docker and startup

### What it is

Compose describes API, SQL, RabbitMQ, subscriber and Mailpit containers, their configuration, dependency order, ports, network and storage.

### Why it exists

It makes the local service topology repeatable without installing each server directly on the host. Flutter desktop/mobile still run separately as clients.

### How it works

The API Dockerfile publishes with .NET SDK 8 in a build stage and runs the result with ASP.NET runtime 8. Compose builds API/subscriber images and uses existing SQL/RabbitMQ/Mailpit images. It creates bridge network `padelclub-2026`, then starts services respecting configured health/dependency checks. API startup applies migrations and seeds when enabled.

Containers resolve `padelclub-sql` and `padelclub-rabbitmq` by service name. `localhost` inside API would refer to API itself, not SQL. Host API port 5000 maps to container 5001; SQL 1433; Rabbit AMQP 5672 and management 15672; Mailpit UI 8025 and internal SMTP 1025. Double underscores map environment settings into .NET hierarchical keys. Compose Development setting overrides the Dockerfile's Docker environment name.

Named volumes preserve SQL data, RabbitMQ data and ASP.NET data-protection keys; backups is also bind-mounted. Removing a container does not delete its named volume. Removing volumes destroys their stored data. Data-protection key storage is distinct from the JWT signing-key setting.

### Important code

Root Dockerfile/docker-compose.yml/.env.example; subscriber Dockerfile; Program bootstrap/health checks; scripts/Invoke-CleanComposeSmoke.ps1 and docker-compose.clean.yml.

### Request/data flow

`Flutter host/emulator → host:5000 → API container:5001 → SQL/Rabbit service DNS on internal network → persisted volumes`.

### What I should demonstrate

Follow DEMONSTRATION.md startup commands; show `docker compose ps`, Swagger and `/health/ready`. Show the 5000:5001 mapping and DefaultConnection hostname. Explain the isolated smoke script without deleting the normal stack's volumes.

### What I should say

“On a new computer I install the repository's required Docker and Flutter/.NET tooling, copy the example local configuration, run Compose, verify readiness, then start Windows Flutter against localhost or Android against 10.0.2.2.”

### What the professor could ask

Image versus container? Host versus container port? How does SQL data survive rebuild? Why isn't Android localhost the host machine? Does a running API mean migrations succeeded?

### What I absolutely need to understand

Compose is configuration, not proof of a successful run. New-machine startup requires dependencies/images, available ports and a functioning Docker engine. Development may expose Swagger even if SQL bootstrap failed. Do not claim empty Stripe/Firebase variables configure those providers.

## Stage 11 — Dependency injection and async/await

### What it is

DI supplies an object's dependencies from registrations. Async/await expresses waiting for I/O completion without blocking a thread throughout the wait.

### Why it exists

Controllers should not build their own dependency graph. HTTP and database operations can take time; the application should stay responsive and make efficient use of server threads.

### How it works

`IProductService → ProductService → AddTransient<IProductService,ProductService>() in Program → ProductController constructor → base controller/service usage`. ProductService additionally needs context, mapper and state resolver. Scoped DbContext is reused within one request; transient services can use that scoped context. AuthService and mapping services are scoped; PasswordHasher and configuration are singleton. Hosted workers create a scope for scoped database services per processing operation.

Flutter uses MultiProvider/ChangeNotifier plus a custom service locator; some features inject repository/use-case abstractions. `notifyListeners()` rebuilds listeners; it does not send a network request by itself.

`async Task<ProductResponse>` describes a method that eventually produces a response. `await SaveChangesAsync()` keeps subsequent response/commit logic from continuing until the save completes and propagates failures. A pass-through method can return another Task without adding async/await. Async does not itself create a new thread. See [Microsoft's async/await explanation](https://learn.microsoft.com/en-us/dotnet/csharp/asynchronous-programming/).

### Important code

Program service registrations; ProductController/ProductService constructors; OutboxPublisherWorker scope creation; BaseCRUDService.CreateAsync; MobileHomeScreen._refresh with Future.wait; AuthProvider notifyListeners.

### Request/data flow

`DI container resolves constructor graph → method starts → async SQL/HTTP starts → await yields when incomplete → completion resumes → result/state update`.

### What I should demonstrate

Trace a registration to constructor to use. Open a method and point to what must complete before its next statement. Show parallel independent Flutter HTTP reads versus sequential operations within one EF transaction.

### What I should say

“DI manages object construction and lifetimes so the controller depends on a contract. Await preserves the logical order of asynchronous operations without blocking for the entire I/O wait.”

### What the professor could ask

Why not new ProductService in the controller? What happens if await is removed? Can DbContext be singleton? Why CreateScope in a BackgroundService?

### What I absolutely need to understand

Removing await can return before a required operation finishes, lose orderly exception handling or start overlapping EF operations; it is not a performance optimization by default. Returning a Task directly when there is no following dependent work is valid. A scoped context is not thread-safe, and singleton services must not capture request-scoped context.

## Stage 12 — Other workflows and recommendations

### What it is

Notifications, player competition, memberships, privacy and recommendation evidence extend the core club data into additional workflows.

### Why it exists

These features show different patterns: per-recipient state, multi-user confirmation, background lifecycle work, explainable ranking and evidence provenance.

### How it works

- Notifications save one content row plus per-user recipient/delivery rows. Preferences decide channels. NotificationDeliveryWorker polls SQL, calls MailKit/Firebase adapters, records Sent/Skipped/Retry/Failed and retries selected failures. RabbitMQ subscriber is not this worker.
- Player Hub uses verified caller identity for profile, discoverable partner search and invitation response. Match confirmation uses a second participant, an Elo-like expected-score formula with K=32 and floor rating 100, then advances the bracket. A confirmation must be by someone other than reporter; opposite-team enforcement is absent.
- Membership hourly processing converts ended Active periods to Cancelled, RenewalDue or Expired and records events. AutoRenew means renewal is due, not that a card is automatically charged. Staff renewal extends the end date 1–24 months.
- Privacy schedules 30-day deletion; the hourly worker anonymizes/inactivates account data and removes/redacts selected personal records while retaining transaction history. Do not call this comprehensive legal compliance or claim instantaneous deletion.
- Recommendations read Delivered purchase history, subtract Approved/Refunded returned quantities, exclude retained owned candidates, and rank eligible in-stock products. ItemBasedCollaborativeRanker uses log(1+quantity), 180-day recency half-life, peer item cosine similarity and support shrinkage n/(n+3). The target user's history selects source items but is excluded from peer similarity vectors. Popularity/new-product fallback covers sparse users.
- Historical evaluation is time-split, compares a popularity baseline and tracks eligibility/provenance/maturity gates. Serving can use demo/legacy history; operational evaluation excludes seeded/admin/test/unverified provenance and requires real delivery timestamps. Immutable snapshots retain aggregate results plus input/config hashes.
- Separate external UCI benchmark evaluates the algorithm on external retail data, not PadelClub customers. Do not memorize historical benchmark numbers as current live application quality. Prospective experiments use consented eligible production traffic, sticky random assignments, fixed control/treatment and Draft→Running→Closed lifecycle; local demo data does not prove causal sales lift.
- Provider readiness checks configuration only. Separate opt-in verification can observe narrowly configured provider actions and records a normalized result. A successful provider acceptance is not recipient receipt or payment completion.

### Important code

NotificationService/NotificationDeliveryWorker; PlayerExperienceController/MatchScoreValidator/BracketService; MembershipsController/MembershipLifecycleWorker; PrivacyController/PrivacyDeletionWorker; ProductRecommendationService/ItemBasedCollaborativeRanker/RecommendationEvaluationService/RecommendationExperimentService; provider readiness/verification controllers.

### Request/data flow

Recommendation example: `Shop → Recommendations/products → caller ID → delivered order lines minus returns → candidate filtering/ranking/fallback → exposure metadata → explanation cards → optional click/checkout attribution → aggregate evaluation/impact`.

### What I should demonstrate

Review one notification read state, one partner invitation response, one membership history and a recommendation explanation. Open evaluator exclusions and evidence tier. Use the detailed screen map to rehearse each extra feature after the core workflows are comfortable.

### What I should say

“The recommendation is deterministic item-to-item collaborative filtering over purchase history, with an explicit sparse-data fallback. A good demo proves the implementation; claiming effectiveness requires eligible evaluation evidence.”

### What the professor could ask

Why not count Pending purchases? How do returns affect recommendations? What is cold start? What is leakage? Does an external benchmark prove this club's conversion lift? Is an impression a click? Why are evidence snapshots immutable?

### What I absolutely need to understand

Implementation, configured deployment, observed provider acceptance, end-user delivery and measured business impact are separate claims. The correct answer may be “the project implements the mechanism, but this demo does not establish that outcome.”
