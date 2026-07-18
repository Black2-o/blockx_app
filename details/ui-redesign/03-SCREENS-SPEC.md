# 03 — Per-Screen Specification

Full detail for every screen. Each spec lists: **purpose · layout · content ·
states (empty/loading/error) · widgets used · data source (frozen provider) ·
responsive notes**. Build the layout skeleton first, then apply
[01 Design System](01-DESIGN-SYSTEM.md) styling (master prompt: wireframe-first).

Every screen is wrapped in `AppScaffold` (SafeArea + scroll + max-width clamp,
see [04](04-RESPONSIVE-RULES.md)). No screen manages its own SafeArea/overflow.

---

## 1. Splash

- **Purpose:** first-run brand moment; decides where to route next.
- **Layout:** full-bleed `dark` bg, centered column. One subtle radial red glow
  behind the logo.
- **Content / motion:** logo scale+fade in (~600ms) → `BLOCKX` wordmark (Bebas
  Neue) fades in → tagline `STAY LOCKED IN` (Oswald 400, `textDim`) fades in last.
- **Logic:** after animation (or immediately if reduce-motion), read
  `permissionsProvider`; route to **Onboarding** if any perm missing, else **Home**.
- **States:** no empty/error; if perm check throws, route to Home (banner handles it).
- **Responsive:** everything centered and vector/scalable; no fixed offsets. Fine
  in any orientation. Cap logo width at ~40% of the shorter screen side.

---

## 2. Onboarding — Permissions (4 steps)

- **Purpose:** guide granting the 3 permissions before Home (Zeigarnik: show
  progress so an unfinished grant nags the user back).
- **Layout:** step indicator `1 of 4 … 4 of 4` (Oswald), a title, one line of
  why, a big illust/icon, one `PrimaryButton` per step, a de-emphasized "Skip"/
  "Do later" `SecondaryLink`.
- **The 4 steps:** (1) welcome/what BlockX does; (2) Accessibility; (3) Display
  over other apps (overlay); (4) Usage access. Steps 2–4 each call the **existing**
  `BlockPlatform.open*Settings()` and re-check on resume via `permissionsProvider`.
- **States:** a granted permission shows a green check + auto-advances; the button
  reflects granted/not-granted from the provider.
- **Data source:** `permissionsProvider` (frozen), `BlockPlatform.open*Settings`
  (frozen). No new native calls.
- **Responsive:** content in a scroll view; the step's CTA pinned to the bottom
  safe area but still reachable when the keyboard/large text pushes content.

---

## 3. Home — Dashboard hub

- **Purpose:** the app's home; shows and manages everything at a glance.
- **Layout (scrollable `CustomScrollView`/`ListView`):**
  1. Header row: logo wordmark (left) + count badge "N blocked" (right).
  2. `PermissionBanner` — only if `!perms.allGranted`.
  3. `SectionHeader("Blocked Apps")`.
  4. Apps list — one restyled row per package (icon · name · `ModeChip` · `AppSwitch`).
     - Row tap → **Config sheet (5)**. Long-press → remove-confirm dialog (restyled).
     - Empty → `EmptyState("No apps blocked yet", "Tap + to add one")`.
  5. `SectionHeader("Shorts & Reels")` → summary `AppCard`: "X of 3 on", tap → **Features (7)**.
  6. `SectionHeader("Blocked Sites")` → summary `AppCard`: "N sites blocked", tap → **Sites (6)**.
- **FAB [+]** → **App Picker (4)**.
- **Data source (all frozen):** `blockListProvider`, `installedAppsProvider`
  (name resolution), `permissionsProvider`, `featureBlocksProvider`,
  `blockedSitesProvider`. Same read/write calls as today
  (`setEnabled`, `putApp`, `removeApp`).
- **States:** installed-apps loading → names fall back to package (as today);
  blockList empty → the apps `EmptyState`, but Sites/Features cards still show.
- **Responsive:** single scroll owner for the whole page; the apps list is a
  non-scrolling `Column`/sliver inside it (never a nested scrollable). See
  [04 §nested scroll](04-RESPONSIVE-RULES.md).

---

## 4. App Picker

- **Purpose:** pick an installed app to block.
- **Layout:** search `AppTextField` pinned at top → filtered list of apps
  (icon · name · package). Already-added apps show a check + are disabled.
- **Flow:** tap an app → **Config sheet (5)** → on save, `putApp` + pop back to Home.
- **Data source:** `installedAppsProvider`, `blockListProvider` (frozen).
- **States:** loading → centered spinner (restyled); error → `EmptyState` with the
  error line + retry; no results for query → "No apps match '<query>'".
- **Responsive:** search field stays pinned; list scrolls under it. Keyboard-safe
  (list shrinks, doesn't overflow). Works in landscape (list just gets shorter).

---

## 5. Timer / Rule Config — **bottom sheet** (was AlertDialog)

- **Purpose:** choose how an app/feature is blocked. Replaces the current
  `showConfigDialog` AlertDialog with a modal bottom sheet (better thumb reach,
  master prompt wireframe).
- **Layout:** drag handle → app/feature name (Oswald 600) → mode chips
  `[Blocked] [Timed]` (`ModeChip`, icon+text) → if **Timed**: "Opens per day"
  `NumberChips` + "Minutes per open" `NumberChips` → optional "Today: used/total"
  line if the value is available → `PrimaryButton("Save")` + `SecondaryLink("Cancel")`.
- **Data contract (frozen):** returns a `BlockConfig(enabled, mode, opensPerDay,
  sessionMinutes)` exactly as today; `opensOptions = [1,2,3,5,10]`,
  `minutesOptions = [1,2,5,10,15,30]` unchanged. Reused by App Picker, Home,
  and Features — same sheet, different title/initial.
- **States:** editing pre-fills from `initial`; adding defaults to
  direct/5/5 as today.
- **Responsive:** sheet content is scrollable and height-capped to ~90% screen;
  when Timed chips wrap, they wrap (`Wrap`), never overflow. Keyboard not involved
  (chips only), but still `SafeArea`-bottom padded.

---

## 6. Sites (website blocklist)

- **Purpose:** manage blocked domains.
- **Layout:** top row: `AppTextField("e.g. youtube.com")` + `PrimaryButton("Add")`
  → a one-line hint (`textDim`) → the domains list (globe icon · host · delete icon).
- **Flow / data (frozen):** `blockedSitesProvider.addSite/removeSite`; the
  `normalize()` logic is untouched. Enter-to-add kept.
- **States:** empty → `EmptyState("No websites blocked yet")`; duplicate/blank add
  is a no-op (as today) — optionally a subtle snackbar.
- **Responsive:** input row uses `Expanded` for the field so the Add button never
  gets pushed off-screen in landscape or with large text. List scrolls; input
  stays put and keyboard-safe.

---

## 7. Features (Shorts / Reels)

- **Purpose:** toggle & configure the 3 in-app feature blocks.
- **Layout:** one explainer paragraph (`textDim`) → 3 rows, one per feature
  (`YouTube Shorts`, `Instagram Reels`, `Facebook Reels`): icon · label · summary
  subtitle · `AppSwitch`. Row tap → **Config sheet (5)** (direct/timed).
- **Data (frozen):** `featureBlocksProvider`; keys `yt_shorts / ig_reels /
  fb_reels` unchanged; `setEnabled` / `setConfig` unchanged.
- **States:** off feature shows subtitle "Off"; on shows `config.summary`.
- **Responsive:** fixed 3-row list — trivially responsive; just wrap in the scroll
  shell so large text never overflows a row (subtitle wraps to 2 lines).

---

## 8. Account (login + premium) — **new, UI-only**

- **Purpose:** placeholder auth + premium badge, structured so real logic slots
  in later without a redesign (master prompt §G).
- **Layout — signed out:** wordmark → `AppTextField(Username)` →
  `AppTextField(Password, obscured)` → `PrimaryButton("Sign In")` → small
  `SecondaryLink("Support Us")`.
- **Layout — signed in:** `★ PREMIUM ACTIVE` `StateBadge` (emerald) → account name
  → `PrimaryButton`/link `Sign Out`.
- **Logic:** hardcoded `admin` / `admin` unlocks the signed-in view; state held in
  a **new UI-only** Riverpod provider (`accountProvider`) that touches **no**
  native/Hive. No real network. Clearly commented as a stub.
- **States:** wrong credentials → inline error line under the fields (red, ≥14sp bold).
- **Responsive:** form in a scroll view, CTA below fields; keyboard pushes nothing
  off-screen; centered column with max-width clamp on tablets/landscape.

---

## 9. Support Us — **new**

- **Purpose:** a simple "support the project" page (donate / share / rate links).
- **Layout:** short heading (Oswald) → one line of context → a small stack of
  `AppCard` link rows (e.g. "Buy me a coffee", "Share BlockX", "Rate") each
  opening an external URL. Exactly **one** visual primary among them.
- **Logic:** links open externally (`url_launcher` if already a dep, else a
  documented TODO stub — no backend). Content copy is real, not lorem.
- **Responsive:** vertical list in the scroll shell; nothing to overflow.

---

## 10. FAQ — **new**

- **Purpose:** answer the common questions (permissions, why accessibility, why it
  sometimes needs re-enabling, how timers reset, etc.).
- **Layout:** page title → accordion list (`ExpansionTile`-style, restyled): each
  item is a question (Oswald 400) that expands to an answer (Barlow). One open at
  a time is fine. Bottom: "Still stuck?" → `SecondaryLink` to **Ask Us (11)**.
- **Content:** seed 6–8 real Q&As drawn from `../STEP-*` docs (permissions, realme
  Game Space, midnight reset, why a site still loads briefly, etc.).
- **Responsive:** each answer wraps freely; the whole list scrolls; no fixed
  heights (expansion changes height — must be in a scroll view).

---

## 11. Ask Us / Contact — **new**

- **Purpose:** single-CTA contact page.
- **Layout:** big heading `ASK US ANYTHING` → one line of context → one
  `PrimaryButton("Message Us")` opening an external mailto/chat link. Optional
  small `SecondaryLink` to FAQ.
- **Logic:** external link only, no backend, no form submission to a server.
- **Responsive:** centered, single CTA — trivially responsive.

---

## Block screens (native `BlockActivity.kt`) — visual-only restyle {#block-screens}

**Scope reminder:** we edit **only** the tiny view-helpers at the bottom of
`BlockActivity.kt` (`container()`, `text()`, `button()`, `spacer()`, and the
per-mode `buildBlock/buildBackBlock/buildInterstitial` *layout* code). We do
**NOT** touch: `onCreate`, `render`, `onOpenTapped`, `startSession`,
`leaveToHome`, `goBack`, the `CountDownTimer`, the mode/extra constants, or any
call into `BlockRepository`/`AppBlockerService`. All 7 variants come from the
existing mode + `reason` + `feature` inputs — **no new modes**.

**Shared skeleton (all 7):** `dark` bg + one radial red/amber glow → state icon
top-center → headline (Oswald 600 uppercase) → body (Barlow 16sp, `text`) → one
`PrimaryButton` (white label) → optional de-emphasized secondary text link.
Reuse the scan-line + radial-glow motif so it still feels like BlockX. **Never
two equal-weight buttons.**

| Var | Native mode/input | Icon | Accent | Headline | Body | Primary button | Secondary |
|---|---|---|---|---|---|---|---|
| B1 | `MODE_BLOCK`, not feature | lock | red | APP BLOCKED | "This app is off-limits right now." | "Go to Home Screen" | — |
| B2 | `MODE_INTERSTITIAL`, not feature | hourglass | **amber** | IS THIS REALLY NEEDED? | "Opens left today: N" | "Open (5…1)" (counts down, then enabled) | "Go to Home Screen" link |
| B3 | `MODE_BLOCK` + daily-limit `reason` | clock | red | DAILY LIMIT REACHED | "Unlocks again tomorrow." | "Go to Home Screen" | — |
| B4 | `MODE_BACK` | globe-off | red | SITE BLOCKED | "This website is off-limits." | "Go Back" (**never** "Go Home") | — |
| B5 | `MODE_BLOCK` + `feature=true` | play-off | red | REELS/SHORTS BLOCKED | "That's off-limits — the rest of the app is fine." | "Back to Feed" (**never** "Go Home") | — |
| B6 | `MODE_INTERSTITIAL` + `feature=true` | hourglass | amber | IS THIS REALLY NEEDED? | "Opens left today: N" | "Open (5…1)" | "Not now" link |
| B7 | `MODE_BLOCK` + `feature=true` + limit `reason` | clock | red | DAILY LIMIT REACHED | "Resets tomorrow." | "Back to Feed" | — |

**Consistency rules (master prompt §D):** red = a real stop, amber = friction/
reflection — never swapped. Button labels **pure white**. The existing button
label text (e.g. "Go back" vs "Go to home screen" vs "Not now") is driven by the
`isFeature`/`isBackMode` flags already present — keep that wiring, only restyle.

**Font note:** to use Oswald/Bebas in native, either load the bundled `.ttf` via
`Typeface.createFromAsset` in the view-helpers (visual-only, allowed) or fall
back to the system condensed face. Decide during Phase 3; do not add logic.
