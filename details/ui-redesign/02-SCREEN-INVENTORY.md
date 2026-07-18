# 02 — Screen Inventory & Navigation Map

## The count

**15 Flutter screens + 7 native block-screen variants = 22 distinct UI states.**

| # | Screen | Status | File (new or existing) |
|---|---|---|---|
| 1 | Splash | **new** | `lib/screens/splash_screen.dart` |
| 2 | Onboarding — Permissions (4 steps) | restyle | new `lib/screens/onboarding_screen.dart` (wraps existing permission logic) |
| 3 | **Home (Dashboard hub)** | restyle + expand | `lib/screens/home_screen.dart` |
| 4 | App Picker | restyle | `lib/screens/app_picker_screen.dart` |
| 5 | Timer / Rule Config (bottom sheet) | restyle | `lib/screens/config_dialog.dart` → convert to sheet |
| 6 | Sites (website blocklist) | restyle | `lib/screens/sites_screen.dart` |
| 7 | Features (Shorts/Reels) | restyle | `lib/screens/features_screen.dart` |
| 8 | Account (login + premium) | **new** | `lib/screens/account_screen.dart` |
| 9 | Support Us | **new** | `lib/screens/support_screen.dart` |
| 10 | FAQ | **new** | `lib/screens/faq_screen.dart` |
| 11 | Ask Us / Contact | **new** | `lib/screens/ask_screen.dart` |
| 12–15 → | listed as 4 in master prompt; **7 real native states** below | restyle (visual-only `.kt`) | `android/.../BlockActivity.kt` |

### The 7 block-screen variants (native, `BlockActivity.kt`)

Full spec in [03 §Block screens](03-SCREENS-SPEC.md#block-screens).

| Var | Native state | Accent | Headline |
|---|---|---|---|
| B1 | Direct app block (`MODE_BLOCK`) | red | APP BLOCKED |
| B2 | Timed app interstitial (`MODE_INTERSTITIAL`) | amber | IS THIS REALLY NEEDED? |
| B3 | Timed app quota used (`MODE_BLOCK` + reason) | red | DAILY LIMIT REACHED |
| B4 | Website block (`MODE_BACK`) | red | SITE BLOCKED |
| B5 | Feature block direct (`feature=true`) | red | REELS / SHORTS BLOCKED |
| B6 | Feature interstitial (timed) | amber | IS THIS REALLY NEEDED? |
| B7 | Feature quota used | red | DAILY LIMIT REACHED |

> These map to `MODE_BLOCK` / `MODE_INTERSTITIAL` / `MODE_BACK` + the `feature`
> and `reason` extras that already exist. **We add zero new modes** — we only
> restyle how each existing mode renders. Logic frozen.

---

## Navigation map

```
Splash (1)
  └─ first launch, perms missing ─▶ Onboarding (2) ─▶ Home
  └─ perms already granted ────────────────────────▶ Home

Home / Dashboard (3)  ── bottom nav, 4 tabs ──┐
  ├─ Tab 1: HOME (apps + summaries)            │
  ├─ Tab 2: SITES (6)                          │
  ├─ Tab 3: FAQ (10)                           │
  └─ Tab 4: ACCOUNT (8)                        │
                                               │
  From Home:                                   │
   • FAB [+] ─▶ App Picker (4) ─▶ Config sheet (5) ─▶ back to Home
   • tap app row ─▶ Config sheet (5)
   • Shorts/Reels summary card ─▶ Features (7) ─▶ Config sheet (5)
   • Sites summary card ─▶ Sites tab (6)
  From Account (8): ─▶ Support Us (9), ─▶ Ask Us (11)
  From FAQ (10): ─▶ Ask Us (11) ("still need help?")
```

### Bottom nav — 4 tabs (Hick's Law cap)

`Home · Sites · FAQ · Account` — icon + label each, `dark2` bar in the thumb
zone. Config sheet, App Picker, Support, and Ask Us are **pushed routes** (not
tabs), so the nav stays at 4.

> **Why this differs from today:** currently Sites and Features are hidden behind
> two AppBar icons on Home. The redesign promotes Sites to a tab and surfaces
> Features on the Home dashboard, so nothing important is hidden.

---

## Home as a dashboard hub (the "all features on home" decision)

Home Tab is not just the apps list. Top-to-bottom:

1. **Header** — logo wordmark + blocked-count badge.
2. **PermissionBanner** — only when a permission is missing (unchanged behavior,
   restyled).
3. **Blocked Apps** section — the live apps list (the current core), each row a
   restyled `ModeChip` + `AppSwitch`. Empty → `EmptyState` with "Tap + to add".
4. **Shorts & Reels** summary card — shows how many of the 3 features are on;
   taps through to Features (7).
5. **Blocked Sites** summary card — shows count of blocked domains; taps through
   to Sites tab (6).
6. **FAB [+]** — bottom-right, thumb zone, adds an app.

This fills the white space with **real state**, not filler (anti-slop §7). Each
summary card reads its real count from the existing providers
(`featureBlocksProvider`, `blockedSitesProvider`) — no new backend.
