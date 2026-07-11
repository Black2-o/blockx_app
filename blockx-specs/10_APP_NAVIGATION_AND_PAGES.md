# App Navigation & Page Architecture

This defines every screen, what's on it, and how you move between them —
so screens can be built one at a time without guessing where they plug in.

## Navigation shell
Bottom navigation bar, 4 tabs, always visible except on full-screen
overlays (which aren't Flutter screens at all — those are native overlay
windows, see `03`/`06`). Bottom nav icons + labels styled per design
system (Bebas Neue label, red highlight on active tab).

```
┌─────────────────────────────┐
│         HEADER (shared)      │   <- BlockXHeader, same on every tab
├─────────────────────────────┤
│                               │
│         TAB CONTENT          │
│                               │
├─────────────────────────────┤
│  Apps | Sites | Timers | ⚙  │   <- bottom nav, 4 tabs
└─────────────────────────────┘
```

## Full page list

| # | Page | Tab? | Purpose |
|---|---|---|---|
| 1 | **Onboarding — Permissions** | no (first-run only) | Walks through granting Accessibility, Overlay, VPN, Battery-exemption, one screen per permission |
| 2 | **Blocked Apps** (Tier 1) | ✅ tab 1 | List of apps with a rule; add/edit/remove; tap row → Timer Config sheet |
| 3 | **Blocked Sites** (Tier 3) | ✅ tab 2 | Domain list — this is your uploaded mockup, ships closest to as-is |
| 4 | **Sub-Features** (Tier 2) | tucked inside tab 1 (see below) | Toggle list for Reels/Shorts per watched app |
| 5 | **Timer Config** | modal/sheet, not a tab | Opened from an app row in Blocked Apps; mode + preset/custom minutes |
| 6 | **Settings / Status** | ✅ tab 4 | Permission status indicators, battery-exemption re-prompt, app version, (later) stats |
| 7 | **App Picker** | modal, launched from Blocked Apps | Search/select an installed app to add a new rule |

That's **4 bottom-nav tabs** (Apps / Sites / Timers-overview / Settings) +
3 modal/sheet screens layered on top. You don't need a separate
always-visible "Sub-Features" tab — fold it into the Apps tab as a second
section or a segmented toggle at the top of that screen, since it only
applies to 3 apps and doesn't need its own top-level slot.

Revised 4-tab bar, reflecting that:

```
[ Apps ]   [ Sites ]   [ Timers ]   [ Settings ]
```

## Per-screen breakdown

### 1. Onboarding — Permissions (first run only)
- Sequence of 4 simple cards, one per permission, each with: icon, one-line
  explanation of *why* BlockX needs it, a button that deep-links to the
  relevant system settings screen, and a status check (auto-detects once
  granted, advances or shows a green check).
  1. Accessibility Service
  2. Display over other apps (Overlay)
  3. VPN permission
  4. Ignore battery optimizations
- Last card: "All set" → routes into the main 4-tab shell, lands on **Apps**.
- Skippable per-permission (in case they want to grant later), but each
  skipped one shows a persistent banner on **Settings** until granted.

### 2. Blocked Apps (Tab 1)
- Header (shared) + count badge ("N BLOCKED").
- Segmented control or two clearly separated sections at top:
  **"Full Block"** (this list) vs **"Sub-Features"** (Reels/Shorts toggles)
  — tapping "Sub-Features" swaps the list content below, same shell,
  avoids a 5th tab.
- **Full Block section:** list of app rows (icon, name, mode chip:
  BLOCKED/TIMED/UNLIMITED). Floating "+" button → opens **App Picker**.
  Tap a row → opens **Timer Config** sheet for that app.
- **Sub-Features section:** fixed list (Instagram/Facebook/YouTube — or
  whatever's in `subfeature_matchers.json`), each row = icon + name +
  toggle switch for "Block Reels/Shorts". No add button — this list is
  curated, not user-extensible in v1.
- Empty state (Full Block, no rules yet): reuse `BlockXEmptyState` — icon +
  "No apps blocked yet. Tap + to add one."

### 3. Blocked Sites (Tab 2)
- Exactly the uploaded mockup. Input row + add button, scrollable domain
  list, footer stat + ACTIVE/INACTIVE status pill (reflecting
  `DomainVpnService` running state).
- No sub-navigation needed — this screen is self-contained.

### 4. Timers overview (Tab 3)
- Not a config screen (that's the modal sheet) — this is a **read-only
  dashboard** of today's usage across all Timed apps:
  - One row per Timed-mode app: icon, name, progress bar
    (`usedTodayMinutes` / `dailyLimitMinutes`), remaining time in Bebas
    Neue numerals.
  - Tapping a row jumps to that app's **Timer Config** sheet to adjust the
    limit.
  - Empty state if no apps are in Timed mode: "No timers running. Set an
    app to Timed mode from the Apps tab."
- This tab is what makes the floating bubble's numbers meaningful at a
  glance without waiting to see the bubble mid-use.

### 5. Timer Config (modal bottom sheet)
- Opened from an Blocked Apps row or a Timers-tab row — same sheet either
  way, pre-filled with that app's current rule.
- Mode chips: **Blocked / Timed / Unlimited**.
- If Timed: preset chips **10 / 20 / 30**, plus **Custom** (reveals numeric
  input, minutes).
- Live "today's usage" readout at the bottom.
- Save / Cancel actions — Save calls `updateBlockedApps()` MethodChannel.

### 6. Settings (Tab 4)
- Permission status list (4 rows matching onboarding steps), each with a
  green check or a red "Fix" button re-triggering that deep-link if
  revoked.
- VPN status (running/stopped) with a manual start/stop toggle as a
  fallback control.
- App version / build number footer.
- (Later, v2) — usage stats / history entry point, data export, reset-all.

### 7. App Picker (modal, from Blocked Apps "+")
- Search field at top (reuses `BlockXTextField`).
- Scrollable list of installed apps (icon + name) via `device_apps`,
  filtered live as you type.
- Tap an app → adds it to Blocked Apps list with default mode = Blocked,
  closes modal, returns to Blocked Apps screen where you can immediately
  tap it to open Timer Config if you want Timed instead.

## Navigation flow diagram

```
                     ┌────────────────────┐
                     │ Onboarding (first   │
                     │ run only, 4 steps)  │
                     └──────────┬──────────┘
                                │
                                ▼
        ┌───────────────────────────────────────────────┐
        │                 Bottom Nav Shell                │
        │   [ Apps ]   [ Sites ]  [ Timers ]  [ Settings ] │
        └───┬───────────────┬────────────┬────────────┬───┘
            │               │            │            │
            ▼               ▼            ▼            ▼
      ┌───────────┐   ┌───────────┐ ┌──────────┐ ┌───────────┐
      │Blocked Apps│   │Blocked    │ │Timers    │ │Settings   │
      │(Full Block │   │Sites      │ │Overview  │ │(perm      │
      │ + Sub-Feat │   │(domain    │ │(read-only│ │ status +  │
      │ segments)  │   │ list)     │ │ dashboard│ │ VPN toggle│
      └─────┬──────┘   └───────────┘ └────┬─────┘ └───────────┘
            │                              │
      ┌─────┴──────┐                       │
      ▼            ▼                       │
 ┌─────────┐  ┌───────────┐                │
 │App      │  │Timer      │◄───────────────┘
 │Picker   │  │Config     │
 │(modal)  │  │(sheet)    │
 └─────────┘  └───────────┘
```

## Build-order mapping
This lines up with `08_BUILD_ORDER.md` as follows — build the *screen*
alongside the milestone that gives it real data:
- Milestone 0 → Blocked Sites screen (static UI first)
- Milestone 1 → Blocked Sites wired to native (Tier 3)
- Milestone 2 → Blocked Apps (Full Block section) + App Picker
- Milestone 3 → Timer Config sheet + Timers overview tab
- Milestone 4 → Onboarding + Settings (permission status matters most once
  everything else exists to protect)
- Milestone 5 → Sub-Features section inside Blocked Apps
