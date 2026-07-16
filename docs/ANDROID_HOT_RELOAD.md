# Android hot reload over Wi-Fi

This project is a Flutter application. Flutter hot reload works only when the
application is launched in **Debug** mode, not from a release APK.

## One-time Android Studio setup

1. Open the project root (`my_new_app`), not the `android` subdirectory.
2. Check that the **Flutter** and **Dart** plugins are enabled in
   `File > Settings > Plugins`.
3. Enable automatic saving:
   `File > Settings > Tools > Actions on Save > Configure autosave options`.
   Enable **Save files if the IDE is idle for X seconds** and set it to
   **2 seconds**.
4. Enable Flutter reloads after a save:
   `File > Settings > Languages & Frameworks > Flutter` > enable
   **Perform hot reload on save**.

After this, a saved Dart change is sent to the running debug application
automatically. Use `Ctrl+S` to reload immediately instead of waiting for the
autosave delay.

## Pair an Android phone over Wi-Fi

The computer and phone must be on the same local Wi-Fi network. Wireless
debugging is available on Android 11 and newer.

1. On the phone, open `Settings > Developer options > Wireless debugging` and
   turn it on.
2. Tap **Pair device with pairing code**. Keep this screen open.
3. In Android Studio, open `Tools > Device Manager` and choose
   **Pair Devices Using Wi-Fi**. Scan the QR code, or select pairing by code
   and enter the IP address, port, and six-digit code shown by the phone.
4. Accept the pairing dialog on the phone. The device should appear in the
   Android Studio device selector.

If the pairing is interrupted, repeat steps 2–4. The phone needs to remain on
the same Wi-Fi network and Wireless debugging needs to stay enabled.

## Start the app with hot reload

1. Open `lib/main.dart`.
2. Select the paired phone from the Android Studio device selector.
3. Start **Debug** (the bug icon), not Run as a release build.
4. Wait until the application opens on the phone. Edit and save any `.dart`
   file: the Flutter hot reload indicator should appear and the UI should
   update automatically.

This application needs its photo-analysis backend settings at launch. Add the
following values to the Flutter run configuration under
`Run > Edit Configurations > Additional run args`:

```text
--dart-define=API_BASE_URL=http://<backend-host>:8000 --dart-define=API_KEY=<PHOTO_FOOD_API_KEY>
```

Use a backend address reachable from the phone. `localhost` points to the
phone itself, so use the computer's LAN IP address (for example,
`http://192.168.1.50:8000`) when the backend runs on the computer. The backend
must listen on the LAN interface and Windows Firewall must permit its port.

## When a reload is not enough

Hot reload preserves current screen state and normally applies UI and Dart
logic changes. Use **Hot Restart** (the circular-arrow button) after changing
`main()`, initial values of global/static fields, native Android code,
dependencies, assets, or application configuration. Stop and launch Debug
again if a hot restart cannot apply the change.

## Diagnose connection issues

From the project root, run:

```powershell
flutter devices
```

The paired phone must be listed. To inspect the Android setup, run:

```powershell
flutter doctor -v
```
