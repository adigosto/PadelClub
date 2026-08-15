# Phase 7: commerce operations

## Inventory

- Checkout decrements stock inside a serializable transaction.
- Manual adjustments require an administrator and a reason.
- Order cancellation restores stock; shipped and delivered orders cannot be cancelled.
- Approved returns restore stock.
- Every change records quantity delta, resulting balance, actor, reason, and reference.

## Coupons

- Fixed and percentage discounts.
- Activation period, minimum order, maximum discount, global usage limit, and per-user usage limit.
- Codes are normalized and enforced during checkout in the same transaction as stock.
- Add `couponCode` to `POST /Orders/checkout` to redeem one.

## Returns

- Players can request item-level quantities within 30 days of delivery.
- Duplicate or excessive return quantities are rejected.
- Discounts are allocated proportionally when refund amounts are calculated.
- Administrators approve or reject requests.
- Approved Stripe orders are refunded through Stripe before inventory is restored.

## Analytics and auditing

- `GET /Operations/analytics` provides revenue, refunds, reservations, memberships, low stock, daily revenue, and top products for a maximum 366-day range.
- `GET /Operations/audit` provides administrator-only mutation audit records.
- Audit records include actor, route, status, IP, correlation ID, and duration.
- Request bodies are intentionally excluded so passwords, tokens, and payment information are not copied into the audit table.

## Swagger testing

1. Create a coupon with `POST /Commerce/coupons` as an administrator.
2. Checkout an order with `POST /Orders/checkout` and its `couponCode`.
3. Inspect `GET /Commerce/inventory/{productId}/history`.
4. Mark the order delivered through the existing order update endpoint.
5. Request a return through `POST /Commerce/returns`.
6. Resolve it through `PUT /Commerce/returns/{id}/resolve` as an administrator.
7. Inspect analytics and audit records under `/Operations`.

Migration: `AddCommerceOperations`.
