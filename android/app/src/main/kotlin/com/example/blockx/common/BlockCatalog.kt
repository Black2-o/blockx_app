package com.example.blockx.common

/**
 * Static reference data for the blocker — package sets, browser address-bar
 * resource-ids, and the in-app feature (Shorts / Reels) detection hints.
 *
 * Pulled out of [AppBlockerService] so that file stays focused on *behaviour*
 * rather than long lookup tables. This is data only; changing it doesn't change
 * any logic. [AppBlockerService] keeps short aliases onto these.
 */
object BlockCatalog {

    // System / overlay / game-space packages that must never be treated as
    // "the foreground app" (see AppBlockerService.isIgnoredPackage, which also
    // catches any "gamespace"/"gameassistant" variant by substring).
    val ignoredPackages = setOf(
        "com.android.systemui",
        "com.google.android.play.games",
        "com.google.android.gms",
        "com.oplus.games",
        "com.oplus.gamespace",
        "com.coloros.gamespaceui",
        "com.coloros.gamespace",
        "com.coloros.gameassistant",
        "com.nearme.gamecenter",
    )

    // Apps that open tapped links in their OWN in-app browser (a WebView inside
    // the app), so the foreground package stays the app, not Chrome. Links that
    // open a Chrome Custom Tab instead run under com.android.chrome and are
    // caught by the normal browser path.
    val inAppBrowserHosts = setOf(
        "com.facebook.orca",       // Messenger
        "com.facebook.mlite",      // Messenger Lite
        "com.facebook.katana",     // Facebook
        "com.facebook.lite",       // Facebook Lite
        "com.instagram.android",   // Instagram
        "com.whatsapp",            // WhatsApp
        "com.twitter.android",     // X / Twitter
        "com.snapchat.android",
        "com.reddit.frontpage",
        "com.linkedin.android",
        "org.telegram.messenger",
        "com.google.android.gm",   // Gmail
    )

    // Known browsers whose address bar we watch. Most Chromium browsers expose
    // the URL under an "url_bar" id; the others use their own toolbar ids.
    val browserPackages = setOf(
        "com.android.chrome",
        "com.chrome.beta",
        "com.chrome.dev",
        "com.chrome.canary",
        "com.brave.browser",
        "com.brave.browser_beta",
        "com.microsoft.emmx",            // Edge
        "com.opera.browser",
        "com.opera.gx",
        "com.opera.mini.native",
        "com.sec.android.app.sbrowser",  // Samsung Internet
        "com.vivaldi.browser",
        "com.kiwibrowser.browser",
        "com.duckduckgo.mobile.android",
        "org.mozilla.firefox",
        "org.mozilla.focus",
        "com.mi.globalbrowser",
        "com.heytap.browser",            // realme/Oppo browser
        "com.coloros.browser",
        "com.UCMobile.intl",
    )

    // Candidate resource-id suffixes for the address bar, tried in order.
    val urlBarIdSuffixes = listOf(
        "url_bar",                        // Chrome/Brave/Edge/Vivaldi/Kiwi/...
        "location_bar_edit_text",         // Samsung Internet
        "url_field",                      // Opera
        "mozac_browser_toolbar_url_view", // Firefox
        "omnibarTextInput",               // DuckDuckGo
        "search_box",                     // some OEM browsers
        "address",                        // fallback
    )

    // Feature-blocking: the parent app package → in-app feature key.
    val featureApps = mapOf(
        "com.google.android.youtube" to "yt_shorts",
        "com.instagram.android" to "ig_reels",
        "com.facebook.katana" to "fb_reels",
    )

    val featureLabels = mapOf(
        "yt_shorts" to "YouTube Shorts",
        "ig_reels" to "Instagram Reels",
        "fb_reels" to "Facebook Reels",
    )

    // Player-specific view-id fragments (matched as case-insensitive substrings),
    // kept narrow so the normal feed / a Shorts shelf / an inline reel preview
    // doesn't trigger. Tuned from real logcat (logFeatureCandidates).
    val featureIdHints = mapOf(
        "yt_shorts" to listOf("reel_recycler", "reel_player", "reel_watch", "shorts_player"),
        // Only the full-screen Reels swipe pager — an inline reel in a DM/feed
        // lacks the pager, so viewing a chat doesn't get blocked.
        "ig_reels" to listOf("clips_viewer_view_pager"),
    )

    // Content-description signals, for apps that expose no useful view-ids.
    // Facebook obfuscates every id, so its Reels surface is identified by these
    // ("Search reels" header + the immersive "…swipe up to see more" reel), which
    // do NOT appear on the normal feed or the bottom-nav Reels tab button.
    val featureDescHints = mapOf(
        // Facebook has TWO reels entry points:
        //  - the BOTTOM-nav reels feed (you're watching) → "search reels" catches
        //    it immediately;
        //  - the TOP reels *tab list* after stories (just browsing thumbnails) →
        //    identified by "Selected Reels tab" / "tab 2 of 6"; this must NOT be
        //    blocked, so we deliberately do NOT match "selected reels tab".
        // Watching an actual reel (from either, or Messenger) → "reel details"
        // (immediate) / "swipe up to see more" (delayed backup).
        // The top list has neither "search reels" nor "reel details", so it's
        // left alone; the home/stories don't match any of these either.
        "fb_reels" to listOf("search reels", "reel details", "swipe up to see more"),
    )
}
