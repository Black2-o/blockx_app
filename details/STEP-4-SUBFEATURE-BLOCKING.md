# Step 4 — Sub-feature blocking (Shorts / Reels)

> Keep using YouTube / Instagram / Facebook, but block **only** the short-video section —
> YouTube Shorts, Instagram Reels, Facebook Reels. Three toggles on the home screen.

This is the **hardest** feature: Shorts/Reels aren't apps or URLs, they're sections *inside* an
app. The only hook is reading the app's **on-screen view tree** and recognising the player.

- Prereq: **[STEP-3-WEBSITE-BLOCKING.md](STEP-3-WEBSITE-BLOCKING.md)** (tree reading is already
  enabled there — `flagReportViewIds`).
- Main code: `AppBlockerService.kt` (`featureApps` / `featureIdHints` / `featureDescHints` /
  `treeHasSignal` / `checkBlockedFeature` / `logFeatureCandidates`), `BlockRepository.kt`
  (`featureConfigFor`), Flutter `feature_store.dart` / `featureBlocksProvider` /
  `features_screen.dart`. **The timer built on top of this is documented in
  [STEP-5-SUBFEATURE-TIMER.md](STEP-5-SUBFEATURE-TIMER.md).**

---

## 1. Detection — the options and what we chose

| Option | Idea | Verdict |
|---|---|---|
| Exact view-id lookup | `findAccessibilityNodeInfosByViewId("…:id/reel_recycler")` | precise, but breaks on every app update |
| Content-description / text scan | look for "Shorts"/"Reels" text | survives updates but the nav-tab labels are **always present** → false-positives everywhere |
| **Hybrid substring scan** ✅ | BFS the tree for **player-specific** view-id *fragments*, and — where ids are useless — content-description fragments | tolerant of minor renames; by matching the *player* (not the shelf/tab) it stays feed-safe |
| screenshot / pixel analysis | — | rejected: fragile, heavy, battery |

We use the **hybrid** approach. `treeHasSignal(root, idHints, descHints)` does a bounded BFS
(≤2500 nodes) and returns true if any node's `viewIdResourceName` contains an id-hint **or** any
node's `contentDescription` contains a desc-hint (case-insensitive substrings).

Because these apps obfuscate and rename constantly, the code carries **tuning logs**
(`logFeatureCandidates`) that print the candidate view-ids / descriptions on screen when nothing
matched. **We captured real `adb logcat -s BlockX:*` output from the device and tuned the hints
from it** — see §5.

---

## 2. Per-app signals (as tuned from real device logs)

Each app uses whichever signal is *clean* (won't fire on that app's normal feed):

- **YouTube Shorts** (`yt_shorts`) — **view-id** (`featureIdHints`: `reel_recycler` / `reel_player`
  / `reel_watch` / `shorts_player`). The feed's Shorts *shelf* uses `reel_time_bar`, which we
  deliberately do **not** match — so the home feed is safe.
- **Facebook Reels** (`fb_reels`) — **content-description** (`featureDescHints`), because FB
  exposes **no useful view-ids** (`ids=[]` in logs). FB has **two** reels entry points that must be
  treated differently:
  - the **bottom-nav reels feed** (you're watching) → **`search reels`** blocks it immediately;
  - the **top reels *tab list*** after stories (just browsing thumbnails,
    `descs=[Reels, tab 2 of 6, Selected Reels tab]`) → **must NOT block**, so we deliberately do
    **not** match `selected reels tab`. It's blocked only once you tap a reel and it starts playing;
  - a **reel actually playing** (from either tab, or Messenger) → **`reel details`** (immediate) /
    **`swipe up to see more`** (delayed backup).
  The top list has neither `search reels` nor `reel details`, so it's left alone; the home/stories
  (`Selected Stories tab`, unselected `Reels tab` / `Reels tab details`, `View X's reels`
  thumbnails) match nothing either (note `reels tab details` does **not** contain `reel details`).
  **Leave action for FB is `GLOBAL_ACTION_BACK`, not the Home-tab click** — clicking Home doesn't
  dismiss FB's reel (it looped); Back exits it cleanly. Instagram/YouTube still use the Home-tab
  click.
- **Instagram Reels** (`ig_reels`) — **the immersive reel *viewer*** (`isReelViewerActive`), NOT a
  plain id. Instagram reuses `clips_viewer_view_pager` in both the immersive player **and** the
  home-feed reels *tray*, so matching that id over-blocked the feed (an inescapable loop). The clean
  distinction from logs: the immersive viewer (Reels tab, a reel opened from a **DM**, or a reel
  watched in the feed) always has **both** `clips_viewer_view_pager` **and**
  `clips_ufi_component` (the like/comment/share action rail); the feed/tray has the pager but
  **not** the action rail. So we require both → this blocks the Reels tab, DM/message reels,
  search/explore reels, and feed reels, while leaving feed browsing alone. **Both nodes must also
  be `isVisibleToUser`** — after you leave Reels, Instagram keeps the *paused* reel fragment in the
  tree but marks it not-visible; without that check the lingering fragment re-triggered the block
  on the home/DM screen (the auto-reload-to-home loop). *(Earlier tries — narrowing to
  `clips_viewer_view_pager` alone, then
  a height/position heuristic, then the tab's `selected` flag — all failed: the feed reused the id,
  the sizes overlapped, and `clips_tab` never reported `selected=true`. `clips_ufi_component` is the
  robust semantic signal for "a reel is being watched.")*

---

## 3. The action — bounce out FIRST, then show a block screen (PiP-safe)

When a blocked feature is on screen and needs blocking (direct, or a timed feature that needs the
interstitial / is exhausted), `checkBlockedFeature` calls **`bounceThenFeatureScreen`**:

```kotlin
graceUntil = now + 1500
if (root == null || !clickHomeTab(root)) performGlobalAction(GLOBAL_ACTION_BACK)  // leave player
handler.postDelayed({ launchBlockActivity(key, mode, reason, feature = true) }, 300L)
```

**Why click the *Home tab*, not just Back?** Showing a full-screen block screen directly over a
*playing* Short backgrounds YouTube → **picture-in-picture** (the Short keeps playing) and dumps
you on the phone home. And on **Instagram's Reels tab, `GLOBAL_ACTION_BACK` exits to the
launcher** (Instagram then resumes on Reels → loop). So instead we **`clickHomeTab`** — find the
app's bottom-nav "Home" tab (a clickable node whose content-description starts with "Home", in the
bottom strip) and click it. That leaves the player **while staying in the app** (→ its feed): no
PiP, no launcher, no loop. (It **falls back to `GLOBAL_ACTION_BACK`** if no Home tab is found, e.g.
Facebook.) A beat later (≈300 ms) we show the screen over the feed, launched with `feature = true`
so its buttons just `finish()` back to the feed — never the phone home. `graceUntil` covers the
transition.

> **History:** an even earlier version skipped the screen entirely (just `GLOBAL_ACTION_BACK` + a
> toast), but a section vanishing with no screen **felt buggy**. Then "Back first + screen" fixed
> YouTube but looped on Instagram's Reels tab (Back → launcher). Clicking the **Home tab** fixes
> both.

The screens themselves — the **interstitial** (5-second Open → spend an open) and the **"resets
tomorrow"** screen — are the timer flow, documented in
**[STEP-5-SUBFEATURE-TIMER.md](STEP-5-SUBFEATURE-TIMER.md)**.

---

## 4. The three problems this step fixed (from a real log)

1. **Instagram over-blocking (chat, then the home feed → loop).** Broad IG view-id hints
   (`clips_video`/`clips_viewer`) matched an inline reel in a **DM**; narrowing to
   `clips_viewer_view_pager` fixed that but the **home feed's auto-playing reel uses the same id**,
   so once the quota was used up the feed itself kept blocking → you couldn't use Instagram. A
   height/position heuristic and the tab's `selected` flag were both tried and rejected as fragile.
   → **final:** require the immersive viewer's **action rail** (`clips_viewer_view_pager` **and**
   `clips_ufi_component`), both **`isVisibleToUser`** — this blocks the Reels tab, DM/message, and
   search/explore reels, leaves feed browsing alone, and (via the visibility check) kills the
   after-you-leave reload loop caused by Instagram keeping the paused reel in the tree. See §2.
2. **YouTube PiP + can't escape.** Showing a block screen backgrounded YouTube → PiP + phone-home
   + resume-loop. → now we **press Back first** (exit the player, stop playback), **then** show
   the block screen over the feed with `feature = true` buttons that return to the feed — no PiP,
   no phone home, no loop (see §3).
3. **Facebook not detecting.** FB exposes no view-ids (`ids=[]`). → added **content-description**
   detection (`featureDescHints`) and generalised the detector (`treeHasSignal`) to match
   view-ids **or** descriptions.

---

## 5. How to re-tune when an app update breaks it

Detection signals **will drift** between app versions. When a Short/Reel stops being caught:

1. Turn the relevant toggle on. Run `adb logcat -s BlockX:*`.
2. On the phone, open the app and go into the Short/Reel for ~5 seconds.
3. Look for a line like:
   ```
   BlockX  feature candidates (fb_reels): ids=[…] descs=[…]
   ```
4. Pick a **player-specific** signal:
   - a view-id fragment that appears **only** while watching (not on the feed / nav bar) → add to
     `featureIdHints`, **or**
   - for an app that hides its ids (FB), a **content-description** that appears only while
     watching → add to `featureDescHints`.
5. Rebuild. Verify you now see `blocked feature in <pkg>: <key> -> back` when you enter the
   Short/Reel, and that the normal feed/chat is **not** blocked.

> Caution: never add a fragment that's also present on the normal feed or the bottom-nav tab
> (e.g. a bare `reels`/`shorts` label), or you'll block the whole app.

---

## 6. Flutter side

- **`data/feature_store.dart`** — Hive box `feature_blocks_v2` (`key -> BlockConfig` JSON; each
  feature can be off / direct / timed, reusing `BlockConfig`).
- **`providers/block_providers.dart`** — `featureBlocksProvider`
  (`StateNotifier<Map<String,BlockConfig>>`): `setEnabled(key, on)` + `setConfig(key, cfg)`;
  mirrors the **enabled** ones to native via `BlockPlatform.setFeatureBlocks` →
  `feature_blocks_json` (`{ "<key>": {mode, opensPerDay, sessionMinutes}, … }`).
- **`screens/features_screen.dart`** — a row per feature: on/off switch + tap to configure
  (direct vs timed, via the shared `config_dialog.dart`). Opened from the **video** icon in the
  home AppBar.

The keys (`yt_shorts` / `ig_reels` / `fb_reels`) must match on both sides: `FeatureStore.keys`
(Dart) and `featureApps` values (Kotlin).

---

## 7. Pieces to know

| Piece | Where |
|---|---|
| which app → which key | `featureApps` (`AppBlockerService`) |
| detection signals | `featureIdHints` (view-ids), `featureDescHints` (descriptions) |
| the scan | `treeHasSignal` (bounded BFS, id OR desc) |
| the action | `checkBlockedFeature` → `bounceThenFeatureScreen` (Back, then block screen); timed flow in STEP-5 |
| tuning logs | `logFeatureCandidates` (`feature candidates (<key>): ids=… descs=…`) |
| config storage | `featureConfigFor` (native) ↔ `FeatureStore` / `featureBlocksProvider` (Flutter) |

Next: **[STEP-5-SUBFEATURE-TIMER.md](STEP-5-SUBFEATURE-TIMER.md)**.
