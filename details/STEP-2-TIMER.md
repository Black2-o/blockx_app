# Step 2 — Timer (time-limited blocking)

> Instead of blocking an app outright, allow it a **limited number of opens per day**, each for a
> **fixed number of minutes**. After a session ends it blocks again; after the day's opens are
> used up it's fully blocked until midnight. A small floating widget shows the remaining
> opens/time during a session.

- Prereq: **[STEP-1-APP-BLOCKING.md](STEP-1-APP-BLOCKING.md)**.
- Main code: `BlockRepository.kt` (decision + runtime state), `BlockActivity.kt`
  (`MODE_INTERSTITIAL`), `AppBlockerService.kt` (the floating widget), `config_dialog.dart`.

---

## 1. The model

`BlockConfig.mode` is `direct` **or** `timed`. A `timed` config adds two numbers:

- `opensPerDay` — how many times per day you may open the app.
- `sessionMinutes` — how long each open lasts.

The user picks these in **`config_dialog.dart`** (a radio for direct/timed, and chip choices for
opens and minutes). The chosen config is stored in Hive and mirrored to native `configs_json`
exactly like Step 1.

---

## 2. The decision logic (`BlockRepository.decide`)

Everything is decided natively:

```kotlin
fun decide(ctx, pkg): Decision {
    val cfg = configFor(ctx, pkg) ?: return NONE       // not blocked / disabled
    if (cfg.mode == "direct") return BLOCK
    if (sessionEndAt(ctx, pkg) > now) return ALLOW_SESSION   // a session is running
    return if (opensUsedToday(ctx, pkg) >= cfg.opensPerDay)
        BLOCK            // quota used up → blocked until midnight
    else
        INTERSTITIAL     // opens remain → "Is this really needed?"
}
```

The four outcomes:

| Decision | Meaning | What the service does |
|---|---|---|
| `NONE` | not in the list / disabled | nothing (hide widget) |
| `BLOCK` | direct block, or timed quota exhausted | `BlockActivity` `MODE_BLOCK` |
| `INTERSTITIAL` | timed, opens remain | `BlockActivity` `MODE_INTERSTITIAL` |
| `ALLOW_SESSION` | timed session currently running | allow the app + show floating widget |

---

## 3. The flow (opening a timed app)

1. **Open the app** → `INTERSTITIAL` → `BlockActivity` in `MODE_INTERSTITIAL`:
   - "Is this really needed?" + "Opens left today: N".
   - An **Open** button that is **disabled for 5 seconds** (a deliberate friction delay; the
     countdown shows "Open (5)"… "Open (1)" → "Open").
   - A "Go to home screen" button.
2. **Tap Open** (`onOpenTapped`) → `BlockRepository.startSession(pkg)`:
   - spends one of the day's opens (`state_<pkg>_opens += 1`),
   - sets `state_<pkg>_sessionEnd = now + sessionMinutes`,
   - stamps `state_<pkg>_date = today`.
   Then it relaunches the app via `getLaunchIntentForPackage`.
3. The service now decides `ALLOW_SESSION` → it **allows** the app and shows the **floating
   widget**.
4. **Session ends** → the next 350 ms poll re-decides. If opens remain → `INTERSTITIAL` again on
   next open; if used up → `BLOCK`.
5. **Quota used up** → `BLOCK` with the reason "Daily limit reached.\nThis app is blocked until
   tomorrow."

**Daily reset** is automatic and needs no alarm: runtime state is keyed by date. `opensUsedToday`
returns 0 if `state_<pkg>_date` isn't today, so a new calendar day starts fresh.

---

## 4. Native runtime state

Written by native, stored in `SharedPreferences` file `block_prefs`:

| Key | Meaning |
|---|---|
| `state_<pkg>_date` | the day (`yyyy-MM-dd`) this state belongs to |
| `state_<pkg>_opens` | opens used today |
| `state_<pkg>_sessionEnd` | epoch ms when the current session ends (`0` = none) |

Relevant `BlockRepository` functions: `startSession`, `endSession` (the "End now" button),
`opensUsedToday`, `opensLeftToday`, `sessionEndAt`, `sessionMillisLeft`.

---

## 5. The floating session widget

Owned by the service (`showFloating` … `hideFloating`), it's a `WindowManager` overlay
(`TYPE_APPLICATION_OVERLAY`) shown only while a session is active:

- **Collapsed:** just the **BlockX app icon** (`getApplicationIcon(packageName)` — *our* icon,
  not the blocked app's), with no dark box around it.
- **Tap the icon:** expands a panel showing **Opens left today**, **Time left (m:ss)**, and an
  **"End now"** button (`endSession` → hides the widget and re-evaluates, so the app blocks
  again immediately).
- **Draggable + edge-snapping:** drag it anywhere; on release it snaps to the nearest left/right
  screen edge (works in portrait and landscape). It remembers its edge + vertical offset for the
  service's lifetime (`floatingIsLeftEdge`, `floatingY`).

How the drag works:

- `attachDragHandler()` sets an `OnTouchListener` on the icon that distinguishes a **tap** (below
  `scaledTouchSlop` → expand the panel) from a **drag** (move: update `params.x/y` via
  `updateViewLayout`).
- On release, `snapToNearestEdge()` decides left/right from the widget's center vs screen center,
  then `anchorToEdge()` pins `params.x` flush to that edge.
- `toggleFloatingPanel()` re-pins after expanding (the panel changes width) so it never runs
  off-screen.

### ⚠️ The crash lesson (do not repeat)

An earlier draggable version tried to keep the expand-panel on the correct side by **reordering
the widget's child views** — `removeAllViews()` then re-`addView()` — on the **live, attached**
overlay. Mutating an attached view group's children left a transient **null child**, and when
Android dispatched window insets it threw:

```
java.lang.NullPointerException:
  ... in ViewGroup.newDispatchApplyWindowInsets ...
```

That crashed the **whole app process**, which killed the accessibility service and **silently
disabled all blocking** (apps opened freely again). It even recurred on relaunch until the app
was uninstalled.

**Rule:** never mutate the live overlay's view hierarchy. The current code keeps a **fixed child
order** (`panel` then `icon`) and only repositions the whole row via `updateViewLayout`
(`anchorToEdge` changes `params.x`). *(Diagnosed from `adb logcat -b crash`; the stack had no app
frames because the null child was hit deep in the framework during a layout traversal.)*

---

## 6. Pieces to know

| Piece | Where |
|---|---|
| timed vs direct model | `BlockConfig` (`block_config.dart`), `config_dialog.dart` |
| decision + quota + daily reset | `BlockRepository.decide` / `startSession` / `opensUsedToday` |
| interstitial screen | `BlockActivity` `MODE_INTERSTITIAL` (`buildInterstitial`, 5 s delay) |
| floating widget | `AppBlockerService.showFloating` … `hideFloating`, `attachDragHandler`, `snapToNearestEdge`, `anchorToEdge` |

Next: **[STEP-3-WEBSITE-BLOCKING.md](STEP-3-WEBSITE-BLOCKING.md)**.
