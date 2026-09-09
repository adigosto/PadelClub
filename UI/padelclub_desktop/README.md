# PadelClub shared Flutter client

This package is both the Windows desktop runner and the shared Flutter feature
implementation imported by `../padelclub_mobile`. Desktop administrators see a
denser management workspace; mobile runners use the same authenticated player
features and API models.

Management access requires the `Administrator` role. The responsive management
breakpoint is 900 logical pixels.

## Languages

Both runners support English (`en`) and Bosnian (`bs`). Use the **EN / BS**
tabs on the login screen or in the app header. The choice is saved on the device;
switching languages preserves the current route and form input.

Translations live in `assets/l10n/en.json` and `assets/l10n/bs.json`, keyed by
English message text. Use `context.tr('Message')` for interface copy and named
placeholders for dynamic messages. Keep API enum values, identifiers and
user-authored content unchanged; translate their display labels separately.
Flutter's built-in controls also use the selected locale.

After editing the catalogs, regenerate the bundled messages from this directory:

```powershell
dart tool/generate_localizations.dart
flutter test test/localization_test.dart
```

## Run against the local Docker stack

From the repository root, start the API and its dependencies:

```powershell
docker compose up --build --detach
```

Then run the desktop client from this directory:

```powershell
flutter pub get
flutter run -d windows --dart-define=baseUrl=http://localhost:5000
```

The Android emulator must use `http://10.0.2.2:5000`. Use a reachable LAN
address for a physical device.

## Development accounts

On an empty database with demo seeding enabled, both accounts use the value configured in `Database__DemoPassword`:

- `admin` for the desktop administration experience.
- `player1` for the player experience.

Authentication uses JWT access and refresh tokens; this client does **not** use
Basic Authentication.

See the repository [README](../../README.md) for the authoritative setup,
service URLs, RabbitMQ worker, configuration, testing commands, and known scope
boundaries.
