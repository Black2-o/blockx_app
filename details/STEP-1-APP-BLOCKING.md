# Step 1 — App blocking (the foundation)

> Block whole apps: open a blocked app and it's instantly covered with a black "This app is
> blocked." screen, and pushed to the background so it actually pauses. This step also
> established the entire architecture the later steps build on.

- Prereq: read **[STEP-0-OVERVIEW.md](STEP-0-OVERVIEW.md)** first.
- Main code: `AppBlockerService.kt`, `BlockActivity.kt`, `BlockRepository.kt`, `MainActivity.kt`;
  Flutter `block_config.dart`, `block_store.dart`, `block_providers.dart`, `home_screen.dart`,
  `app_picker_screen.dart`, `config_dialog.dart`.

---

## 1. What it does (the happy path)

1. You add an app to the block list (home `+` → app picker → config dialog) and leave its switch **ON**.
2. `AppBlockerService` (running in the background) notices that app come to the foreground.
3. It asks `BlockRepository.decide(pkg)`, which returns `BLOCK` for a plain blocked app.
4. It launches **`BlockActivity`** — a real full-screen Activity — over the app.
5. Because it's a real Activity, Android backgrounds the app underneath, so it truly pauses (no
   sound, not visible). The screen shows **"This app is blocked."** + **"Go to home screen."**

---

## 2. How foreground detection works

The service figures out the current foreground package **two ways at once**:

### a) Instant — accessibility events

```kotlin
override fun onAccessibilityEvent(event: AccessibilityEvent?) {
    ...
    if (type == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
        currentForegroundPackage = pkg
        evaluate()
    }
    ...
}
```

`TYPE_WINDOW_STATE_CHANGED` fires the moment a new window comes to the front — this gives an
instant reaction.

### b) Source of truth — a 350 ms UsageStats poll

```kotlin
private val recheckRunnable = object : Runnable {
    override fun run() {
        pollForegroundApp()   // reads UsageStatsManager
        evaluate()
        handler.postDelayed(this, recheckIntervalMs)  // 350 ms
    }
}
```

`pollForegroundApp()` queries `UsageStatsManager.queryEvents(...)` for the last resumed app.
This is the **authoritative** source (see the Game Space problem below). The poll also re-blocks
an already-open app after unlock, and catches any missed accessibility event.

### c) Ignoring non-app windows

`isIgnoredPackage()` filters out systemui, Play Games, and Game Space / game-assistant
side-panels (`com.oplus.gamespace`, `*gamespace*`, `*gameassistant*`, …) so they can't be
mistaken for the user switching apps. Our own package is also skipped in `onAccessibilityEvent`
so the floating widget / block screen isn't treated as a "foreground app".

---

## 3. The decision and the block screen

`evaluate()` turns the foreground package into an action:

```kotlin
when (BlockRepository.decide(this, pkg)) {
    NONE          -> hideFloating()                       // not blocked
    ALLOW_SESSION -> showFloating(pkg)                    // Step 2
    INTERSTITIAL  -> showBlockScreen(pkg, MODE_INTERSTITIAL, null)  // Step 2
    BLOCK         -> showBlockScreen(pkg, MODE_BLOCK, reason)       // this step
}
```

`showBlockScreen` → `launchBlockActivity` starts `BlockActivity` with
`FLAG_ACTIVITY_NEW_TASK | SINGLE_TOP | NO_ANIMATION` and extras `EXTRA_PACKAGE / EXTRA_MODE /
EXTRA_REASON`. `BlockActivity` renders a plain black screen (`MODE_BLOCK`): the reason text
(default "This app is blocked.") + a **"Go to home screen"** button (`leaveToHome()` → launches
the launcher and finishes).

`BlockActivity` is declared in the manifest with its **own `taskAffinity`
(`com.blockx.app.blockscreen`)**, `excludeFromRecents`, `singleTask`, and
`Theme.Black.NoTitleBar` (NoTitleBar, *not* Fullscreen, so the status bar stays usable). It
tracks `isVisible` so the service doesn't stack duplicates.

---

## 4. The problems we hit — and why the code looks like it does

This step took the most iteration. Each fix is still load-bearing; don't undo them.

### 4.1 VPN → AccessibilityService
The first prototype was a VPN traffic filter. On a real phone it only cut internet; apps still
opened. The whole mechanism was replaced with the accessibility service. **Never bring the VPN
back.**

### 4.2 You can't self-grant Accessibility → a permission gate
Android blocks a sideloaded app from enabling its own accessibility/overlay (a "restricted
setting"), and hides the toggle until you pick "Allow restricted settings" (or install via USB).
So the home screen has a **banner** (`_PermissionBanner`) with one button per missing
permission, deep-linking to the right Settings screen, re-checked on `AppLifecycleState.resumed`
(invalidates `permissionsProvider`). The three checks are native in `MainActivity.kt`:
- `isAccessibilityEnabled` — reads `Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES` and looks for
  our `ComponentName`.
- `canDrawOverlays` — `Settings.canDrawOverlays(this)`.
- `hasUsageAccess` — `AppOpsManager` `OPSTR_GET_USAGE_STATS`.

### 4.3 Games slipped through (the Game Space problem) → Usage access
On realme/Oppo, **Game Space hosts games under its own window** (`com.oplus.gamespace`), so
accessibility window events reported the *wrong* package and games bypassed the block
("sometimes blocks, sometimes not"). **Fix:** poll `UsageStatsManager` every 350 ms
(`pollForegroundApp`) as the real source of truth — it reports the actually-resumed app. This
required a **third permission: Usage access.** `isIgnoredPackage()` also skips the game
side-panels so they aren't mistaken for an app switch.

### 4.4 Overlay → real Activity
An early version *drew* a `WindowManager` overlay over the app. It only *hid* the app — it kept
running (sound continued, reachable from Recents) and fought the status/nav bars. Switched to
launching a real `BlockActivity`, which backgrounds the app so it pauses.

### 4.5 Re-block after unlock / missed events
A `BroadcastReceiver` for `ACTION_USER_PRESENT` / `SCREEN_ON` (`screenUnlockReceiver`) plus the
350 ms re-check re-run the decision, so an already-open blocked app is re-blocked after you
unlock the phone.

### 4.6 Anti-flicker for apps that fight back (Facebook)
Some apps aggressively re-launch themselves to the foreground and ping-pong with the block
screen. `showBlockScreen` detects the **same** package reappearing within 4 s and fires
`GLOBAL_ACTION_HOME` first — an app can't beat the global Home action — to decisively background
it before showing the block screen. Guards: `BlockActivity.isVisible` + a 400 ms cooldown so it
can't stack/spam. Normal apps block on the first try and never hit this (no extra launcher
flash).

### 4.7 Home-kick race → delayed launch (a later fix)
The Home kick had a subtle bug. Firing `performGlobalAction(GLOBAL_ACTION_HOME)` and
**immediately** `startActivity(BlockActivity)` **raced**: the Home transition won and the block
screen never rendered — the app just closed to the launcher with **no screen**. It showed up
most when you dismissed a block via the in-app button and reopened the same app within 4 s.

**Fix (current code):**

```kotlin
val needsHomeKick = pkg == lastBlockedPackage && now - lastBlockStart < 4000
...
if (needsHomeKick) {
    performGlobalAction(GLOBAL_ACTION_HOME)
    val launch = Runnable { launchBlockActivity(pkg, mode, reason) }
    pendingBlockLaunch = launch
    handler.postDelayed(launch, 350L)   // let Home settle, THEN show the screen
} else {
    launchBlockActivity(pkg, mode, reason)   // normal path: immediate
}
```

So the Home kick fires, and the block screen is launched **~350 ms later**, landing cleanly on
top of the launcher. *(Diagnosed from `ActivityTaskManager` logs — the block screen now always
shows `Displayed …BlockActivity`.)*

---

## 5. The Flutter side of Step 1

- **`models/block_config.dart`** — `BlockConfig{enabled, mode(direct|timed), opensPerDay,
  sessionMinutes}`. For a plain block, `mode = direct`; the timed fields matter in Step 2.
  `toMap`/`fromMap` (JSON), `summary` (the home-row subtitle).
- **`data/block_store.dart`** — Hive box `blocklist_v2` (`pkg → JSON`). "In the list" == a key
  exists; whether it's blocked right now is `config.enabled`. Migrates the original `blocklist`
  `Box<bool>` → direct-mode configs on first open, then clears it.
- **`providers/block_providers.dart`** — `blockListProvider`
  (`StateNotifier<Map<String,BlockConfig>>`) is the core state. On **every** change,
  `_syncNative()` mirrors the **enabled** apps' configs to native via `BlockPlatform.setConfigs`.
  Also `installedAppsProvider` (native app list) and `permissionsProvider` (the 3 checks).
- **Screens:**
  - `home_screen.dart` — the list (name + `config.summary` + enable switch; tap = edit,
    long-press = remove) + `_PermissionBanner` + the `+` FAB + AppBar icons (added in Steps 3 & 4).
  - `app_picker_screen.dart` — searchable installed-apps list; tapping opens the config dialog
    then adds.
  - `config_dialog.dart` — Direct vs Time-limited (uses `RadioGroup`, not the deprecated
    `RadioListTile.groupValue`).

---

## 6. Native pieces to know

| Piece | Where | Role |
|---|---|---|
| Foreground detection | `AppBlockerService.pollForegroundApp` / `onAccessibilityEvent` | who's in front |
| Decision | `BlockRepository.decide` | `NONE / BLOCK / INTERSTITIAL / ALLOW_SESSION` |
| Launch block screen | `AppBlockerService.showBlockScreen` / `launchBlockActivity` | with anti-flicker + delayed launch |
| The screen | `BlockActivity` (`MODE_BLOCK`) | plain black + "Go to home screen" |
| Save config | `MainActivity.saveConfigs` → `configs_json` | what Flutter mirrors |

Next: **[STEP-2-TIMER.md](STEP-2-TIMER.md)** — turning a hard block into a daily quota.
