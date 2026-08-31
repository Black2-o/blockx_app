# Device Compatibility & Reliability — Research + Release Plan

Analysis of the cross-device problems seen in testing (Android 13+ restricted
settings, overnight accessibility shutdown, MIUI/ColorOS block screen not
showing) and what actually fixes each — including what a **release** build does
and does **not** solve.

---

## TL;DR

- A **release APK** is smaller/faster, not `debuggable`, and signed — you should
  ship it. But by itself it does **not** fix any of the OEM permission / app-kill
  problems. Those are OS + manufacturer behaviour, not build type.
- Your "**Allow restricted settings**" friction is caused by **install source**
  (sideloaded APK on Android 13+), not build type. Installing from **Google Play
  removes it**.
- The three highest-impact engineering fixes:
  1. Draw the block screen as a **full-screen overlay** instead of starting an
     Activity from the background → fixes MIUI/ColorOS "reel just closes, no
     block screen".
  2. Run a **foreground service** so the accessibility process survives overnight
     Doze / OEM memory killers.
  3. An in-app **Device Setup / Health** screen that detects the manufacturer and
     walks the user through that phone's exact hidden settings.

---

## Issue-by-issue

### 1. "Allow restricted settings" before you can enable Accessibility
**Where:** your phone, and any Android 13/14/15 device.

**Root cause:** Android 13+ "**Restricted settings**" (Enhanced Confirmation
Mode). When an app is installed from **outside the Play Store** (a sideloaded /
file-manager APK, and on Android 14+ often `adb` too), the OS greys out
Accessibility and Notification access with *"For your security, this setting is
currently unavailable."* The user must open **App info → ⋮ menu → Allow
restricted settings** first.

**What fixes it:**
- **Install from Google Play** → the installer is `com.android.vending`, which is
  trusted, so restricted settings never appears. This is the real fix.
- If staying off-Play: you **cannot** disable this from code (it's an OS security
  gate). You can only ship a clear walkthrough (screenshots for "Allow restricted
  settings").

**Release APK effect:** none. A sideloaded release APK still hits it.

---

### 2. Accessibility turns itself off overnight
**Where:** your phone — works at night, dead by morning.

**Root cause (combination):**
- **OEM battery/memory killers** (MIUI, ColorOS/realme, Samsung, etc.) kill
  background apps when the screen is off for a while. See dontkillmyapp.com.
- **Doze mode** deep-idles the device overnight.
- **"Remove permissions / pause app if unused"** (Android auto-reset) and some
  OEM security apps *revoke* accessibility for apps they consider idle.

**What fixes it (layered — no single 100% fix on aggressive OEMs):**
- **Battery-optimization exemption** — already added
  (`REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`).
- **Foreground service** with a low-priority persistent notification, started by
  the accessibility service, so the process stays resident and is far less likely
  to be killed. (Recommended to add.)
- **OEM Autostart / Auto-launch** enabled for the app (MIUI "Autostart", ColorOS
  "Startup manager", etc.).
- Turn **off** "Pause app activity if unused / remove permissions" for BlockX.
- Ask the user to **lock the app in recents** (OEM one-tap cleaners skip locked
  apps).

**Release APK effect:** small positive — non-`debuggable` release processes are
killed slightly less aggressively than debug, but the OEM killers still apply.

---

### 3. Redmi 9 / MIUI — blocking "works" but the block screen never shows
**Symptom:** the reel/app just closes; with a timer block the user never sees the
block screen. They granted every permission we ask for.

**Root cause:** **Background Activity Launch restrictions.** Since Android 10 the
OS restricts starting an Activity from the background, and **MIUI enforces this
hard.** Our `BlockActivity` is a real Activity launched *from the accessibility
service* (background). On MIUI that launch is silently dropped unless the hidden
permission **"Display pop-up windows while running in the background"** is on. So:
the service successfully backs out of the reel player (that's why it "closes"),
but the block screen Activity never appears → looks like the app just quit. Being
**on a call** makes the OS suppress background full-screen launches even more.

**What fixes it:**
- **Short term / guide:** tell MIUI users to enable *Settings → Apps → BlockX →
  Other permissions → "Display pop-up windows while running in the background"*
  (and "Show on lock screen").
- **Proper fix (recommended):** render the block screen as a **full-screen
  overlay window** (`TYPE_APPLICATION_OVERLAY`, using the `SYSTEM_ALERT_WINDOW`
  permission we already require) instead of — or as a fallback to — starting
  `BlockActivity`. Overlays are **not** subject to background-activity-launch
  limits. Our floating widget already draws an overlay successfully on these same
  phones, which proves the path works. This makes the block screen appear
  reliably on MIUI/ColorOS and even during a call.
  - Trade-off: an overlay doesn't push the blocked app to the background the way
    an Activity does, so the block logic would still need to send the app Home /
    Back behind the overlay. This touches the (currently frozen) blocking
    backend, so it's a deliberate, tested change — see Plan item 1.

**Release APK effect:** none. This is architectural.

---

### 4. realme Narzo (realme UI / ColorOS) — can't grant permission / gets errors
**Root cause:** ColorOS adds its own gates: **Startup Manager** (autostart off by
default), a separate **"Display over other apps"** toggle that can silently reset,
and the same Android-13 restricted-settings gate. If autostart is off, the
service may never rebind after a kill; if the overlay reset, the block screen /
widget can't draw.

**What fixes it:**
- Per-OEM guide: **Startup manager → allow BlockX**, **Auto-launch**, **Display
  over other apps**, battery = "Don't optimize".
- The overlay block screen (item 3) also helps here.

---

### 5. "Other devices will have other errors"
Correct — this is Android fragmentation. There is no build flag that fixes all of
it. The durable strategy is:
- **Overlay block screen** (removes the biggest OEM-specific failure).
- **Foreground service** (removes most overnight kills).
- **In-app Device Setup + live Health check** that detects `Build.MANUFACTURER`
  and shows the exact steps + current status of each permission, so any user can
  self-diagnose. Link dontkillmyapp.com for the long tail.

---

## Debug APK vs Release APK — what actually changes

| | Debug (now) | Release |
|---|---|---|
| `android:debuggable` | true | false |
| Code shrink / R8 / minify | no | yes (smaller, faster) |
| Signing | debug key | **your** release keystore |
| Killed by OEM battery mgr | a bit more | a bit less |
| Restricted settings (sideload) | yes | **still yes** |
| MIUI/ColorOS block-screen issue | yes | **still yes** |
| Overnight accessibility death | yes | **still yes** |

**So building release is necessary for shipping** (signing, size, Play upload) but
is **not** a fix for the OEM problems. Also note: R8 can strip
reflection-referenced code — after building release, **verify** the accessibility
service, the `MethodChannel`, and the block screen all still work (add ProGuard
keep rules if anything breaks).

---

## Google Play considerations (if you publish there)

- **Removes the restricted-settings friction** (item 1) — big UX win.
- Google **heavily scrutinises AccessibilityService use.** You must justify it
  (app-blocking / focus), provide a **privacy policy**, and complete the
  Accessibility/Prominent-disclosure declarations. Blocker apps *can* be rejected
  if the disclosure is weak. Budget time for policy compliance.
- Alternatives: other stores (less friction rules) or keep direct-APK with a
  strong setup guide (but you keep the restricted-settings friction).

---

## Recommended release plan (priority order)

1. **[High] Overlay-based block screen** (fixes MIUI/ColorOS "reel closes, no
   block screen", and the on-call case). Touches the blocking backend → do it
   deliberately with device testing. *Needs your go-ahead.*
2. **[High] Foreground service** for the accessibility service, so it survives
   overnight Doze / OEM killers. Persistent low-priority notification.
3. **[High] Device Setup / Health screen:** detect manufacturer, show per-OEM
   steps (MIUI pop-up + autostart; ColorOS startup manager; battery exemption;
   "allow restricted settings"), plus a live ✓/✗ for accessibility, overlay,
   usage access, battery, and (best-effort) autostart.
4. **[Med] Release signing + build:** create a keystore, wire `signingConfigs`,
   build an AAB/APK, and smoke-test the shrunk build.
5. **[Med] Privacy policy + Play listing** (only if going the Play route).
6. **[Low] Permission auto-reset:** guide users to disable "remove permissions if
   unused", and re-check permissions on app resume (we already refresh some).

---

## What a release build will and won't solve (direct answer)

- **Will:** smaller/faster app, proper signing for distribution, eligibility for
  Play upload, marginally fewer background kills.
- **Won't:** the restricted-settings gate, the MIUI/ColorOS block-screen failure,
  the overnight accessibility shutdown, or realme's startup gate. Those need the
  overlay block screen + foreground service + per-OEM setup guide above.
