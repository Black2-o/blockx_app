# 04 — Responsive & Breakage Rules

This is the section that fixes the previous attempt's problem: **"the UI breaks
when I rotate the phone, on different screen sizes, and scrolling breaks / times
break."** These rules are mandatory for every screen. Most breakage comes from a
handful of anti-patterns — ban them once, in the shared shell, and no individual
screen can reintroduce them.

---

## 1. The root causes (what was breaking, and why)

| Symptom | Root cause | Rule that fixes it |
|---|---|---|
| Overflow (yellow/black stripes) on rotate | fixed heights + `Column` with no scroll; landscape has less vertical space | §2 every page scrolls; §4 no fixed heights |
| Content under the notch / nav bar | no `SafeArea` | §3 SafeArea in the shell |
| Bottom content hidden by keyboard | no `resizeToAvoidBottomInset` / not scrollable | §5 keyboard rules |
| Huge gaps / stretched on tablet & landscape | full-width unconstrained content | §6 max-width clamp |
| Text clipped when user has large font size | fixed-height rows, no wrapping, `maxLines:1` | §7 text scaling |
| "Scroll breaks" — jitter, double scrollbars, can't reach items | nested scrollables (a `ListView` inside a `Column`/`ScrollView`) | §8 single scroll owner |
| RenderFlex / `Row` overflow | rigid `Row` children without `Expanded`/`Flexible` | §9 flex rules |

---

## 2. Every page scrolls

Every screen body is inside a scroll view (`SingleChildScrollView`,
`ListView`, or `CustomScrollView`). Even short screens (Splash aside) — because a
short screen in portrait can be a too-tall screen in landscape or with large
text. **No screen is a bare non-scrolling `Column` that fills the height.**

---

## 3. `AppScaffold` — the one responsive shell

Build `lib/widgets/app_scaffold.dart` once; every screen uses it. It centralizes
all responsive behavior so screens can't get it wrong:

- `Scaffold(backgroundColor: dark, resizeToAvoidBottomInset: true)`
- `SafeArea` (top + bottom) wrapping the body.
- A **scroll owner** (the page's single scrollable) — screens pass slivers or a
  child column; the shell owns the scroll.
- The **max-width clamp** (§6).
- Consistent 16 edge padding.
- Optional pinned header + optional bottom nav slot.

Screens supply content; they never re-implement SafeArea/scroll/clamp.

---

## 4. No fixed heights for content

- Never hard-code a `SizedBox(height: X)` to size a content region or force a
  layout. Fixed spacing tokens (§1 of design system) are fine; fixed **content**
  heights are not.
- Cards/rows size to their content. Use `mainAxisSize: MainAxisSize.min`.
- The block-screen (native) centers content in a `LinearLayout` with
  `Gravity.CENTER` — that's already height-agnostic; keep it.

---

## 5. Keyboard handling (Sites, App Picker, Account, Config)

- `resizeToAvoidBottomInset: true` (in `AppScaffold`).
- Text-entry screens keep their input reachable: the field is in the scroll view
  (or pinned with the list scrolling under it, as in App Picker), never in a
  region the keyboard can cover.
- Add bottom padding equal to `MediaQuery.viewInsets.bottom` where a CTA sits
  under a field, so the button rides above the keyboard.

---

## 6. Max-width clamp (tablets, foldables, landscape)

- Clamp readable content to a max width (~**520dp**) and center it. On phones this
  is a no-op; on tablets/landscape it prevents lines stretching edge-to-edge and
  huge empty side gaps.
- Lists may go full-width; **forms and centered hero content** get the clamp.

---

## 7. Text scaling & wrapping

- Respect the OS font-size setting but **clamp** the scale factor to a sane range
  (e.g. `MediaQuery.textScaler` clamped to ≤ ~1.3) via a `MediaQuery` override at
  the app root, so a 2× system font can't shatter every layout — while still
  honoring accessibility to a reasonable degree.
- Titles/labels that could clip use `maxLines` + `TextOverflow.ellipsis`; body and
  answers **wrap freely** (no maxLines). Never rely on a single line fitting.
- Honor the **14sp floor** (design system §1) — small text is the first thing to
  clip.

---

## 8. Single scroll owner (fixes "scroll breaks")

- **One** scrollable per screen. On the dashboard Home, the whole page is one
  `CustomScrollView`/`ListView`; the apps list is rendered as **items/slivers in
  that same scrollable**, not a nested `ListView`.
- If a nested list is unavoidable, it uses `shrinkWrap: true` +
  `NeverScrollableScrollPhysics()` so it participates in the parent's scroll
  instead of fighting it.
- Never put a `ListView`/`GridView` with its own scroll directly inside a
  `SingleChildScrollView`/`Column` — that is the classic "scroll breaks / infinite
  height" crash.

---

## 9. Flex & row rules

- Any `Row` with text + a trailing control puts the text in `Expanded`/`Flexible`
  so it truncates/wraps instead of overflowing (list rows, the Sites add-row, the
  header count badge).
- `Wrap` for chip groups (mode chips, number chips) so they flow to the next line
  instead of overflowing on narrow screens.

---

## 10. Orientation

- No screen assumes portrait. Because every page scrolls (§2) and clamps width
  (§6), landscape "just works": content scrolls, forms center.
- Splash and block screens are centered columns — orientation-agnostic already.
- Do **not** lock orientation to dodge the problem; fix the layout instead.

---

## 11. Test matrix (verify before calling a screen done)

Check each screen at:

- Small phone portrait (~360×640) and large phone portrait.
- **Landscape** of the above (the previous breakage hotspot).
- Tablet width (~800dp) — clamp + centering behave.
- **Large system font** (1.3×) — no clipping/overflow.
- Keyboard open on every text-entry screen.
- The apps/sites lists both **empty** and **long enough to scroll**.

A screen isn't "done" until it passes this matrix — add it to each screen's task
in [05](05-TASK-LIST.md).
