# 00 — Overview & Architecture

> The big picture: what BlockX is, the single idea it's built on, the permissions it needs, how
> the Flutter and native halves talk, and how data is stored. Read this before the step files.

---

## What BlockX is

**BlockX** is a **personal-use Android app** (Flutter UI + native Kotlin engine) that stops you
from using distracting things by **covering them or bouncing you off them** the instant they
appear. It blocks four kinds of things, each added in its own step:

1. **Apps** — open a blocked app → a full-screen "This app is blocked." screen. *(Step 1)*
2. **Timed apps** — open a limited number of times per day, for a set number of minutes each. *(Step 2)*
3. **Websites** — visit a blocked domain in any browser → block screen. *(Step 3)*
4. **In-app sub-features** — YouTube Shorts, Instagram Reels, Facebook Reels → bounced back. *(Step 4)*

Constraints that shape everything:

- **No backend, no login, no Play Store.** It is a sideloaded APK for one person.
- **Plain UI.** Default Material widgets, no theming, no animations. Function over form.
- **Native-first.** Reliable blocking must be native (Kotlin accessibility service), not a
  Flutter plugin.

---

## The one core idea: an AccessibilityService

All blocking is done by a single native **Android AccessibilityService** called
`AppBlockerService`. An accessibility service is a privileged background service that Android
lets "see" the screen — which app is in front, and (if you request it) the on-screen view tree.

BlockX uses that ability to:

- know **which app is in the foreground** — Steps 1 & 2,
- **read a browser's address bar text** — Step 3,
- **scan an app's on-screen view tree** for the Shorts/Reels player — Step 4,

and then react: launch a full-screen block screen, or press the global Back button.

The service runs **continuously** once enabled, independent of the Flutter UI. It's a plain
`AccessibilityService` (not a foreground service); it survives the UI being closed, but the OS
can still kill it (see the realme note in [REFERENCE.md](REFERENCE.md)).

> ### Why not a VPN or an overlay?
> - **VPN (first prototype):** filtered traffic, but that only cut an app's *internet* — the app
>   still **opened**. Blocking must stop the app from opening, which a VPN can't do.
> - **Drawn overlay (second prototype):** a `WindowManager` overlay only *hid* the app; it kept
>   running underneath (sound continued, reachable from Recents) and fought the status/nav bars.
> - **Real Activity (current):** launching a real full-screen `BlockActivity` makes Android
>   background the app underneath, so it actually **pauses**.
>
> **Never reintroduce the VPN or the overlay-only block screen.**

---

## The three permissions

Android won't let a sideloaded app grant these itself, so the home screen shows a **banner**
with one button per missing permission (deep-links to the right Settings page, re-checks on
resume):

| Permission | Manifest / API | Why it's needed |
|---|---|---|
| **Accessibility service** | `BIND_ACCESSIBILITY_SERVICE` | detect the foreground app + read the screen — the whole engine |
| **Display over other apps** | `SYSTEM_ALERT_WINDOW` | draw the floating timer widget + reliably launch the block screen from the background |
| **Usage access** | `PACKAGE_USAGE_STATS` | reliably read the *real* foreground app (needed because realme Game Space hosts games under its own window — see Step 1) |

Plus **`QUERY_ALL_PACKAGES`** (declared in the manifest, no user prompt) so the app picker can
list every installed app.

Because the `applicationId` is `com.blockx.app`, if you ever change it, Android treats the
rebuilt APK as a brand-new app: you'd have to uninstall, re-grant all 3 permissions, and re-add
your lists. Don't change it casually.

---

## How the two halves talk (Flutter ⇄ Native)

```
┌───────────────────────────── Flutter (Dart) ──────────────────────────────┐
│  UI screens   →   Riverpod providers   →   BlockPlatform (MethodChannel)   │
│  home / pickers / toggles       state         "com.blockx.app/blocker"     │
└───────────────────────────────────┬────────────────────────────────────────┘
                                     │  invokeMethod(...)  →  saves JSON into
                                     │  SharedPreferences file "block_prefs"
                                     ▼
┌───────────────────────────── Native (Kotlin) ─────────────────────────────┐
│  MainActivity        — MethodChannel handler; saves prefs; permission checks│
│  AppBlockerService   — the running engine: detect, decide, act              │
│  BlockRepository     — shared read/write of config + runtime state          │
│  BlockActivity       — the full-screen block screen                         │
│  BuiltInBlocklist    — code-only always-on website list                     │
└─────────────────────────────────────────────────────────────────────────────┘
```

Key points:

- **Flutter never blocks anything.** It is only the settings UI. It writes the user's choices
  to native storage; the native service reads them and does the real work.
- The bridge is **exactly one** `MethodChannel`, named **`com.blockx.app/blocker`**
  (`lib/services/block_platform.dart` on the Dart side, `MainActivity.kt` on the native side).
- The service reads its configuration from **`SharedPreferences` file `block_prefs`**, which
  Flutter mirrors from its **Hive** boxes on every change. This decoupling is deliberate: the
  service can read config even when Flutter isn't running.

---

## The data model

Everything the user configures is stored twice: in Flutter's **Hive** (the source the UI edits)
and mirrored into native **`SharedPreferences`** (the copy the service reads). The service also
keeps its own **runtime** state (timer quotas) that Flutter never touches.

| What | Flutter store (Hive box) | Native mirror (`block_prefs` key) | Written by |
|---|---|---|---|
| Blocked apps + config | `blocklist_v2` (`pkg → BlockConfig` JSON) | `configs_json` (enabled apps only) | Flutter |
| Blocked websites | `blocked_sites` (`domain → domain`) | `blocked_sites_json` (array) | Flutter |
| Shorts/Reels config | `feature_blocks_v2` (`key → BlockConfig` JSON) | `feature_blocks_json` (object) | Flutter |
| Timer runtime (per app **or** feature) | — (native only) | `state_<id>_date` / `_opens` / `_sessionEnd` | Native |

There is also a **code-only** always-on website list, `BuiltInBlocklist.kt`, merged in by the
service (see Step 3).

Every Flutter notifier mirrors to native on change, e.g. `blockListProvider` →
`BlockPlatform.setConfigs`, `blockedSitesProvider` → `setBlockedSites`, `featureBlocksProvider` →
`setFeatureBlocks`.

---

## Naming & identity rules (don't casually change)

- **Display name:** `BlockX` (manifest `android:label`, service label, `strings.xml` app_name,
  Flutter `MaterialApp.title` + AppBar).
- **Identity:** applicationId `com.blockx.app`; Kotlin package/namespace `com.example.blockx`;
  Dart package `blockx`; MethodChannel `com.blockx.app/blocker`; block-screen taskAffinity
  `com.blockx.app.blockscreen`.
- **The domain word "block"** in class/file/key names (`BlockActivity`, `BlockRepository`,
  `block_store.dart`, `blocklist_v2`, `block_prefs`) means *the blocking feature* — it is **not**
  the app identity and is deliberately **not** renamed to "blockx".

---

## Conventions & scope (working rules)

Rules that keep BlockX simple and focused (carried over from the project guide):

- **Solo, personal-use project.** Don't add multi-user, auth, or cloud sync unless explicitly
  asked.
- **No fancy UI.** Default Material widgets, no custom theming/animation. Function over form.
- **Native-first.** Prefer a native Android implementation (Kotlin AccessibilityService) over
  hunting for a Flutter plugin — reliable app-open blocking must be native.
- **Never reintroduce** the VPN or the overlay-only block screen (see "Why not a VPN" above).
- Keep storage minimal and JSON-based (the Hive boxes + the mirrored `block_prefs` keys).

**In scope (built):** app blocking, per-app time limits (opens/day + minutes), website (domain)
blocking, and sub-feature blocking for **YouTube Shorts / Instagram Reels / Facebook Reels**.

**Not in scope unless asked later:**

- iOS support
- Play Store publishing / compliance
- Remote / cloud block-list sync
- Multi-device support
- **Time-of-day schedules** (e.g. "block 9–5") — per-app *usage limits* are built; calendar/clock
  schedules are not
- Other in-app sub-features (and other apps' Reels/Shorts) beyond the three above
- Custom UI / theming

---

## Where to go next

- **[STEP-1-APP-BLOCKING.md](STEP-1-APP-BLOCKING.md)** — the foundation.
- The full file map, storage keys, MethodChannel table, and build order are in
  **[REFERENCE.md](REFERENCE.md)**.
