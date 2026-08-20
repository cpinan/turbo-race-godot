# Web distribution & monetization — portals playbook

Companion to `WEB_BUILD_SETUP.md` (how to export) and `MARKETING_PLAN.md` (strategy).
This doc is about **where the web build goes and how it earns**.

Status as of 2026-08-20. Rev-share percentages and program terms are the single
most volatile thing here — **re-verify each portal's current terms on its
developer page before signing anything**. Figures below are directional.

---

## 1. Current artifacts

Build every variant with:

```sh
tools/build_web.sh all          # or: owned | crazygames | gamedistribution
```

| Variant | Zip | Shell | Size (gzipped transfer) |
|---|---|---|---|
| `owned` — itch.io, Pages, your site | `builds/turbo-race-web-1.4.0.zip` | Godot default | **13.6 MB** |
| `crazygames` | `builds/turbo-race-web-crazygames-1.4.0.zip` | `web/shells/crazygames.html` | 13.6 MB |
| `gamedistribution` | `builds/turbo-race-web-gamedistribution-1.4.0.zip` | `web/shells/gamedistribution.html` | 13.6 MB |

`index.html` sits at each zip root, which is what every HTML5 portal expects.
`play/` (the GitHub Pages copy) is synced from the `owned` build.

**Export was slimmed on 2026-08-20**, from 19.4 MB gzipped to 13.6 MB:

- `exclude_filter="tests/*, addons/gut/*, addons/admob/*, web/*, tools/*"` on all
  three web presets. The AdMob addon alone was ~7 MB of Android-only `.aar`
  payload shipping to every browser player. `index.pck`: **10.9 MB → 5.4 MB**.
- `resources/audio/vg_bt_music.mp3` re-encoded 160 → 96 kbps joint-stereo:
  **2.83 MB → 1.70 MB**. This shrinks the Android build too.
- `play/.gdignore` and `builds/.gdignore` — both directories live inside the
  project, so Godot was re-importing the previous web export's own PNGs and
  shipping them back inside the next `.pck`.

`GodotPlayGameServices` and `InappReviewPlugin` are deliberately **not** excluded:
`project.godot` autoloads GPGS by uid, and excluding it risks a boot-time autoload
failure. They are ~500 KB combined — not worth the risk.

Verified: the slimmed build boots and plays in desktop Chrome; 184/184 tests pass.

---

## 2. The size problem (the one real blocker)

13.6 MB gzipped is fine for itch and Newgrounds. It is **borderline for
CrazyGames and likely disqualifying for Poki**, both of which judge on
time-to-first-play on a mid-range phone on mobile data.

Breakdown of the 13.6 MB:

| File | gzipped |
|---|---|
| `index.wasm` (Godot engine) | **9.6 MB** |
| `index.pck` (game) | 3.9 MB |
| `index.js` | 0.1 MB |

The game is not the problem — the engine is. Two-thirds of the download is
Godot itself, and no asset optimisation touches it.

**The fix, if a portal rejects on load time:** compile custom web export
templates with the unused engine modules stripped. For a 2D endless runner:

```sh
scons platform=web target=template_release \
      disable_3d=yes \
      module_webrtc_enabled=no module_websocket_enabled=no \
      module_multiplayer_enabled=no module_camera_enabled=no \
      module_csg_enabled=no module_gridmap_enabled=no \
      module_navigation_enabled=no module_openxr_enabled=no \
      optimize=size lto=full
```

`disable_3d=yes` plus `optimize=size` is where the bulk of the win is. Expect
roughly 9.6 → 5–6 MB gzipped; that has to be measured, not assumed. Cost is a
one-off SCons toolchain setup (emscripten) plus a full re-test of the build,
since a custom template is a different binary than the one currently verified.

Do this **only when a portal actually asks for it.** It is not needed for itch,
Newgrounds, or the GitHub Pages page.

The cheap asset-side wins are already taken (see §1). What is left in the pck is
mostly textures; squeezing them further trades visible quality for well under a
megabyte, so the engine template is the only lever that still matters.

---

## 3. Portals, ranked by effort vs. return

### Tier 1 — publish now, this week, zero code changes

**itch.io** — free, instant, no review.
- Upload `builds/turbo-race-web-1.4.0.zip`, kind = HTML, tick "play in browser".
- Viewport 960×540, Fullscreen button ON, Mobile friendly ON.
- SharedArrayBuffer support **OFF** — this is a no-threads build and turning it
  on will break it.
- **Money: effectively zero.** itch's browser-game audience does not pay for a
  free arcade title and there is no ad revenue share. Its value is a permanent
  URL, a devlog channel, and jam/collection discovery.
- Do turn on "Support this game" / pay-what-you-want donations anyway — costs
  nothing. itch's default cut is 10%, configurable by you.

**Newgrounds** — free, instant. **Exposure only — it does not pay.**
- Corrected 2026-08-20. Newgrounds' author ad-revenue-share is a **legacy
  system that is no longer active** (their own monetization page: "regarding
  legacy systems that are no longer active"). The site is moving to an ad-free
  model funded by paid Supporters, with a new rev-share planned only once there
  are enough of them. There is no toggle to enable.
- Fill in the account **Payment Address** anyway: it is what contest prizes pay
  to, and it is already in place if the new rev-share ever launches.
- Audience skews toward exactly this kind of arcade/runner game, so it is still
  worth publishing — as a traffic channel, ranked with itch, not above it.
- Optional: their Medals/Scoreboards API. **Out of scope for now** — the
  leaderboard interface is Android/GPGS-specific and adding a web backend is a
  separate milestone (see `NEXT_MILESTONES.md` M2/M3 reasoning).

**Your own GitHub Pages page** — already live via `play/`, already updated to
1.4.0. This is the only channel where you control the funnel completely and can
put the Play Store CTA anywhere you want.

### Tier 2 — real money, needs SDK work and passes a review

**CrazyGames** (`developer.crazygames.com`) — the best effort-to-revenue ratio
for a solo dev.
- Non-exclusive tier exists, so it does not block the other portals.
- Requires their SDK: gameplay start/stop calls, midgame + rewarded ad hooks,
  and **no third-party ad code** in the build.
- Requires keyboard controls on desktop — ✅ already done (`game_scene.gd:418-421`
  WASD/arrows, `:577` space to jump).
- Restricts outbound links, which conflicts with the Play Store CTA. See §4.
- Human QA review before it goes live; load time is part of that review.

**GameDistribution** (Azerion) — the widest non-exclusive reach.
- One SDK integration, then syndicated to thousands of small portals.
- Low RPM per play, but the plays are volume and you do nothing after upload.
- Non-exclusive by design, stacks with CrazyGames.

**GameMonetize / GamePix** — same model as GameDistribution, same SDK-shaped
work. The variant plumbing in §4 now exists, so adding a third portal is one new
snippet in `web/head/` plus one cloned preset — an hour, not a project.

### Tier 3 — high ceiling, high bar

**Poki** — the highest RPM in the industry, and correspondingly selective.
- They playtest against retention/session metrics before accepting.
- Expect exclusivity pressure. **Read the contract before signing: exclusivity
  here can lock you out of every portal in Tier 2.**
- The 13.6 MB load is a likely rejection reason as-is. Do §2's custom template
  before submitting.
- Realistic assessment: apply, but do not wait on the answer.

**Armor Games, CoolMathGames, Silvergames, Y8** — mostly flat-fee licensing or
site-lock deals rather than rev share. Worth an email once the game is live and
has play numbers to quote. A non-exclusive site-lock license for a game like
this typically lands in the low hundreds of dollars, per site.

**Verify before investing time:** Kongregate's web-portal program and Google's
GameSnacks have both changed shape in recent years. Check whether they are
currently accepting submissions rather than assuming from older guides.

---

## 4. Build variants — built, 2026-08-20

Two goals are in direct conflict:

1. **Your own channels** (site, itch.io) want a loud "Get it on Google Play"
   CTA. The web build is a funnel to the Android install.
2. **Portals** (CrazyGames, GameDistribution, Poki) restrict or forbid outbound
   links, and require *their* ad SDK with no third-party ads.

One build cannot serve both. Variants are selected by Godot **custom feature
tags** (`custom_features=` in the export preset), read at runtime through
`OS.has_feature()` — the same guard pattern `ad_manager.gd`,
`leaderboard_service.gd`, and `review_service.gd` already use for Android.

| Preset | Feature tag | HTML shell | Play CTA | Ads |
|---|---|---|---|---|
| `Web` | *(none)* | Godot default | **yes** — home, pause, game-over | none |
| `Web CrazyGames` | `crazygames` | `web/shells/crazygames.html` | no | CrazyGames SDK |
| `Web GameDistribution` | `gamedistribution` | `web/shells/gamedistribution.html` | no | GD SDK |

### What was added

| File | Role |
|---|---|
| `autoload/web_portal.gd` | Variant detection, CTA gating, gameplay-session + ad calls. Inert off-web. |
| `scripts/ui/play_cta.gd` | Shared "Get it on Google Play" button factory. Returns null and adds nothing when the CTA is not allowed. |
| `web/head/{crazygames,gamedistribution}.html` | Hand-written portal SDK glue. **Edit these.** |
| `web/shells/*.html` | Generated shells. **Never edit — they are overwritten.** |
| `tools/gen_web_shells.py` | Regenerates shells from Godot's own template + the head snippets. `--check` fails on stale. |
| `tools/build_web.sh` | Builds and zips any variant, or `all`. |
| `tests/unit/test_web_portal.gd` | 18 tests: inert off-web, CTA gating, ad pacing, CTA present on all three screens for the owned build and absent on every other target, and CTA labels renderable in the button font. |

### Preset settings — recreate these by hand if needed

`export_presets.cfg` is **gitignored** (it holds the release keystore password in
plaintext, so it must stay out of the repo). That means the three web presets
exist only on this machine. Everything else in this section is committed; the
presets are not. To rebuild them in a fresh checkout, clone the `Web` preset
twice in the editor and set:

| Key | `Web` | `Web CrazyGames` | `Web GameDistribution` |
|---|---|---|---|
| `custom_features` | *(empty)* | `crazygames` | `gamedistribution` |
| `export_path` | `builds/web/index.html` | `builds/web-crazygames/index.html` | `builds/web-gamedistribution/index.html` |
| `html/custom_html_shell` | *(empty)* | `res://web/shells/crazygames.html` | `res://web/shells/gamedistribution.html` |

All three share:

```
platform="Web"
variant/thread_support=false
exclude_filter="tests/*, addons/gut/*, addons/admob/*, web/*, tools/*"
progressive_web_app/enabled=false
```

`variant/thread_support=false` is what lets these run on itch.io and GitHub Pages
without COOP/COEP cross-origin isolation headers. Do not turn it on.

### The façade

GDScript never calls a portal SDK directly. Each shell installs a
`window.TurboPortal` object with a fixed four-method surface —
`isReady`, `gameplayStart`, `gameplayStop`, `requestAd(cb)` — and
`web_portal.gd` reaches it through `JavaScriptBridge.get_interface()`. When a
portal revs its SDK, only that portal's file in `web/head/` changes.

`requestAd`'s callback **must fire exactly once on every path**, including
errors and refusals: GDScript unmutes the audio bus in that handler, so a
dropped callback leaves the game permanently silent. Both snippets have a
`settled` latch, and the GD one adds a 30 s timeout because its SDK signals
completion by event rather than callback and can go quiet on a failed ad frame.

### Before the first GameDistribution build

`web/head/gamedistribution.html` carries `GD_GAME_ID_PLACEHOLDER`. Register the
game in GD's dashboard, paste the real id, then
`python3 tools/gen_web_shells.py && tools/build_web.sh gamedistribution`.
`build_web.sh` warns if the placeholder survives into a build.

### After any Godot upgrade

The shells are generated from the installed export template, so they pin an
engine version (currently 4.7.1.stable). After upgrading Godot:

```sh
python3 tools/gen_web_shells.py       # update GODOT_VERSION in the script first
tools/build_web.sh all
```

### Still untested

The SDK paths have **never run against a real portal SDK** — there is no way to
exercise them before a portal account exists. The GDScript side, the CTA gating,
and the ad pacing are unit-tested; the JavaScript façades are not. Expect to
debug them live during each portal's QA round, and treat the first submission as
the real integration test.

---

## 5. Honest revenue expectations

Ranked by what will actually pay, for this game, at realistic traffic:

0. **Correction, 2026-08-20:** Newgrounds was listed here as paying a small
   amount. It does not — its author ad-revenue-share is retired (see §3). That
   leaves the ad portals as the only web channels that pay anything at all,
   which makes the §4 build variants the only route to web revenue rather than
   one of two.

1. **Google Play + AdMob — already shipped, and still the main earner.**
   Installed users open the app repeatedly; browser players almost never come
   back. Nothing on this page will out-earn the Android build.
2. **CrazyGames + GameDistribution** — a plausible few dollars to low hundreds
   per month, entirely dependent on how many plays the portals send you. Traffic
   is theirs, not yours, and can drop without notice.
3. **Flat-fee site-lock licensing** — lumpy but real money once there is a live
   build and play counts to quote in the email.
4. **itch donations** — treat as zero and be pleasantly surprised.

The web build's highest-value job is **not** ad revenue. It is removing the
install step from "try my game" — for a Reddit or Hacker News post, a portfolio
link, or a press email, a playable URL converts far better than an APK.

---

## 6. Publishing checklist

Assets are already produced — reuse `playstoreassets/marketing/` (8 screenshots,
`turbo_race_gameplay.gif`) and `docs/store-listing/en-US.md` for copy.

**Ready to upload now** (`builds/turbo-race-web-1.4.0.zip`):

- [x] **itch.io — LIVE: https://cpinan.itch.io/turbo-race** (2026-08-20).
      Kind = HTML, "play in browser" on, viewport 960×540, Fullscreen + Mobile
      friendly (landscape) on, SharedArrayBuffer OFF, animated GIF cover,
      donations on, Play Store link in the App-store-links field.
      Store CTA verified working from inside itch's iframe — that was the real
      risk, since an iframe blocks `window.open()` without `allow-popups` and a
      dead CTA looks identical to a working one.
- [x] **Newgrounds — LIVE: https://www.newgrounds.com/portal/view/1047972**
      (2026-08-20, under judgment). Same zip, 960×540 embed, touchscreen
      friendly on, gamepads off (no `InputEventJoypad` handling exists),
      SharedArrayBuffer off, Allow Embedding on.
      No revenue to enable — see §3, the author ad-revenue-share is retired.
      Payment Address is on file for contest prizes.
- [x] Own site: `play/` serves 1.4.0 with the Play CTA on home, pause and
      game-over; "Also playable on itch.io" strip live on the landing page
- [x] "Also playable on" strip links both itch.io and Newgrounds
- [ ] **Test on a real phone browser** — iOS Safari and Android Chrome. Godot 4
      web is memory-hungry and audio-fragile on mobile, and portal traffic is
      majority mobile. Genuinely untested right now.

**Needs an account before it can proceed:**

- [ ] CrazyGames: register, submit `builds/turbo-race-web-crazygames-1.4.0.zip`,
      re-verify the v3 SDK surface in `web/head/crazygames.html` first
- [ ] GameDistribution: register, paste the real game id into
      `web/head/gamedistribution.html`, regenerate shells, rebuild, upload
- [ ] Poki: apply. Expect the §2 custom engine template to be required, and read
      the exclusivity terms before signing — they can void everything above.
- [ ] Armor Games / CoolMathGames / Silvergames / Y8: email once the game is
      live somewhere and there are play counts to quote

**Verify, do not assume:** Kongregate's web-portal programme and Google's
GameSnacks have both changed shape in recent years. Check they are currently
accepting submissions rather than trusting an older guide.
