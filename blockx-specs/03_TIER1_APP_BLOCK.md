# Tier 1 — Full App Blocking

## Goal
Detect when a blocked app (Instagram, Facebook, YouTube, or any user-added
app) comes to the foreground, and immediately cover it with a full-screen
block overlay, respecting the app's current mode (blocked / timed / unlimited).

## Detection: BlockAccessibilityService
- Register with `TYPE_WINDOW_STATE_CHANGED` events.
- `AccessibilityServiceInfo`: set `eventTypes = TYPE_WINDOW_STATE_CHANGED`,
  `feedbackType = FEEDBACK_GENERIC`, no `notificationTimeout` delay needed.
- On event: read `event.packageName`. If it matches an entry in the current
  rules where `mode == "blocked"` OR (`mode == "timed"` AND
  `usedTodayMinutes >= dailyLimitMinutes`) → trigger block immediately.

```kotlin
override fun onAccessibilityEvent(event: AccessibilityEvent) {
    if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return
    val pkg = event.packageName?.toString() ?: return
    val rule = RulesStore.getRule(pkg) ?: return
    if (shouldBlockNow(rule)) {
        BlockOverlayService.showBlock(context = this, packageName = pkg)
    }
}
```

## Enforcement: BlockOverlayService
- `TYPE_APPLICATION_OVERLAY` window, `MATCH_PARENT` x `MATCH_PARENT`, drawn
  above everything, not dismissible by back button (`FLAG_NOT_TOUCH_MODAL`
  off, intercept back).
- Content: reuse the BlockX shell (dark bg, red glow, scanline overlay per
  design system) with a short message — e.g. "INSTAGRAM IS LOCKED", the
  Bebas Neue wordmark, and one button: "Go Home" (`Intent.ACTION_MAIN` +
  `CATEGORY_HOME`) — no "unlock" button when `mode == "blocked"`.
- If `mode == "timed"` and the user still has minutes left, do **not**
  show the overlay — let the app through and let `TimerForegroundService`
  (see `06_TIMER_SYSTEM.md`) handle the countdown/bubble instead.

## Config surface in Flutter (Blocked Apps screen)
- Reuses the shell from the uploaded mockup:
  - Header: "BLOCKX" + count badge showing number of blocked apps.
  - "Add" area replaced with an **app picker** (via `device_apps` package)
    instead of a text field — search installed apps, tap to add.
  - List items: app icon + app name (instead of the red dot + URL), plus a
    small mode chip on the right (BLOCKED / TIMED / UNLIMITED) that opens
    the timer config sheet on tap.
  - Footer: same stat/status pill pattern — "Apps Blocked" count,
    "ACTIVE" status pill reflecting whether AccessibilityService is
    currently enabled and running.

## Permission requirements
- `BIND_ACCESSIBILITY_SERVICE` — user must manually enable in
  Settings → Accessibility (cannot be silently granted). On first launch,
  detect if disabled and deep-link there via
  `Settings.ACTION_ACCESSIBILITY_SETTINGS`.
- `SYSTEM_ALERT_WINDOW` — request via `Settings.canDrawOverlays()` /
  `ACTION_MANAGE_OVERLAY_PERMISSION`.
- Battery optimization exemption strongly recommended (see architecture doc).

## Acceptance criteria for this milestone
- [ ] Opening a blocked app shows the overlay within ~1 second (no visible
      flash of app content before block, ideally).
- [ ] "Go Home" always returns to launcher, never leaves overlay dismissible
      via back/recents swipe while `mode == "blocked"`.
- [ ] Toggling accessibility off in system settings is detected and surfaced
      in the app UI within one app-resume cycle.
- [ ] Works after device reboot without reopening the Flutter app.
