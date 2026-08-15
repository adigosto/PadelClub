# PadelClub Mobile

Android/iOS distribution target for the PadelClub player experience. The app
reuses the feature-first domain, data, provider, theme, and screen code from
`../padelclub_desktop`; this package owns only the mobile runners and entrypoint.

## Run

```powershell
flutter pub get
flutter run --dart-define=baseUrl=http://10.0.2.2:5001
```

Use `http://localhost:5001` on an iOS simulator or a physical-device-accessible
LAN address when testing on hardware.
