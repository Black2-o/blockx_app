# Building the release (final) APK

The `release` build type is wired to sign with a real keystore when
`android/key.properties` exists, and to fall back to the debug key otherwise
(see `android/app/build.gradle.kts`). Both the keystore and `key.properties` are
git-ignored — never commit them, never lose them (updates must use the same key).

---

## 1. One-time: create your signing keystore

From the project root, in a terminal:

```bash
cd android/app
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
cd ../..
```

It will ask for a keystore password, your name/org (can be anything), and a key
password (press Enter to reuse the keystore password). **Write these down** — you
need them for every future update.

> If `keytool` isn't found, it ships with the JDK. Use the one Android Studio
> bundles, e.g.
> `"C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -genkey ...`

## 2. One-time: create `android/key.properties`

Create a file at `android/key.properties` (next to `app/`) with:

```properties
storePassword=YOUR_KEYSTORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=upload-keystore.jks
```

`storeFile` is resolved relative to `android/app/`, which is where step 1 put the
`.jks`. (Both files are already in `android/.gitignore`.)

## 3. (Optional) set the version

In `pubspec.yaml`:

```yaml
version: 1.0.0+1   # <name>+<code>; bump +code on every release
```

---

## 4. Build

Pick one:

```bash
# a) One universal APK (simplest for sideloading / sharing a single file)
flutter build apk --release
#   -> build/app/outputs/flutter-apk/app-release.apk

# b) Smaller per-architecture APKs (most modern phones use arm64-v8a)
flutter build apk --release --split-per-abi
#   -> build/app/outputs/flutter-apk/app-arm64-v8a-release.apk  (+ others)

# c) App Bundle for Google Play upload
flutter build appbundle --release
#   -> build/app/outputs/bundle/release/app-release.aab
```

## 5. Install to test the release build

```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

> ⚠️ If you had the **debug** app installed, the signatures differ, so the
> install fails with `INSTALL_FAILED_UPDATE_INCOMPATIBLE`. Uninstall first:
> `adb uninstall com.blockx.app`, then install the release.

---

## Notes

- **Minification is intentionally OFF.** R8/ProGuard can strip
  reflection-referenced code (the accessibility service, `MethodChannel`), which
  could silently break blocking. Leave it off unless you add keep-rules and test.
- **Debug-signed vs release-signed:** without `key.properties`,
  `flutter build apk --release` still works but uses the debug key — fine to test,
  not for Play, and updatable only from the same machine's debug key.
- **Keep a backup** of `upload-keystore.jks` + its passwords somewhere safe. Lose
  it and you can never update this app (Play) / users must uninstall+reinstall
  (sideload).
