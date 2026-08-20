# CrazyGames listing — web build

Paste-ready copy for the CrazyGames Details step. Companion to `itch-io.md`
(itch.io + Newgrounds) and `en-US.md` (Play Store).

## Two hard rules that make this copy different

**1. No links in the description — but there IS a Play Store field.**
Corrected 2026-08-20 against the real submission form: CrazyGames' Details step
has dedicated **Google Play Store / iOS App Store / Steam** link fields, each
with a download count. So the store link belongs there, as structured metadata,
and **not** in the description prose or anywhere inside the game.

This is narrower than "portals forbid store links", which is what earlier notes
here assumed. The in-game CTA still has to stay out — that is why
`web/head/crazygames.html` is a separate build variant — but the funnel is not
dead on CrazyGames the way it first appeared. See `docs/WEB_PORTALS.md` §4.

**2. Do not advertise what the web build lacks.** No leaderboards, no
achievements, no tilt steering — those are Google Play Games / Android features
and do not exist in the browser build.

---

## Short description / tagline
```
Jump the walls, dodge the traps, and chase a new high score in this fast arcade endless runner.
```
`95 chars`

---

## Description
```
Ride the rocket sled through a hostile alien world. The obstacles never stop coming, the speed never lets up, and one mistimed jump ends the run.

Turbo Race is a fast, pick-up-and-play endless runner built for one more try. No tutorial, no waiting — you are moving within a second of the page loading.

Weave between the walls, time your jumps over the spikes, and push your score higher on every attempt. Easy gets you started. Hard will humble you.

FEATURES

• Endless action — obstacles keep coming and the run never ends
• Three difficulties — Easy, Normal and Hard, each with its own obstacle density and speed curve
• Beat your own best — a high score is saved for every difficulty
• Instant play — no download, no account, straight into the game
• Plays on desktop and mobile — keyboard or touch

How far can you get before you crash?
```

---

## Controls / How to play
```
Arrow keys or WASD — move
Space — jump

On touch devices: drag on the left half of the screen to move, tap the right half to jump.
```

---

## Category and tags

- **Category:** Arcade. (Not Racing — there are no opponents and no lap times,
  so players filtering for Racing would arrive with the wrong expectation.)
- **Tags:** `endless runner`, `arcade`, `casual`, `high score`, `jumping`,
  `obstacle`, `reflex`, `skill`, `1 player`

---

## Assets — generated 2026-08-20

CrazyGames wants **three** cover ratios and **two** preview videos, none of
which matched anything we already had. All five are composited from the real
game sprites at full resolution by
`playstoreassets/marketing/generate_crazygames_assets.py`, reusing the layer
order and parallax speeds from `generate_gif.py` / `game_scene.gd`, so the
marketing looks like the actual game.

| File | Spec |
|---|---|
| `cg_cover_1920x1080.png` | landscape 16:9 |
| `cg_cover_800x1200.png` | portrait 2:3 |
| `cg_cover_800x800.png` | square 1:1 |
| `cg_video_landscape.mp4` | 1920×1080, 10s, H.264 |
| `cg_video_portrait.mp4` | 1080×1920, 10s, H.264 |

Composition notes, because they were not obvious:

- **Portrait is composed, not cropped.** The game is landscape-only; cropping
  16:9 to 2:3 pushes either the player or the obstacle out of frame. Instead the
  gameplay runs full-width in a banded strip with the logo above and a tagline
  below, over a blurred darkened backdrop.
- **The hero frame is just *past* the jump apex.** At the exact apex the
  obstacle sits directly under the player and the still reads as "perched on
  it" rather than "clearing it".
- **The square cover uses a vertical gradient, not a shade rectangle.** A flat
  rectangle leaves a hard seam straight across the cover.
- Re-run stills only with `--covers-only`; the full run re-encodes 600 frames.

**Screenshots** (if a screenshot slot exists separately): `01_hero_jump`,
`02_dodge`, `04_difficulty`, `08_nearmiss`. **Skip `05_leaderboard`** — that
feature is not in the web build.

> ⚠️ `playstoreassets/` is **not a git repository**, so this generator — like
> the existing `generate_gif.py` and `generate_frames.py` beside it — is not
> version controlled. Worth moving into the repo if these assets matter.

---

## Reminders for the rest of the form

- Embed **960 × 540**, Touchscreen friendly **on**, gamepads **off** (no
  `InputEventJoypad` handling exists), **SharedArrayBuffer off**.
- Expect *"not eligible for mobile homepage (>20MB)"*. The build is 30 MB raw
  after a custom slimmed engine template; 20 MB is not reachable in Godot 4.
  See `docs/WEB_PORTALS.md` §2.
- Ads are not served during basic launch, so the ad path returns errors with no
  fill. That is handled and has no user-visible effect.
