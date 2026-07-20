# Launch kit — copy-paste posts & content

Ready-to-post templates for the free channels in `docs/MARKETING_PLAN.md` §4–5.
Attach `docs/assets/turbo_race_gameplay.gif` (or a short clip) to every post —
motion out-converts a static link everywhere.

**Links to reuse**
- Play: https://play.google.com/store/apps/details?id=com.carlos.pinan.turborace.godot
- Site: https://cpinan.github.io/turbo-race-godot/
- Web demo (once on itch): `https://<user>.itch.io/turbo-race`

> Read each community's self-promo rules first. Post as a dev sharing work, reply
> to comments, don't drive-by drop links.

---

## 1. r/godot  (strongest fit — the migration story is on-topic)

**Title:** I rewrote my old Cocos2d-x/C++ mobile game in Godot 4.7 — here's the result

**Body:**
```
A few years ago I shipped a little endless runner called Turbo Race in
Cocos2d-x/C++. I just finished porting the whole thing to Godot 4.7 + GDScript,
aiming for 1:1 behavioral parity — same jump arc, same collision rules, same
scoring.

Some things I did to keep it faithful:
- Pulled every gameplay constant straight from the C++ source into a spec doc
  first, no guessing.
- Kept all physics/collision as pure functions so I could unit-test them against
  the original logic (GUT, 140 tests).
- Matched Cocos2d-x's Y-up world by flipping the root node.

It's live on Play (free), and I'm putting a browser build on itch. Happy to
answer anything about the port — the trickiest parts were the coordinate flip
and reproducing the JumpBy action exactly.

[GIF]  [Play link]  [repo if public]
```

## 2. r/AndroidGaming

**Title:** Turbo Race — a free tilt-or-tap endless runner I just relaunched (Godot)

**Body:**
```
Free, no forced ads during play, offline-friendly. Ride a rocket sled, jump the
walls, chase a high score. Tilt to steer or use the on-screen joystick, three
difficulties, global leaderboards + 20 achievements.

Would love feedback on difficulty balance and controls.

[GIF]  [Play link]
```

## 3. r/playmygame  /  r/IndieGaming  /  r/gamedev (Feedback Friday)

**Title:** [Mobile] Turbo Race — endless runner, looking for feedback on feel & controls

**Body:**
```
Endless runner: time your jumps, dodge spikes, survive longer. Built in Godot 4.7
(port of my old C++ game). Free on Android; browser build here: [itch link].

Specifically after feedback on: jump timing, tilt vs joystick, and first-30-seconds
onboarding. Thanks!

[GIF]  [links]
```

## 4. Godot Discord  #showcase  (short blurb)
```
Just shipped my Cocos2d-x → Godot 4.7 port: Turbo Race, a tilt/tap endless runner.
Full parity port with pure-function physics + 140 GUT tests. Free on Play, browser
build on itch. Details/GIF 👇  [links]
```

---

## 5. Devlog series (dev.to / Hashnode / blog) — outline

Each post ends with the Play link. Pull specifics from the repo docs cited.

1. **"Porting a C++ game to Godot without guessing"** — the spec-first method:
   extract every constant to `SPEC.md` before writing code. (src: `docs/SPEC.md`)
2. **"Matching Cocos2d-x's Y-up world in Godot"** — the root `scale=(1,-1)` flip and
   what it touched. (src: `scenes/main/game_scene.gd`)
3. **"Testable game physics: pure functions + GUT"** — collision as plain
   input→output, 140 regression tests vs the original. (src: `scripts/physics/`, `tests/`)
4. **"Reproducing JumpBy: a parabolic jump arc by hand"** — jump duration/height
   parity. (src: `docs/SPEC.md` §Jump)
5. **"GPGS + AdMob + UMP consent in a Godot Android build"** — the integration
   gotchas. (src: `docs/LEADERBOARD_SETUP.md`, `autoload/ad_manager.gd`)

There's a `cocos2dx-to-godot` skill in `.claude/skills/` — mine it for concrete
before/after snippets.

---

## 6. Short-form video hooks (TikTok / Shorts / Reels)

Record 15–30s with `adb shell screenrecord`, or reuse the GIF loop upscaled.

- "I rebuilt my 5-year-old C++ game in a new engine in [N] days" → gameplay.
- "This bee rides a rocket sled. That's the whole pitch." → near-miss jump.
- "POV: one more run turns into fifty." → high-score climb.
- Text-on-screen first frame = the hook; gameplay fills the rest; end card = Play badge.

---

## 7. README / site embed

README already shows `docs/assets/turbo_race_gameplay.gif`. For the site, put the
GIF + a "Play in browser" button (itch embed) + the Play badge above the fold.
Regenerate the GIF with `playstoreassets/marketing/generate_gif.py`.
```
