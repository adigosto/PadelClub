# Live professor demonstration

This is a rehearsal plan, not a record of operations already performed. Use a local demo database and disposable records. Rehearse before the exam; do not depend on downloads, first-time builds or four-person registration during the timed presentation.

## Start on a fresh computer

Install Docker Desktop/Compose, .NET SDK 8 for local builds/tests, and the compatible Flutter toolchain (CI pins Flutter 3.44.5; pubspec requires Dart ^3.12.2). Windows desktop needs Flutter's Windows build prerequisites; Android needs a configured emulator/SDK. Check `flutter doctor` before the exam.

From the repository root, copy the sample only if a local file does not already exist:

```powershell
if (-not (Test-Path -LiteralPath .env)) {
    Copy-Item -LiteralPath .env.example -Destination .env
}
$env:AUTH_SIGNING_KEY = "$(New-Guid)-$(New-Guid)-$(New-Guid)"
$env:SEED_DEMO_DATA = "true"
$env:DEMO_PASSWORD = "Choose-a-local-demo-password-2026!"
docker compose up --build --detach
docker compose ps
Invoke-RestMethod http://localhost:5000/health/ready
```

Open Swagger at `http://localhost:5000/swagger`, Mailpit at `http://localhost:8025`, RabbitMQ management at `http://localhost:15672`. SQL is `localhost,1433`, database PadelClub, using your local Compose credentials. On a fresh seeded local database, `admin` and `player1` use the value of `$env:DEMO_PASSWORD`; existing accounts may differ. Those are development accounts, not a production credential policy.

Start desktop in a second terminal:

```powershell
Set-Location UI/padelclub_desktop
flutter pub get
flutter run -d windows --dart-define=baseUrl=http://localhost:5000
```

Start the Android emulator before starting mobile in another terminal:

```powershell
Set-Location UI/padelclub_mobile
flutter pub get
flutter devices
flutter run --dart-define=baseUrl=http://10.0.2.2:5000
```

Select the emulator if several devices are listed. Use localhost for an iOS simulator on its host; use the host's reachable LAN address for a physical device. Do not run a separate local API on the same port as the API container. The local API launch profile needs a separately correct SQL connection string.

## Before the 15-minute clock

- Verify readiness and both logins; load the screens once.
- Prepare one available future booking date and note the club time zone.
- Prepare a draft product with valid active category/type IDs, plus an active product with sufficient stock.
- Keep Swagger, a read-only SQL query window and subscriber logs ready. Obtain fresh admin/player JWTs through login and keep tokens out of screenshots/reports.
- Create a disposable player/membership if using the secondary examples. If demonstrating tournament brackets, prepare four verified distinct players and two confirmed teams in advance.
- Use notification targets you control. Provider settings must be rehearsed separately if you choose an external integration demonstration.

## Main sequence: 15 minutes

1. **0:00–1:30 — System and architecture.** Show Compose services/readiness. Explain shared Flutter package, platform-specific shell, API/service/context/SQL, separate subscriber.
2. **1:30–2:30 — Identity and permissions.** Show invalid login, then admin login. State authentication versus authorization. Keep a player token available for later denied API call.
3. **2:30–4:00 — One management CRUD operation.** Create/edit a disposable court or user. Demonstrate a simple form validation and explain controller/service/EF path. Do not spend the entire demo on repeated CRUD screens.
4. **4:00–7:00 — Cross-client reservation.** On mobile login as player1, Reservations → choose future available slot → confirm. Note booking ID. Desktop Reservation Management → Refresh → find ID → cancel. Mobile revisit Reservations/reload → show Cancelled. Explain shared SQL and explicit HTTP refresh.
5. **7:00–8:30 — Database and invalid input.** Run the reservation join from DATABASE.md with that ID. Show FK CourtId/UserId. Through Swagger, show a protected management action rejected with player credentials; optionally show overlap rejection using another occupied slot.
6. **8:30–11:30 — State pattern plus messaging.** Product Management → edit a prepared draft → save. Show outbox row and matching subscriber event/inbox. Activate → attempt another edit through Swagger → show failure → open BaseProductState and DraftProductState. Explain durable intent/at-least-once/deduplication.
7. **11:30–13:30 — Shop and stock.** Mobile Shop → item → cart → valid address → checkout. Desktop Order Management → Refresh → find matching order number. Show Pending and inventory movement. Explain server prices and that an order is not a card charge.
8. **13:30–15:00 — Advanced evidence and close.** Show recommendation explanation/fallback and admin evaluation exclusions. Point to current limitations without overstating quality/provider completion. Open the requested code when challenged.

For 10 minutes, omit the extra management CRUD and shop segment. For 20 minutes, add full order delivery/return resolution or a prepared membership/notification workflow. Choose one substantial extension rather than rushing through every screen.

## Exact cross-application alternatives

### A. Booking → staff cancellation → player status

1. Mobile player → Reservations; choose a future free slot and create a single booking.
2. Note returned reservation ID/date/court.
3. Desktop admin → Reservation Management → Refresh; find that ID.
4. Cancel through the cancellation action, not generic DELETE.
5. Mobile navigate away/back or use the screen's reload action; show cancelled record and free slot.
6. Query the same SQL row. Explain `search.UserId = callerId` on mine, server-side price, overlap check and commit.

### B. Checkout → staff delivery → customer return

1. Mobile player → Shop → details → add quantity one → checkout with valid recipient/phone/address/city/postcode.
2. Note order number; no card-charge claim.
3. Desktop admin → Order Management → Refresh; find order.
4. Progress Pending → Processing → Shipped → Delivered, saving each step.
5. Mobile Shop → My orders; reload/reopen and observe Delivered.
6. Submit return for one eligible line/quantity with reason.
7. Desktop Return requests → Refresh → inspect → approve with note or reject.
8. Mobile refresh own returns; show server status/note. Ordinary local approval is Approved; Stripe-backed approval can remain RefundPending until provider settlement.
9. Show OrderItems price snapshot, DeliveredAt, ReturnRequestItem and InventoryMovements. Do not equate approval with a provider refund unless provider evidence exists.

### C. Staff membership → player self-service

1. Use an existing disposable player's membership; note its ID.
2. Desktop Memberships → find record → suspend with note.
3. Mobile Profile → My memberships → refresh/reopen; see Suspended and history.
4. Desktop renew by one month; mobile reload shows new period/status.
5. Explain record renewal and MembershipEvents; no automatic charge is made.

### D. Staff notification → player read state

1. Desktop Notifications → create a uniquely titled notification targeted to a demo player.
2. Mobile switch to Home again; the data-loading path retrieves `/Notifications/mine`.
3. Open/read the notification or Mark all read.
4. Query NotificationRecipients for that player/notification.
5. Separately inspect Delivery Diagnostics. In-app read state, SMTP/push sending state and RabbitMQ product events are three different mechanisms.

### E. Product update across clients and subscriber

1. On desktop choose a draft product with valid category/type IDs; change its description and save.
2. Mobile reopen the shop/details so the product is fetched again; observe the saved description where the catalogue exposes it.
3. Show the outbox/inbox correlation and subscriber log. Explain that HTTP reload caused the client update; subscriber receipt is independent.
4. Activate product, attempt forbidden edit and show the state method.

## API demonstrations worth preparing

Use current IDs and the exact Swagger schema. Base routes are `/Product`, `/Users`, `/Reservations`, `/Orders`, etc.; do not invent `/api/products`.

- GET `/Product?Page=1&PageSize=2&IncludeTotalCount=true`, then Page=2: shows actual server pagination, independent of the shop's total-count omission.
- Anonymous GET `/Product`: 401. Player PUT `/Product/{id}/activate`: 403. Admin action with invalid state: business failure after authorization.
- POST `/Reservations` using an occupied interval: conflict from create path. Changing client UserId/TotalPrice does not set final owner/price because controller/service replaces them.
- PUT `/Product/{activeId}`: invalid state rejected. PUT a deactivated product twice: first goes to draft, second applies fields.
- POST `/Orders/checkout` with empty items or excessive quantity: server validation. Generic create endpoints may have weaker contracts; explain the actual route being tested.
- GET `/Payments/mine?UserId=<other>`: owner filter is replaced. Do not generalize this guarantee to inherited reservation GET-by-ID.

## Failure recovery during the exam

If the API cannot reach SQL, show `/health/ready` and service logs before continuing. If a client cannot connect, check host/emulator/LAN baseUrl and port. If RabbitMQ is offline, show durable pending outbox rows; do not claim receipt. If Stripe/Firebase is not configured, show the implemented code/readiness boundary and use a local workflow instead.

For a separate full rehearsal, the repository provides `scripts/Invoke-CleanComposeSmoke.ps1 -Cleanup`, which uses an isolated Compose project/fresh volumes and its own API port. Read that script's current parameters and ensure Docker capacity/ports before running. Do not use `docker compose down --volumes` on the normal demo stack merely to reset one record.
