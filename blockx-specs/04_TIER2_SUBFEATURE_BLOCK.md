# Tier 2 — Sub-Feature Blocking (Reels / Shorts)

## Goal
Let the parent app (Instagram, Facebook, YouTube) stay usable while blocking
just one internal feature. **This tier has no domain-blocking equivalent —
it must inspect the on-screen view hierarchy**, because sub-feature traffic
shares the same domains as normal traffic (see architecture discussion —
DNS/VPN cannot distinguish a Reel from a regular post).

## Mechanism
Extend `BlockAccessibilityService` (same service as Tier 1, don't spin up a
second one) to, for a small set of "watched" packages, walk the active
window's node tree looking for known Reels/Shorts view signatures.

```kotlin
private val watchedPackages = setOf(
    "com.instagram.android",
    "com.facebook.katana",
    "com.google.android.youtube"
)

override fun onAccessibilityEvent(event: AccessibilityEvent) {
    val pkg = event.packageName?.toString() ?: return
    if (pkg !in watchedPackages) return
    if (!subFeatureRuleEnabled(pkg)) return

    val root = rootInActiveWindow ?: return
    if (NodeMatchers.isOnReelsOrShorts(pkg, root)) {
        performGlobalAction(GLOBAL_ACTION_BACK)
        // optional: brief overlay toast "Reels blocked" instead of silent back
    }
}
```

## NodeMatchers — per-app detection rules
Two matching strategies, used together (id match preferred, text/description
as fallback since ids churn across app updates more than labels):

1. **Resource-id match** — walk `AccessibilityNodeInfo` tree, check
   `viewIdResourceName` against a known list, e.g.:
   - Instagram Reels tab/player: ids containing `clips_viewer` / `reel_viewer` / `clips_tab`
   - YouTube Shorts: ids containing `reel_player` / `shorts_container`
   - Facebook Reels: ids containing `reels_player` / `video_home_reels`
2. **Content-description / text fallback** — search visible text/labels for
   strings like `"Reels"`, `"Shorts"`.

**These exact ids must be captured by you, per app version, using
`uiautomatorviewer` or Android Studio Layout Inspector** — open the app to
the Reels/Shorts screen and inspect the live tree. Store the discovered ids
in a simple config so they're updatable without recompiling:

```jsonc
// assets/subfeature_matchers.json (bundle + allow override via app-writable copy)
{
  "com.instagram.android": {
    "resourceIds": ["clips_viewer_view_pager", "reel_viewer_container"],
    "textFallbacks": ["Reels"]
  },
  "com.google.android.youtube": {
    "resourceIds": ["reel_player_page_container", "shorts_container"],
    "textFallbacks": ["Shorts"]
  },
  "com.facebook.katana": {
    "resourceIds": ["reels_player_fragment"],
    "textFallbacks": ["Reels"]
  }
}
```

## Config surface in Flutter (Sub-Feature Screen)
- Same shell as other screens. List = the 3 watched apps (extendable
  later), each row is app icon + name + a **toggle switch** ("Block Reels" /
  "Block Shorts") instead of add/remove — no free-text input needed here
  since the target list is fixed and curated by you.
- Small helper text under each row: "May need occasional updates if
  [App] changes its layout" — sets expectations per our earlier discussion.

## Maintenance workflow (document this for future-you)
1. App update breaks detection (Reels stops getting blocked).
2. Open the app to Reels/Shorts, connect via `adb`, run
   `uiautomatorviewer` or use Layout Inspector in Android Studio.
3. Find the new resource-id(s) for the Reels/Shorts container.
4. Update `subfeature_matchers.json`, rebuild/redeploy the APK to your
   device (or, if you build a remote-config fetch later, just push the
   updated JSON — not required for v1 given single-user/no-store scope).

## Acceptance criteria
- [ ] Scrolling into Reels/Shorts within the app triggers a back-navigation
      within ~1 second, without blocking the rest of the app.
- [ ] Toggling a sub-feature rule off in-app stops enforcement immediately
      (no service restart required).
- [ ] False positives (blocking normal feed content) are rare — verify by
      manually using each app for a few minutes with the rule on.
