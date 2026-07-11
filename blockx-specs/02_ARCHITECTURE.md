# BlockX — Architecture

## High-level split
Flutter owns UI, configuration, and persistence of user-facing rules. Native
Kotlin owns everything that requires OS-level hooks Flutter plugins don't
reliably cover: Accessibility Service, Overlay windows, VPN Service,
Foreground Service.

```
lib/                                    Flutter (UI + config + rules)
├── main.dart
├── theme/                              design tokens from 01_DESIGN_SYSTEM.md
├── models/
│   ├── blocked_app.dart                {packageName, mode, dailyLimitMin, usedTodayMin, subFeatureBlocks}
│   ├── blocked_domain.dart             {domain, addedAt}
│   └── app_rule_mode.dart              enum: blocked | timed | unlimited
├── data/
│   ├── rules_repository.dart           sqflite/hive CRUD
│   └── native_bridge.dart              MethodChannel + EventChannel wrapper
├── screens/
│   ├── blocked_apps_screen.dart        Tier 1
│   ├── subfeature_screen.dart          Tier 2
│   ├── blocked_sites_screen.dart       Tier 3 (matches uploaded mockup)
│   └── timer_config_screen.dart        cross-cutting timer UI
└── widgets/                            reusable components from design system

android/app/src/main/kotlin/.../blockx/
├── MainActivity.kt                     MethodChannel/EventChannel bridge entrypoint
├── accessibility/
│   ├── BlockAccessibilityService.kt    foreground-app detection + node-tree scanning
│   └── NodeMatchers.kt                 per-app resource-id / content-desc rules for Reels/Shorts
├── overlay/
│   ├── BlockOverlayService.kt          full-screen block screen (SYSTEM_ALERT_WINDOW)
│   └── TimerBubbleService.kt           floating countdown bubble
├── vpn/
│   ├── DomainVpnService.kt             VpnService, establishes tun interface
│   ├── DnsProxy.kt                     packet loop, DNS parse/forward/block
│   └── BlocklistStore.kt               loads JSON blocklist, exposes Set<String>
├── timer/
│   └── TimerForegroundService.kt       per-app allowance ticking, persists usage
└── bridge/
    └── ChannelHandlers.kt              maps MethodChannel calls → services
```

## Communication: MethodChannel + EventChannel

**MethodChannel** (`com.blockx/control`) — one-off imperative calls,
Flutter → native:
- `requestAccessibilityPermission()`
- `requestOverlayPermission()`
- `requestVpnPermission()` (returns `VpnService.prepare()` intent result)
- `startVpnService(blockedDomains: List<String>)`
- `stopVpnService()`
- `updateBlockedApps(rules: List<Map>)`
- `updateSubFeatureRules(rules: List<Map>)`
- `updateBlockedDomains(domains: List<String>)`
- `getAccessibilityStatus()`, `getOverlayStatus()`, `getVpnStatus()` (bool)
- `isIgnoringBatteryOptimizations()` / `requestIgnoreBatteryOptimizations()`

**EventChannel** (`com.blockx/events`) — continuous native → Flutter stream:
- App-block events: `{type: "app_blocked", package: "com.instagram.android"}`
- Sub-feature block events: `{type: "subfeature_blocked", package, feature: "reels"}`
- Timer ticks: `{type: "timer_tick", package, remainingSeconds}`
- Timer expired: `{type: "timer_expired", package}`
- Domain block hits (for a stats/log screen later): `{type: "domain_blocked", domain, timestamp}`

Flutter listens to the EventChannel stream to update in-app stats/history UI;
it does **not** need to be running for blocking to work — all enforcement
happens natively in the services, so blocking still works if the Flutter
app/activity isn't in the foreground.

## Data model (shared shape between Dart models and native JSON)

```jsonc
// per-app rule
{
  "packageName": "com.instagram.android",
  "mode": "timed",              // "blocked" | "timed" | "unlimited"
  "dailyLimitMinutes": 20,       // used when mode == "timed"; 0 = always blocked
  "usedTodayMinutes": 4,
  "subFeatureBlocks": ["reels"], // subset of features blocked within this app
  "lastResetDate": "2026-07-11"
}

// domain blocklist entry
{
  "domain": "example-site.com",
  "addedAt": "2026-07-10T21:00:00+06:00"
}
```

Persist on the **native side** (SharedPreferences or a small SQLite file
under `filesDir`) as the source of truth for enforcement, since native
services must be able to read rules even if Flutter's Dart VM isn't running
(e.g. after device reboot, before the user opens the app). Flutter's local
DB (sqflite/hive) is the UI-facing copy; on every rule change, Flutter writes
through the MethodChannel so native re-persists and reloads. Simplest
approach for v1: **native owns persistence entirely**, Flutter always reads
current state via `getRules()` MethodChannel call rather than keeping its
own separate DB — avoids sync-drift bugs. Revisit only if this becomes a
performance problem.

## Process/lifecycle notes
- `BlockAccessibilityService`, `TimerForegroundService`, and
  `DomainVpnService` must all set `android:foregroundServiceType` correctly
  and be declared with `START_STICKY` / restart intents so OEM task-killers
  (MIUI/ColorOS/etc.) are less likely to kill them. Battery optimization
  exemption is mandatory — prompt for it in onboarding.
- On device boot, register a `BOOT_COMPLETED` broadcast receiver that
  restarts the Accessibility check (Accessibility services usually
  auto-resume, but the VPN and foreground timer service need an explicit
  restart) — implement `BootReceiver.kt`.
- Overlay windows (`BlockOverlayService`, `TimerBubbleService`) need
  `TYPE_APPLICATION_OVERLAY` and the corresponding runtime permission grant
  screen (`Settings.canDrawOverlays`).

## Error/edge cases to design for now
- User revokes Accessibility permission mid-use → Flutter should detect via
  `getAccessibilityStatus()` on app resume and show a "protection disabled"
  banner, not fail silently.
- Daily usage counters need a reliable midnight-reset — do this via
  date-string comparison (`lastResetDate` field above) checked on every
  foreground-app event, not a scheduled alarm (`AlarmManager` under Doze can
  be unreliable for exact-time triggers).
- VPN conflicts: only one VPN can be active on Android at a time — if the
  user has another VPN app active, `VpnService.prepare()` will prompt to
  replace it. Surface this clearly in-app rather than failing silently.
