# Phase 6: tournaments and memberships

## Tournament lifecycle

- Verified players register as a two-player team.
- The invited partner must confirm the registration.
- A team can withdraw before registration closes or a bracket is generated.
- Administrators generate a single-elimination bracket from confirmed teams.
- Non-power-of-two team counts receive automatic first-round byes.
- Every match contains an explicit next-match and next-team slot.
- Confirmed results advance winners automatically; the final completes the tournament.
- Bracket state is available from `GET /Tournaments/{id}/bracket`.

Suggested Swagger flow:

1. Create an upcoming tournament with at least four participant slots and a future registration deadline.
2. As a verified player call `POST /Tournaments/{id}/register` with `{ "partnerUserId": 3 }`.
3. Sign in as the partner and call `PUT /Tournaments/{id}/registration/respond` with `{ "accept": true }`.
4. Repeat for another team.
5. As an administrator call `POST /Tournaments/{id}/bracket/generate`.
6. Report and confirm results through the Phase 5 match endpoints.

## Membership lifecycle

- Explicit `Active`, `Suspended`, `Cancelled`, `Expired`, and `RenewalDue` states.
- User-controlled cancellation at period end and automatic-renewal preference.
- Administrator suspension, reactivation, cancellation, and paid/manual renewal.
- Immutable membership event history.
- Hourly expiry processing and lifecycle notifications.
- Automatic renewal never grants unpaid access: it transitions to `RenewalDue` until payment and renewal are processed.

Useful endpoints:

- `GET /Memberships/mine`
- `PUT /Memberships/{id}/cancel-at-period-end`
- `PUT /Memberships/{id}/auto-renew`
- `GET /Memberships/{id}/history`
- `PUT /Memberships/{id}/status` (administrator)
- `POST /Memberships/{id}/renew` (administrator/payment fulfillment)

Migration: `AddTournamentAndMembershipLifecycle`.
