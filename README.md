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

You need GNU Make and ADB. For a local build, also install JDK 17, Android SDK platform 34
and build-tools 34.0.0. Set `ANDROID_HOME` to your Android SDK directory (or create a
`local.properties` file with `sdk.dir=...`). The included Gradle wrapper downloads Gradle
8.9 on first use. Docker can supply the build tools instead; its first build downloads the
Android SDK and takes longer.

On the TV, enable ADB debugging in Developer options and accept the **Allow USB debugging?**
prompt when connecting. For network ADB on port 5555, run:

```sh
make connect TV_HOST=192.168.1.50
make install ADB_SERIAL=192.168.1.50:5555
make enable ADB_SERIAL=192.168.1.50:5555
make status ADB_SERIAL=192.168.1.50:5555
```

If you have Docker instead of a local JDK and Android SDK, replace `make install` with
`make install-docker` in the example. The remaining commands are the same.
Docker keeps its debug signing key in the `philips-headphone-gradle` volume. Keep that
volume if you want later builds to update an already installed APK; a different key cannot
replace it in place.

Replace the example address with your TV's address. If you connect by USB or Android's
Wireless debugging instead, use the serial shown by `adb devices` for `ADB_SERIAL`; Wireless
debugging uses a port assigned by the TV. `make build` or `make build-docker` only builds
the APK, at
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

## Build a public release APK

Run these once on the computer that will sign releases:

```sh
make release-key
make release-docker
```

`make release-key` creates a private keystore and two strong password files in
`~/.local/share/philips-headphone-volume-keys/signing/`. Back up **all three files** securely.
Keep them out of Git and out of release assets; future versions must use the same key to
install as updates. `make release-docker` builds, aligns, signs, and verifies the APK. Upload
`dist/philips-headphone-volume-keys-1.0.0.apk` as the release asset. The adjacent `.sha256`
file is its checksum and can be uploaded too. Neither file is committed to Git.

The public release is signed with a different key from a local debug build, so it cannot
update that debug build in place. New users installing the release APK are unaffected.

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
The optional Docker build setup includes an MIT attribution in
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
