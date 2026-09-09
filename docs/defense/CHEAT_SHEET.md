# Defense cheat sheet

## The explanation to memorize

“PadelClub has desktop staff management and a mobile player experience built from a shared Flutter package. Both call a .NET 8 ASP.NET Core API. Business services and some controllers use EF Core with SQL Server. JWT identifies and authorizes callers. Product edits use a State pattern and transactional outbox; a separate RabbitMQ subscriber records durable receipts.”

## Facts to memorize

- **Stack:** Flutter/Dart, Provider/ChangeNotifier, http, secure storage; ASP.NET Core 8, EF Core 8/SQL Server, Mapster, JWT/PBKDF2, EasyNetQ/RabbitMQ, Docker/Compose. Stripe/MailKit/Firebase adapters exist; configuration/observed delivery is separate.
- **Projects:** Model contracts; Services/business/EF; WebAPI/HTTP/workers; Subscriber separate executable; desktop shared Flutter; mobile wrapper; Tests; external benchmark tool.
- **Desktop:** users, courts, reservations/maintenance/no-show, products/states/stock/coupons, fulfillment/returns, memberships, tournament/bracket, notifications/delivery, audit/provider readiness, operational/recommendation evidence panels.
- **Mobile:** Home updates/reviews/next booking; Search/Player Hub/partners/tournaments/matches; Reservations/recurrence/waitlist/credits; Shop/recommendations/cart/checkout/orders/returns; Profile/account/verification/membership/payment history/preferences/privacy.
- **Roles:** Administrator and Player. AdminOnly requires exact Administrator; VerifiedPlayer requires authenticated + verified-email claim, not a Player role by itself.
- **Core tables:** Users/UserRoles/Roles; Courts/Reservations; Products/Orders/OrderItems; Payments; Memberships/Events; Tournaments/Participants/Matches; Notifications/Recipients/Deliveries; Outbox/Inbox. Full 48-DbSet catalogue is in DATABASE.md.
- **Booking defaults:** Europe/Sarajevo; 07–23; 60-minute slots; max four hours; two-hour cancellation notice; max 12 recurring weeks. Verify runtime overrides.
- **Product states:** Initial → Draft → Active → Deactivated; Deactivated activate → Active; Deactivated update → Draft only; Draft update changes fields and adds event. No Archived state.
- **Order states:** Pending → Processing → Shipped → Delivered; cancellation from Pending/Processing; same-state update accepted. DeliveredAt is server-stamped.
- **Docker:** API host 5000/container 5001; SQL 1433; AMQP 5672; Rabbit management 15672; Mailpit UI 8025/internal SMTP 1025. Service DNS names inside containers; Android emulator host gateway 10.0.2.2.

## Concepts to understand rather than recite

- **Request flow:** screen/provider HTTP → JWT/policy/controller → service or direct context → SQL → DTO/projection → Dart parse/state rebuild. No direct client SQL and no direct desktop/mobile synchronization.
- **DI:** interface/registration/constructor/usage; transient versus scoped/singleton. Hosted workers create scopes for DbContext. Flutter uses a custom locator and Provider, not uniformly pure Clean Architecture.
- **State pattern:** state classes implement allowed behavior; inherited methods reject. Generic delete and independent IsActive are outside this narrow pattern.
- **Authentication:** PBKDF2 verification issues signed JWT and rotating opaque refresh token; secure storage remembers refresh secret, not password. JWT claims remain valid until expiry; refresh revocation is different.
- **Authorization:** server policies and owner/participant checks, not hidden buttons. Know the inherited reservation GET-by-ID gap.
- **DTO/mapping:** contract separate from entity; conventions/manual projections; omissions/defaults can behave differently during updates. Mapping does not validate business rules.
- **Validation:** UI convenience; API rule enforcement; database constraints. Some DTOs lack annotations. InvalidOperationException can be 400 or 409 depending on controller catch.
- **EF/relationships:** PK/FK/navigation; joins with data; unique optional one-to-one; per-relationship Cascade/Restrict/SetNull. IQueryable execution versus in-memory filtering.
- **Async:** awaiting I/O completion, not automatically creating threads. Do not fire-and-forget saves or concurrently use one DbContext.
- **RabbitMQ:** SQL outbox records intent atomically; background publish/retry; stable event ID; inbox deduplication; at-least-once, current subscriber log-only.
- **Commerce:** server prices/stock/coupons and transaction; order != payment; refund saga != distributed SQL/Stripe transaction.
- **Recommendation:** delivered net purchases → weighted peer item similarity → ranked unseen candidates/fallback. Serving demonstration, historical evaluation, external benchmark and causal experiment are different evidence.

## Twenty likely professor questions, with short preparation answers

1. **Explain the architecture.** Shared Flutter distributions → .NET API → services/direct controllers → EF/SQL; separate Rabbit subscriber.
2. **Why does mobile depend on desktop?** That package holds the shared implementation; the mobile project provides runners/composition, with shell selection at runtime.
3. **Trace a booking.** Provider POST → controller claims identity → ReservationService serializable validation/price/save/notification → commit → response/reload.
4. **What stops a player calling admin API manually?** JWT validation plus AdminOnly policy requiring Administrator. Ownership checks solve a separate problem.
5. **How are passwords stored?** PBKDF2-HMAC-SHA256 derived hash and random salt; active code supports legacy separated fields and encoded format. No decryption.
6. **What does logout invalidate?** Client state and refresh token; existing access JWT is not immediately revoked by this implementation.
7. **Why a DTO?** Restricts/shapes contract and avoids exposing persistence details/private fields; mapping is not validation.
8. **Is searching client- or server-side?** Both: BaseService LINQ filters/paging server-side; several desktop screens filter capped fetched lists. Memberships has actual paging; shop total-count omission is a gap.
9. **Explain a many-to-many.** Users↔Roles through UserRoles, with assignment time and unique pair; OrderItems similarly joins orders/products with quantity/price.
10. **Why Include here?** UserService needs UserRoles.Role to construct role responses/claims; EF does not promise every navigation is loaded automatically.
11. **What does SaveChangesAsync do?** Persists tracked changes; explicit outer transaction is needed to make several saves atomic together.
12. **Why async?** Wait for database/HTTP I/O without blocking throughout the wait; await sequences dependent work and propagates exceptions.
13. **Why inject IProductService?** Centralized dependency construction/lifetimes, replaceable contract, easier isolated testing; controller avoids constructing context/mapper/state graph.
14. **Why State pattern instead of enum?** An enum names state; state classes organize state-specific allowed behavior and rejection, though enums plus explicit logic are a valid alternative.
15. **What if I edit an active product in Swagger?** Authorization first; state dispatch reaches rejecting base Update. Deactivate and return to draft before editing.
16. **Why RabbitMQ rather than a direct call?** Independent consumer availability/deployment and asynchronous integration; durable SQL outbox preserves event intent across broker failure.
17. **What if publishing succeeds but acknowledgment to SQL fails?** Retry can duplicate delivery; stable EventId and unique inbox receipt deduplicate. No exactly-once guarantee for arbitrary side effects.
18. **What prevents stock/refund duplication?** SQL transaction/update locks, current-state checks and durable refund idempotency/leases. Explain the chosen workflow, not a blanket guarantee.
19. **Does Compose prove your payment provider works?** No; it starts/configures local services. Readiness, actual provider acceptance, recipient delivery and payment completion are separate evidence.
20. **Is the recommender a trained ML model and is it effective?** It is application-side deterministic item-to-item CF. Show actual evaluation provenance, exclusions, baseline/gates; demo data/external retail metrics cannot establish club conversion lift.

## Twenty priority code locations

For each critical group, follow its public methods, constructor dependencies and success/error branches in the tutor lesson. Full navigation links are in SOURCE_INDEX.

### Critical

1. **PadelClub.WebAPI/Program.cs:** composition, middleware, JWT/policies, bootstrap and workers. Follow registration → resolution → middleware order. Question: why authorization after authentication?
2. **UI shared lib/main.dart + mobile lib/main.dart + layouts/master_screen.dart:** bootstrap, providers, route/shell selection and login. Follow sign-in → `/home` → platform/role branch. Question: where does mobile reuse occur?
3. **providers/auth_provider.dart:** login/headers/refresh/storage/logout and fixed refresh timer; depends on HTTP/config/secure storage. Question: which token is persisted?
4. **Authentication/AuthService.cs + UserService.cs + PasswordHasher.cs:** credentials, roles, hash variants, issue/rotate/revoke sessions. Question: stale JWT versus refresh reuse?
5. **BaseController/BaseCRUDController + BaseService/BaseCRUDService:** inherited routes, CRUD hooks, pagination/mapping and differing errors. Question: which inherited endpoint remains accessible?
6. **ReservationsController + ReservationService:** claims, overlap/maintenance/time/price, cancellation/series; context/mapper/notifications/options. Question: what is inside the transaction?
7. **ProductService + ProductStateMachine/*.cs:** dispatch/allowed behavior, draft mapping/outbox, state-only deactivated update. Question: which hook is bypassed?
8. **Database/PadelClubContext.cs:** keys/FKs/indexes/delete behavior/DbSets and tracked evidence guards. Question: can a direct ExecuteDelete bypass a SaveChanges guard?
9. **OrderService.cs:** CheckoutAsync, UpdateAsync, IsAllowedTransition; context/mapper/notifications/recommendations; pricing/stock/coupon/locking/delivery. Question: repeat cancellation and case-sensitive state check?
10. **CommerceOperationsController + refund-operation service/processor:** return validation, row claim, approval/provider handoff/reconciliation. Question: crash after provider acceptance?
11. **OutboxPublisherWorker + SqlServerOutboxLeaseService:** claim/renew/publish/deadline/mark/retry; context scopes + bus. Question: two replicas and expired lease?
12. **ProductUpdatedSubscriber + InboxDeduplicationService:** subscription retry, unique durable receipt, current log side effect. Question: receipt committed but log not written?

### Important

13. **ProductRecommendationService + ItemBasedCollaborativeRanker:** source signals, returns, peer vectors, score/fallback/exposure.
14. **RecommendationEvaluationService + RecommendationExperimentService:** temporal/provenance gates, immutable runs, consent, sticky randomized assignment/lifecycle.
15. **PlayerExperienceController + BracketService:** participant identity, result validation/confirmation/rating and bracket generation/advancement.
16. **NotificationService + NotificationDeliveryWorker:** recipient versus delivery state, preferences, retries and sender adapters.
17. **MembershipsController + MembershipLifecycleWorker:** ownership, staff lifecycle, events and hourly expiry.

### Useful

18. **PrivacyController/PrivacyDeletionWorker + AuditMiddleware/OperationsController:** exports, scheduled anonymization, request metadata/analytics.
19. **Dockerfiles/docker-compose.yml + scripts/Invoke-CleanComposeSmoke.ps1:** topology, host/container network/storage and isolated rehearsal.
20. **features/product/.../product_list_screen.dart + ProductProvider + CartProvider:** actual client request construction, pagination gap, cart/checkout/returns and model parsing.

## Last-minute facts to avoid getting wrong

No Archived product state; no mobile gallery/rental workflow proven; no normal public signup page; generic create often returns 200 not 201; Stripe checkout is not wired as a Flutter card payment; membership auto-renew does not auto-charge; notifications do not use the product Rabbit subscriber; dashboard schedule panels are previews; API read guards are not uniformly owner-scoped; not every Id suffix denotes an FK.
