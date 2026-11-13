# avafli_example

Minimal host app for the Avafli SDK (`avafli_sdk`): `MaterialApp(navigatorKey:
Avafli.navigatorKey, …)`, one `Avafli.configure(...)` call with a demo key, and
the drawer auto-opens once per day. The screen has one demo-only button:

- **Reset demo state** — clears the SDK's once-per-day auto-open mark and the
  unregistered-impression counter so you can see the auto-open again today
  (kill and relaunch the app after tapping).

Deleting one's data is the user's own action: Privacy Policy → "Delete my
data" inside the drawer. There is no host-app call for it, so the example has
no button for it either.

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
