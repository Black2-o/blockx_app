# Step 3 — Website blocking

> Visiting a blocked domain (e.g. `youtube.com`) in **any** browser shows the block screen; its
> close button returns you to the **browser's** home, not the phone home. This also covers
> **in-app browsers** (links opened inside Messenger/Instagram/etc.) and a **code-only built-in
> blocklist**.

- Prereq: **[STEP-1-APP-BLOCKING.md](STEP-1-APP-BLOCKING.md)** (block screen), and the
  [overview](STEP-0-OVERVIEW.md).
- Main code: `AppBlockerService.kt` (browser + in-app-browser detection),
  `BlockRepository.kt` (`blockedSites` / `isBlockedHost` / `normalizeHost`), `BlockActivity.kt`
  (`MODE_BACK`), `BuiltInBlocklist.kt`, and Flutter `site_store.dart` / `blockedSitesProvider` /
  `sites_screen.dart`.

---

## 1. How it works

The accessibility service can read the on-screen view tree **if configured to**. Website
blocking turns that on and reads the browser's address bar.

### 1.1 Enable content retrieval (the config)

`res/xml/accessibility_service_config.xml` was upgraded to:

```xml
android:accessibilityEventTypes="typeWindowStateChanged|typeWindowContentChanged"
android:canRetrieveWindowContent="true"
android:accessibilityFlags="flagDefault|flagReportViewIds"
```

- `canRetrieveWindowContent="true"` + `typeWindowContentChanged` — lets us read the tree and get
  events as a page navigates within itself.
- **`flagReportViewIds` is required.** Without it, `findAccessibilityNodeInfosByViewId` returns
  nothing and URL reading **silently fails**. This bit us once; it's essential.

No new runtime permission — this is all covered by the existing accessibility grant.

### 1.2 Read the address bar

When a known browser is foreground (`isBrowser`), `checkBrowserUrl` reads the URL:

```kotlin
root.findAccessibilityNodeInfosByViewId("$pkg:id/$suffix")
```

trying each `urlBarIdSuffixes` in order: `url_bar` (most Chromium browsers),
`location_bar_edit_text` (Samsung), `url_field` (Opera), `mozac_browser_toolbar_url_view`
(Firefox), `omnibarTextInput` (DuckDuckGo), `search_box`, `address`.

Then it matches the text against the blocklist with `BlockRepository.isBlockedHost`. On a hit →
`showBlockScreen(pkg, MODE_BACK, "This website is blocked.")`.

---

## 2. Which browsers are covered

`browserPackages` includes: Chrome (+ beta/dev/canary), Brave (+ beta), Edge
(`com.microsoft.emmx`), Opera (+ GX + Mini), Samsung Internet
(`com.sec.android.app.sbrowser`), Vivaldi, Kiwi, DuckDuckGo, Firefox (+ Focus), Mi Browser
(`com.mi.globalbrowser`), realme/Oppo HeyTap (`com.heytap.browser`) & ColorOS, and UC.

**To add a browser:** add its package to `browserPackages` and, if it's not Chromium-based, its
address-bar view-id suffix to `urlBarIdSuffixes`.

---

## 3. The journey — problems and fixes (in order)

### 3.1 First approach: silent bounce (abandoned)
The first version, on a blocked URL, just did `GLOBAL_ACTION_BACK` + a toast — **no screen**. It
technically worked, but a web page **silently vanishing felt buggy** — you couldn't tell what
happened. So we switched to a real block screen.

### 3.2 Blocked while typing (the autocomplete trap)
With a page-URL read, a nasty problem appeared: as you **typed** `tgc.com`, the browser
**autocompleted from history** to a previously-visited blocked `tgc.edu.bd`, so the detector saw
the blocked host and blocked you **before you could navigate** — you literally couldn't reach
`tgc.com`.

**Fix:** only read the address bar when it is **not focused**:

```kotlin
for (node in nodes) {
    if (node.isFocused) continue   // user is typing / a suggestion is showing → ignore
    val text = node.text?.toString()
    if (!text.isNullOrBlank()) return text
}
```

Focused = you're editing (typing/autocomplete). Not focused = a page is actually loaded. So it
only fires **after** you've genuinely visited the site.

### 3.3 Close button → browser home, not phone home
The block screen originally used the app "Go to home screen" (phone home). For websites the
owner wanted to **stay in the browser**. So we added a third block-screen flavour,
**`MODE_BACK`**, whose button is **"Go back"** and calls:

```kotlin
fun goBackAndPause() {                       // in AppBlockerService
    graceUntil = now + 2000                  // pause detection ~2 s
    handler.postDelayed({ performGlobalAction(GLOBAL_ACTION_BACK) }, 200L)
}
```

The block Activity reaches the service through the **`AppBlockerService.instance`** companion
reference (set in `onServiceConnected`, cleared in `onUnbind`). The `graceUntil` pause is
important: after the block screen finishes, the browser is briefly still showing the blocked
page, so we must pause URL checks until the Back lands, or it would instantly re-block.

*(This exact `MODE_BACK` screen is reused for in-app browsers below, and its Back mechanism is
reused for Shorts/Reels in [Step 4](STEP-4-SUBFEATURE-BLOCKING.md).)*

### 3.4 In-app browsers (links opened inside apps)
Tapping a link inside an app opens one of two things:

- **Chrome Custom Tab** — runs under `com.android.chrome`, so the normal browser path already
  catches it. **No extra work.**
- **In-app WebView** — the app's *own* embedded browser; the foreground package stays the app
  (e.g. `com.facebook.orca` for Messenger). The normal path never runs.

So `checkInAppBrowserUrl` handles a set of `inAppBrowserHosts` (Messenger, Messenger Lite,
Facebook, Facebook Lite, Instagram, WhatsApp, X, Snapchat, Reddit, LinkedIn, Telegram, Gmail).
To avoid false-blocking a link merely **mentioned** in a chat/feed, `findBlockedInAppUrl`
requires **two signals together**:

1. an on-screen **`android.webkit.WebView`** (an in-app browser page is genuinely open), **and**
2. a **URL-shaped text node** (`looksLikeUrl`: no spaces, has a dot, sane length) in the **top
   ~30 %** of the screen whose host is blocked.

On a hit → the same `MODE_BACK` screen; the Back it sends closes the in-app browser and returns
you to the chat/feed. Heuristic and app-version-dependent, so `findBlockedInAppUrl` **logs the
top URL it sees when nothing matched** (`in-app browser top url (not blocked): "…"`) for tuning.

### 3.5 A built-in, code-only blocklist
`BuiltInBlocklist.kt` is an **always-on** list the owner edits **in code**:

```kotlin
object BuiltInBlocklist {
    val domains: List<String> = listOf(
        // "pornhub.com",
        // "youtube.com",
    )
}
```

`BlockRepository.blockedSites()` merges it with the user's list, normalizing everything to a bare
host:

```kotlin
return (user + BuiltInBlocklist.domains)
    .map { normalizeHost(it) }
    .filter { it.isNotEmpty() }
    .distinct()
```

Properties: enforced as soon as Accessibility is on (even without opening the app); **cannot** be
removed from the in-app screen (that UI only reflects the Hive box); accepts a bare host, a full
`https://…` link, or a subdomain (all reduced by `normalizeHost`).

---

## 4. Host matching rules

`normalizeHost(input)` → lowercase, strip scheme (`substringAfter("://")`), strip leading
`www.`, drop path/query/fragment. So `https://www.YouTube.com/feed` → `youtube.com`.

`isBlockedHost(urlText)` → `hostMatches(text, site)` for each blocked host, matching it as a
**whole host token**:

- ✅ `youtube.com` blocks `youtube.com`, `m.youtube.com`, `youtube.com/feed`.
- ❌ does **not** block `notyoutube.com` or `youtube.company`.

It checks the character *before* the match isn't a letter/digit/`-` (a `.` is allowed, for
subdomains) and the character *after* isn't a letter/digit/`-`/`.`.

---

## 5. Flutter side

- **`data/site_store.dart`** — Hive box `blocked_sites` (`Box<String>`, one entry per domain,
  key == value).
- **`providers/block_providers.dart`** — `blockedSitesProvider`
  (`StateNotifier<List<String>>`): `addSite` / `removeSite`, with a Dart `normalize()` that
  mirrors the native one (bare host). Mirrors to native via `BlockPlatform.setBlockedSites` →
  `blocked_sites_json`.
- **`screens/sites_screen.dart`** — text field + **Add**, list with delete. Opened from the
  **globe** icon in the home AppBar.

---

## 6. Pieces to know

| Piece | Where |
|---|---|
| enable tree reading | `accessibility_service_config.xml` (`flagReportViewIds`!) |
| read the URL (skip focused bar) | `AppBlockerService.readBrowserUrl` |
| browser detection | `browserPackages`, `urlBarIdSuffixes`, `checkBrowserUrl` |
| in-app WebView detection | `inAppBrowserHosts`, `findBlockedInAppUrl`, `looksLikeUrl` |
| host matching | `BlockRepository.isBlockedHost` / `hostMatches` / `normalizeHost` |
| block screen (back to browser) | `BlockActivity` `MODE_BACK`, `goBackAndPause`, `instance` |
| built-in list | `BuiltInBlocklist.kt`, merged in `blockedSites()` |
| Flutter | `site_store.dart`, `blockedSitesProvider`, `sites_screen.dart` |

Next: **[STEP-4-SUBFEATURE-BLOCKING.md](STEP-4-SUBFEATURE-BLOCKING.md)**.
