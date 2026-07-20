# Launch posts — final, paste-ready

Finalized versions of the templates in `LAUNCH_KIT.md`. Copy directly.
Attach `docs/assets/turbo_race_gameplay.gif` to every post — motion out-converts
a static link. If a platform rejects/strips the GIF (file-size cap, no-GIF
upload), fall back to the static image named per post below.

**Links**
- Play: https://play.google.com/store/apps/details?id=com.carlos.pinan.turborace.godot
- Site: https://cpinan.github.io/turbo-race-godot/
- Repo (confirm public before linking): https://github.com/cpinan/turbo-race-godot
- Web demo (after itch upload): `https://<user>.itch.io/turbo-race`

**Assets (exact filenames)**
- GIF (primary attach, all posts): `docs/assets/turbo_race_gameplay.gif` (1.74 MB — same file also at `playstoreassets/marketing/turbo_race_gameplay.gif`)
- Static image (fallback if GIF can't upload): `docs/assets/hero.png` (same image as `playstoreassets/marketing/01_hero_jump.png`)

**Universal tips**
- Post when you can reply for the first hour — early engagement drives reach.
- Read each sub's self-promo rules; set the right flair.
- Reply as a dev; steer comments to the game/tech, not "please download".

---

## 1. r/godot   *(dev audience — the migration story)*

**Flair:** `Selfpromo (games)`

**Title:**
```
I rewrote my old Cocos2d-x/C++ mobile game in Godot 4.7 — full parity port
```

**Body:**
```
A few years back I shipped a small endless runner, Turbo Race, in Cocos2d-x/C++.
I just finished porting the whole thing to Godot 4.7 + GDScript, aiming for 1:1
behavioral parity — same jump arc, same collision rules, same scoring, no new
mechanics.

Things that kept it faithful:
- Extracted every gameplay constant from the C++ source into a spec doc first,
  no guessing.
- Kept all physics/collision as pure functions (plain input -> output) so I could
  unit-test them against the original logic — 140 GUT tests, all green.
- Matched Cocos2d-x's Y-up world by flipping the root node (scale.y = -1), which
  touched more than I expected.
- Reproduced the old JumpBy action as a hand-rolled parabolic arc (fixed height +
  duration).

Trickiest bits were the coordinate flip and getting the jump/collision to feel
identical. Sits on top of GPGS leaderboards, AdMob, and UMP consent on Android.

It's free on Play, and I'm putting a browser build on itch next. Happy to answer
anything about the port process.

Play: https://play.google.com/store/apps/details?id=com.carlos.pinan.turborace.godot
```
**Attach:** `docs/assets/turbo_race_gameplay.gif` (fallback: `docs/assets/hero.png`).

---

## 2. r/AndroidGaming   *(player audience)*

**Title:**
```
Turbo Race — a free tilt-or-tap endless runner I just relaunched
```

**Body:**
```
Free, offline-friendly, no ads during actual gameplay. Ride a rocket sled, jump
the walls, dodge the spikes, and chase a high score.

- Tilt your phone to steer, or use the on-screen joystick
- Three difficulties: Easy, Medium, Hard
- Global leaderboards + 20 achievements (Google Play Games)
- Quick pick-up-and-play runs

Rebuilt from the ground up in Godot 4.7. Would love feedback on the difficulty
balance and which control scheme feels better.

https://play.google.com/store/apps/details?id=com.carlos.pinan.turborace.godot
```
**Attach:** `docs/assets/turbo_race_gameplay.gif` (fallback: `docs/assets/hero.png`).

---

## 3. r/playmygame  /  r/IndieGaming  /  r/gamedev (Feedback Friday)

**Title:**
```
[Mobile] Turbo Race — endless runner, feedback on feel & controls welcome
```

**Body:**
```
Endless runner: time your jumps, dodge spikes, survive longer. Built in Godot 4.7
(parity port of my old Cocos2d-x/C++ game). Free on Android.

After feedback specifically on: jump timing, tilt vs joystick, and the first 30
seconds of onboarding. Thanks for playing!

Play: https://play.google.com/store/apps/details?id=com.carlos.pinan.turborace.godot
```
**Attach:** `docs/assets/turbo_race_gameplay.gif` (or web demo link once live; fallback image: `docs/assets/hero.png`).

---

## 4. Godot Discord — #showcase   *(short blurb)*
```
Just shipped my Cocos2d-x -> Godot 4.7 port: Turbo Race, a tilt/tap endless
runner. Full parity port with pure-function physics + 140 GUT tests. Free on Play,
browser build on itch soon.
https://play.google.com/store/apps/details?id=com.carlos.pinan.turborace.godot
```
**Attach:** `docs/assets/turbo_race_gameplay.gif` (fallback: `docs/assets/hero.png`).

---

## 5. Discord (indie/mobile servers) — #self-promo
```
Turbo Race — free tilt-or-tap endless runner on Android. Rocket sled, spikes,
high scores, leaderboards. Rebuilt in Godot 4.7. Feedback welcome!
https://play.google.com/store/apps/details?id=com.carlos.pinan.turborace.godot
```
**Attach:** `docs/assets/turbo_race_gameplay.gif` (fallback: `docs/assets/hero.png`).

---

## Posting log (track to avoid double-posting / measure reach)

| Date | Channel | URL of post | Notes / result |
|------|---------|-------------|----------------|
|      | r/godot |             |                |
|      | r/AndroidGaming |     |                |
|      | r/playmygame |        |                |
|      | Godot Discord #showcase | |             |
|      | itch.io |             |                |
