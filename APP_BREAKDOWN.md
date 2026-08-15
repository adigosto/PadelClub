# PadelClub product breakdown

## What exists now

### Backend

- ASP.NET Core Web API with controller/service/model separation.
- Users and roles, courts, availability and reservations.
- Tournaments and participants, match participants and discovery summaries.
- Memberships, payments, products, categories/types, orders and order items.
- Notifications and club reviews.
- Entity Framework migrations, Docker support, and a RabbitMQ product subscriber.

### Desktop admin app

- Flutter desktop management shell with role-aware authentication.
- Management modules for users, courts, reservations, products, orders, and notifications.
- Shared green/blue Material 3 theme, reusable admin components, loading/error/empty states.
- Feature-first layers for most modules and provider-based state management.

### Mobile player app

- Independent Android/iOS target in `UI/padelclub_mobile`.
- Shared authenticated player experience: Home, Search, Reservations, Shop, and Profile.
- Home updates and reviews, court availability and booking, discovery/rankings/tournaments,
  profile and membership information, product browsing, cart, checkout, and order history.

## What a production-complete padel club app still needs

### Must-have before release

1. Replace Basic Authentication and stored passwords with short-lived access tokens,
   refresh-token rotation, password reset, email verification, logout/revocation, and
   server-side authorization policies for every admin operation.
2. Integrate a real payment provider. Make checkout idempotent, verify payment webhooks,
   support refunds, invoices/receipts, taxes, failed payments, and reconciliation.
3. Add booking lifecycle rules: configurable opening hours and slot length, maintenance
   blocks, recurring bookings, cancellation/no-show policy, credits/refunds, waitlists,
   and explicit timezone handling.
4. Add push notifications (FCM/APNs), device-token management, notification preferences,
   deep links, and transactional email for booking and payment confirmations.
5. Add production operations: environment-specific secrets, HTTPS, health checks,
   structured logs, crash/error monitoring, backups with restore drills, rate limiting,
   audit logs, and database retention/privacy controls.
6. Add automated coverage for authentication/authorization, concurrent double-booking,
   payments/webhooks, cancellation/refunds, API contracts, and critical mobile journeys.

### Important product gaps

- Player registration/onboarding and consent/privacy flows.
- Partner finder with skill levels, invitations, chat or contact preferences.
- Complete match model, score entry/confirmation, rankings/ratings, and match history.
- Tournament brackets, seeding, schedules, results, check-in, and capacity/waitlists.
- Membership plans, renewal, pause/cancel, entitlements, discounts, and access control.
- Staff calendar and court utilization view; exports and revenue/occupancy analytics.
- Inventory/SKU/stock tracking, product images, delivery tracking, returns, and coupons.
- Multi-club/location support if the product will serve more than one venue.
- Accessibility review, localization, legal pages, account deletion, and data export.

## Recommended delivery order

1. Security and authorization foundation.
2. Booking reliability, timezone rules, cancellation/refund workflow.
3. Stripe payments plus receipts, refunds, signed webhooks, idempotency, and reconciliation.
4. Push/email notifications and deep links.
5. Mobile onboarding and partner/match flows.
6. Tournament and membership completeness.
7. Admin analytics, stock/commerce depth, and multi-location support.
8. Release hardening: tests, monitoring, accessibility, privacy, store assets, CI/CD.

## Project boundary

The desktop and mobile apps intentionally share one feature implementation to prevent
business rules and API models from drifting. `padelclub_desktop` is the shared Flutter
application/library and desktop runner; `padelclub_mobile` is the mobile runner and
package identity. A future cleanup can move shared code into `padelclub_client_core`
once independent release cadence or platform-specific teams justify the extra package.
