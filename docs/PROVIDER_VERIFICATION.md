# Provider verification protocol

`GET /Operations/provider-readiness` is intentionally configuration-only. It
does not contact a provider and it cannot be used as proof of payment or
delivery.

The separate administrator-only provider-verification route exists to collect
bounded **test/rehearsal** evidence when the club owner deliberately configures
it:

```text
POST /Operations/provider-verification/{stripe|smtp|firebase}
{ "confirmExternalCall": true }

GET /Operations/provider-verification
```

The request never accepts a recipient address, push installation ID, key,
payment ID, or provider reference from the client. Those values come only from
deployment configuration. The feature is disabled by default.

## Required deployment gates

Set only the provider you intend to rehearse; keep every other gate false.

```text
PROVIDER_VERIFICATION_ENABLED=true
PROVIDER_VERIFICATION_ALLOW_STRIPE_TEST_READ=false
PROVIDER_VERIFICATION_ALLOW_SMTP=false
PROVIDER_VERIFICATION_ALLOW_FIREBASE=false
```

Additional fixed targets are required per provider:

- Stripe: `PROVIDER_VERIFICATION_ALLOW_STRIPE_TEST_READ=true`, a `sk_test_...`
  Stripe key, and `PROVIDER_VERIFICATION_STRIPE_TEST_PAYMENT_INTENT_ID` pointing
  to a deliberately created non-live `pi_...` test object.
- SMTP: `PROVIDER_VERIFICATION_ALLOW_SMTP=true`, an actual configured SMTP host,
  and `PROVIDER_VERIFICATION_SMTP_RECIPIENT` owned by the authorised tester.
- Firebase: `PROVIDER_VERIFICATION_ALLOW_FIREBASE=true`, Firebase project and
  credentials, and `PROVIDER_VERIFICATION_FIREBASE_INSTALLATION_ID` for an
  authorised tester's device.

The endpoint checks a per-provider cooldown, defaulting to 15 minutes and
configurable from 1 to 1,440 minutes. This check is not a distributed lease:
concurrent requests can both pass, so run rehearsals serially. It has no
live Stripe write mode: the Stripe rehearsal performs only a read of the fixed
test PaymentIntent and rejects a live-mode object.

## Evidence semantics

A durable `Started` record is committed before any outbound call. The record is
then finalized as `Succeeded` or `Failed` with a normalized category. It stores
no secret, recipient, device ID, provider object ID, raw provider error, email
body, or notification token. A `Started` record without a terminal outcome is
an indeterminate interrupted attempt, not success.

- `StripeTestReadAccepted`: the configured Stripe test credential could read the
  fixed non-live object. This does not prove a charge, webhook, refund, or
  production payment flow.
- `SmtpAccepted`: the SMTP server accepted a fixed correlation-only message.
  This is not an inbox-delivery or read-receipt claim.
- `FirebaseAccepted`: FCM accepted a fixed correlation-only notification. This
  is not a device-delivery, display, or read-receipt claim.

Run an external rehearsal only with permission from the account/recipient/device
owner and preserve the returned safe attempt record plus the independently
observed provider-side result. Do not use local Mailpit as third-party SMTP
proof, and do not label a configured state or a rehearsal outcome as a live
customer integration.

Verification in this pass used fake provider gateways and a disabled real
gateway through SQL-backed HTTP tests. No external message was sent and no
Stripe/Firebase/third-party SMTP result was obtained. The new experiment
consent, lifecycle, analysis-run, and provider-rehearsal controls are API-led;
the existing desktop readiness page remains a configuration-only view.
