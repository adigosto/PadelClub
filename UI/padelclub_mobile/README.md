# PadelClub Mobile

Android/iOS distribution target for the PadelClub player experience. It imports
the feature-first domain, data, provider, theme, and screen code from
`../padelclub_desktop`; this package intentionally owns only the mobile runners
and entrypoint.

## Run

Start the local API stack from the repository root:

```powershell
docker compose up --build --detach
```

Then run from this directory:

```powershell
flutter pub get
flutter run --dart-define=baseUrl=http://10.0.2.2:5000
```

Use `http://localhost:5000` on an iOS simulator. A physical device needs a
reachable LAN address, for example
`--dart-define=baseUrl=http://192.168.x.x:5000`.

The seeded player account is `player1` with the password configured in `Database__DemoPassword`. See the
repository [README](../../README.md) for all local services, credentials, and
testing instructions.

## Verify

```powershell
flutter analyze
flutter test
flutter build apk --debug
```

`flutter test` mounts the actual mobile runner composition root, checks that it
opens at login, and verifies the Android player shell exposes its five primary
destinations without a live API request.
