# BlockX — Project Overview

## What this is

BlockX is a **personal-use Android app** for blocking distracting apps, specific
in-app features (Reels/Shorts), and websites/domains. It is built with Flutter
for UI and native Kotlin for the parts Android requires to be native
(Accessibility Service, VPN Service, Overlay windows, Foreground Service).

## Explicitly NOT a goal

- **Not going on the Play Store.** No policy compliance work needed
  (no need to justify Accessibility/VPN permission usage to Google reviewers).
- Not multi-user, not cloud-synced, not for distribution. Single device,
  single user (you), sideloaded APK.
- Not trying to be bulletproof against a determined attacker uninstalling the
  app — it just needs to be inconvenient enough that casual willpower failure
  doesn't win. (Optional: a PIN/delay on uninstall/settings later, not v1.)

## Core feature tiers (recap)

| Tier | What                                                                                                            | Mechanism                                                                                   |
| ---- | --------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------- |
| 1    | Full app block (Facebook, Instagram, YouTube, any installed app, like i can select and block any app directly.) | AccessibilityService (foreground app detection) + full-screen overlay                       |
| 2    | Sub-feature block (Reels, Shorts) — app usable, feature isn't                                                   | AccessibilityService reading view hierarchy (`AccessibilityNodeInfo`) inside the target app |
| 3    | Domain/website block — permanent, no unlock                                                                     | VpnService + local DNS filtering against a JSON blocklist                                   |

Cutting across all tiers: a **timer/allowance system** per app
(10/20/30 min presets, custom minutes, or 0 = always blocked) with a small
floating countdown bubble shown while a timed app is in foreground.

## App identity

- **Name:** Block X
- **Visual identity:** dark, red-accented, "lockdown/HUD" aesthetic — see
  `01_DESIGN_SYSTEM.md`. Tagline used in the mockup: **"STAY LOCKED IN."**

## Document index

- `01_DESIGN_SYSTEM.md` — colors, type, components, motifs (from existing HTML mockup)
- `02_ARCHITECTURE.md` — Flutter/native split, channels, service map, data model
- `03_TIER1_APP_BLOCK.md` — full app blocking spec
- `04_TIER2_SUBFEATURE_BLOCK.md` — Reels/Shorts blocking spec
- `05_TIER3_DOMAIN_BLOCK.md` — DNS/domain blocking spec
- `06_TIMER_SYSTEM.md` — allowance engine + floating bubble spec
- `07_TECH_STACK_AND_PACKAGES.md` — Flutter packages, native deps, permissions
- `08_BUILD_ORDER.md` — the order Claude Code should implement things in, milestone by milestone
- `10_APP_NAVIGATION_AND_PAGES.md` — This is for App navigation and pages how many page and others

Each file is meant to be dropped into a Claude Code session (or referenced
via `@filename`) as ground truth for that part of the build.
