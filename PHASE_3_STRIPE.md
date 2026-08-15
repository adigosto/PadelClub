# Phase 3: Stripe payments

## Implemented

- Server-calculated PaymentIntents for reservations, memberships, and orders.
- A unique internal and Stripe idempotency key for safe request retries.
- Authenticated ownership checks; clients never submit the charge amount.
- Raw-body, signature-verified Stripe webhooks.
- Idempotent webhook processing and reconciliation history.
- Success, failure, cancellation, receipt URL, full refund, and partial refund state.
- Admin-only refund endpoint with refund idempotency.
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
