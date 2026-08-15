# Phase 1 security foundation

## Delivered

- JWT bearer access tokens with configurable 15-minute expiry.
- Opaque refresh tokens with rotation, one-time use, hashed database storage, and logout revocation.
- Password-reset tokens with one-hour expiry; successful reset revokes all refresh sessions.
- Email-verification tokens with 24-hour expiry and an `email_verified` JWT claim.
- Named `AdminOnly` and `VerifiedPlayer` authorization policies.
- Flutter secure storage now retains only the rotating refresh token, never the password.
- Swagger uses bearer-token authentication.

## Required deployment configuration

Set a unique high-entropy signing key outside source control:

`Authentication__SigningKey=<at-least-32-random-characters>`

The checked-in key exists only in `appsettings.Development.json`. Production startup fails validation when no secure key is supplied.

`LoggingTransactionalEmailSender` is deliberately a development adapter. Replace it with the transactional email provider during Phase 4; the recovery and verification lifecycle is already provider-independent.

Apply migration `AddProductionAuthentication` before deploying the new API.

## Phase 3 decision

Stripe is the selected payment provider. Phase 3 will use PaymentIntents/Checkout as appropriate, idempotency keys, signature-verified Stripe webhooks, refunds, receipts, and reconciliation records. No Stripe secret should be committed to the repository.
