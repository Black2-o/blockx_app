# Reference — files, storage, build & debugging

> The lookup companion to the step files: where every piece lives, every storage key and channel
> method, how to build from scratch in the right order, and how to debug/tune with logcat.

- Index: **[README.md](README.md)** · Overview: **[STEP-0-OVERVIEW.md](STEP-0-OVERVIEW.md)**

---

## A. File-by-file map

### Flutter (`lib/`)

| File | Responsibility |
|---|---|
| `main.dart` | opens the 3 Hive stores, overrides the providers, runs `BlockApp` (plain `MaterialApp`, title "BlockX") |
| `models/block_config.dart` | `BlockConfig{enabled, mode(direct/timed), opensPerDay, sessionMinutes}` + `BlockMode`; `toMap`/`fromMap`; `summary` |
| `models/app_info.dart` | `{packageName, appName}` for the picker |
| `data/block_store.dart` | Hive box `blocklist_v2` (apps); migrates legacy `blocklist` `Box<bool>` |
| `data/site_store.dart` | Hive box `blocked_sites` (websites) |
| `data/feature_store.dart` | Hive box `feature_blocks_v2` (`key → BlockConfig` JSON: off/direct/timed); `keys = [yt_shorts, ig_reels, fb_reels]` |
| `providers/block_providers.dart` | all Riverpod state: `blockListProvider`, `blockedSitesProvider`, `featureBlocksProvider`, `installedAppsProvider`, `permissionsProvider`; every notifier mirrors to native on change |
| `services/block_platform.dart` | the only Dart↔native bridge — `MethodChannel("com.blockx.app/blocker")` |
| `screens/home_screen.dart` | app list + switches + `+` FAB + permission banner + AppBar icons (video → features, globe → websites) |
| `screens/app_picker_screen.dart` | searchable installed-apps list → config dialog → add |
| `screens/config_dialog.dart` | Direct vs Time-limited + opens/day + minutes chips |
| `screens/sites_screen.dart` | blocked-websites manager (text field + Add + list) |
| `screens/features_screen.dart` | 3 Shorts/Reels rows (switch + tap → config dialog: off/direct/timed) |

### Native (`android/app/src/main/kotlin/com/example/blockx/`)

| File | Responsibility |
|---|---|
| `MainActivity.kt` | `MethodChannel` handler; saves prefs; the 3 permission check/open pairs; `getInstalledApps` |
| `AppBlockerService.kt` | the running engine — foreground detection, `evaluate`/`showBlockScreen`, website + in-app-browser + Shorts/Reels detection, the floating widget, `goBackAndPause` |
| `BlockRepository.kt` | shared `object` — `configs_json` + runtime state; `decide()`; `startSession`/`endSession` (id = app pkg OR feature key, via `anyConfig`); `blockedSites`/`isBlockedHost`/`normalizeHost`; `featureConfigFor` |
| `BlockActivity.kt` | the full-screen block screen — `MODE_BLOCK` / `MODE_INTERSTITIAL` / `MODE_BACK` |
| `BuiltInBlocklist.kt` | always-on, code-only website blocklist |

### Config

| File | Key bits |
|---|---|
| `AndroidManifest.xml` | permissions (`QUERY_ALL_PACKAGES`, `SYSTEM_ALERT_WINDOW`, `PACKAGE_USAGE_STATS`); `MainActivity`; `BlockActivity` (own taskAffinity `com.blockx.app.blockscreen`, `excludeFromRecents`, `singleTask`, `Theme.Black.NoTitleBar`); `AppBlockerService` (accessibility) |
| `res/xml/accessibility_service_config.xml` | `canRetrieveWindowContent="true"`, `typeWindowStateChanged\|typeWindowContentChanged`, `flagDefault\|flagReportViewIds` |
| `res/values/strings.xml` | `app_name = BlockX` + accessibility description |
| `android/app/build.gradle.kts` | `applicationId = com.blockx.app`, `namespace = com.example.blockx`, release signed with debug key |
| `pubspec.yaml` | `name: blockx`; deps: `flutter_riverpod`, `hive`/`hive_flutter`; dev: `flutter_launcher_icons` (icon from `assets/logo.png`) |

---

## B. Storage keys & MethodChannel

### MethodChannel `com.blockx.app/blocker` (Dart → Kotlin)

| Method | Args | Effect |
|---|---|---|
| `getInstalledApps` | — | returns `[{appName, packageName}]` (launchable apps via `queryIntentActivities` LAUNCHER) |
| `setConfigs` | `configsJson` | save enabled apps' config → `configs_json` |
| `setBlockedSites` | `sitesJson` | save blocked domains → `blocked_sites_json` |
| `setFeatureBlocks` | `featuresJson` | save enabled Shorts/Reels configs `{key:{mode,opensPerDay,sessionMinutes}}` → `feature_blocks_json` |
| `isAccessibilityEnabled` / `openAccessibilitySettings` | — | check / open Accessibility settings |
| `canDrawOverlays` / `openOverlaySettings` | — | check / open overlay settings |
| `hasUsageAccess` / `openUsageAccessSettings` | — | check / open Usage-access settings |

### `SharedPreferences` file `block_prefs` (native)

| Key | Written by | Meaning |
|---|---|---|
| `configs_json` | Flutter | `{ "<pkg>": {mode, opensPerDay, sessionMinutes}, … }` (enabled apps only) |
| `blocked_sites_json` | Flutter | `[ "youtube.com", … ]` |
| `feature_blocks_json` | Flutter | `{ "yt_shorts": {mode, opensPerDay, sessionMinutes}, … }` (enabled features only) |
| `state_<id>_date` | native | the day (`yyyy-MM-dd`) the runtime state belongs to |
| `state_<id>_opens` | native | timed opens used today |
| `state_<id>_sessionEnd` | native | epoch ms when the current timed session ends (`0` = none) |

> `<id>` is an **app package** (app timer) OR a **feature key** (`yt_shorts`/`ig_reels`/`fb_reels`,
> Shorts/Reels timer) — the same runtime-state machinery is shared by both.

### Hive boxes (Flutter)

| Box | Type | Contents |
|---|---|---|
| `blocklist_v2` | `Box<String>` | `pkg → BlockConfig` JSON (apps) |
| `blocked_sites` | `Box<String>` | `domain → domain` (websites) |
| `feature_blocks_v2` | `Box<String>` | `key → BlockConfig` JSON (Shorts/Reels: off/direct/timed) |

---

## C. Build from scratch, in order

Each layer is testable before the next:

1. **New Flutter app** + `flutter_riverpod` + `hive`/`hive_flutter`. Set `applicationId`,
   `namespace`, package `name`.
2. **Foreground detection.** `AppBlockerService` (AccessibilityService) +
   `accessibility_service_config.xml` + manifest entry. Poll `UsageStatsManager`; log the
   foreground package. Add the 3 permissions + manifest declarations.
3. **Block screen.** `BlockActivity` (`MODE_BLOCK`) + `showBlockScreen` in the service; hardcode
   one package to test end-to-end.
4. **Flutter home + storage.** `BlockConfig`, `BlockStore` (Hive), `blockListProvider`, the
   `MethodChannel` (`BlockPlatform` ↔ `MainActivity.saveConfigs`), home screen with switches, app
   picker. Now blocking is user-configurable. *(→ Step 1)*
5. **Permission gate** on the home screen (banner + the 3 check/open channel methods).
6. **Anti-flicker + home-kick + delayed launch** in `showBlockScreen`. *(→ Step 1.6–1.7)*
7. **Timer.** Extend `BlockConfig` (timed), `BlockRepository.decide`, `MODE_INTERSTITIAL`,
   `startSession`/quota/daily-reset, and the floating widget (draggable/edge-snap; never mutate
   the live overlay hierarchy). *(→ Step 2)*
8. **Website blocking.** Turn on `canRetrieveWindowContent` + `flagReportViewIds`;
   `browserPackages`/`urlBarIdSuffixes`; `readBrowserUrl` (skip focused bar);
   `isBlockedHost`/`normalizeHost`; `MODE_BACK` + `goBackAndPause`; `SiteStore` +
   `blockedSitesProvider` + `sites_screen`; `BuiltInBlocklist`; then in-app-browser handling.
   *(→ Step 3)*
9. **Sub-feature blocking.** `featureApps`/`featureIdHints`/`featureDescHints`; `treeHasSignal`;
   `checkBlockedFeature` (Back + toast + grace); `FeatureStore` + `featureBlocksProvider` +
   `features_screen`; the `logFeatureCandidates` tuning logs. *(→ Step 4)*

### Building the APK

Never run gradle/APK builds inside tooling — build on the machine:

```
flutter build apk --debug                       # fat ~150 MB, easiest for reading logs
flutter build apk --release --split-per-abi     # ~17 MB, install app-arm64-v8a-release.apk
```

Install over the existing app — same `applicationId`, no uninstall needed (release is signed
with the debug key too, so signatures match):

```
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

*(Only the one-time rename from the original `com.block.app` → `com.blockx.app` required an
uninstall, because a changed `applicationId` is a brand-new app to Android.)*

---

## D. Debugging & tuning with logcat

Everything logs under the tag **`BlockX`**:

```
adb logcat -s BlockX:*                          # BlockX logs only
adb logcat -s BlockX:* ActivityTaskManager:I    # + which activity is foreground
adb logcat -b crash -d                          # last crash (for a sudden stop)
```

Log lines and what they mean:

| Log line | Means |
|---|---|
| `evaluate: <pkg> -> <DECISION>` | the decision changed for the foreground app |
| `showBlockScreen: <pkg> mode=… homeKick=…` | a block screen is being launched (homeKick = anti-flicker) |
| `launched BlockActivity for <pkg>` | the screen actually started |
| `failed to launch BlockActivity …` | `startActivity` threw (background-launch restriction, etc.) |
| `leaveToHome (Go to home button) …` | the app block screen's phone-home button was tapped |
| `blocked site in <pkg>: "<url>"` | a browser URL was matched and blocked |
| `in-app browser top url (not blocked): "<url>"` | tuning: what an in-app browser showed (didn't match) |
| `blocked feature in <pkg>: <key> -> back` | a Short/Reel was detected → Back sent |
| `feature candidates (<key>): ids=… descs=…` | tuning: on-screen candidates when detection missed |

### The realme/ColorOS service-kill gotcha

The system sometimes kills the accessibility-service process to save battery — seen in logcat as
`MainActivity … app died, no saved state` with a **new pid** and **no** `AndroidRuntime` crash.
When it does, realme often flips the Accessibility toggle **off**, and blocking silently stops.

- **It is not a BlockX bug.** Verify by checking `adb logcat -b crash -d` is clean (no
  `FATAL EXCEPTION … com.blockx.app`).
- **Mitigate on-device:** lock BlockX in Recents (padlock), and Settings → Battery / App battery
  management → BlockX → allow background + auto-launch, don't optimize.
- No app-side code can stop the OS from disabling an accessibility service.
- Unrelated noise: a `com.coloros.phonemanager` `TrackApi` crash sometimes appears in logcat —
  that's a realme system app, **not** BlockX.

### realme/Oppo sideload tips

Enable Developer options → "Install via USB"; keep internet on during install; pick "Allow
restricted settings" for the Accessibility toggle; and grant Usage access.

### A real crash we did fix (for reference)

A `NullPointerException in ViewGroup.newDispatchApplyWindowInsets` (no app frames in the stack)
came from mutating the **live floating-widget overlay's** child views. It killed the whole
process → the service died → blocking stopped. Fix: never `removeAllViews()`/re-`addView()` on
the attached overlay; keep a fixed child order and reposition via `updateViewLayout`. *(See
[STEP-2-TIMER.md](STEP-2-TIMER.md) §5.)*
