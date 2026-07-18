# BlockX — UI/UX Redesign Plan (index)

This folder is the **complete plan** for the BlockX visual redesign. It turns the
research in [`../BLOCKX_UIUX_MASTER_PROMPT.md`](../BLOCKX_UIUX_MASTER_PROMPT.md)
into a buildable spec: every screen, every shared widget, the exact rules that
keep it from looking like AI slop, and the responsive rules that fix the
rotate/scroll/overflow breakage from the previous attempt.

> **Read order:** this file → 01 → 02 → 03 → 04 → 05. Nothing gets coded until
> the task list in **05** is approved.

## The files

| File | What it defines |
|---|---|
| [01-DESIGN-SYSTEM.md](01-DESIGN-SYSTEM.md) | Palette, fonts, spacing scale, the shared widget library, motion, iconography, and the **anti-AI-slop rules** (what NOT to do). |
| [02-SCREEN-INVENTORY.md](02-SCREEN-INVENTORY.md) | Every screen that exists, the navigation map, and the new **dashboard Home** + 4-tab bottom nav structure. |
| [03-SCREENS-SPEC.md](03-SCREENS-SPEC.md) | Full per-screen spec: layout, content, states (empty/loading/error), and exact widgets — for all 15 screens + the 7 block-screen variants. |
| [04-RESPONSIVE-RULES.md](04-RESPONSIVE-RULES.md) | The rules that fix rotation, small-screen, large-text, and scroll-overflow breakage. **This is the section that solves the "it breaks everywhere" problem.** |
| [05-TASK-LIST.md](05-TASK-LIST.md) | The phased, checkable build order. Follow this top to bottom when coding. |

## Two decisions already locked (2026-07-18)

1. **Block screens** (`BlockActivity.kt`) — **visual-only native edits allowed.**
   We may edit the *view-builder / styling* helpers in `BlockActivity.kt`
   (colors, fonts, spacing, layout skeleton) to deliver the Part D redesign.
   We may **NOT** touch any blocking logic, mode handling, countdown, session,
   repository, or MethodChannel there. See [03 §Block screens](03-SCREENS-SPEC.md#block-screens).
2. **Home = dashboard hub.** Home surfaces *all* features (apps list + Sites
   summary + Shorts/Reels summary), filling white space with real content, not
   just the apps list. Full management pages still live behind the bottom nav.

## The frozen backend (never change — verified against the current code)

The redesign is **UI only**. These are confirmed by reading the code and must
stay byte-identical in behavior:

- **No `.kt` logic.** `AppBlockerService.kt`, `BlockRepository.kt`,
  `BuiltInBlocklist.kt`, `MainActivity.kt` — untouched. `BlockActivity.kt` —
  **visual helpers only**, logic frozen.
- **The one MethodChannel** `com.blockx.app/blocker` and every method on it
  (`getInstalledApps`, `setConfigs`, `setBlockedSites`, `setFeatureBlocks`,
  `isAccessibilityEnabled`, `openAccessibilitySettings`, `canDrawOverlays`,
  `openOverlaySettings`, `hasUsageAccess`, `openUsageAccessSettings`) — signatures
  frozen. UI keeps calling `lib/services/block_platform.dart` exactly as today.
- **Data model frozen.** `BlockConfig` (enabled/mode/opensPerDay/sessionMinutes),
  `BlockMode { direct, timed }`, the Hive boxes (`blocklist_v2`, `blocked_sites`,
  `feature_blocks_v2`), the `block_prefs` mirror keys, and the feature keys
  (`yt_shorts` / `ig_reels` / `fb_reels`). We restyle the widgets that read/write
  these; we do not change the shapes.
- **The Riverpod providers** in `lib/providers/block_providers.dart`
  (`blockListProvider`, `blockedSitesProvider`, `featureBlocksProvider`,
  `permissionsProvider`, `installedAppsProvider`) — kept as the state layer. New
  UI reads the same providers.

If a redesign idea would require changing any of the above, it is **out of
scope** — note it and move on.
