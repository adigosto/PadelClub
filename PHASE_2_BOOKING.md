# Phase 2 booking lifecycle

The booking engine stores reservation instants in UTC and interprets club hours in the configured IANA timezone (`Europe/Sarajevo` by default). Availability correctly follows daylight-saving changes.

Configuration lives under `Booking`: opening/closing hour, slot length, cancellation notice, recurring-booking limit, and timezone.

Implemented lifecycle primitives:

- global or court-specific maintenance blocks;
- atomic weekly recurring series;
- identity-bound waitlists with first-in notification after cancellation;
- cancellation credits for settled payments and explicit no-show state;
- owner-only waitlist and credit queries;
- admin-only maintenance and no-show operations.

Apply the latest EF migration before deployment. Stripe refunds remain Phase 3; Phase 2 cancellation currently creates an internal account credit that Phase 3 can reconcile against a Stripe refund or future checkout.
