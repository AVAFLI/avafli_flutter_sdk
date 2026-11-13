# avafli_example

Minimal host app for the Avafli SDK (`avafli_sdk`): `MaterialApp(navigatorKey:
Avafli.navigatorKey, …)`, one `Avafli.configure(...)` call with a demo key, and
the drawer auto-opens once per day. The screen has two demo-only buttons:

- **Reset demo state** — clears the SDK's once-per-day auto-open mark and the
  unregistered-impression counter so you can see the auto-open again today
  (kill and relaunch the app after tapping).
- **Erase My Data** — calls `Avafli.optOut()`, the same erasure the in-app
  Privacy Policy's "Delete my data" performs; the drawer stays silent for 24
  hours, then the device rejoins as a new participant.

Platform setup the SDK needs is already in place here: `NSCameraUsageDescription`
and `NSPhotoLibraryUsageDescription` in `ios/Runner/Info.plist` (prize-claim
photo step) and the `INTERNET` permission in the main Android manifest.

Run it from this directory:

```bash
flutter run
```

`lib/parity_gallery.dart` is a developer-only screen gallery that renders the
SDK's internal widgets with fixed data (`flutter run -t lib/parity_gallery.dart`);
it imports implementation files and is not an integration example.
