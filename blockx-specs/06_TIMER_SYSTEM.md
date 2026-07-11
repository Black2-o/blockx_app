# Timer System — Allowances + Floating Bubble

Cross-cutting feature used by Tier 1 (and could extend to Tier 2 later, but
v1 scope is Tier 1 apps only).

## Per-app modes
- **Blocked** — `dailyLimitMinutes = 0`. Always blocked, no bubble.
- **Timed** — preset chips `10 / 20 / 30` minutes, or a custom numeric input
  for any other value. App is usable until the daily allowance runs out,
  then Tier 1 overlay kicks in for the rest of the day.
- **Unlimited** — no restriction, no bubble, just present in the tracked
  list (useful if you want usage stats without blocking).

## TimerForegroundService
- A single foreground service (not one per app) that:
  1. Listens for `app_blocked`-adjacent "app in foreground" events from
     `BlockAccessibilityService` (reuse the same detection — don't
     duplicate foreground-app polling).
  2. If the foregrounded app has `mode == "timed"` and remaining allowance
     > 0: starts a 1-second tick loop, incrementing `usedTodayMinutes`
     (persist every ~15s, not every tick, to avoid excessive disk writes),
     and pushes `timer_tick` events over the EventChannel so Flutter UI (if
     open) can reflect it.
  3. When allowance hits 0: emits `timer_expired`, stops the tick loop,
     calls into `BlockOverlayService` to show the block screen immediately
     — same as Tier 1's direct-block path.
  4. When the user backgrounds/leaves the timed app before running out: stop
     ticking, keep the remaining balance for next time they open it that day.
- Daily reset: on each tick/check, compare `lastResetDate` to today's date
  (device local time); if different, reset `usedTodayMinutes = 0` and update
  `lastResetDate` before evaluating anything else.

## Floating timer bubble (TimerBubbleService)
- `TYPE_APPLICATION_OVERLAY`, small circular view, shown **only** while a
  timed app with `usedTodayMinutes < dailyLimitMinutes` is in the
  foreground.
- Visuals (per design system): dark circular badge, red ring/progress
  arc showing remaining-time fraction, Bebas Neue numeral in the center
  (e.g. "12" for 12 minutes left, or "0:45" under a minute), subtle
  red-glow shadow matching button/dot glow style elsewhere in the app.
- Draggable (standard `WindowManager` touch-move-update-layout pattern),
  snaps to nearest screen edge on release, position persisted
  (`SharedPreferences`) so it reappears in the same spot next time.
- Tapping it could later open a quick "add 5 more minutes" affordance — not
  required for v1, flag as a nice-to-have.
- Disappears immediately when: the timed app is backgrounded, the timer
  reaches 0 (overlay block takes over instead), or the app's mode is
  switched to Unlimited/Blocked from settings mid-session.

## Config surface in Flutter (Timer Config screen / sheet)
- Reuses the same list-row shell as other screens. Opening a blocked-app
  row (from the Tier 1 screen) opens this as a bottom sheet or sub-screen:
  - Mode selector: three chips — **Blocked / Timed / Unlimited** (Bebas
    Neue labels, red fill on selected, matches "+ ADD" button styling).
  - If Timed selected: preset chips **10 / 20 / 30 min**, plus a "Custom"
    chip that reveals a numeric input (reuse `BlockXTextField`).
    Selecting a preset just sets `dailyLimitMinutes` to that value — no
    separate "0 min" preset needed, since 0 is just the Blocked mode.
  - Live readout of today's usage vs limit (e.g. "4 / 20 min used today"),
    Bebas Neue value styled like the footer stat elsewhere.

## Acceptance criteria
- [ ] Bubble appears within ~1s of opening a timed app with remaining
      allowance, and disappears within ~1s of leaving it.
- [ ] Countdown is accurate to within a couple seconds over a 20-minute
      session (i.e., ticking isn't drifting badly from wall-clock time).
- [ ] Allowance correctly persists across app switches within the same day
      (leaving and reopening a timed app resumes the remaining balance, not
      a fresh 20 minutes).
- [ ] Allowance resets at local midnight, verified across a day boundary.
- [ ] Switching a timed app to Blocked mid-session immediately blocks it,
      even with time remaining.
