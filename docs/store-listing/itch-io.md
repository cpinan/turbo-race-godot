# itch.io + Newgrounds listing — web build

**Live:** https://cpinan.itch.io/turbo-race (published 2026-08-20)

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

### Description  (itch supports rich text)

```
Ride the rocket sled. Jump the walls, dodge the traps, and see how far you get before you crash.

Turbo Race is a fast, pick-up-and-play endless runner — no tutorial, no waiting, one more try every time.

## Controls
- **Arrow keys** or **WASD** — move
- **Space** — jump
- On touch: drag the left half of the screen to move, tap the right half to jump

## Features
- **Endless action** — the obstacles never stop and the run never ends
- **Three difficulties** — Easy, Normal and Hard, each with its own obstacle density and speed curve
- **Local high score** per difficulty — beat your own best
- **Instant play** — runs in the browser, nothing to install

## Want the full version?
The Android build adds **global leaderboards**, **20 achievements**, and **tilt steering** — steer by tilting your phone instead of using the joystick.

👉 [Get it on Google Play](https://play.google.com/store/apps/details?id=com.carlos.pinan.turborace.godot)

---

Built in Godot 4 as a full rewrite of the original Cocos2d-x game. Source: [github.com/cpinan/turbo-race-godot](https://github.com/cpinan/turbo-race-godot)
```

### Tags  (itch allows up to 10)
```
arcade, endless-runner, casual, singleplayer, high-score, pixel, 2d, html5, godot, mobile
```

### Classification / metadata
- **Kind of project:** HTML
- **Release status:** Released
- **Genre:** Action → Platformer / Arcade
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
| Mobile friendly | **on** | |
| **SharedArrayBuffer support** | **OFF** | this is a no-threads build — turning it on breaks it |

### Cover image
`playstoreassets/marketing/turbo_race_gameplay.gif` (1.8 MB, animated, loops).
itch's cover slot is 630×500; an animated cover meaningfully lifts click-through
over a static one.

### Screenshots
Use `01_hero_jump`, `02_dodge`, `04_difficulty`, `07_speed`, `08_nearmiss` from
`playstoreassets/marketing/`. **Skip `05_leaderboard`** — that feature is not in
the web build.

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

## After both pages are live

1. Uncomment the "Also playable on" strip in `index.html` and paste the real URLs
2. Rebuild nothing — that strip is on the landing page, not in the game
3. Commit, push; GitHub Pages redeploys in about a minute
