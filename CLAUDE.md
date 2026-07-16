# BlockX — Project Guide for Claude Code

## What this app is
A **personal-use Android app** (display name **BlockX**) built with **Flutter**, for blocking distracting apps by **preventing them from opening**: a native Accessibility Service detects the blocked app in the foreground and, based on that app's config, either covers it with a full-screen "This app is blocked" screen or runs a time-limited flow. No backend, no multi-user auth, no Play Store distribution (sideloaded APK only). **No fancy UI — keep everything as plain and functional as possible.** Default Material widgets, no custom theming, no animations unless Flutter gives them for free.

> **Mechanism note (changed from the original VPN plan):** blocking is done with a native **AccessibilityService** that launches a real full-screen block Activity (which backgrounds the app so it actually pauses), NOT a VPN and NOT a floating overlay for the block screen. The VPN approach only cut an app's internet and did not stop it from opening; a plain overlay left the app running underneath (sound kept playing, reachable via Recents). Do not re-introduce the VPN or the overlay-only block screen.

## Tech stack
- **Flutter** (latest stable) — UI layer (Riverpod for state).
- **Kotlin** — the native blocker: an `AccessibilityService` (`AppBlockerService`) that detects the foreground app (via UsageStats) and enforces the block; a full-screen `BlockActivity` (block + interstitial screens); a `BlockRepository` holding the config/quota logic; a small floating `WindowManager` widget during timed sessions. Wired through one `MethodChannel` (`com.block.app/blocker`).
- **Local storage:** Hive (`blocklist_v2`, one JSON `BlockConfig` per package). The enabled apps' full config is mirrored into native `SharedPreferences` (`block_prefs`, key `configs_json`) so the service can read it; the service keeps its own runtime quota/session state there too.

## Names / IDs (do not casually change)
- **Display name = `BlockX`** (manifest `android:label`, service label, `strings.xml` app_name, Flutter `MaterialApp.title` + AppBar). This is the only "name" that was changed.
- **applicationId stays `com.block.app`; Dart package stays `block`; Kotlin package/namespace stays `com.example.block`.** Changing the applicationId would make Android treat it as a brand-new app (uninstall + re-grant all 3 permissions + lose the block list), and renaming the Kotlin/Dart packages is churn for no user benefit. Keep them.

## App flow (exactly this, nothing more)

1. **Home screen**
   - Shows the list of apps the user has already chosen to block, each with an **on/off switch** next to it.
   - Switch ON = actively blocked right now. Switch OFF = still in the list, but not currently blocked.
   - A **`+` button** (floating action button, top-right or bottom-right, whichever is default/simplest).

2. **Tap `+`**
   - Opens a screen/list of **all apps installed on the device** (`QUERY_ALL_PACKAGES` permission).
   - User taps an app → a **config dialog** appears: choose **Direct block** or **Time-limited**. For time-limited, pick **opens/day** and **minutes per open**.
   - Goes back to home screen, new app now appears in the list with its switch (default ON). Tapping a row re-opens the config dialog to edit; long-press removes.

3. **Blocking behavior** (two modes per app)
   - **Direct block:** opening the app shows a full-screen **"This app is blocked."** and pushes it to the background (it actually pauses — no sound).
   - **Time-limited:** opening shows an interstitial **"Is this really needed?"** with **Go home** and **Open** (Open is disabled for 5s, then enabled). Tapping Open spends one of the day's opens and grants a session of the configured length. During the session a **floating widget** (app icon) shows opens-left / time-left and an **End now** button. When the session time runs out it auto-returns to the block screen. When the daily opens are used up, it's **fully blocked until midnight** (opens reset daily).

4. **Toggle behavior**
   - Switching an app's toggle OFF immediately stops blocking it (user can open it normally).
   - Switching it back ON re-enables the block.

## Build order (as built)
1. Native Kotlin `AppBlockerService` (AccessibilityService) — detect the foreground app (UsageStats) and, for a blocked app, launch the full-screen `BlockActivity` (which backgrounds/pauses the app)
2. Home screen: list of blocked apps + on/off switches + per-app mode summary
3. `+` button → installed apps picker → config dialog (direct vs timed) → add to block list
4. Hive storage: single box `packageName -> BlockConfig` (JSON); enabled apps' configs mirrored to native `SharedPreferences` (`configs_json`)
5. `BlockActivity` shows "This app is blocked" (direct / quota-used) or the "Is this really needed?" interstitial (timed) when a blocked+on app is opened
6. Time-limited mode: interstitial + daily opens quota + session timer + floating widget (see change history below)
7. First-run permission gate on the home screen: banner + buttons for Accessibility, "draw over other apps", and Usage access

## Android manifest permissions needed
- `BIND_ACCESSIBILITY_SERVICE` (declared on the service)
- `SYSTEM_ALERT_WINDOW` (floating session widget + reliable background activity launch)
- `QUERY_ALL_PACKAGES`
- `PACKAGE_USAGE_STATS` ("Usage access" — reliable foreground detection; needed because realme Game Space hosts games under its own window)

## Working conventions
- This is a **solo, personal-use project** — don't add multi-user, auth, or cloud sync unless explicitly asked.
- **No fancy UI.** Default Material widgets, no custom theming/animation. Function over form.
- Prefer **native Android implementation** (Kotlin AccessibilityService + overlay) over searching for a Flutter plugin — reliable app-open blocking must be native.
- Keep the data model to a single Hive box: `packageName -> BlockConfig` (enabled, mode, opensPerDay, sessionMinutes), stored as JSON.
- Per-app **time-limited blocking is now in scope** (opens/day + minutes/open + session widget). Don't add website blocking or sub-feature (Reels/Shorts) blocking, or scheduled/time-of-day rules, unless explicitly asked.

## Not in scope (unless asked later)
- iOS support
- Play Store publishing / compliance
- Remote/cloud block-list sync
- Multi-device support
- **Time-of-day schedules** (e.g. "block 9–5") — note: per-app *usage limits* (opens/day + minutes) ARE built; calendar/clock schedules are not
- Website or sub-feature (Reels/Shorts) blocking
- Custom UI/theming

---

# Architecture & change history (why the code looks like it does)

This app was built and then reshaped several times based on on-device testing. The bullets below capture **what** each part does and **why** it ended up this way, so future changes don't undo hard-won fixes.

## Files at a glance
**Flutter (`lib/`)**
- `models/block_config.dart` — `BlockConfig{enabled, mode(direct|timed), opensPerDay, sessionMinutes}` + `BlockMode`. `toMap`/`fromMap` for JSON. `summary` for the home row.
- `models/app_info.dart` — `{packageName, appName}` for the picker.
- `data/block_store.dart` — Hive box `blocklist_v2` (`Box<String>`, one JSON config per package). Migrates the old `blocklist` `Box<bool>` → direct-mode configs on first open, then clears it.
- `providers/block_providers.dart` — `blockStoreProvider` (overridden in main), `installedAppsProvider`, `blockListProvider` (`StateNotifier<Map<String,BlockConfig>>`), `permissionsProvider` (`BlockPermissions{accessibility, overlay, usageAccess}`). On every change the notifier mirrors the **enabled** apps' configs to native via `BlockPlatform.setConfigs`.
- `services/block_platform.dart` — the only Dart↔native bridge (`MethodChannel com.block.app/blocker`): `getInstalledApps`, `setConfigs`, and permission check/open methods.
- `screens/home_screen.dart` — list (name + `config.summary` + enable switch; tap = edit, long-press = remove) + `_PermissionBanner` (one button per missing permission; re-checked on `AppLifecycleState.resumed`).
- `screens/app_picker_screen.dart` — searchable installed-apps list; tapping opens the config dialog then adds.
- `screens/config_dialog.dart` — Direct vs Time-limited + opens/day + minutes chips. Uses `RadioGroup` (not deprecated `RadioListTile.groupValue`).

**Native (`android/.../kotlin/com/example/block/`)**
- `MainActivity.kt` — `MethodChannel` handler: installed apps (`queryIntentActivities` LAUNCHER), `saveConfigs` → `block_prefs.configs_json`, and the 3 permission checks/openers (accessibility via `Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES` + `ComponentName`; overlay via `Settings.canDrawOverlays`; usage via `AppOpsManager.OPSTR_GET_USAGE_STATS`).
- `AppBlockerService.kt` — the running blocker (accessibility service). Detects foreground app, decides via `BlockRepository`, launches `BlockActivity`, and owns the floating widget.
- `BlockRepository.kt` — Kotlin `object`. Reads `configs_json` + per-app runtime state (`state_<pkg>_date/_opens/_sessionEnd`), does daily reset, and `decide()` → `NONE / ALLOW_SESSION / INTERSTITIAL / BLOCK`. `startSession` (spend an open) / `endSession`.
- `BlockActivity.kt` — full-screen black screen, two modes via intent extras: `MODE_BLOCK` (plain) and `MODE_INTERSTITIAL` ("Is this really needed?" + Go home + Open disabled 5s → spend open + relaunch app).
- Manifest: `AppBlockerService` (accessibility) + `BlockActivity` (own task affinity, `excludeFromRecents`, `singleTask`, `Theme.Black.NoTitleBar`, `configChanges` so rotation doesn't recreate). `res/xml/accessibility_service_config.xml`, `res/values/strings.xml`.

## Why the key decisions were made (chronological)
1. **VPN → AccessibilityService.** Original plan was a VPN traffic filter. On device it only killed internet; the app still *opened*. Replaced with an accessibility-based blocker. **Never reintroduce the VPN.**
2. **Two runtime permissions, user-granted, with a home banner.** Android won't let a sideloaded app enable Accessibility or overlay itself (and blocks the toggle as a "restricted setting" until you pick "Allow restricted settings" or install via USB). The banner deep-links to each settings screen and re-checks on resume.
3. **Overlay → real `BlockActivity`.** A drawn `WindowManager` overlay only *hid* the app; it kept running (sound continued, reachable via Recents) and fought the status/nav bars. Switched to launching a real Activity, which backgrounds the app so it actually pauses. Theme is `NoTitleBar` (NOT Fullscreen) so the status bar/notifications stay usable.
4. **Foreground detection via UsageStats (3rd permission: Usage access).** On realme/Oppo, **Game Space hosts games under `com.oplus.gamespace`**, so accessibility window events reported the wrong package and games bypassed the block ("sometimes blocks, sometimes not"). `AppBlockerService.pollForegroundApp()` polls `UsageStatsManager.queryEvents` every 350ms as the source of truth (reports the real resumed app); accessibility events are only for instant response. `isIgnoredPackage()` still skips systemui / Play Games / gamespace / `*gamespace*` / `*gameassistant*` side-panels so they can't be mistaken for an app switch.
5. **Lock/unlock + missed-event robustness.** A 350ms re-check timer + an `ACTION_USER_PRESENT`/`SCREEN_ON` receiver re-run the decision, so an already-open blocked app is re-blocked after unlocking.
6. **Anti-flicker for aggressive apps.** Some apps (e.g. Facebook) re-launch themselves to the foreground and ping-pong with the block screen. `showBlockScreen` detects the *same* package reappearing within 4s and fires `GLOBAL_ACTION_HOME` to decisively background it before showing the block screen (an app can't beat Home). Normal apps/games block on the first try and never trigger the Home kick (so no extra launcher flash). Guarded by `BlockActivity.isVisible` + a 400ms cooldown so it can't stack/spam.
7. **Time-limited mode (usage quota).** Per app: `opensPerDay` + `sessionMinutes`. Flow: open a timed app → interstitial "Is this really needed?" (Open disabled 5s) → Open spends one daily open + starts a session + relaunches the app → a floating widget (app icon; tap = opens-left / time-left / **End now**) shows during the session → when the session time runs out the 350ms poll re-decides and blocks again → when the day's opens are used up it's fully blocked until midnight (opens reset on date change). Decisions all live in `BlockRepository.decide()`.

## Build / test notes
- **Never run build/APK/gradle commands** for the user — give them the command; they run it. `flutter analyze` / `flutter test` are fine to run.
- Debug builds are ~150 MB (all ABIs, unshrunk); **release is ~17 MB**. Real use: `flutter build apk --release --split-per-abi` (install `app-arm64-v8a-release.apk`) or `flutter run --release` over USB.
- realme/Oppo sideload gotchas: enable Developer options → "Install via USB"; keep internet on during install; "Allow restricted settings" for the Accessibility toggle; grant Usage access. A `com.coloros.phonemanager` `TrackApi` crash sometimes appears in logcat — that's a realme system app, not BlockX.
