# Philips Headphone Volume Keys

Control the independent 3.5 mm headphone output volume on a compatible Philips Android TV
with the remote's Volume Up and Volume Down keys. This is a small Android accessibility
service. It does not require root, change system packages, or use the network.

**Tested on:** Philips 49PUS6412 (TPM171E), Android TV 8.0.0. Other Philips models and
firmware are untested. The app relies on Philips's Quick Settings headphone slider and
`org.droidtv.GlobalKey/.InjectKeyReceiver`; a TV without both will not work. The row finder
currently recognizes the Polish and English headphone-volume labels.

## What it does

- A short Volume press changes the headphone level by one.
- Holding Volume starts repeating after 450 ms, at about one level every 150 ms. Releasing
  stops the repeat. A 12-second limit stops a hold if its release event is lost.
- The Philips headphone slider appears while the level changes and closes shortly after.
  The adjustment is not hidden.
- The service has no `INTERNET` permission, analytics, or background polling. Android's
  Accessibility setting can turn it off at any time.

## Build and install

You need JDK 17, Android SDK platform 34 and build-tools 34.0.0, GNU Make, and ADB. Set
`ANDROID_HOME` to your Android SDK directory (or create a `local.properties` file with
`sdk.dir=...`). The included Gradle wrapper downloads Gradle 8.9 on first use.

On the TV, enable ADB debugging in Developer options and accept the **Allow USB debugging?**
prompt when connecting. For network ADB on port 5555, run:

```sh
make connect TV_HOST=192.168.1.50
make install ADB_SERIAL=192.168.1.50:5555
make enable ADB_SERIAL=192.168.1.50:5555
make status ADB_SERIAL=192.168.1.50:5555
```

Replace the example address with your TV's address. If you connect by USB or Android's
Wireless debugging instead, use the serial shown by `adb devices` for `ADB_SERIAL`; Wireless
debugging uses a port assigned by the TV. `make build` only builds the APK, at
`app/build/outputs/apk/debug/app-debug.apk`.

`make install` installs the app but does not enable its accessibility service. `make enable`
adds only this service to Android's enabled service list and preserves the others. If your
firmware refuses that ADB setting, enable **Philips headphone volume keys** in the TV's
Accessibility settings. A physical remote press is needed to test the service; an injected
ADB key is not proof that your remote's events reach it.

If you built the APK separately, `make install-built ADB_SERIAL=<serial>` installs that
existing APK without running Gradle again.

If installation returns `INSTALL_FAILED_VERIFICATION_FAILURE`, the TV blocks sideloading;
do not keep retrying. If it returns `INSTALL_FAILED_OLDER_SDK`, the TV is below Android 8.0.
The app has not been tested on those devices.

## Turn it off

```sh
make disable ADB_SERIAL=192.168.1.50:5555
```

This removes only this service from the enabled list. You can also turn it off in the TV's
Accessibility settings. It does not uninstall the app or change the regular TV volume
setting. Network ADB on port 5555 is plaintext; turn debugging off after setup unless you
intentionally use it for another purpose.

## How it works

The service intercepts Android Volume key down/up events, opens Philips Quick Settings,
focuses the headphone slider, and sends Philips's own volume step keys through its exported
key receiver. It then closes the slider. The TV keeps the actual volume level; the app does
not store or guess it. Hold timing and the supported headphone row labels are in
[`HeadphoneKeyService.java`](app/src/main/java/local/philips/headphone/HeadphoneKeyService.java).

## License

Copyright 2026 Michał Dulko. Licensed under the [Apache License 2.0](LICENSE).
