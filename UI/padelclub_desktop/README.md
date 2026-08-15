# PadelClub Desktop

This package is the desktop admin distribution and the shared Flutter feature
implementation used by the separate `../padelclub_mobile` runner.

- Mobile players receive the branded consumer experience, including court availability, booking, personal reservations, results, and the club shop.
- Desktop administrators receive a denser management workspace. The first implemented module is reservation management.

The responsive management breakpoint is 900 logical pixels and management access requires the `Administrator` role.

## Local development

Start SQL Server and the API from the repository root:

```powershell
docker compose up --build
```

Run the Flutter client from this directory:

```powershell
flutter run --dart-define=baseUrl=http://localhost:5001
```

For an Android emulator, the default API address is `http://10.0.2.2:5001`.

Seeded development accounts use the password `password123!`:

- `admin` opens the desktop management experience on wide screens.
- `player1` opens the mobile player experience.

## Reservation rules

- Active courts expose hourly slots from 07:00 until 23:00.
- The API calculates price from the court hourly rate; clients cannot select a price or user ID.
- Overlapping active reservations are rejected inside a serializable transaction.
- Player cancellations close two hours before a booking. Administrators can cancel later.
- Players can only retrieve their own reservations; administrators can retrieve the management list.

Basic authentication is still used during this development phase. Replace it with a token-based session before production deployment.
# Local API address

The default desktop API URL is `http://localhost:5000`. The Android emulator uses
`http://10.0.2.2:5000`. Start the API with its checked-in launch profile:

```powershell
dotnet run --project PadelClub.WebAPI --launch-profile http
```

For the simplest complete local stack, run this from the repository root instead:

```powershell
docker compose up --build
```

This exposes the containerized API at `http://localhost:5000` and starts its SQL Server dependency.

Override the client URL when needed:

```powershell
flutter run -d windows --dart-define=baseUrl=https://localhost:5001
```
