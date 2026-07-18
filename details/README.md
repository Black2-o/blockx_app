# BlockX — Final Summary & Documentation

This folder is the complete "documentary" of how **BlockX** was built. This page is the **final,
end-to-end summary** — what the app is, why it exists, the approach behind every feature, and the
exact state everything is in now. The per-step files below have the deep detail; start here.

---

## 1. What BlockX is (one paragraph)

**BlockX** is a **personal-use, sideloaded Android app** that stops you using distracting things by
**covering them or bouncing you off them the instant they appear**. It's built as a **Flutter UI +
a native Kotlin engine**: Flutter is only the settings screens; all real blocking is done by a
single always-running **Android AccessibilityService**. No backend, no login, no Play Store, no
VPN — one APK for one person.

It blocks **four kinds of things**, plus a time-limit option on two of them:

| # | What it blocks | How you experience it |
|---|---|---|
| 1 | **Apps** | Open a blocked app → full-screen "This app is blocked." |
| 2 | **Timed apps** | Open a blocked app N times/day for M minutes each, then blocked till midnight |
| 3 | **Websites** | Visit a blocked domain in any browser (or in-app browser) → block screen |
| 4 | **In-app sub-features** | YouTube Shorts / Instagram Reels / Facebook Reels → bounced off |
| 5 | **Timed sub-features** | Same opens/day + minutes limit for Shorts/Reels |

---

## 2. Why it's built the way it is

**The constraints shaped every decision:**

- **Personal, sideloaded, solo.** No multi-user, no auth, no cloud sync, no Play-Store compliance.
- **Plain UI.** Default Material widgets, no theming/animation. Function over form.
- **Native-first.** Reliable "stop the app from opening" blocking **must** be native — a Flutter
  plugin can't see the foreground app or the screen. So the engine is Kotlin; Flutter is just the
  settings that feed it.

**Why an AccessibilityService — and not the two things we tried first:**

| Approach | Why it failed / why we use it |
|---|---|
| **VPN** (1st prototype) | Filtered traffic, but only cut an app's *internet* — the app still **opened**. Blocking must stop the open, which a VPN can't do. |
| **Drawn overlay** (2nd prototype) | A `WindowManager` overlay only *hid* the app; it kept running underneath (sound, reachable from Recents) and fought the system bars. |
| **AccessibilityService + a real Activity** ✅ | The service "sees" the foreground app and the on-screen view tree; launching a real full-screen `BlockActivity` makes Android **background and pause** the app underneath. This is the whole engine. |

> **Rule carried forward: never reintroduce the VPN or the overlay-only block screen.**

An AccessibilityService is a privileged background service Android lets "see" the screen. BlockX
uses that to (a) know the foreground app, (b) read a browser's address bar, and (c) scan an app's
view tree for the Shorts/Reels player — then react.

---

## 3. The approach, feature by feature

### Feature 1 — App blocking *(Step 1)*
Detect the **foreground app** two ways and OR them: accessibility `TYPE_WINDOW_STATE_CHANGED`
events (instant) **plus** a 350 ms `UsageStatsManager` poll (the source of truth — needed because
realme's Game Space hosts games under its own window). If the front app is on the blocklist, launch
`BlockActivity` (`MODE_BLOCK`). Hardened with anti-flicker, a home-kick, and a delayed launch so
the screen reliably appears.

### Feature 2 — Timed apps + the floating widget *(Step 2)*
`BlockConfig` gains a **timed** mode: *N opens/day × M minutes*. Opening a timed app shows an
**interstitial** (`MODE_INTERSTITIAL`, "Is this really needed?", Open disabled 5 s). Tapping Open
spends one daily open and starts an M-minute session; a **draggable, edge-snapping floating widget**
shows the countdown (tap → opens-left / time-left / **End now**). Quota resets at midnight.
*(Hard lesson: never `removeAllViews()`/re-`addView()` on the live overlay — it crashed the whole
process; reposition via `updateViewLayout` with a fixed child order.)*

### Feature 3 — Website blocking *(Step 3)*
Turn on `canRetrieveWindowContent` + `flagReportViewIds`, read the **browser address bar**
(`urlBarIdSuffixes`, skipping the *focused* bar so mid-typing autocomplete doesn't false-trigger),
normalise the host, and match it against the user's list **plus** a code-only `BuiltInBlocklist`.
Blocked → `MODE_BACK` (Go back returns you to the browser's previous page, **not** the phone home).
Also covers **in-app browsers** (WebView + a top-of-screen URL node).

### Feature 4 — Sub-feature blocking (Shorts / Reels) *(Step 4)* — the hardest
Shorts/Reels aren't apps or URLs — they're sections *inside* an app. The only hook is **scanning
the on-screen view tree** for a signal that means "a short/reel is actually being watched," while
**never** matching the normal feed or a browse list. Signals were **tuned from real
`adb logcat` output** (`logFeatureCandidates`), because these apps obfuscate and rename constantly.

When a reel/short is detected: **leave the player first, then show the block screen** — because
dropping a full-screen Activity over a *playing* video triggers picture-in-picture + phone-home +
a loop. We leave via the app's **Home tab** (YouTube/Instagram) or **Back** (Facebook), wait ~300 ms,
then show the screen over the app's own feed with `feature=true` so its buttons return you to the
feed, never the phone home.

### Feature 5 — Timed sub-features *(Step 5)*
Shorts/Reels reuse the **exact app timer** — the runtime state is keyed by a string id, so we just
use the feature key (`yt_shorts`/`ig_reels`/`fb_reels`) as that id. Off / Direct / Time-limited,
same interstitial + "resets tomorrow" screens, same daily reset — all inherited for free.

---

## 4. The final detection signals (current, tuned state)

This is the part that took the most iteration. Each app uses whichever signal is **clean** — it
fires only while a short/reel is genuinely being *watched*, never on the normal feed or a browse
list:

| Feature | Signal (final) | Deliberately NOT matched | Leave action |
|---|---|---|---|
| **YouTube Shorts** | view-ids `reel_recycler` / `reel_player` / `reel_watch` / `shorts_player` | the feed's Shorts *shelf* (`reel_time_bar`) | Home tab |
| **Instagram Reels** | the immersive **viewer**: `clips_viewer_view_pager` **AND** `clips_ufi_component`, **both `isVisibleToUser`** | the home feed reels *tray* (pager but no action rail); a *paused* reel lingering in the tree after you leave (not visible) | Home tab |
| **Facebook Reels** | `search reels` (bottom-nav reels feed) · `reel details` / `swipe up to see more` (a reel actually playing, incl. Messenger) | the **top reels tab *list*** after stories (`Selected Reels tab` — browsing, not watching); home/stories | Back |

**Why these, and the traps we hit:**
- **Instagram** reuses `clips_viewer_view_pager` in both the real player *and* the home feed tray,
  so matching it alone over-blocked the feed. The clean distinction is the **action rail**
  (`clips_ufi_component`, like/comment/share) — present only in the immersive viewer. And requiring
  both to be **`isVisibleToUser`** kills the reload loop: Instagram keeps the paused reel fragment
  in the tree after you leave, but marks it not-visible, so it no longer re-triggers. This single
  detector correctly blocks the **Reels tab, DM/message reels, and search/explore reels**, while
  leaving feed browsing (and home/messages after you leave) fully usable.
- **Facebook** exposes **no useful view-ids** (`ids=[]`), so it's description-only. It has **two**
  reels entry points that must be treated differently: the **bottom-nav feed** = watching → block
  immediately (`search reels`); the **top reels tab list** after stories = browsing → **don't
  block** (that's why `selected reels tab` is deliberately *not* matched). Either way, an actual
  playing reel (`reel details`) blocks. FB leaves via **Back**, not the Home tab (clicking Home
  doesn't dismiss FB's reel — it looped).
- **Golden rule:** never add a signal that also appears on the normal feed / nav tab / browse list,
  and prefer **semantic** signals over fragile pixel/height/position heuristics (those break on
  every app UI update — we tried them and they did).

---

## 5. Architecture — how the two halves talk

```
┌───────────────────────── Flutter (Dart) — settings UI only ─────────────────────────┐
│  screens  →  Riverpod providers  →  BlockPlatform (one MethodChannel)                 │
│  (home / pickers / toggles)   (state, mirror on change)   "com.blockx.app/blocker"    │
└───────────────────────────────────────┬──────────────────────────────────────────────┘
                                         │  invokeMethod → writes JSON into
                                         │  SharedPreferences file "block_prefs"
                                         ▼
┌───────────────────────── Native (Kotlin) — the engine ──────────────────────────────┐
│  MainActivity       — MethodChannel handler, saves prefs, permission checks           │
│  AppBlockerService  — the running engine: detect foreground / read screen, decide, act│
│  BlockRepository    — shared config + runtime timer state; decide(); sessions         │
│  BlockActivity      — the full-screen block screen (BLOCK / INTERSTITIAL / BACK)       │
│  BuiltInBlocklist   — always-on, code-only website list                               │
└───────────────────────────────────────────────────────────────────────────────────────┘
```

- **Flutter never blocks anything** — it only writes your choices to native storage.
- The bridge is **exactly one** `MethodChannel`: `com.blockx.app/blocker`.
- The service reads config from **`SharedPreferences` "block_prefs"** (mirrored from Flutter's Hive
  boxes on every change), so it keeps working even when the Flutter UI is closed.

**The 3 permissions** (banner on the home screen deep-links to each): **Accessibility** (the whole
engine), **Display over other apps** (floating widget + reliable block-screen launch), **Usage
access** (real foreground app, for the realme Game Space case). Plus `QUERY_ALL_PACKAGES` for the
app picker.

**Data model** — everything is stored twice: Hive (the UI's source of truth) mirrored into native
`block_prefs`. Apps → `blocklist_v2` / `configs_json`; websites → `blocked_sites` /
`blocked_sites_json`; Shorts/Reels → `feature_blocks_v2` / `feature_blocks_json`; timer runtime
(native only) → `state_<id>_date/_opens/_sessionEnd` where `<id>` is an app package **or** a feature
key (same machinery for both).

---

## 6. The hard problems we solved (highlights)

- **realme Game Space** hides the real foreground app → added the `UsageStatsManager` poll as the
  source of truth.
- **Block-screen flicker / no-show** → anti-flicker + home-kick + delayed launch.
- **Floating-widget crash** (NPE in `newDispatchApplyWindowInsets`) → never mutate the live overlay
  hierarchy; fixed child order + `updateViewLayout`.
- **Website autocomplete false-block** (typing `tgc.com` → autocompleted `tgc.edu.bd`) → skip the
  *focused* address bar.
- **YouTube PiP + phone-home loop** when blocking a playing Short → leave the player first, then
  show the screen over the feed.
- **Instagram over-blocking the feed, then the reload-to-home loop** → require the action rail
  (`clips_ufi_component`) **and** `isVisibleToUser`.
- **Facebook blocking the browse list / looping** → split the two reels entry points; use `Back`
  to leave; match `search reels` + `reel details`, not `selected reels tab`.

---

## 7. Build & run

```
flutter build apk --debug                       # fat ~150 MB, easiest for reading logs
flutter build apk --release --split-per-abi     # ~17 MB, install app-arm64-v8a-release.apk
adb install -r build/app/outputs/flutter-apk/app-debug.apk   # install over existing, no uninstall
```
Then enable the 3 permissions from the home-screen banner. Debug/tune with `adb logcat -s BlockX:*`.

---

## 8. The rest of the documentation

| File | What it covers |
|---|---|
| **[STEP-0-OVERVIEW.md](STEP-0-OVERVIEW.md)** | Architecture, the core idea, the 3 permissions, Flutter⇄Native, data model, naming rules |
| **[STEP-1-APP-BLOCKING.md](STEP-1-APP-BLOCKING.md)** | Blocking whole apps — the foundation + every fix |
| **[STEP-2-TIMER.md](STEP-2-TIMER.md)** | Time-limited apps (opens/day + minutes) + the floating widget |
| **[STEP-3-WEBSITE-BLOCKING.md](STEP-3-WEBSITE-BLOCKING.md)** | Websites in any browser + in-app browsers + the built-in list |
| **[STEP-4-SUBFEATURE-BLOCKING.md](STEP-4-SUBFEATURE-BLOCKING.md)** | YouTube Shorts / Instagram Reels / Facebook Reels detection |
| **[STEP-5-SUBFEATURE-TIMER.md](STEP-5-SUBFEATURE-TIMER.md)** | Time-limit option for Shorts/Reels, reusing the app timer |
| **[REFERENCE.md](REFERENCE.md)** | File-by-file map, storage keys, MethodChannel, build order, logcat debugging |

> **Status: all five features are built and working.** Detection signals are tuned to the current
> app versions; if an app update ever breaks a Short/Reel signal, re-tune from `logcat` per
> [STEP-4 §5](STEP-4-SUBFEATURE-BLOCKING.md).
