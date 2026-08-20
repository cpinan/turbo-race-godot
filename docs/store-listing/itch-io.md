# itch.io + Newgrounds listing — web build

**Live:** https://cpinan.itch.io/turbo-race (published 2026-08-20)
**Live:** https://www.newgrounds.com/portal/view/1047972 (published 2026-08-20)

Paste-ready copy for the browser build. Companion to `en-US.md` (Play Store).

**The web build is not the Android build.** Leaderboards, achievements, and tilt
steering are Google Play Games / Android features and do not exist in the
browser version (`docs/WEB_PORTALS.md`, `MIGRATION_NOTES.md`). Copy here must not
promise them as web features — that is what the Play Store link is for. Do not
reuse `05_leaderboard.png` on these pages for the same reason.

---

## itch.io

### Title
```
Turbo Race
```

### Short description / tagline  (max 120)
```
Fast arcade endless runner. Jump the walls, dodge the traps, chase a new high score. Free in your browser.
```
`105/120`

### Description

**itch's description box is a rich-text editor, not markdown.** Pasting `##` or
`**` shows the literal characters. This is the plain-text version that was
actually used; bold the two headings with the toolbar if you want them.

```
Ride the rocket sled. Jump the walls, dodge the traps, and see how far you get before you crash.

Turbo Race is a fast, pick-up-and-play endless runner — no tutorial, no waiting, one more try every time.

CONTROLS

Arrow keys or WASD to move. Space to jump.
On touch: drag the left half of the screen to move, tap the right half to jump.

FEATURES

• Endless action — the obstacles never stop and the run never ends
• Three difficulties — Easy, Normal and Hard, each with its own obstacle density and speed curve
• Local high score per difficulty — beat your own best
• Instant play — runs in the browser, nothing to install

WANT THE FULL VERSION?

The Android build adds global leaderboards, 20 achievements, and tilt steering — steer by tilting your phone instead of using the joystick.

https://play.google.com/store/apps/details?id=com.carlos.pinan.turborace.godot

Built in Godot 4 as a full rewrite of the original Cocos2d-x game.
Source: https://github.com/cpinan/turbo-race-godot
```

### Tags  (max 10; itch says not to repeat the genre or the platform)
```
endless-runner, arcade, casual, high-score, singleplayer, 2d, godot, runner, obstacles, mobile
```

### Classification / metadata
- **Kind of project:** HTML
- **Release status:** Released
- **Genre:** `Action`. itch allows exactly one. *Platformer* implies traversal
  (you jump over obstacles on flat ground, there is none) and *Racing* implies
  opponents (there are none) — either would mislead the filter. Precision comes
  from the `endless-runner` tag, which is the pairing itch expects
- **AI generation disclosure:** `No`. Sprites are ports from the original
  Cocos2d-x game; music is credited third-party (VGMusic, Diego Rodriguez,
  PlayOnLoop) — see `README.md` §Assets. The question is about content in the
  game, not tooling used to write code or this page
- **Community:** Comments. Not a discussion board — that is a forum to moderate
  for an audience that does not exist yet
- **Pricing:** No payments, **but enable "Support this game"** (donations). Costs
  nothing and itch's cut is configurable, default 10%
- **App store links:** add the Google Play URL in the dedicated field, not only
  in the body text — itch renders it as a proper badge

### Upload settings — the ones that break it if wrong
| Setting | Value | Why |
|---|---|---|
| File | `builds/turbo-race-web-1.4.0.zip` | `index.html` is at the zip root, which is what itch requires |
| "This file will be played in the browser" | **ticked** | otherwise it uploads as a download, not a playable |
| Viewport | **960 × 540** | 16:9; the game's internal viewport is 1024×768 but it letterboxes cleanly |
| Fullscreen button | **on** | |
| Mobile friendly | **on**, orientation **landscape** | the game is landscape-only |
| **SharedArrayBuffer support** | **OFF** | this is a no-threads build — turning it on breaks it |

### Cover image
**Used: `playstoreassets/marketing/turbo_race_gameplay.gif`** — 720×405, 1.8 MB,
animated.

itch's cover slot is 630×500 and gameplay footage is 16:9; they do not
reconcile. The animated GIF is letterboxed slightly but motion wins
click-through in the browse grid, which is the cover's whole job. A correctly
sized static alternative is at `itch_cover_630x500.png` — generated with
`sips -c 1080 1361` then `sips -z 500 630`, but the centre crop eats the score
badge and clips the obstacle, which is why it was not used.

### Screenshots
**Used: `01_hero_jump`, `02_dodge`, `04_difficulty`, `08_nearmiss`.**

**Skip `05_leaderboard`** — the browser build has no leaderboard, and a player
who clicks in from that shot has been misled. `07_speed` dropped as redundant
with `08_nearmiss`; itch recommends 3–5.

---

## Newgrounds

Same zip, same assets. Differences that matter:

- **Upload as:** Game → HTML5. Same "index.html at zip root" requirement.
- **Join the ad revenue share** during submission — this is the one Tier 1
  channel that pays anything, and it is opt-in, so it is easy to miss.
- **Dimensions:** 960 × 540, scaling allowed.
- **Rating:** Everyone. No violence, no ads in the build itself.
- Newgrounds' audience skews toward exactly this kind of arcade runner, so lead
  the description with the gameplay hook rather than the Play Store link. Keep
  the Play link, but at the bottom.

### Newgrounds description
```
Ride the rocket sled. Jump the walls, dodge the traps, and see how far you get before you crash.

A fast, pick-up-and-play endless runner — no tutorial, no waiting, one more try every time.

Arrow keys or WASD to move, Space to jump.

Three difficulties, endless obstacles, and a local high score to beat. Built in Godot 4 as a full rewrite of the original Cocos2d-x game.

Also on Android with global leaderboards and achievements: https://play.google.com/store/apps/details?id=com.carlos.pinan.turborace.godot
```

---

## Before going public: test the draft

Set visibility to **Draft**, save, and play the page itself — the real build over
itch's CDN, in itch's iframe.

The one that actually matters: **click the store CTA inside the embed.** itch
runs the game in an `<iframe>`, Godot's `OS.shell_open()` compiles to
`window.open()`, and an iframe blocks that without `allow-popups`. A dead CTA
looks identical to a working one until someone clicks it, and the whole install
funnel would be silently broken. Verified working 2026-08-20, in the embed and
in fullscreen.

## After a page goes live

1. Add the link to the "Also playable on" strip in `index.html` — only once the
   page exists. A link to a 404 is worse than no link
2. Rebuild nothing; that strip is on the landing page, not in the game
3. Commit, push; GitHub Pages redeploys in about a minute
