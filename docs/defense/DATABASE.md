# Database training

The database is a connected record of people, bookings, competition, commerce and asynchronous work. `PadelClub.Services/Database/PadelClubContext.cs` is the EF model authority; the migration chain under `Database/Migrations` describes schema evolution. [SOURCE_INDEX.md](SOURCE_INDEX.md) contains exact entity declarations, property types, navigation properties and configured relationships.

## Read the database from its central relationships

`Users` connects to reservations, orders, payments, memberships, notifications and player activity. `Courts` connects to reservations and matches. `Products` connects to catalogue references, assets, order lines and stock movements. Most relationships are one-to-many; join entities model many-to-many associations and carry additional data.

A **primary key** identifies a row: Reservation.Id identifies one booking, independently of its date or customer name. A **foreign key** stores a reference: Reservation.CourtId must refer to an existing Court.Id. The C# `Court` navigation is an object relationship; `CourtId` is the scalar stored relationship. Navigation data is not automatically present in every JSON response.

## Entity catalogue

Unless stated otherwise the entity has an integer `Id` primary key. Use the indexed declarations to check long/Guid key types for infrastructure entities; never assume the generic integer CRUD API applies to all tables. A property ending in Id is not automatically a database FK: EF requires a mapped relationship or migration constraint.

### Identity and player data

- **Users**: username/email/contact, PasswordHash/PasswordSalt, IsActive, EmailVerifiedAt, timestamps. Unique username and email. Collections include UserRoles, Reservations, Orders, Payments, Memberships and notification relations. Used by login, admin management and account self-service. Do not select password/token columns in the live defense.
- **Roles**: name/description/active flag; UserRoles collection. Seeded Administrator and Player determine access claims.
- **UserRoles**: UserId and RoleId FKs, assignment date; User and Role navigations. Unique (UserId,RoleId) prevents duplicate assignment. This is the explicit Users↔Roles many-to-many join with its own Id.
- **AuthTokens**: opaque-token SHA-256 hash, UserId FK/User navigation, purpose, expiry, family/replacement/consumed/revoked metadata. Used for refresh rotation, verification and recovery. A token's hash is stored rather than the bearer secret itself.
- **PlayerProfiles**: UserId FK with unique index and User navigation; level, preferred side, city, bio, availability, discoverability, rating. User↔PlayerProfile is optional one-to-one: a newly created user may not have completed onboarding.
- **PartnerInvitations**: SenderUserId/RecipientUserId FKs, Message, Status, CreatedAt/RespondedAt; Sender/Recipient navigations. Two distinct relationships to Users express two roles in the same invitation. NoAction avoids automatic deletion through both paths.
- **ClubReviews**: UserId FK/User navigation, rating/comment/published flag/timestamps. Unique UserId gives at most one review per user. Used by Home review strip and save-mine upsert.
- **PrivacyRequests**: UserId FK/User navigation, RequestType/Status, RequestedAt/ScheduledFor/CompletedAt/CancelledAt. The scheduled-deletion workflow preserves and anonymizes the User row rather than hard-deleting all historical transactions.

### Courts and bookings

- **Courts**: name/description, HourlyRate decimal, indoor/active flags, MaxPlayers. Reservation/maintenance/waitlist collections. Used by court management, booking availability and tournament match placement.
- **Reservations**: CourtId/UserId FKs, StartTime/EndTime UTC, TotalPrice, Status, Notes, SeriesId, CancelledAt, IsNoShow and timestamps. Court/User/Payment/Credits navigations. A Guid SeriesId groups recurring records; it is not an FK to a Series table.
- **MaintenanceBlocks**: nullable CourtId FK, UTC start/end, reason/active flag; optional Court navigation. Null means a club-wide closure in availability/booking predicates, not an unknown user selection.
- **WaitlistEntries**: CourtId/UserId FKs, UTC interval, Waiting/Notified status, CreatedAt/PromotedAt; Court/User navigations. Unique user/court/exact interval. Cancellation picks the earliest overlapping Waiting entry and notifies it.
- **AccountCredits**: UserId FK and nullable ReservationId FK, Amount, Reason, CreatedAt/UsedAt; User/Reservation navigations. Created for a qualifying cancelled booking with a Completed payment. Read-only credit display does not consume the balance.

### Catalogue, orders and returns

- **ProductCategories** and **ProductTypes**: name/description/active/timestamps, Products collections. Both are required Product references. Category and type have different columns; UI category-like search chips are not necessarily FK filtering.
- **Products**: Name/Description/Price/StockQuantity, ProductCategoryId/ProductTypeId FKs, ImageUrl, IsActive, ProductState, timestamps. Category/Type/Assets/OrderItems/InventoryMovements navigations. `ProductState` contains state class names; IsActive is independent.
- **Assets**: ProductId FK/Product navigation, Base64Image, DisplayOrder, IsPrimary. One product can have multiple assets. Table existence does not prove a complete gallery/editor UI.
- **Orders**: UserId FK/User navigation, OrderNumber unique, shipping/contact fields, SubtotalAmount/DiscountAmount/TotalAmount, CouponId/CouponCode, Status/DeliveredAt, IsSeededForDemo and Origin. OrderItems/Payment/ReturnRequests navigations. Stored provenance distinguishes actual checkout from admin/demo/legacy/import/test data.
- **OrderItems**: OrderId/ProductId FKs, Quantity, UnitPrice, TotalPrice; Order/Product navigations. Prices snapshot the checkout price; later catalogue edits must not rewrite historical order totals. Orders↔Products is many-to-many through this quantity/price-bearing join.
- **InventoryMovements**: ProductId FK/Product navigation, QuantityChange, BalanceAfter, Reason, ReferenceType/ReferenceId, ActorUserId and CreatedAt. Long Id. ReferenceType/ReferenceId is a polymorphic application reference, not one FK that can target every referenced table.
- **Coupons**: normalized unique Code, DiscountType/Value, MinimumOrderAmount, MaximumDiscount, ValidFrom/ValidUntil, UsageLimit/UsageCount, PerUserLimit, IsActive; Redemptions navigation.
- **CouponRedemptions**: long Id, CouponId FK/Coupon navigation, UserId/OrderId identifiers, DiscountAmount/RedeemedAt; OrderId has unique index. Do not call UserId/OrderId enforced FKs solely from their names: explicit configuration defines Coupon navigation here.
- **ReturnRequests**: OrderId FK/Order navigation, UserId identifier, reason/status/refund amount/admin note/time; Items/ProviderRefundOperations navigations. Requested → Rejected or Approved for ordinary local returns; Stripe path Requested → RefundPending → Refunded.
- **ReturnRequestItems**: ReturnRequestId/OrderItemId FKs, quantity/refund amount/restocked flag; ReturnRequest/OrderItem navigations. Unique request/line pair. Quantity is bounded against original quantity and earlier non-Rejected requests.

### Payments and memberships

- **Payments**: UserId FK; nullable ReservationId/MembershipId/OrderId FKs; Amount/Currency, PaymentType/PaymentMethod/Status, Provider, TransactionId, IdempotencyKey, RefundedAmount, receipt/failure/reconciliation metadata. User/Reservation/Membership/Order/ProviderRefundOperations navigations. Each payable relation is optional one-to-one, not a generic one-to-many payment collection.
- **StripeWebhookEvents**: unique StripeEventId, event type, processing/error timestamps. This is provider-delivery deduplication, not a user checkout table.
- **ProviderRefundOperations**: Guid Id, PaymentId FK, optional ReturnRequestId FK, RequestedByUserId FK; amount/currency/provider-payment snapshot, expected cumulative refunded amount, stable idempotency key, Pending/Succeeded, provider result, attempts/retry/lease metadata. Payment/ReturnRequest/RequestedByUser navigations. SQL stores intent before Stripe I/O; lease owner settles the local outcome.
- **Memberships**: UserId FK/User navigation, MembershipType/StartDate/EndDate/Price, Status/IsActive, AutoRenew/CancelAtPeriodEnd and lifecycle timestamps; Payment/Events navigations. Many memberships may belong to a user over time.
- **MembershipEvents**: membership FK/navigation, event type/notes/actor/time. Used by self-service and staff history. The API exposes history without editing actions; do not confuse that with the specific append-only context protection implemented for recommendation evidence.

### Competition

- **Tournaments**: name/description/dates/deadline, capacity/entry fee/prize/status, Participants/Matches collections. Generic catalogue and team lifecycle routes share these rows.
- **TournamentParticipants**: TournamentId/UserId FKs, status/team number/seed/confirmation time; Tournament/User navigations. Unique tournament/user. TeamNumber groups two participants inside a tournament; no separate Team table is needed by this implementation.
- **Matches**: TournamentId/CourtId FKs; schedule/status/score/winner, proposed-result/report/confirmation fields, rating deltas, bracket round/position/bye, nullable self-FK NextMatchId and NextMatchTeamNumber. Tournament/Court/Participants/NextMatch/PreviousMatches navigations. WinnerTeamId is the local 1/2 side identifier in this workflow, not evidence of a Team FK.
- **MatchParticipants**: MatchId/UserId FKs, TeamNumber and participant Role; Match/User navigations. Unique match/user. Models Users↔Matches with per-match side membership.

### Notifications and operations

- **Notifications**: title/message/type/timestamps; Recipients/Deliveries collections. Stores content once.
- **NotificationRecipients**: NotificationId/UserId FKs, IsRead/ReadAt; Notification/User navigations. Unique notification/user. This join gives each recipient a separate read state.
- **NotificationPreferences**: unique UserId FK/User navigation, in-app/email/push toggles/time. Optional one-to-one with User.
- **PushDevices**: UserId FK/User navigation, unique InstallationId, platform/active state. Server accepts an installation token but a registered usable mobile token must exist for delivery.
- **NotificationDeliveries**: NotificationId/UserId FKs, channel/status/attempts/next-attempt/sent time/provider message/error; Notification/User navigations. Unique notification/user/channel. Status tracks sending, separately from recipient reading.
- **AuditLogs**: actor identifier, method/path/status/duration/IP/correlation/time. Read-only operational view; a nullable actor permits anonymous/redacted entries. It is request metadata, not a complete before/after business event store.
- **ProviderVerificationAttempts**: request actor FK, provider/kind, correlation/status/normalized outcome/start/end times. Evidence excludes secrets/targets. One terminal completion of a Started attempt is allowed; later edits/deletion are guarded by context tracking.

### Recommendation evidence and event transport

- **RecommendationEvaluationRuns**: long Id and unique Guid RunId; ExecutedByUserId FK, cutoff/end/K, algorithm/protocol/config/input hashes, counts/tier and aggregate ReportJson. Context rejects tracked modification/deletion. No raw customer history is copied into these reports.
- **RecommendationAnalyticsConsents**: UserId is both PK and FK, policy version and grant/revoke/update timestamps; User navigation. This is a shared-key one-to-one, unlike PlayerProfile which also has its own Id.
- **RecommendationExperiments**: Guid Id, experiment key/status, fixed protocol/algorithm/control/treatment/config metadata, actor and lifecycle timestamps; Assignments/AnalysisRuns. Filtered unique Running-status index permits at most one running experiment.
- **RecommendationExperimentAssignments**: Guid Id, ExperimentId/UserId FKs, variant/time; Experiment/User/Exposures navigations. Unique experiment/user provides a sticky arm assignment.
- **RecommendationExperimentAnalysisRuns**: run/report/config/input evidence and experiment/executor FKs; aggregate prospective analysis snapshots. Append-only tracked evidence, separate from historical evaluator runs.
- **RecommendationExposures**: Guid Id, UserId/ProductId FKs, algorithm/strategy/rank/served/click time, optional purchased order FK and experiment assignment FK; user/product/order/assignment navigations. Server stamps provenance and immutable assignment/source.
- **OutboxMessages**: Guid Id equal to ProductUpdated.EventId, message type/payload, occurred/published/next-attempt times, attempts/error/lease. No product FK is needed: payload is a historical event snapshot.
- **InboxMessages**: long Id, Consumer, EventId, message type/time. Unique (Consumer,EventId) means the same event may be recorded once per distinct subscriber. EventId correlates with outbox but is not configured as an outbox FK.

## Relationships and deletion: concrete answers

**One-to-many:** one Court has many Reservations; each Reservation uses one Court. One Order has many OrderItems. Show the FK and the `WithMany` collection.

**Many-to-many:** Users↔Roles through UserRoles; Users↔Tournaments through TournamentParticipants; Users↔Matches through MatchParticipants; Users↔Notifications through NotificationRecipients; Orders↔Products through OrderItems. A join entity exists because the association itself has fields such as quantity, team number, assignment time or read state.

**One-to-one:** User↔PlayerProfile and User↔NotificationPreference use unique UserId. User↔RecommendationAnalyticsConsent uses UserId as primary/foreign key. Reservation↔Payment, Membership↔Payment and Order↔Payment use nullable unique payable FKs. The Stripe service requires exactly one payable per request; nullable columns alone do not enforce exactly-one across three columns for every generic write.

**Cascade:** deleting an Order cascades its OrderItems; deleting a Product cascades Assets; deleting a User cascades UserRoles/profile/preferences/auth tokens; deleting a Notification cascades recipient rows. This does not guarantee the parent delete succeeds: other restrictive relations may block it.

**Restrict/NoAction:** bookings prevent deleting referenced users/courts; products referenced by OrderItems cannot be deleted through that relationship; UserRole references protect roles; competition/history records have restrictive relations. NoAction is not “ignore the FK”: the database still rejects an invalid reference.

**SetNull:** deleting a payable Reservation/Order/Membership can null the corresponding Payment reference, preserving the payment record, if other relationships permit deletion. AccountCredit.ReservationId also uses SetNull. Nullable FK allows meaningful history after removal of an optional parent.

## EF Core in this project

`AddDatabaseServices` registers a scoped PadelClubContext with `UseSqlServer`. DbSet exposes a query/update surface, not a preloaded in-memory table. A LINQ `Where` on IQueryable builds a query; `ToListAsync`, `CountAsync`, `AnyAsync`, `SingleAsync` and similar terminal operations execute it. Additional `.Where` on an already materialized list runs in the application process.

`Include(...).ThenInclude(...)` in UserService loads UserRoles then Role for login claims. Without that loaded data (or a projection), you cannot assume roles are available. Projection with Select can produce flattened responses without materializing an entire entity graph.

EF tracks ordinary queried entities: updating ProductState then awaiting SaveChangesAsync writes the modified row. `AsNoTracking` is used for read-only snapshots/diagnostics and avoids ordinary change tracking. It does not make the SQL database read-only. See [Microsoft's tracking documentation](https://learn.microsoft.com/en-us/ef/core/querying/tracking).

`SaveChangesAsync` persists the tracked unit of work; it does not retroactively wrap earlier/later unrelated saves or provider calls in a single transaction. Explicit serializable transactions appear in bookings, checkout and fulfillment/return resolution. `ExecuteUpdateAsync`/`ExecuteDeleteAsync` issue direct database commands and bypass tracked-entity SaveChanges guards; privacy cleanup deliberately uses these operations. Append-only guards are application protections, not a ban on all administrative SQL writes.

Methods to explain from actual code:

- `First`/`FirstAsync`: first result, throws if empty. Startup role lookup assumes prior seeding.
- `FirstOrDefaultAsync`: first or null/default; used by user lookup and oldest waitlist selection. The caller must handle absence.
- `SingleAsync`: exactly one expected; zero or multiple results throw. Used for validated court/user lookups.
- `SingleOrDefaultAsync`: zero gives null, multiple throws; used for unique token/identity/reference queries.
- `AnyAsync`: existence/overlap check without needing every matching row.
- `Where`: predicate; `Select`: projection; `Include`: related entity loading.
- `OrderBy`/`ThenBy`: deterministic order. `Skip((Page-1)*PageSize).Take(PageSize)` selects one 1-based page.
- `ToListAsync`: executes/materializes; `SaveChangesAsync`: persists tracked changes. `Task` represents eventual completion, not the SQL result itself.

## Migrations

Migration files have Up/Down operations and a model snapshot. Current migrations include booking/auth/lifecycle, order provenance, recommendation evidence/impact/experiments, outbox/inbox and durable refunds/provider verification. A model edit alone does not update an existing database.

Startup calls ApplyMigrationsWithRetry then seeds initial data when bootstrap is enabled. In Development, a database bootstrap exception is logged and the API can still start; opening Swagger is therefore weaker evidence than successful `/health/ready` and database-backed requests.

For a planned schema change the usual repository-specific commands are `dotnet ef migrations add <Name> --project PadelClub.Services --startup-project PadelClub.WebAPI`, then `dotnet ef database update --project PadelClub.Services --startup-project PadelClub.WebAPI`, with the EF tool and connection configuration present. No migration should be added merely for this defense preparation.

## Read-only SQL demonstrations

Use SQL Server Management Studio or another SQL client against the demo database. Record IDs returned by the app/API, then replace the zero-valued variables below. Do not identify records only by “the last row” when multiple users are active.

```sql
USE PadelClub;
DECLARE @ReservationId int = 0; -- replace with the booking ID from your demo
SELECT r.Id, r.UserId, u.Username, r.CourtId, c.Name AS CourtName,
       r.StartTime, r.EndTime, r.TotalPrice, r.Status, r.SeriesId
FROM Reservations r
JOIN Users u ON u.Id = r.UserId
JOIN Courts c ON c.Id = r.CourtId
WHERE r.Id = @ReservationId;
```

Run after booking, then again after staff cancellation. Show the same Id with changed Status; cancellation is an update, not deletion.

```sql
DECLARE @OrderId int = 0; -- replace
SELECT Id, OrderNumber, UserId, Status, SubtotalAmount, DiscountAmount,
       TotalAmount, DeliveredAt, Origin, IsSeededForDemo
FROM Orders WHERE Id = @OrderId;
SELECT i.Id, i.ProductId, p.Name, i.Quantity, i.UnitPrice, i.TotalPrice
FROM OrderItems i JOIN Products p ON p.Id = i.ProductId
WHERE i.OrderId = @OrderId;
SELECT ProductId, QuantityChange, BalanceAfter, Reason, ReferenceType, ReferenceId
FROM InventoryMovements WHERE ReferenceType = 'Order' AND ReferenceId = @OrderId;
```

Run after mobile checkout and after desktop delivery/cancellation. Explain price snapshots, provenance and delivery timestamp. Order creation does not prove a corresponding payment.

```sql
DECLARE @ProductId int = 0; -- replace
SELECT Id, Name, ProductState, IsActive, Price, StockQuantity
FROM Products WHERE Id = @ProductId;
SELECT TOP (10) Id, Type, OccurredAtUtc, PublishedAtUtc, AttemptCount, NextAttemptAtUtc
FROM OutboxMessages ORDER BY OccurredAtUtc DESC;
SELECT TOP (10) Consumer, EventId, ReceivedAtUtc
FROM InboxMessages ORDER BY ReceivedAtUtc DESC;
```

After a draft edit, use the actual outbox EventId to correlate subscriber log and inbox receipt. Do not expose full event payloads unnecessarily.

```sql
DECLARE @UserId int = 0; -- replace with disposable player
SELECT ur.UserId, r.Name AS RoleName, ur.DateAssigned
FROM UserRoles ur JOIN Roles r ON r.Id = ur.RoleId WHERE ur.UserId = @UserId;
SELECT n.Id, n.Title, nr.IsRead, nr.ReadAt
FROM NotificationRecipients nr JOIN Notifications n ON n.Id = nr.NotificationId
WHERE nr.UserId = @UserId ORDER BY n.CreatedAt DESC;
SELECT NotificationId, Channel, Status, AttemptCount, SentAt
FROM NotificationDeliveries WHERE UserId = @UserId ORDER BY Id DESC;
SELECT MigrationId, ProductVersion FROM __EFMigrationsHistory ORDER BY MigrationId;
```

Use the notification queries before/after reading on mobile: recipient read state and external delivery state are independent. The migration query shows applied schema versions; it does not prove every feature works.
