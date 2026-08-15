# Phase 8: production readiness

## Health and monitoring

- `GET /health/live` confirms that the API process is running.
- `GET /health/ready` checks SQL Server and returns structured JSON.
- Mutation audit logs provide status code, actor, latency, IP address, and correlation ID through `GET /Operations/audit`.
- Commerce and operational metrics remain available from `GET /Operations/analytics`.

Configure the deployment platform to use `/health/live` for liveness and `/health/ready` for readiness. Alert on readiness failures, elevated 5xx counts, and sustained latency increases.

## Backups

The SQL container now mounts `./backups` at `/var/opt/mssql/backup`.

Create and verify a backup:

```powershell
.\scripts\backup-database.ps1
.\scripts\verify-backup.ps1 -BackupFile .\backups\PadelClub-YYYYMMDD-HHMMSS.bak
```

Production deployments must replace the development SQL password, encrypt backup storage, copy backups off-host, define retention, and regularly perform a test restore. A backup is not considered reliable until `RESTORE VERIFYONLY` and a periodic full restore both succeed.

## Privacy

- `GET /Privacy/export` exports the authenticated user's account, profile, booking, order, membership, payment, and notification data without credentials or token hashes.
- `POST /Privacy/deletion` schedules deletion with a 30-day grace period.
- `DELETE /Privacy/deletion` cancels a scheduled request.
- The deletion worker removes authentication and push identifiers and anonymizes identity, shipping, return, invitation, review, audit, and player-profile data while retaining legally relevant financial records in anonymized form.

Legal retention periods and the final privacy notice still require review for the deployment jurisdiction.

## Accessibility

- Login branding and password visibility controls now expose explicit semantics.
- Flutter tests assert labeled interactive controls.
- Existing admin controls use 44x44 minimum targets and semantic status labels.
- CI runs Flutter analysis and widget tests on every pull request.

Manual keyboard navigation, screen-reader testing, zoom/reflow checks, and contrast review remain release checklist requirements because automated tests cannot prove full accessibility.

## CI/CD

`.github/workflows/ci.yml` performs:

- Release-mode .NET restore, build, and test.
- Flutter dependency restore, static analysis, and widget tests.
- Docker image build.
- Test-result artifact upload.

Dependabot checks NuGet, Pub, and GitHub Actions weekly. Deployment is intentionally not automatic until a target environment, secret store, approval gate, migration strategy, and rollback procedure are selected.

Migration: `AddPrivacyReadiness`.
