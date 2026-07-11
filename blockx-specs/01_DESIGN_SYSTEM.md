# BlockX — Design System

Extracted from the existing HTML mockup (popup-style block-list screen).
This is the source of truth for theming the Flutter app — replicate these
tokens as a Flutter `ThemeData` / `ThemeExtension`, not just "similar-ish" colors.

## Identity
- **Name lockup:** "BLOCKX" (no space), subtitle "STAY LOCKED IN" in the header.
- **Logo mark:** square icon, 24–32px, currently a raster image
  (`Block-x.png`) — replace with a proper vector asset later, but keep the
  same slot/sizing.
- **Mood:** lockdown / HUD / lock-screen-of-a-vault. Not playful. Red = alert/restriction.

## Color tokens

```
red        #E8000D   -- primary accent, CTAs, alerts, active states
red-dim    rgba(232,0,13,0.25)  -- badges, subtle fills
red-glow   rgba(232,0,13,0.35)  -- box-shadow glows on buttons/dots
dark       #080808   -- app background
dark2      #111111   -- secondary background
dark3      #161010   -- input/field background (slightly red-tinted black)
surface    rgba(255,255,255,0.04)  -- card/list-item background
border     rgba(255,255,255,0.08)  -- default hairline borders
border-red rgba(232,0,13,0.3)      -- accented borders (focused/hover/active)
text       #F0E0E0   -- primary text (warm off-white, not pure white)
text-dim   rgba(240,200,200,0.5)   -- secondary/label text (warm dim)
```

In Flutter, define these as a `ThemeExtension<BlockXColors>` so widgets pull
`Theme.of(context).extension<BlockXColors>()` rather than hardcoding hex.

## Typography
- **Display / numerals / logo:** `Bebas Neue` — used for the logo wordmark,
  countdown numbers, big stat values, buttons. Always uppercase, wide
  letter-spacing (~0.1–0.15em).
- **Body / UI text:** `Barlow Condensed` — weights 300/400/600/700. Used for
  inputs, list items, labels.
- Labels (e.g. "ADD SITE TO BLOCK", "BLOCKED SITES") are always:
  - uppercase
  - small (0.65–0.75rem equivalent, ~11–13sp in Flutter)
  - heavy letter-spacing (0.15–0.2em)
  - `text-dim` color

Flutter font setup: bundle both fonts via `google_fonts` package (fastest) or
as local assets in `pubspec.yaml` if you want offline-first / no network font
fetch (recommended since Google Fonts package hits network on first load).

## Motifs (carry these into the Flutter build)
1. **Scan-line overlay** — a very faint repeating horizontal line pattern
   over the whole screen (`opacity ~0.12`, 3–4px repeat). Purely
   decorative, gives the HUD feel. Implement as a `CustomPainter` overlay or
   a semi-transparent repeating gradient `Container` on top of the stack.
2. **Radial red glow** behind the header, top-center, bleeding downward —
   `RadialGradient` in a positioned `Container` behind content, low opacity.
3. **Blinking status dot** — small circle, red, `opacity 1↔0` loop (~1.4s
   step), paired with uppercase text ("ACTIVE") inside a pill-shaped
   container with a red-tinted border. Use for "protection is running" state.
4. **Glow shadows on interactive elements** — buttons and active dots get a
   soft red `boxShadow` (blur ~14–22, spread 0, color `red-glow`).
5. **4px border radius everywhere** — inputs, buttons, list items, badges.
   Consistent small-radius look, not pill-shaped except the status indicator
   and count badge.
6. **Uppercase count/stat badges** — e.g. "0 BLOCKED" — small pill/rect with
   `red-dim` fill, `border-red` border, `red` text, Bebas Neue.

## Core components to build in Flutter (reusable widgets)

| Component | Notes |
|---|---|
| `BlockXHeader` | logo + wordmark + subtitle left, count badge right |
| `BlockXTextField` | dark3 fill, hairline border, red border + glow on focus |
| `BlockXPrimaryButton` | red fill, Bebas Neue label, glow shadow, slight lift on hover/press |
| `BlockXSectionHeader` | uppercase label + fading gradient line |
| `BlockXListItem` | surface bg, hairline border → red border on hover, left dot + label, right icon/remove button |
| `BlockXEmptyState` | centered icon + dim uppercase message, 2-line |
| `BlockXStatPill` | label above, Bebas Neue value below (footer stats) |
| `BlockXStatusPill` | blinking dot + "ACTIVE"/"PAUSED" text |
| `ScanlineOverlay` | full-screen decorative overlay, IgnorePointer |

## Screens implied by the mockup (extend this pattern app-wide)
- The uploaded HTML is essentially the **"Blocked Sites" (Tier 3 domain
  list) screen**. Reuse the exact same shell (header, input row, section
  head, scrollable list, footer stat/status) for:
  - **Blocked Apps** screen (Tier 1) — list item shows app icon instead of a
    dot, plus a mode chip (Blocked / Timed / Unlimited).
  - **Sub-feature toggles** screen (Tier 2) — simpler: a list of
    apps-with-a-sub-feature-block-option, each with a toggle switch instead
    of add/remove.
  - **Timer config** screen (Tier 6) — per-app row with preset chips
    (10/20/30/Custom/0) instead of a plain list.
- Keep the same header/footer chrome across all screens for consistency —
  navigate via bottom nav or a simple side drawer, not by replacing the
  whole shell.

## Non-negotiables when Claude Code implements this
- Don't substitute default Material red/black theme — use the exact tokens
  above.
- Keep the condensed, uppercase, wide-letter-spacing typographic voice
  consistent across every screen, not just the one mockup.
- Keep corner radii at 4px (not Material's default 8–12) to preserve the
  "tactical HUD" feel.
