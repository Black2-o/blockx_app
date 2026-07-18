# 05 — Task List (build order)

Follow top to bottom. Order is from master prompt §F, adjusted for our two
decisions (dashboard Home, visual-only native block screens). **Do not start
coding until this list is approved.** Each screen task is "done" only after it
passes the [04 §11 test matrix](04-RESPONSIVE-RULES.md#11-test-matrix).

Legend: `[ ]` todo · every task keeps the [frozen backend](README.md) intact.

---

## Phase 0 — Setup (no visual change yet)

- [ ] 0.1 Add font files to `assets/fonts/` (Bebas Neue, Oswald 400 + 600,
      Barlow Condensed 400 + 500) and declare them in `pubspec.yaml` `fonts:`.
- [ ] 0.2 Confirm `flutter_riverpod`, `hive_flutter` deps unchanged; add
      `url_launcher` only if not present (for Support/Ask external links).
- [ ] 0.3 `flutter pub get`, verify the app still builds and runs unchanged.

## Phase 1 — Theme + shared widget library (the foundation)

- [ ] 1.1 `lib/theme/app_colors.dart` — palette tokens (design system §1).
- [ ] 1.2 `lib/theme/app_typography.dart` — named `TextTheme` from the 3 fonts (§2).
- [ ] 1.3 `lib/theme/app_spacing.dart` — spacing/radius scale (§3).
- [ ] 1.4 `lib/theme/app_theme.dart` — `ThemeData` (dark, themed switch/chip/
      button/input) and wire into `MaterialApp` in `main.dart` (keep title +
      ProviderScope overrides).
- [ ] 1.5 `lib/widgets/app_scaffold.dart` — the responsive shell ([04 §3](04-RESPONSIVE-RULES.md)).
- [ ] 1.6 Shared widgets: `PrimaryButton`, `SecondaryLink`, `AppCard`,
      `SectionHeader`, `AppTextField`, `ModeChip`/`StateBadge`, `AppSwitch`,
      `EmptyState`, `HeroNumber`, `AppBottomNav` (design system §4).
- [ ] 1.7 A throwaway "gallery" route to eyeball every widget in light of the
      anti-slop rules (design system §7); delete before ship.

## Phase 2 — Splash

- [ ] 2.1 `splash_screen.dart` — logo scale+fade, wordmark, tagline, radial glow.
- [ ] 2.2 Route: splash → `permissionsProvider` → Onboarding or Home.
- [ ] 2.3 Reduce-motion + orientation + clamp checks.

## Phase 3 — Block screens (native, visual-only) — highest value

- [ ] 3.1 In `BlockActivity.kt`, restyle **only** the view-helpers
      (`container/text/button/spacer`) + `buildBlock/buildBackBlock/
      buildInterstitial` layout to the shared skeleton
      ([03 §Block screens](03-SCREENS-SPEC.md#block-screens)). Logic untouched.
- [ ] 3.2 Apply per-variant icon + accent (red vs amber) + headline/body/button
      for B1–B7, driven by the existing `mode`/`reason`/`isFeature`/`isBackMode`.
- [ ] 3.3 Load bundled font via `Typeface.createFromAsset` (or system condensed
      fallback). Add the radial-glow/scan-line background drawable.
- [ ] 3.4 Manually trigger each of the 7 states on-device and verify wording +
      button behavior unchanged (Open countdown still 5s, Go Back still backs,
      feature buttons still return to feed).

## Phase 4 — Sites (closest to a reference design)

- [ ] 4.1 Restyle `sites_screen.dart` with the shared widgets + `EmptyState`.
- [ ] 4.2 `Expanded` add-row, keyboard-safe, test matrix.

## Phase 5 — Home dashboard + App Picker + Config sheet + Features

- [ ] 5.1 `home_screen.dart` → dashboard hub ([03 §3](03-SCREENS-SPEC.md)):
      header+badge, restyled `PermissionBanner`, apps section, Shorts/Reels
      summary card, Sites summary card, FAB. Single scroll owner ([04 §8](04-RESPONSIVE-RULES.md)).
- [ ] 5.2 Convert `config_dialog.dart` from AlertDialog → modal bottom sheet,
      same `BlockConfig` return contract + same options arrays.
- [ ] 5.3 Restyle `app_picker_screen.dart` (pinned search, restyled rows,
      loading/error/empty states).
- [ ] 5.4 Restyle `features_screen.dart` rows + wire row-tap to the new sheet.
- [ ] 5.5 Test matrix on all four.

## Phase 6 — Bottom nav + new pages

- [ ] 6.1 `AppBottomNav` shell hosting 4 tabs: Home · Sites · FAQ · Account.
      Move Sites from an AppBar icon to a tab; Features reached via Home card.
- [ ] 6.2 `account_screen.dart` + UI-only `accountProvider` (hardcoded admin/admin,
      static premium badge; no native/Hive/network).
- [ ] 6.3 `support_screen.dart` (external links).
- [ ] 6.4 `faq_screen.dart` (accordion, 6–8 real Q&As from STEP docs).
- [ ] 6.5 `ask_screen.dart` (single external-link CTA).

## Phase 7 — Onboarding (lowest visual complexity, last)

- [ ] 7.1 `onboarding_screen.dart` — 4-step flow with progress indicator, wrapping
      the existing permission checks/opens; reuse `permissionsProvider`.
- [ ] 7.2 Wire Splash → Onboarding (perms missing) and re-check on resume.

## Phase 8 — Polish & verify

- [ ] 8.1 Run the full [04 §11 test matrix](04-RESPONSIVE-RULES.md#11-test-matrix)
      across all screens (rotate, small/large, tablet, 1.3× font, keyboard).
- [ ] 8.2 Anti-slop pass (design system §7) — one CTA per screen, real content,
      consistent tokens, no emoji icons, no clip.
- [ ] 8.3 Confirm **zero** behavioral change: block/timer/site/feature flows work
      exactly as before; MethodChannel, Hive boxes, `block_prefs`, and
      `BlockConfig` untouched. Existing tests in `test/` still pass.
- [ ] 8.4 Remove the Phase 1 gallery route.

---

## Guardrails on every task

1. No change to any `.kt` **logic**, `BlockRepository`, `AppBlockerService`,
   `MainActivity`, Hive box names/schemas, `block_prefs` keys, the MethodChannel,
   or `BlockConfig`/`BlockMode` shapes.
2. Only `BlockActivity.kt` view-helpers may change, visually.
3. Every screen goes through `AppScaffold` and passes the responsive test matrix.
4. Reuse the shared widget library — no screen invents its own tokens.
5. Follow the anti-slop rules; one red-fill CTA per screen.
