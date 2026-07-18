# 01 — Design System

The single source of truth for every visual token and shared widget. Build this
layer **first** (Task Phase 1). Every screen is assembled from these; no screen
invents its own colors, fonts, or spacing.

---

## 1. Palette (from master prompt §E — corrected, WCAG-checked)

Define once in `lib/theme/app_colors.dart` as `const Color` values. Never write a
raw hex anywhere else.

| Token | Hex / value | Only used for |
|---|---|---|
| `red` | `#E8000D` | borders, icons, glows, badges (≥14sp bold), **button fills** — never small body text |
| `amber` | `#FFB020` | friction / interstitial state only — **never** a hard block |
| `emerald` | `#34D399` | "unlimited / allowed" indicator only, sparingly |
| `dark` | `#080808` | outermost app background **only** |
| `dark2` | `#111111` | primary surface — cards, sheets, bottom nav |
| `dark3` | `#161010` | input fields |
| `surface` | `rgba(255,255,255,0.04)` | subtle raised fills, dividers-as-fills |
| `border` | `rgba(255,255,255,0.08)` | default hairline borders |
| `borderRed` | `rgba(232,0,13,0.30)` | red-glowing card/border accents |
| `text` | `#F0E0E0` | default text — **14sp floor** |
| `textDim` | `rgba(240,200,200,0.5)` | secondary text, hints, captions |
| `white` | `#FFFFFF` | **required** for any text on a solid red/amber fill |

**Hard contrast rules (do not violate — these are the AA failures we're fixing):**
- Red is **never** small body/label text on dark. Red text only at **≥14sp bold**
  or **≥18sp regular**.
- Any button with a **red or amber fill** uses **pure white** label text — never
  the warm `text` off-white.
- Body text never sits directly on `dark` (`#080808`); it sits on `dark2`/`dark3`
  surfaces (halation fix).

---

## 2. Typography (from master prompt §B) — three bundled fonts

Bundle the `.ttf` files locally under `assets/fonts/` and declare them in
`pubspec.yaml`. **Do not** use the `google_fonts` package (no runtime fetch).

| Role | Font | Weight | Style |
|---|---|---|---|
| Logo wordmark, splash, hero numbers (countdowns, big stats) | **Bebas Neue** | Regular (only weight) | uppercase, letter-spacing 0.12em |
| Page titles, section headers, card titles | **Oswald** | 600 | uppercase, letter-spacing 0.08em |
| Sub-headers, labels, emphasis body | **Oswald** | 400 | |
| Body, list items, descriptions, input text | **Barlow Condensed** | 400 (500 emphasis) | **min 14sp everywhere** |
| Buttons | **Oswald** | 600 | uppercase |

Font files needed (Google Fonts, OFL-licensed):
`BebasNeue-Regular.ttf`, `Oswald-Regular.ttf` (400), `Oswald-SemiBold.ttf` (600),
`BarlowCondensed-Regular.ttf` (400), `BarlowCondensed-Medium.ttf` (500).

Expose as a `TextTheme` in `lib/theme/app_typography.dart` with named styles:
`hero`, `titleL`, `title`, `sectionHeader`, `label`, `body`, `bodyDim`, `button`.
Screens reference `context.textTheme.title` etc. — never a raw `TextStyle`.

---

## 3. Spacing, radius, elevation

One 4px-based scale in `lib/theme/app_spacing.dart`. No magic numbers in screens.

- Space scale: `xs 4 · sm 8 · md 12 · lg 16 · xl 24 · xxl 32 · xxxl 48`
- Screen edge padding: **16** (`lg`). Card inner padding: **16**.
- Corner radius: `sm 8` (chips, inputs) · `md 12` (cards) · `lg 20` (sheets top).
- Min tap target: **48×48dp** everywhere (Fitts's Law). Icon buttons included.
- Elevation is expressed by **surface color + hairline border**, not Material
  shadows (dark theme reads shadow poorly). A raised card = `dark2` + `border`.

---

## 4. Shared widget library (`lib/widgets/`)

Every screen is built from these. Build + visually proof them once (Phase 1),
then reuse. This is what prevents both AI-slop inconsistency **and** the
per-screen responsive breakage.

| Widget | Purpose | Key rules |
|---|---|---|
| `PrimaryButton` | the one red-fill CTA per screen | white label, Oswald 600, 48dp min height, full-width by default, 150ms press feedback |
| `SecondaryLink` | de-emphasized secondary action | plain text link (no fill), never competes with `PrimaryButton` |
| `AppCard` | the standard surface container | `dark2` fill, `border` hairline, radius 12, 16 padding |
| `SectionHeader` | titled group header | Oswald 600 uppercase + optional trailing action |
| `AppTextField` | all text inputs | `dark3` fill, `border`, red focus ring, 48dp height |
| `ModeChip` / `StateBadge` | Blocked / Timed / Unlimited / Active | **always icon + text label + color** — never color alone (§A.4) |
| `AppSwitch` | on/off toggle | themed (red active track) — no default Material switch |
| `EmptyState` | "nothing here yet" | icon + line + optional CTA; used by every list |
| `PermissionBanner` | setup-needed card | restyled version of the current banner, per-permission rows |
| `AppScaffold` | the responsive page shell | wraps `SafeArea` + scroll + max-width clamp (see [04](04-RESPONSIVE-RULES.md)) |
| `AppBottomNav` | the 4-tab nav | `dark2`, thumb-zone, icon + label per tab |
| `HeroNumber` | big countdown / stat | Bebas Neue, tabular figures |

Every list row (apps, sites, features) shares one row anatomy: leading icon →
title (Oswald 400) → subtitle/`ModeChip` (Barlow) → trailing `AppSwitch`.

---

## 5. Motion (from master prompt §A.5 / §E)

- All transitions and micro-interactions: **150–300ms** — nothing longer.
- Splash: logo scale+fade ~600ms (the one exception, it's a first-run moment).
- Page transitions: a quick fade/slide, 200ms. Chip/switch state: 150ms.
- Respect "reduce motion": if `MediaQuery.disableAnimations`, drop to instant.

---

## 6. Iconography

- One icon set (Material `Icons` outlined variants) for a consistent stroke.
- Each block/state gets a **fixed, meaningful** icon (never swapped between
  screens): direct block = lock, interstitial = hourglass, quota = clock,
  website = globe-off, feature = movie/play-off, allowed/unlimited = check-circle.
- Icons that carry state always sit next to a text label (§A.4).

---

## 7. Anti-AI-slop rules — what NOT to do

This app must not look machine-generated. Concrete bans:

**Don't:**
- ❌ Use purple/indigo gradients, glassmorphism blur cards, or the generic
  "SaaS dashboard" look. BlockX is a dark, red, tactical/HUD identity — commit to it.
- ❌ Put a gradient on everything. One radial red glow motif, used with restraint
  (block screen + splash + maybe home header). Not on every card.
- ❌ Center-align long paragraphs of body text. Only hero moments (splash, block
  screens, empty states) center text; lists and settings are left-aligned.
- ❌ Emoji as UI icons. Use the real icon set. (The master prompt's 🚫/⏳ etc. are
  *shorthand for the spec*, not literal glyphs to ship.)
- ❌ Two competing filled buttons on one screen (Von Restorff / Hick's Law) —
  exactly **one** red-fill CTA per screen; everything else is a text link or chip.
- ❌ Rainbow of accent colors. Red = stop, amber = friction, emerald = allowed.
  Three meanings, never mixed or swapped.
- ❌ Fake data, lorem ipsum, or placeholder stat cards with invented numbers.
  Every number shown is real (opens left, minutes, counts) or the widget isn't there.
- ❌ Inconsistent corner radii / paddings / font sizes per screen. Tokens only.
- ❌ Tiny 10–12sp labels. **14sp floor**, always.
- ❌ Decorative illustrations that add nothing. Empty states get one simple icon,
  not a stock illustration.
- ❌ Over-animation. No bouncing, no long springs, no parallax. 150–300ms, done.

**Do:**
- ✅ One clear visual hierarchy per screen: one title, one primary action.
- ✅ Real content filling the space (dashboard Home) instead of empty padding.
- ✅ Consistent row/card anatomy so the app feels like one product.
- ✅ Icon + text + color for every state, always.
- ✅ Generous but consistent spacing from the scale — breathing room, not
  emptiness, and never cramped.

---

## 8. Theme wiring

- Replace the bare `MaterialApp` in `lib/main.dart` with a `ThemeData` built from
  the tokens above: `ThemeMode.dark`, `scaffoldBackgroundColor: dark`,
  themed `switchTheme`, `chipTheme`, `elevatedButtonTheme`, `inputDecorationTheme`,
  `textTheme`. No screen should rely on default Material styling (master prompt §E).
- Keep `MaterialApp.title: 'BlockX'` and the existing `ProviderScope` overrides in
  `main()` — those touch the frozen store wiring; leave them intact.
