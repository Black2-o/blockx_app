# Build Order

Recommended sequence for Claude Code sessions. Each milestone should be
independently testable on-device before moving to the next — don't stack
untested native services.

## Milestone 0 — Project scaffold
- Flutter project init, package name/applicationId decided
  (e.g. `com.yourname.blockx`).
- Wire up design system: theme tokens, fonts as local assets, the reusable
  widget set from `01_DESIGN_SYSTEM.md`.
- Build the **Blocked Sites screen** as a static UI first (matches the
  uploaded mockup, local-state only, no native calls yet) — cheapest way to
  validate the design system port before touching any native code.

## Milestone 1 — Tier 3: Domain blocking
Doing this first, ahead of Tier 1/2, because it's the most mechanically
self-contained (no Accessibility complexity) and validates the
Flutter↔native MethodChannel bridge early.
- `DomainVpnService` + `DnsProxy` + `BlocklistStore`.
- Wire the already-built Blocked Sites screen to real
  `addDomain`/`removeDomain`/VPN status via MethodChannel.
- Test: add a real domain, confirm it fails to resolve in a browser; remove
  it, confirm it resolves again.

## Milestone 2 — Tier 1: Full app blocking
- `BlockAccessibilityService` (foreground app detection only, no node
  scanning yet) + `BlockOverlayService`.
- Build the Blocked Apps screen (app picker via `device_apps`, list with
  mode chips — Blocked/Unlimited only for now, Timed comes in Milestone 3).
- Test: block Instagram, confirm overlay appears within ~1s of opening it
  and can't be dismissed via back/recents.

## Milestone 3 — Timer system
- `TimerForegroundService`, allowance persistence, midnight reset logic.
- `TimerBubbleService` floating countdown widget.
- Extend Blocked Apps screen with Timed mode + preset/custom chips + usage
  readout.
- Test: set a 1-minute limit on a test app to quickly verify expiry →
  overlay transition without waiting a full 10–30 min cycle.

## Milestone 4 — Boot persistence & robustness
- `BootReceiver`, battery optimization exemption prompt in onboarding,
  accessibility/overlay/vpn permission status checks surfaced in-app.
- Test: reboot device, confirm blocking resumes without opening the Flutter
  app manually.

## Milestone 5 — Tier 2: Sub-feature blocking (Reels/Shorts)
Deliberately last — most fragile, most likely to need rework, best done
once the rest of the app (and your patience for native debugging) is warmed
up.
- Manually inspect Instagram/YouTube/Facebook via Layout Inspector to get
  current resource-ids, populate `subfeature_matchers.json`.
- Extend `BlockAccessibilityService` with node-tree scanning for watched
  packages.
- Build the Sub-Feature screen (toggle-per-app, per `04_TIER2...`).
- Test: scroll into Reels/Shorts in each app, confirm auto-back behavior;
  use the rest of each app normally to check for false positives.

## Milestone 6 (optional, later) — Stats & polish
- Usage history/logging (domain-block hits, time saved), `fl_chart`
  dashboard.
- Bubble drag-to-edge polish, "+5 min" quick-add affordance.
- Uninstall-friction / settings-PIN if you decide you want it.

## What NOT to parallelize
Don't build Tier 2 and Tier 3 at the same time even though they're
independent — they both touch `BlockAccessibilityService`/native service
lifecycle debugging, and getting Tier 1 rock-solid first makes Tier 2's
extension much easier to reason about when something breaks.
