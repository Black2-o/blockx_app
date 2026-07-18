# Step 5 — Sub-feature timer (Shorts / Reels)

> Give Shorts/Reels the same **time-limit** option apps have (Step 2): instead of blocking them
> outright, allow a **limited number of opens per day**, each granting a **session of N minutes**,
> then block until midnight. Built by **reusing the app timer** and adapting the *action* to the
> picture-in-picture constraint.

- Prereq: **[STEP-2-TIMER.md](STEP-2-TIMER.md)** (the app timer this reuses) and
  **[STEP-4-SUBFEATURE-BLOCKING.md](STEP-4-SUBFEATURE-BLOCKING.md)** (the detection this builds on).
- Main code: `BlockRepository.kt` (`featureConfigFor`, shared `startSession`/`opensLeftToday`),
  `AppBlockerService.kt` (`checkBlockedFeature`, `evaluate` guard, poll-driven check, widget
  "End now"), Flutter `feature_store.dart` / `featureBlocksProvider` / `features_screen.dart` /
  `config_dialog.dart`.

---

## 1. What you can now set

Each feature (YouTube Shorts / Instagram Reels / Facebook Reels) has an on/off switch and a
**mode**, exactly like an app:

- **Off** — not blocked.
- **Direct** — always blocked (bounce out every time — the Step 4 behaviour).
- **Time-limited** — e.g. "3 opens/day, 5 minutes each" → up to 15 minutes of Shorts a day, then
  blocked until midnight.

It's configured in `features_screen.dart`: tap a row → the **same `config_dialog.dart`** used for
apps (Direct vs Time-limited + opens/day + minutes chips).

---

## 2. How it reuses the app timer

The app timer's runtime state is keyed by a **string id** (`state_<id>_date/_opens/_sessionEnd`)
and its logic is all in `BlockRepository`. For features we simply use the **feature key**
(`yt_shorts` / `ig_reels` / `fb_reels`) as that id. The only new native piece is where the config
comes from:

- `featureConfigFor(ctx, key)` reads the feature's `{mode, opensPerDay, sessionMinutes}` from
  `feature_blocks_json` (null = off).
- `startSession` and `opensLeftToday` were changed to look up config via
  `anyConfig(id) = configFor(id) ?: featureConfigFor(id)`, so the **same functions** work for both
  apps and feature keys. `sessionMillisLeft` / `opensUsedToday` / `endSession` were already
  id-based, so they just work.

So the daily quota, session end time, and **automatic daily reset** (state is stamped with the
date) are all inherited from Step 2 for free.

---

## 3. The flow (a block screen at every boundary — PiP-safe)

When the Shorts/Reels **player is detected** and the feature is **timed**, `checkBlockedFeature`:

1. **A session is running** (`sessionMillisLeft > 0`) → allow it, and show the **floating
   countdown widget** (tap it for opens-left / time-left / **End now**). Same widget as the app
   timer.
2. **No session, opens remain** → the **interstitial** ("Is this really needed?", **Open**
   disabled 5 s). Tapping **Open** spends one open (`startSession`) and dismisses; you re-enter the
   player to watch the new N-minute session. **Not now** returns you to the feed.
3. **No session, quota used up** → a plain **"Daily limit reached — comes back tomorrow"** screen.
   **Go back** returns you to the feed.

All three screens are shown via **`bounceThenFeatureScreen`** — it leaves the player by
**clicking the app's bottom-nav "Home" tab** (`clickHomeTab`; falls back to `GLOBAL_ACTION_BACK`),
which stays *in the app* on its feed (no PiP, and no Instagram Reels-tab → launcher loop), then
shows the screen over that feed, launched with `feature = true` so its buttons `finish()` back to
the feed, not the phone home (see [STEP-4 §3](STEP-4-SUBFEATURE-BLOCKING.md)).

Because a new session needs a fresh **Open**, "3 opens × 5 min" is **three separate 5-minute
sessions**, each gated by the 5-second interstitial. When a session ends mid-watch you're bounced
to the feed and shown the interstitial again; when the opens run out you get the "resets tomorrow"
screen. This is the app-timer experience, adapted for the PiP constraint.

**End now** on the widget ends the session *and* sends Back, so you leave the player — otherwise
the next detection would immediately show the interstitial again on the same screen.

---

## 4. Two integration details that matter

- **`evaluate()` must yield the widget to `checkBlockedFeature`, but still app-block.** The
  350 ms poll calls `evaluate()`; its `NONE` branch would `hideFloating()` for YouTube. It now
  keeps the widget **only while a feature session is running** (`sessionMillisLeft > 0`) and hides
  it otherwise. Importantly it **no longer skips app-blocking** for feature apps (an earlier
  version returned early and broke it) — so you can block **Instagram the app** on top of
  **Instagram Reels**.
- **Session expiry must be re-checked even without content events.** A paused Short may stop
  firing `typeWindowContentChanged`, so `checkBlockedFeature` is **also driven from the 350 ms
  poll** (`recheckRunnable`), not only from accessibility events. That guarantees a session that
  runs out is re-evaluated (→ interstitial if opens remain, or the "resets tomorrow" screen).

---

## 5. Storage

- **Flutter:** Hive box **`feature_blocks_v2`** — `key -> BlockConfig` JSON (reuses `BlockConfig`:
  `enabled` + `mode` + `opensPerDay` + `sessionMinutes`). *(New box name; the old `feature_blocks`
  bool box is abandoned, so existing on/off toggles reset once — just re-enable them.)*
- **Native mirror:** `feature_blocks_json` = `{ "<key>": {mode, opensPerDay, sessionMinutes}, … }`
  for the **enabled** features only. Read by `featureConfigFor`.
- **Runtime (native, per feature key):** `state_<key>_date` / `_opens` / `_sessionEnd` — same keys
  and daily-reset logic as apps.

---

## 6. Notes & trade-offs

- **Each session is gated by the 5-second interstitial** — you tap **Open** to start each
  N-minute session, exactly like the app timer. Session ends mid-watch → bounced to the feed +
  interstitial again (until the day's opens run out).
- **You re-enter the player after tapping Open.** Because we Back out to the feed first (to avoid
  PiP), tapping **Open** lands you on the feed with a fresh session — tap back into Shorts/Reels
  to watch. One extra tap, in exchange for no PiP / no phone-home / no loop.
- **Rare edge:** configuring the SAME app as both app-timed *and* feature-timed (e.g. Instagram
  timed **and** Instagram Reels timed) can make the two countdown widgets fight; uncommon and
  non-crashing.
- Detection itself is unchanged from Step 4 (still tuned via `logFeatureCandidates`).

---

## 7. Pieces to know

| Piece | Where |
|---|---|
| feature config (off/direct/timed) | `featureConfigFor` (native) ↔ `FeatureStore` / `featureBlocksProvider` (Flutter) |
| shared timer state | `startSession` / `opensLeftToday` (via `anyConfig`), `sessionMillisLeft`, `endSession` |
| the timed flow | `checkBlockedFeature` (allow / spend-open / bounce) |
| widget ownership | `evaluate()` early-return for feature apps + poll-driven `checkBlockedFeature` |
| UI | `features_screen.dart` (switch + tap → `config_dialog.dart`) |

Back to the **[index](README.md)** · Reference: **[REFERENCE.md](REFERENCE.md)**.
