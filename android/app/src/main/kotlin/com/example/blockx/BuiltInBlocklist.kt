package com.example.blockx

/**
 * Always-on website blocklist, baked into the app.
 *
 * ────────────────────────────────────────────────────────────────────────────
 *  HOW TO USE: add one domain per line inside [domains] below, then rebuild.
 * ────────────────────────────────────────────────────────────────────────────
 *
 * These sites are blocked in ADDITION to anything added in the app. They are
 * enforced as soon as the BlockX accessibility service is enabled (you don't
 * even need to open the app), and they CANNOT be removed from the in-app
 * "Blocked websites" screen — the only way to change them is to edit this file
 * and rebuild.
 *
 * You can paste any form — a bare domain ("youtube.com"), a full link
 * ("https://www.youtube.com/feed"), or a subdomain ("m.youtube.com") — it is
 * reduced to the bare host automatically. Blocking a host also blocks its
 * subdomains and paths (e.g. "youtube.com" also blocks "m.youtube.com" and
 * "youtube.com/watch"), but NOT look-alikes like "notyoutube.com".
 */
object BuiltInBlocklist {
    val domains: List<String> = listOf(
        // ── Add your permanent blocks here, one per line, e.g.: ──
        // "pornhub.com",
        // "xvideos.com",
        // "youtube.com",
        // "instagram.com",
        "tgc.edu.bd",
    )
}
