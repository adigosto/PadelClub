# Phase 4: notification delivery

Phase 4 adds durable email and push delivery on top of the existing in-app notification feed.

## Included

- Per-user in-app, email, and push preferences.
- Firebase installation registration for Android and iOS devices.
- Database-backed delivery outbox with exponential retries and terminal failure state.
- Firebase Cloud Messaging through the Firebase Admin SDK.
- SMTP transactional mail through MailKit.
- Password-reset and verification messages now use SMTP when configured.
- Admin delivery diagnostics.
- Mailpit development inbox in Docker.

## Test locally

Start the stack:

```powershell
docker compose up -d --build
```

Open Swagger at `http://localhost:5000/swagger`, authenticate, and create a notification with `POST /Notifications`. Email deliveries appear in Mailpit at `http://localhost:8025` within about ten seconds.

Useful endpoints:

- `GET /NotificationSettings/mine`
- `PUT /NotificationSettings/mine`
- `POST /NotificationSettings/devices`
- `DELETE /NotificationSettings/devices?installationId=...`
- `GET /NotificationSettings/deliveries` (administrator)

When SMTP host is empty outside Docker, messages are safely logged for development. Never enable debug-level token logging in production.

## Production SMTP

Set `SMTP_HOST`, `SMTP_PORT`, `SMTP_STARTTLS`, `SMTP_USERNAME`, `SMTP_PASSWORD`, and `SMTP_FROM_ADDRESS`. Keep credentials in the deployment secret store, not appsettings or source control.

## Firebase

Create a Firebase project, enable the FCM HTTP v1 API, and give the service account the Firebase Cloud Messaging API Admin role. Configure:

```powershell
$env:FIREBASE_PROJECT_ID="your-project-id"
$env:FIREBASE_SERVICE_ACCOUNT_JSON=(Get-Content "C:\secure\firebase-service-account.json" -Raw)
```

The mobile client must submit its Firebase installation ID to `POST /NotificationSettings/devices`. If Firebase is not configured, push jobs retry and then become `Failed`; inspect them through the admin delivery endpoint.

## Database

Migration: `AddNotificationDelivery`.
