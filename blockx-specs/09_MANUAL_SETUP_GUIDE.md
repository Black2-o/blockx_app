# Manual Setup Guide — Do This Yourself Before Claude Code Starts

This is the part you do by hand, once, before handing anything to Claude
Code. None of this is project-specific yet — it's just getting a working
Flutter environment and an empty-but-running app on your device.

## 1. Install Flutter SDK
1. Download Flutter SDK: https://docs.flutter.dev/get-started/install
   (pick your OS — Windows/Linux/Mac).
2. Extract it somewhere permanent, e.g. `C:\src\flutter` (Windows) or
   `~/development/flutter` (Linux/Mac).
3. Add `flutter/bin` to your system `PATH`.
4. Restart your terminal, then verify:
   ```
   flutter --version
   ```

## 2. Install Android toolchain
1. Install **Android Studio** (needed for Android SDK + emulator tooling,
   even if you write code in VS Code instead).
2. On first launch, let it install the Android SDK, SDK Platform-Tools,
   and an Android Virtual Device (AVD) image.
3. Accept Android licenses:
   ```
   flutter doctor --android-licenses
   ```
4. Run the doctor check and fix anything marked with `[✗]`:
   ```
   flutter doctor -v
   ```
   You want Flutter, Android toolchain, and (Android Studio or VS Code) all
   green before moving on. Chrome/web and iOS lines can stay red — not
   relevant, Android-only project.

## 3. Pick your editor
- **VS Code** (lighter) — install the "Flutter" and "Dart" extensions from
  the marketplace. This is what most Claude Code sessions pair well with.
- or stick with **Android Studio** if you're already comfortable there —
  install the Flutter plugin via Settings → Plugins.

## 4. Connect a real device (recommended over emulator)
Since this app needs Accessibility Service, Overlay permission, and VPN
Service — all of which behave more reliably (and are just easier to
grant/toggle) on a real phone than an emulator:
1. On your phone: Settings → About Phone → tap "Build Number" 7 times to
   unlock Developer Options.
2. Settings → Developer Options → enable **USB Debugging**.
3. Plug into your computer via USB, accept the "Allow USB debugging?"
   prompt on the phone.
4. Verify it's detected:
   ```
   flutter devices
   ```
   You should see your phone listed. If not, run `adb devices` — if that
   also shows nothing, it's a driver/cable issue (try a different USB cable
   — some are charge-only).

## 5. Create the project
```
flutter create blockx
cd blockx
```
This scaffolds a default counter-app template. You'll gut most of it, but
running it once first confirms your whole toolchain actually works before
any real code goes in.

## 6. Run it
```
flutter run
```
This builds and installs the default template app to your connected
device. If it launches and you see the counter demo — your environment is
fully working. This is the point where Claude Code takes over for actual
BlockX development.

## 7. Set the real app identity now (before Claude Code starts)
Two things worth doing by hand right away, since they're annoying to change
later and Claude Code will assume they're already set:
1. **App name / applicationId** — in
   `android/app/build.gradle`, set:
   ```gradle
   defaultConfig {
       applicationId "com.yourname.blockx"   // pick something permanent
       ...
   }
   ```
   Use your own reverse-domain style id — doesn't need to be a real domain
   since you're never publishing, but avoid changing it later (permissions
   like Accessibility are tied to the exact package name).
2. **App label** — in `android/app/src/main/AndroidManifest.xml`, set
   `android:label="BlockX"` on the `<application>` tag, and drop your logo
   PNG into `android/app/src/main/res/mipmap-*/ic_launcher.png` (or just
   leave the default icon for now and swap it later — purely cosmetic).

## 8. Git, once
```
git init
git add .
git commit -m "flutter create: blockx scaffold"
```
Gives Claude Code (and you) a clean baseline to diff against as features
land, and an easy rollback point if a native-service milestone goes
sideways.

## 9. Initialize project docs
Copy the whole `blockx-specs/` folder (all the `.md` files) into the
project root, e.g. `blockx/docs/`. Then when you open a Claude Code session
in this project, reference them directly — e.g. "read `docs/02_ARCHITECTURE.md`
and `docs/09_APP_NAVIGATION.md` and scaffold Milestone 0 from
`docs/08_BUILD_ORDER.md`."

---

**Once `flutter run` shows the default app on your phone, you're done with
this manual part** — everything past this point (folder structure,
services, screens) is what Claude Code builds, following the specs.
