# Project analysis and map

Paths in this document are relative to the repository root. Open exact declarations through [SOURCE_INDEX.md](SOURCE_INDEX.md).

## Applications and technologies actually present

- `UI/padelclub_desktop`: shared Dart/Flutter package, with Windows/other runners and both management and player features. Uses Material widgets, Provider/ChangeNotifier, `http`, JSON serialization, `flutter_secure_storage` and `url_launcher`.
- `UI/padelclub_mobile`: Android/iOS distribution wrapper. Its pubspec has a path dependency on the desktop package. Its `main.dart` calls `sl.init()` and builds the shared `PadelClubBootstrap`. It does not duplicate all features.
- `PadelClub.WebAPI`: ASP.NET Core/.NET 8 HTTP API, JWT middleware, Swagger/Swashbuckle, controllers, some directly implemented workflows, hosted background workers and provider adapters.
- `PadelClub.Services`: .NET 8 class library containing service contracts/implementations, generic CRUD, EF Core 8 SQL Server persistence, migrations, product State pattern, recommendations and messaging persistence helpers.
- `PadelClub.Model`: shared C# request/response/search/message contracts. Flutter consumes their JSON representation using Dart models; it does not reference the C# DLL.
- `PadelClub.WebAPI/PadelClub.Subscriber`: separate .NET 8 worker executable, explicitly excluded from API compilation. Consumes `ProductUpdated` using EasyNetQ and records inbox receipts in SQL.
- `PadelClub.WebAPI.Tests`: xUnit, ASP.NET Core test hosting, EF InMemory tests and SQL Server Testcontainers integration tests. Flutter packages have separate tests.
- `tools/PadelClub.RecommendationBenchmark`: separate command-line recommendation benchmark. It is outside the application's serving/database flow.
- Infrastructure: Docker/Compose, SQL Server 2022, RabbitMQ 3.13 management image, Mailpit. API adapters use Stripe.net, FirebaseAdmin and MailKit. Package declarations establish dependencies, not successful external integrations.

Mapster performs ordinary convention-based mapping. `Program.cs` scans the API assembly, but no custom `IRegister`/`NewConfig` mapping profile was found. Some responses are manually projected instead. Passwords use PBKDF2; the BCrypt package reference is not the active algorithm. No MAUI/WPF/WinUI, React frontend, PostgreSQL, separate backend repository abstraction, or dedicated rental service was found in the active application paths inspected.

## Actual architecture

The main backend is a layered application with a separately deployed event subscriber. Calling the whole project a set of domain microservices would exaggerate its separation: the API owns many domains and shares one DbContext/database with the subscriber.

The common request path is:

`Flutter screen → Provider → HTTP + Bearer token → controller → service interface/implementation → PadelClubContext → SQL Server → mapping/projection → JSON → Dart model → provider/widget refresh`.

There are two material exceptions:

- Flutter has feature/domain/data/use-case/repository structures, but active providers such as `ProductProvider`, `ReservationProvider`, `AuthProvider` and `PlayerExperienceProvider` make HTTP calls directly. The custom `InjectionContainer` is a service locator; it is not GetIt.
- Controllers including `PlayerExperienceController`, `PrivacyController`, `CommerceOperationsController` and parts of `MembershipsController` query/update the context directly. Do not invent an absent `PrivacyService` or `CommerceRepository`.

`usesDesktopManagement()` selects desktop on Windows/Linux/macOS, and on web at width >= 900. Android/iOS use the player shell. The desktop dashboard additionally checks the administrator role. A player's desktop login can authenticate successfully and then show management access denied. The shell decision and backend authorization are different mechanisms.

Desktop and mobile exchange no direct messages. A mutation commits to the shared database; the other client sees it on its next HTTP reload. RabbitMQ is a separate product-event demonstration, not a mobile synchronization channel. No SignalR/WebSocket live synchronization was found in these paths.

## Desktop screen map

The desktop top bar contains User Management, Memberships, Order Management, Reservation Management, Product Management, Court Management, Tournament Management, Notifications and Audit Trail. Click the branding/home destination for the management overview.

### Login and management overview

- Reach: application launch, then `/home` after login. Code: `main.dart`, `providers/auth_provider.dart`, `dashboard_page.dart`.
- Data/API: `POST /Users/login`; JWT/session/user response. Overview uses `GET /Operations/analytics` and recommendation evaluation/readiness endpoints.
- Rules/actions: required login inputs; wrong credentials; remember-session; logout; administrator dashboard access. Summary cards query reservations, orders, memberships and low stock.
- Demo: invalid password, correct admin login, refresh metrics, open one real management screen. Schedule/court-status panels are explicitly example previews, not live availability. Practice question: which cards come from SQL and which are examples?

### User Management

- Reach: top bar → User Management. Screen `features/users/presentation/screens/user_management_screen.dart`; `UserProvider`.
- Displays/searches: username, names, email, contact and active status, with role assignment in the form. The loaded list is filtered in the screen; inspect provider fetch limits before claiming all users are searched.
- API/service/entities: `GET/POST /Users`, `PUT/DELETE /Users/{id}`, role lookups; `UserService`, `Users`, `Roles`, `UserRoles`.
- Validation/actions: add/edit/delete confirmation; unique username/email; password handling; distinct active role IDs. Related reservations/orders can prevent hard deletion through restrictive FKs. Empty role assignment is permitted by `ValidateRoleIdsAsync`.
- Demo: create a disposable player with a unique username/email and Player role, edit contact details, test a duplicate, delete only if no dependent records exist. Explain role assignment versus authentication. No public self-registration endpoint was found.

### Court Management

- Reach: top bar → Court Management. Screen `court_management_screen.dart`, `CourtProvider`.
- Displays: name, description, indoor/outdoor, rate, max players and active flag. Provider loads up to 200 and the screen filters the snapshot.
- API/service/entities: `/Courts` generic GET/POST and `/{id}` PUT/DELETE; `CourtService`; `Courts` and referencing reservations/matches/maintenance.
- Validation/actions: name/numeric form checks, edit rate/availability, hard-delete confirmation. Required lengths/FKs are enforced by SQL, but do not assume all numeric business limits are validated server-side.
- Demo: edit an unused court's description/rate; show the player availability refresh. Deleting a used court may fail. Question: why is disabling a court different from deleting it?

### Reservation Management

- Reach: top bar → Reservation Management. `ManagementReservationsScreen` in `reservation_screens.dart`; `ReservationProvider`.
- Data: court/user IDs, start/end, amount, status, notes. Fetches `/Reservations` with PageSize 100, then local list filters/sorting. Do not describe this screen as paging through every database row.
- API/service/entities: `GET /Reservations`; `PUT /Reservations/{id}/cancel`; `POST /Reservations/maintenance`; `PUT /Reservations/{id}/no-show`; `ReservationService`; `Reservations`, `Courts`, `Users`, `MaintenanceBlocks`, `AccountCredits`, `WaitlistEntries`, notification records.
- Actions: inspect/cancel, maintenance dialog, no-show confirmation. Generic admin update/delete also exist in API, but are not equivalent to the screen's workflow actions.
- Validation/edges: overlap, future time, club hours, slot alignment, maximum duration and active court/user on booking. Maintenance has a nullable court ID meaning all courts. No-show currently sets the flag/status without checking that the start has passed; do not claim that guard exists.
- Demo: find the mobile booking by ID and cancel it; refresh mobile. Create future maintenance and show blocked availability. Question: who chooses UserId and price? The server does on creation, even for an admin caller.

### Product Management, stock and coupons

- Reach: top bar → Product Management. `product_management_screen.dart`, shared `ProductProvider`, product detail dialog/screen and inventory/coupon features.
- Data: products, prices, stock, state; fetches page 1 of 200 and filters locally. Actions include add/edit/delete and lifecycle controls, stock adjustment/history, Manage coupons.
- API/service/entities: `/Product`, `/{id}/activate`, `/{id}/deactivate`; `ProductService` and product state classes; `Products`, `ProductCategories`, `ProductTypes`, `Assets`, `OrderItems`, `OutboxMessages`.
- Stock: `POST /Commerce/inventory/{id}/adjust`, `GET .../history`; controller directly uses SQL and writes `InventoryMovements`. Quantity change/reason and nonnegative resulting stock are validated.
- Coupons: `GET/POST /Commerce/coupons`, `PUT /Commerce/coupons/{id}`; create/edit/enable/disable with validity window, percentage/fixed discount, minimum spend, caps and usage limits. No coupon delete endpoint. Stored codes are normalized and unique.
- Demo: select valid category/type IDs, create a draft, edit it, observe outbox/subscriber, activate, attempt an illegal edit through Swagger, deactivate. A PUT on a deactivated product only returns it to draft; submit a second edit to change its fields. `IsActive` and `ProductState` are separate fields.
- Questions: what blocks an active edit? Does the activation set `IsActive`? What happens if a product is referenced by an order? Product-type API creation is explicitly forbidden by its service; category/type data access classes do not prove dedicated management screens.

### Order Management and return queue

- Reach: top bar → Order Management; Orders and Return requests tabs. `OrderProvider`, `ReturnRequestsProvider`.
- Data/filtering: order number/customer/shipping/status/totals, locally filtered from a 200-row fetch; return queue uses server status filter and contains requested line quantities, amount, reason and resolution notes.
- API/service/entities: `/Orders`, `PUT /Orders/{id}` → `OrderService`; `/Commerce/returns`, `PUT /Commerce/returns/{id}/resolve` → `CommerceOperationsController` and refund-operation service. `Orders`, `OrderItems`, `Products`, `InventoryMovements`, `ReturnRequests`, `ReturnRequestItems`, `Payments`, `ProviderRefundOperations`.
- Actions: valid next fulfillment step, cancel before dispatch, inspect return, approve/reject Requested return. Progression is Pending → Processing → Shipped → Delivered; cancellation only from Pending/Processing; same-state updates are allowed. A real transition to Delivered stamps `DeliveredAt`.
- Demo: find a fresh mobile checkout, advance sequentially, refresh My orders. Return approval without a Stripe payment becomes Approved and restores stock; it is not proof of money moving. Stripe-backed approval becomes RefundPending and requires worker/provider settlement.
- Question: how are double resolution and double restocking prevented? SQL update locks, status validation, transaction and durable refund operation.

### Memberships

- Reach: top bar → Memberships. `MembershipManagementProvider` and screen.
- Data/API: real 20-row server pagination with membership type/active filters; `GET /Memberships`, `PUT /{id}/status`, `POST /{id}/renew`, `GET /{id}/history`.
- Handling/storage: generic queries use `MembershipService`; lifecycle actions directly use context in `MembershipsController`; `Memberships`, `MembershipEvents`, `Users`.
- Actions: Active/Suspended/Cancelled, manual renewal 1–24 months, history. Generic CRUD exists in API; the visible staff screen prioritizes lifecycle actions.
- Demo: suspend a disposable membership and refresh Profile → My memberships. Explain that renewal extends the record; it does not collect a card payment. Hourly worker ends expired periods as Cancelled, RenewalDue or Expired.

### Tournament Management

- Reach: top bar → Tournament Management; screen/provider/data source under `features/tournament_management`.
- API/storage: singular `/Tournament` is catalogue CRUD through `TournamentService`; plural `/Tournaments/{id}/bracket/generate` is lifecycle through `TournamentLifecycleController`/`BracketService`; `Tournaments`, `TournamentParticipants`, `Matches`, `MatchParticipants`, `Courts`.
- Actions: create/edit/confirmed hard delete, generate bracket once. Server requires >= 2 complete confirmed two-player teams and an active court; power-of-two bracket uses byes.
- Demo: prepare four distinct players beforehand, confirm both teams, generate, inspect mobile bracket. Repeated generation conflicts. Generic deletion can fail on dependent participants/matches.
- Question: why are `/Tournament` and `/Tournaments` both present? They are two explicit route families, not interchangeable names.

### Notifications and delivery diagnostics

- Reach: top bar → Notifications; Delivery Diagnostics inside it. `NotificationProvider`, diagnostics provider/data source.
- API/service: generic `/Notifications` CRUD, `NotificationService`; diagnostics `GET /NotificationSettings/deliveries?status=...` accesses context directly.
- Entities: `Notifications`, `NotificationRecipients`, `NotificationPreferences`, `NotificationDeliveries`, `PushDevices`, `Users`.
- Actions: create broadcast/targeted notification, edit content, delete, search/filter loaded 200-row snapshot. Empty recipient list means all active users, subject to channel preferences. Diagnostics is read-only and filters on the server.
- Demo: target a disposable player, navigate mobile back to Home, read it, inspect recipient read state separately from email/push attempts. External sends are executed by `NotificationDeliveryWorker`, not the RabbitMQ subscriber.
- Edge: Sent is provider acceptance, not user read. Missing push registration can produce Skipped. Editing a notification does not create a fresh delivery campaign.

### Audit Trail and provider readiness

- Reach: Audit Trail top bar; Provider readiness from that screen. Administrator-only.
- API/storage: `GET /Operations/audit` uses user/method/start-date filters and capped results over `AuditLogs`; `AuditMiddleware` records request metadata. `/Operations/provider-readiness` checks configuration shape for Stripe/SMTP/Firebase.
- Actions: read/filter/details/refresh; no editing audit entries, retrying messages or initiating payments here.
- Demo: inspect an entry/correlation ID after an ordinary mutation. Distinguish readiness configuration from an actual provider test. Separate `GET/POST /Operations/provider-verification` endpoints record bounded opt-in external checks and are API-only in the paths inspected.

## Mobile screen and navigation map

Native mobile runs the shared bootstrap; it opens Login, then Home. Bottom navigation is **Home → Search → Reservations → Shop → Profile**. Authenticated player features are available on this shell; `VerifiedPlayer` gates the Player Hub and tournament participation paths specifically.

### Home: reservations, updates, reviews and shortcuts

- `MobileHomeScreen` loads notifications, own reservations and published reviews using `Future.wait`.
- APIs: `/Notifications/mine`, `/Reservations/mine`, `/ClubReviews`; mark read `/Notifications/{id}/read`, mark all `/Notifications/read-all`, own review `PUT /ClubReviews/mine`.
- Data: next upcoming booking, recipient-scoped club updates, review strip. Add/edit review dialog permits rating 1–5 and comment 10–600 characters, enforced in `ClubReviewService`. One review per user via unique UserId index; saving updates/re-publishes own review.
- Demonstrate: add a review and revisit Home; read one targeted notification. The screen has shortcut tiles, not a dedicated photo-gallery workflow. Product assets/image URLs are a different concern.

### Search and Player Hub

- `SearchScreen` shows matches/rankings/tournaments; Player Hub is opened from Search. `DiscoveryProvider` makes parallel `/Discovery/matches` and `/Discovery/rankings` requests; tournaments use `/Tournament`.
- `PlayerHubScreen`/`PlayerExperienceProvider`: player profile/onboarding, skill/side/city/availability/discoverability; partner search/invitations; own tournament participation; match history/results.
- APIs: `/PlayerExperience/profile/mine` GET/PUT; `/partners` GET; `/partners/{userId}/invite` POST; `/invitations/mine` GET; `/invitations/{id}/respond` PUT; `/matches/mine` GET; `/matches/{id}/result` and `/confirm` POST. Controller directly queries `PlayerProfiles`, `Users`, `PartnerInvitations`, `Matches`, `MatchParticipants`.
- Rules: verified-email claim required; own profile; discoverable active partners; no self-invite or duplicate pending invite; only recipient responds once. Allowed levels Beginner/Intermediate/Advanced/Competitive and sides Left/Right/Either.
- Tournament registration: choose a partner on a tournament card, POST `/Tournaments/{id}/register`; second player accepts in own hub using `/registration/respond`; own-team withdrawal `/registration/mine`; view `/bracket`. Capacity/deadline, active Player partner, duplicate registration and complete teams are checked. Withdrawn rows are retained and can block re-registration under the existing duplicate check.
- Match result: participant reports valid padel score and winning local team 1/2; another participant confirms; rating changes and bracket advancement follow. The confirmer must differ from reporter, but need not belong to the opposing team in current code.
- Demo: use two verified accounts for invitation/response. Four accounts and a prepared bracket are needed for a complete match/tournament example. Question: which identity comes from the JWT and which user ID is the chosen recipient?

### Reservations

- `MobileReservationsScreen`: choose date, view active courts/available slots, confirm one-off or weekly series, join occupied-slot waitlist, inspect own bookings/waitlist/credits, cancel within notice period.
- APIs: `/Reservations/availability?date=...`; POST `/Reservations`; `/recurring`; `/waitlist`; GET `/mine`, `/waitlist/mine`, `/credits/mine`; PUT `/{id}/cancel`.
- DTOs: `ReservationInsertRequest`, `RecurringReservationRequest`, `WaitlistRequest`; availability/reservation/waitlist/credit responses. `ReservationService` owns rules and price calculation.
- Booking uses club time zone Europe/Sarajevo, defaults 07:00–23:00, 60-minute slots, max four-hour reservation, max 12 recurring weeks, two-hour cancellation notice. Read configured values when running. UTC values cross HTTP; client converts for display.
- Demo: reserve a free future slot; attempt duplicate via API; cancel and see it freed. Waitlist notification is an opportunity to book, not automatic promotion into a new reservation. Cancellation creates credit only when a Completed payment exists; credit display is not automatic redemption.

### Shop, details, cart, checkout and My orders

- `ProductListScreen` → active feature `product_details_screen.dart`; in-memory `CartProvider`; checkout dialog; My orders and return request dialogs live in the list-screen file.
- APIs: `GET /Product` with Name/Page/PageSize; `GET /Recommendations/products`; click telemetry POST `/Recommendations/products/{exposureId}/click`; POST `/Orders/checkout`; GET `/Orders/mine`; `/Commerce/returns/eligible-orders/mine`, `/returns/mine`, POST `/returns`.
- Search/category chips use a Name text query (for example Rackets → Racket), not a true ProductCategoryId filter. Page size is 12. The current request omits IncludeTotalCount, so the next-page controls may stay hidden: demonstrate paging through Swagger or Memberships instead.
- Details/cart: inspect description, image, price/stock; add/remove/change quantity. Checkout submits product IDs/quantities, contact/address/optional coupon and optional recommendation exposure IDs. Server rechecks stock, price and coupon; transaction saves order/items, stock movements, coupon redemption and attribution.
- Checkout creates Pending order and decrements stock. No Flutter Stripe payment sheet or completed card charge is part of this checkout path. Address map opening uses `url_launcher`, not server geocoding/delivery tracking.
- Returns: choose delivered eligible own order and quantities, enter reason, submit, then inspect server status/club note. Thirty-day window uses actual DeliveredAt; remaining quantities subtract prior non-Rejected requests. Partial refunds allocate the discounted total in cents.
- Demo: one item, valid address, no payment claim; staff progresses order; player refreshes. Try empty cart/excess quantity/expired coupon. Do not claim the product catalogue applies every visibility rule correctly; see limitations below.

### Profile and account sub-screens

- `ProfileScreen`: account/contact edit, password change, email verification, reservation-derived activity, logout. GET/PUT `/Users/me`, `/Users/request-email-verification`, `/Users/verify-email`.
- My memberships: GET `/Memberships/mine`, PUT `/{id}/auto-renew` or `/cancel-at-period-end`, GET `/{id}/history`; owner-scoped membership records/events, no card collection.
- Payment history: `PaymentHistoryScreen`, GET `/Payments/mine`; persisted amount/status/provider/refund/reconciliation/receipt details, read-only. Does not initiate payment/refund.
- Notification settings: GET/PUT `/NotificationSettings/mine`; in-app/email/push toggles, saved preferences. Server supports device registration; no Firebase messaging client SDK was found in Flutter dependencies, so do not promise end-to-end mobile push registration/delivery.
- Privacy: GET `/Privacy/export` displays own exported data; POST/GET/DELETE `/Privacy/deletion` schedules/views/cancels deletion request. Worker performs later anonymization/inactivation and related cleanup; scheduling is 30 days out, not immediate hard deletion of transaction history.
- Demo: edit phone, inspect owner-scoped history, save settings, view export. Use a disposable account to rehearse deletion scheduling and cancel the request immediately afterward. A backend password-recovery endpoint does not imply a visible forgot-password page on Login.

## Backend inventory and responsibilities

The [source index](SOURCE_INDEX.md) lists declarations and every method-level route/policy. Groups below explain responsibility; inherited routes must also be considered.

- Generic controllers: BaseController GET/list/by-ID; BaseCRUDController create/update/delete. `IService`/`ICRUDService` and BaseService/BaseCRUDService implement common behavior.
- Service-backed entity controllers: Users, Product, ProductCategories, ProductTypes, Courts, Reservations, Orders, OrderItems, Payments, Memberships, Tournament, TournamentParticipants, MatchParticipants, Roles, Notifications, ClubReviews. Role and participant/line administration is restricted; some read-only base controllers expose no full CRUD.
- Authentication: UsersController calls IAuthService/AuthService, which calls IUserService/UserService and password verification; JWT middleware handles future authenticated requests.
- Direct orchestration: Discovery, PlayerExperience, TournamentLifecycle, CommerceOperations, Privacy, NotificationSettings, Operations. Operations also delegates recommendation evidence/collection readiness.
- Dedicated integration/evidence APIs: StripePayments, Recommendations, RecommendationImpact, RecommendationExperiments, ProviderReadiness, ProviderVerification.
- Hosted services: OutboxPublisherWorker, ProviderRefundOperationWorker, NotificationDeliveryWorker, MembershipLifecycleWorker, PrivacyDeletionWorker. Separate process: ProductUpdatedSubscriber.
- Mapping: Mapster conventions in CRUD/state classes; manual user/notification/review responses and explicit LINQ projections elsewhere. Many small requests are records declared at the bottom of controller files, not only in Model/Requests.
- Validation: Flutter forms, selected DataAnnotations, explicit service/controller checks, EF required/max-length/FK/unique constraints. No separate FluentValidation pipeline was found.
- Errors: ExceptionFilter, controller-specific catches/results, automatic ApiController validation, JWT challenges/forbids and auth rate limits; AuditMiddleware records metadata. Status mapping is not uniform across all CRUD and workflow endpoints.

## Roles and authorization truth

The seeded application roles are **Administrator** and **Player**. Match participant Role values such as Captain are sports roles, not automatically JWT access roles. Role records can be managed, but only exact `Administrator` is required by `AdminOnly`. Flutter additionally recognizes an `admin` spelling; that UI acceptance does not satisfy the backend policy.

- Anonymous: login/refresh/password recovery/reset/email verification and Stripe webhook (provider signature validated), plus configured development documentation/health routes. Generic entity reads normally inherit `[Authorize]`.
- Administrator: management CRUD/actions, operational/evidence/provider diagnostics, delivery diagnostics, refunds/bracket generation. Staff workflows use Administrator; there is no separate seeded Staff role.
- Ordinary authenticated user: catalogue/discovery, own account, bookings, checkout, own orders/payments/memberships/notifications, reviews/preferences/privacy. Most of these require authentication, not an explicit Player-role check.
- VerifiedPlayer policy: authenticated + `email_verified=true` claim; it does **not** require the Player role. PlayerExperience and specific tournament participant actions use it. An administrator with the claim can also satisfy that policy.
- Ownership: `/mine` and `/me` take caller ID from claims and override caller-supplied user filters. Specific mutations check recipient/owner/participant. Hiding buttons is presentation only; `[Authorize(Policy="AdminOnly")]` is the server restriction for management endpoints. Roles in a JWT reflect issuance time.
- Exception requiring review: inherited `GET /Reservations/{id}` calls generic GetByIdAsync without owner filtering, whereas `/mine` and cancel do scope identity. Do not claim all reservation reads are owner-protected.

## Main workflows to be ready to trace

Login/refresh/logout; user/role administration; court management; available-slot booking/recurring bookings/cancellation/waitlist/credit; product lifecycle plus outbox/inbox; catalogue search/recommendations; cart/checkout/coupon/stock; fulfillment/cancellation; return approval/refund saga; notifications/read state/preferences/delivery; review upsert; partner profile/invite/response; tournament team registration/bracket/result confirmation/rating; membership end/renewal/preferences; privacy export/scheduled deletion; analytics/audit/provider diagnostics; recommendation evaluation/consent/prospective experiments.

## Material implementation limits to explain honestly

1. `ReservationsController` does not override inherited GetById with owner enforcement.
2. Shop pagination omits IncludeTotalCount although controls depend on TotalCount; several desktop searches operate only on capped first-page snapshots.
3. `OrderService.CheckoutAsync` uses case-sensitive `ProductState.Contains("deactivated")`, while stored class names include `DeactivatedProductState`. `ProductService.ApplyFilter` does not restrict catalogue results to active/published products. State transitions do not synchronize the separate IsActive flag. Consequently do not claim every draft/deactivated purchase is blocked.
4. Product create overrides base CRUD and bypasses its BeforeInsert reference-normalization hook; omitted nullable category/type IDs can map to invalid required FKs. Use valid reference IDs in a demo. Product DTOs do not have comprehensive required/range annotations; frontend validation does not prove negative values are blocked through the API.
5. Product DELETE is inherited generic deletion, outside the State pattern. It may be blocked by database references, but no state-specific delete guard exists.
6. Access JWTs are not immediately revoked by logout/password reset; refresh tokens are revoked. Existing claims remain valid until token expiry unless an additional check is implemented. AuthProvider's timer is fixed at 12 minutes, rather than using the returned expiration timestamp.
7. Booking creation/series use explicit serializable transactions; generic reservation updates do not use that same transaction wrapper. Bracket generation makes several saves without an enclosing transaction, and result confirmation commits before advancing the winner. Do not claim atomicity across every workflow.
8. RabbitMQ subscriber commits receipt then logs. A crash between those steps can omit the log; inbox deduplication does not make arbitrary future business side effects exactly-once.
9. Server provider adapters, email preferences and read-only readiness screens do not establish live Stripe/Firebase/mobile push completion. Checkout, manual membership renewal and ordinary non-Stripe return approval are local business operations.

These are source observations and inferences, not newly reproduced exploit results. They belong in your preparation so you can distinguish implemented behavior from intended improvements.
