# Tier 3 — Website / Domain Blocking

## Goal
Permanently block a curated list of domains, no timer, no unlock — "never
visit these sites at all." This is the feature the uploaded HTML mockup
already represents (Blocked Sites screen), so **that screen ships close to
as-is**, just wired to the native VPN layer instead of local-only state.

## Mechanism: local no-op VPN + DNS filtering
- No remote VPN server needed — `DomainVpnService` establishes a local tun
  interface and acts as its own DNS resolver.
- Parse outgoing DNS queries (UDP port 53) captured by the tun interface;
  check the queried hostname against the blocklist; if blocked, respond
  with `0.0.0.0` (or `NXDOMAIN`); otherwise forward to a real upstream DNS
  (e.g. `8.8.8.8`) and relay the response back untouched.

```kotlin
class DomainVpnService : VpnService() {
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val vpnInterface = Builder()
            .addAddress("10.0.0.2", 32)
            .addDnsServer("10.0.0.2")
            .addRoute("0.0.0.0", 0)
            .setSession("BlockX")
            .establish()
        DnsProxy(vpnInterface!!, BlocklistStore.current()).startLoop()
        return START_STICKY
    }
}
```

Use `dnsjava` (plain Java library, works fine on Android, add as a Gradle
dependency — not a Flutter package) to parse/build DNS packets rather than
hand-rolling wire-format parsing.

## Blocklist storage
- JSON file, editable from within the app (the mockup's add/remove UI is
  exactly this):

```json
{
  "blockedDomains": [
    "example-site.com",
    "another-domain.net"
  ]
}
```

- Native side (`BlocklistStore.kt`) loads this on VPN service start and
  whenever Flutter pushes an update via `updateBlockedDomains()`
  (MethodChannel — see architecture doc). Store the canonical file under
  app-internal storage (`filesDir/blocklist.json`), not `assets/`, so it's
  writable at runtime.
- **Subdomain matching:** blocking `example-site.com` should also catch
  `www.example-site.com`, `m.example-site.com`, etc.:

```kotlin
fun isBlocked(host: String, blocklist: Set<String>): Boolean =
    blocklist.any { host == it || host.endsWith(".$it") }
```

## Flutter screen (already designed — from your uploaded mockup)
This spec intentionally matches the HTML you provided 1:1:
- Header: "BLOCKX" wordmark + "STAY LOCKED IN" subtitle, count badge
  ("N BLOCKED") top-right.
- Input row: text field (placeholder `e.g. instagram.com`) + red "+ ADD"
  button. On submit: normalize input (strip `http(s)://`, `www.`, trailing
  slashes/paths — store bare domain only), call
  `NativeBridge.addDomain(domain)`.
- Section header: "Blocked Sites" with fading red gradient line.
- Scrollable list: each row = red dot + domain text + remove (×) button.
  Empty state: 🎯 icon + "No sites blocked yet. Add one above to stay
  focused."
- Footer: "Sites Blocked" stat (count) + "ACTIVE" status pill reflecting
  whether `DomainVpnService` is currently running.

Port the existing HTML/CSS almost directly into Flutter widgets using the
tokens in `01_DESIGN_SYSTEM.md` — this file already nails the intended look,
so treat it as the literal reference implementation for this screen, not
just inspiration.

## Permission requirements
- `BIND_VPN_SERVICE` + user consent via `VpnService.prepare()` intent
  (system dialog, one-time per app unless revoked).
- If another VPN app is active, Android will prompt to switch — surface
  this in-app rather than letting it fail silently (see architecture doc
  edge cases).

## Known limitation to document in-app (footer note or settings screen)
- **DNS-over-HTTPS (DoH) bypass**: some apps/browsers hardcode DoH resolvers
  (e.g. Chrome → Google's DoH), which encrypts DNS queries end-to-end and
  skips your local DNS proxy entirely. If a blocked site ever loads
  unexpectedly, this is why. Fix path (not required for v1): block by IP
  range at the tun interface for specific stubborn domains, or block the
  known DoH provider IPs to force fallback to plaintext DNS.

## Acceptance criteria
- [ ] Adding a domain blocks it (resolves to nowhere / connection fails)
      within a few seconds, without needing to restart the VPN service.
- [ ] Removing a domain unblocks it without a full app restart.
- [ ] Subdomains of a blocked domain are also blocked.
- [ ] VPN status accurately reflects in the footer "ACTIVE"/"INACTIVE" pill.
- [ ] Survives device reboot (VPN restarts automatically, or at minimum
      prompts you once on next unlock).
