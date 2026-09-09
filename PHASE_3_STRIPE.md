# Phase 3: Stripe payments

## Implemented

- Server-calculated PaymentIntents for reservations, memberships, and orders.
- A unique internal and Stripe idempotency key for safe request retries.
- Authenticated ownership checks; clients never submit the charge amount.
- Raw-body, signature-verified Stripe webhooks.
- Idempotent webhook processing and reconciliation history.
- Success, failure, cancellation, receipt URL, full refund, and partial refund state.
- Admin-only refund endpoint that queues a durable, caller-idempotent refund
  operation and returns `202 Accepted` rather than calling Stripe inside the
  request transaction.
- Leased provider-refund worker with Stripe metadata reconciliation, immutable
  idempotency keys, bounded retry/backoff, and final SQL settlement.
- Stripe receipt email on the PaymentIntent.

## Configuration

Never commit Stripe secrets. Set these environment variables before starting Compose:

```powershell
$env:STRIPE_SECRET_KEY = "sk_test_..."
$env:STRIPE_WEBHOOK_SECRET = "whsec_..."
$env:STRIPE_CURRENCY = "bam"
docker compose up -d --build
```

For local webhook forwarding with the Stripe CLI:

```powershell
stripe listen --forward-to http://localhost:5000/StripePayments/webhook
```

Copy the `whsec_...` value printed by the CLI into `STRIPE_WEBHOOK_SECRET`, then restart the API container.

## API

- `POST /StripePayments/intent` — player-owned PaymentIntent creation.
- `POST /StripePayments/webhook` — anonymous only because Stripe calls it; every payload must pass signature verification.
- `POST /StripePayments/{paymentId}/refund` — administrator-only full or partial refund.

The client receives a PaymentIntent client secret. Android/iOS should confirm it with Stripe's Payment Sheet using a publishable key; secret keys remain server-only.

For an administrator refund, supply an `idempotencyKey` (8-100 characters).
`POST /StripePayments/{paymentId}/refund` queues the durable operation and
returns `202 Accepted`; `GET /StripePayments/refunds/{operationId}` exposes its
read-only status/error snapshot.

## Refund consistency boundary

The application does not use a distributed Stripe-to-SQL transaction. Instead,
it commits a durable refund intent first, calls/reconciles Stripe outside the
SQL transaction, then performs owner-checked SQL settlement. A crash after a
Stripe acceptance can be retried safely because the operation ID is stored in
Stripe metadata and the same immutable idempotency key is reused. This is
reliable local reconciliation, not proof of a live Stripe payment until real
credentials and provider results are demonstrated.
