# BlockX — UI/UX Master Prompt (research-backed, final)

This replaces `BLOCKX_UI_REDESIGN_PROMPT.md`. Same rule as before: **functionality is
frozen** — no changes to `.kt` files, `BlockRepository`, Hive boxes, or the
MethodChannel. This file is UI/UX only, but goes deeper: real contrast math, named
UX laws, wireframes before polish, an exact font decision, the full screen count,
a splash screen, and a dedicated spec for every block-screen variant the app
actually has.

---

## PART A — Research: what I checked, and what I found wrong

### A.1 Color contrast — actual numbers (WCAG 2.1)

I computed real contrast ratios instead of assuming the palette was accessible.
Two things in the original palette fail WCAG AA:

| Pair | Ratio | AA normal text (4.5:1) | AA large text/UI (3:1) |
|---|---|---|---|
| Red `#E8000D` text on dark bg `#080808` | **4.23:1** | ❌ fails | ✅ passes |
| Off-white `#F0E0E0` text on red `#E8000D` button | **3.71:1** | ❌ fails | ✅ passes |
| Dark `#080808` text on red button | 4.23:1 | ❌ fails | ✅ passes |
| **White `#FFFFFF` text on red button** | **4.73:1** | ✅ passes | ✅ passes |
| Off-white text on dark bg `#080808` | 15.68:1 | ✅ | ✅ |
| Off-white on card surface `#161010` | 14.74:1 | ✅ | ✅ |
| Amber `#FFB020` on dark bg | 10.95:1 | ✅ | ✅ |
| Emerald `#34D399` on dark bg | 10.42:1 | ✅ | ✅ |

**Fixes applied below:**
- Red is now **never used as small body text**. It's reserved for: icons, borders,
  glows, badges/pills at ≥14sp bold or ≥18sp regular ("large text" AA threshold),
  and button *fills* — not button *text on red fills*.
- Button labels on a red fill must be **pure white `#FFFFFF`**, not the warm
  off-white — the off-white fails AA on red, pure white passes.

### A.2 A second problem: pure black + a condensed font hurts legibility at small sizes

Two brand choices compound each other:
1. `#080808` is near-pure-black. Material Design's own dark-theme guidance
   recommends **~`#121212`, not pure black**, because pure black next to bright
   text causes visible "halation" (glow/blur) on OLED and some LCD panels,
   especially at night.
2. Condensed typefaces (Barlow Condensed) have a **smaller x-height** than
   regular-width fonts at the same point size, which makes small body text
   *feel* smaller than it measures.

**Fix:** Keep `#080808` only as the outermost app background (it's core to the
brand, not worth abandoning) — but make sure every surface that holds body text
sits on `dark2`/`dark3`, never directly on pure black, and set a **14sp floor**
for any Barlow Condensed body text (no 11–12sp labels anywhere, even though the
original mockup used ~11sp for some labels — bump those up).

### A.3 A third problem: one typeface, no weight range

Bebas Neue ships in a **single weight** — no bold, no light. That's fine for a
logo or a splash screen, but it means you can't create emphasis hierarchy (e.g.
"this stat matters more than that one") using the same face. Using Bebas Neue for
*every* heading everywhere in the original prompt flattens hierarchy.

**Fix:** Bebas Neue is now reserved for **hero moments only** — the logo
wordmark, the splash screen, and headline numbers (timer countdowns, stat
values). For section headers, page titles, and anywhere you need more than one
weight, use **Oswald** instead — same tall/condensed/geometric family feel (it's
practically a cousin of Bebas Neue), but ships in weights 200–700, so you get
actual hierarchy without breaking the visual voice. See §B for the full spec.

### A.4 A fourth problem: color-only state signaling

The original plan implied mode chips (Blocked/Timed/Unlimited) would be
distinguished mainly by color. **~8% of men have some form of red-green color
vision deficiency** — color alone is not a reliable signal.

**Fix:** every state (blocked/timed/unlimited/active/inactive) is always paired
with an **icon + text label**, never color alone. Color reinforces, it doesn't
carry the meaning by itself.

### A.5 UX laws applied, by name

| Law | Where it's applied |
|---|---|
| **Fitts's Law** (bigger/closer targets are faster to hit) | Primary actions (Add, Open, Go Back) are large (min 48×48dp), bottom-nav sits in the thumb zone, the block-screen's single action button is oversized and centered |
| **Hick's Law** (more choices = slower decisions) | Bottom nav capped at 4 tabs; block-screen shows exactly **one** primary action, never two competing CTAs |
| **Jakob's Law** (users expect familiar patterns) | Standard bottom nav, standard back-gesture behavior, standard iOS/Android switch and chip conventions — don't reinvent basic controls even in a stylized skin |
| **Miller's Law / chunking** | Settings and config screens group related controls into visually distinct cards, never a flat unbroken list |
| **Aesthetic-Usability Effect** (polished UI is *perceived* as more usable/trustworthy) | Directly justifies investing in the HUD/premium visual language at all — this is the whole point of this redesign pass |
| **Von Restorff Effect / isolation** (the item that looks different gets noticed) | Exactly one red-filled button per screen — if everything is red-glowing, nothing stands out |
| **Doherty Threshold** (respond within ~400ms or perceived responsiveness drops) | Matches the existing native behavior (block screen shows in ~1s); UI transitions/animations kept to 150–300ms so the *interface* doesn't feel slower than the *engine* |
| **Peak-End Rule** (people remember the peak moment and the ending of an experience) | The block screen itself IS the peak moment of this app — see Part D, it gets the most design attention of any screen, more than Settings ever will |
| **Zeigarnik Effect** (incomplete tasks stick in memory / drive completion) | Onboarding shows a visible step progress (1 of 4, 2 of 4…) so an unfinished permission grant nags the user back to finish it |

---

## PART B — Typography, final decision

| Role | Font | Weight | Notes |
|---|---|---|---|
| Logo wordmark, splash screen, hero numbers (timer countdowns, big stats) | **Bebas Neue** | Regular (only weight available) | uppercase, letter-spacing 0.12em |
| Page titles, section headers, card titles | **Oswald** | 600 (SemiBold) | uppercase, letter-spacing 0.08em — same tall/condensed family feel as Bebas Neue, but gives you a real weight range |
| Sub-headers, labels, emphasis body text | **Oswald** | 400 | |
| Body copy, list items, descriptions, input text | **Barlow Condensed** | 400 (500 for emphasis inline) | minimum 14sp anywhere it appears |
| Buttons | **Oswald** | 600 | uppercase — more legible at small button sizes than Bebas Neue |

Both Oswald and Barlow Condensed are free, open-source Google Fonts, same
licensing situation as Bebas Neue — bundle all three as local font assets in
`pubspec.yaml`, don't fetch via the `google_fonts` package at runtime.

---

## PART C — Full screen inventory (wireframe-first)

15 screens total. Each gets a rough wireframe below before any visual polish —
build the layout skeleton first, then apply Part B/E styling on top of a layout
that's already proven to work.

### C.1 Screen list

| # | Screen | New or existing |
|---|---|---|
| 1 | Splash | **new** |
| 2 | Onboarding — Permissions (4 steps) | existing, restyle |
| 3 | Home (Blocked Apps) | existing, restyle |
| 4 | App Picker | existing, restyle |
| 5 | Timer / Rule Config (sheet) | existing, restyle |
| 6 | Sites (website blocklist) | existing, restyle |
| 7 | Features (Shorts/Reels toggles) | existing, restyle |
| 8 | Account (login + premium status) | new |
| 9 | Support Us | new |
| 10 | FAQ | new |
| 11 | Ask Us / Contact | new |
| 12–15 | **Block screens** — 4 distinct native states, each needs its own visual treatment | existing (native `BlockActivity`), restyle — see Part D |

### C.2 Wireframes (low-fidelity, layout only)

**Splash**
```
┌───────────────────┐
│                    │
│                    │
│     [ LOGO ]       │   <- centered, scale+fade in ~600ms
│     BLOCKX         │   <- Bebas Neue, appears after logo
│  STAY LOCKED IN     │   <- fades in last
│                    │
│                    │
└───────────────────┘
```

**Home**
```
┌───────────────────┐
│ [logo] BLOCKX  [N] │  <- header, count badge
│ ⚠ Permission banner│  <- only if something's missing
├───────────────────┤
│ [icon] App A   [●]│  <- row: icon, name, mode chip, switch
│ [icon] App B   [●]│
│ [icon] App C   [●]│
│        ...         │
├───────────────────┤
│        [+]         │  <- FAB, bottom-right, thumb zone
├───────────────────┤
│ Apps Sites FAQ Acct │  <- bottom nav, 4 tabs
└───────────────────┘
```

**Timer Config (bottom sheet)**
```
┌───────────────────┐
│  ▬▬ (drag handle)  │
│  App Name          │
│  [Blocked][Timed][Unlim]│  <- mode chips
│  10 / 20 / 30 / Custom │  <- only shown if Timed
│  Today: 4/20 min used  │
│  [ Save ]  [ Cancel ]  │
└───────────────────┘
```

**Account**
```
┌───────────────────┐
│  BLOCKX             │
├───────────────────┤
│  [ Username field ] │
│  [ Password field ] │
│  [ Sign In ]         │
├───────────────────┤
│  (after sign-in:)    │
│  ★ PREMIUM ACTIVE    │  <- static badge for now
│  [ Sign Out ]         │
└───────────────────┘
```

**FAQ**
```
┌───────────────────┐
│  FAQ                │
├───────────────────┤
│  ▸ Question 1        │  <- accordion, tap to expand
│  ▾ Question 2        │
│    Answer text here…  │
│  ▸ Question 3        │
└───────────────────┘
```

**Ask Us / Contact**
```
┌───────────────────┐
│  ASK US ANYTHING     │
│  One line of context  │
│  [ Message Us → ]     │  <- big single CTA, external link
└───────────────────┘
```

Sites, Features, App Picker, and Onboarding keep the layouts already specced in
the previous prompt (`BLOCKX_UI_REDESIGN_PROMPT.md` §4) — those wireframes
already matched the working app well; no change needed there.

---

## PART D — Block screens, one spec per actual native state

This is the **peak-moment screen** (Peak-End Rule, §A.5) — it deserves more
craft than any settings page, because it's the screen the user sees most often
and the one moment the whole app exists to deliver. The native code already
distinguishes these exact states (`BlockActivity` modes) — give each a distinct
but *consistent-family* visual so the user instantly reads *why* they're
blocked without reading the copy.

| # | State (native mode) | Trigger | Icon | Accent color | Headline | Body copy | Button |
|---|---|---|---|---|---|---|---|
| 1 | Direct app block (`MODE_BLOCK`) | app is on Blocked mode | 🚫 lock icon | Red | "APP BLOCKED" | "[App name] is off-limits right now." | "Go to Home Screen" (white text on red fill) |
| 2 | Timed app — interstitial (`MODE_INTERSTITIAL`) | opens remain, about to spend one | ⏳ hourglass icon | **Amber**, not red — this is friction, not a hard stop | "IS THIS REALLY NEEDED?" | "Opens left today: N" | "Open (5…1)" — disabled/counting down, then enabled; secondary "Go to Home Screen" text-link below, de-emphasized |
| 3 | Timed app — quota exhausted (`MODE_BLOCK` w/ daily-limit reason) | opens used up | 🕛 clock icon | Red | "DAILY LIMIT REACHED" | "[App name] unlocks again tomorrow." | "Go to Home Screen" |
| 4 | Website block (`MODE_BACK`) | blocked domain visited | 🌐 crossed-out globe | Red | "SITE BLOCKED" | "This website is off-limits." | "Go Back" (returns to browser, not phone home — copy must say "Go Back", never "Go Home" here, that's the whole point of MODE_BACK) |
| 5 | Feature block — direct (Reels/Shorts, `feature=true`) | Shorts/Reels detected, feature is Blocked mode | 🎬 crossed-out play icon | Red | "[Reels/Shorts] BLOCKED" | "That's off-limits — the rest of [app] is fine." | "Back to Feed" (never "Go Home" — stays in-app, see STEP-4 in your build docs) |
| 6 | Feature — interstitial (timed) | opens remain | ⏳ hourglass | Amber | "IS THIS REALLY NEEDED?" | "Opens left today: N" | "Open (5…1)" + secondary "Back to Feed" |
| 7 | Feature — quota exhausted | opens used up | 🕛 clock | Red | "DAILY LIMIT REACHED" | "Resets tomorrow." | "Back to Feed" |

**Consistency rules across all 7:**
- Same layout skeleton every time: icon top-center → headline (Oswald 600,
  uppercase) → body copy (Barlow Condensed, 16sp, off-white) → one primary
  button, one optional de-emphasized secondary link.
- **Never two buttons of equal visual weight** (Hick's Law + Von Restorff) — a
  secondary action is always a plain text link, not a second filled button.
  This also matches the real behavior: the app already treats "Go to Home
  Screen" during an interstitial as the *less* wanted path.
- Red = a real stop. Amber = a moment of friction/reflection, not a stop. Don't
  let these two ever swap meaning across screens — that consistency is what
  lets the user read state at a glance (Jakob's Law: once they learn "amber =
  I still have a choice," it must hold everywhere).
- Reuse the scan-line + radial-glow motif from the base design system so the
  block screen still feels like *the same app*, not a jarring switch to a
  different visual style.
- Button label text is **pure white**, per the contrast fix in §A.1 — not the
  warm off-white used elsewhere.

---

## PART E — Final palette (corrected) and component rules

```
red        #E8000D   -- borders, icons, glows, badges (≥14sp bold), button FILLS
amber      #FFB020   -- friction/interstitial states only — never used for a hard block
emerald    #34D399   -- "unlimited/allowed" state indicator only, used sparingly
dark       #080808   -- outermost app background only
dark2      #111111   -- primary surface (cards, sheets sit here, never on pure dark)
dark3      #161010   -- input fields
surface    rgba(255,255,255,0.04)
border     rgba(255,255,255,0.08)
border-red rgba(232,0,13,0.3)
text       #F0E0E0   -- default text color, 14sp floor
text-dim   rgba(240,200,200,0.5)
white      #FFFFFF   -- REQUIRED for any text sitting on a solid red/amber fill (contrast fix, §A.1)
```

Component rules (supersedes the checklist in the previous prompt where they
conflict):
- Red is never small body/label text on a dark background — 14sp+ bold or
  18sp+ regular only, per §A.1.
- Any button with a solid red or amber fill uses **white** label text, never
  the warm off-white.
- Every mode/state indicator (Blocked/Timed/Unlimited, Active/Inactive) pairs
  an icon + text label with its color — never color alone (§A.4).
- Default Material `Switch` colors, `ChoiceChip` styling, and `ElevatedButton`
  theming must not appear anywhere unstyled.
- All screen transitions and micro-interactions: 150–300ms (Doherty Threshold,
  §A.5) — nothing longer, this app's whole value prop is speed.

---

## PART F — Build order

1. Theme layer: corrected palette (Part E), three fonts (Part B), shared
   widget library (buttons, inputs, cards, switches, chips, badges,
   empty-states, the icon+text state-indicator pattern).
2. **Splash screen** — cheapest, most isolated, good first proof of the visual
   language (logo, wordmark, tagline, motion per the C.2 wireframe).
3. **Block screens (all 7 variants, Part D)** — highest-value screen in the
   whole app per the Peak-End Rule; do this early while attention is fresh,
   not last.
4. Sites screen (closest to an existing reference design).
5. Home, App Picker, Timer Config, Features — same shared widgets, different
   data.
6. Account, Support Us, FAQ, Ask Us — new pages, same widget library.
7. Onboarding — lowest visual complexity, finish once the widget library is
   proven everywhere else.

## PART G — Explicit non-goals (unchanged)
No changes to `BlockConfig`, `BlockRepository`, any `.kt` file, Hive box
names/schemas, `block_prefs` keys, detection logic, or timer logic. No real
authentication or payment integration — Account page is UI + hardcoded
admin/admin + a static premium badge only, structured so real logic can slot
in later without a visual redesign.
