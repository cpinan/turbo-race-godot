# Handoff brief — remaining marketing work (for Sonnet 5)

Purpose: hand the remaining, well-bounded tasks to a cheaper model (Sonnet 5) so
you burn fewer tokens. Everything needed to execute is inline — **do not re-explore
the repo; use the paths and commands below.**

**How to use:** in Claude Code, `/model` → Sonnet 5, open this repo, then say
*"Read docs/SONNET5_HANDOFF.md and do Task N."* Do one task per request.

---

## Context (read once, don't re-derive)

Turbo Race: an endless-runner mobile game, ported Cocos2d-x/C++ → **Godot 4.7 +
GDScript**, live on Google Play (`com.carlos.pinan.turborace.godot`). Engineering
is complete (140 GUT tests pass). Current effort is **marketing**: the store
listing was refreshed with new gameplay screenshots + copy. Strategy lives in
`docs/MARKETING_PLAN.md`; remaining actions in `docs/MARKETING_NEXT_STEPS.md`;
finalized launch posts in `docs/LAUNCH_POSTS.md`.

## Asset & file map

| What | Path |
|------|------|
| Marketing screenshots (6, 1920×1080) | `../playstoreassets/marketing/0[1-6]_*.png` |
| Screenshot generator (Pillow) | `../playstoreassets/marketing/generate_frames.py` |
| Gameplay GIF + generator | `../playstoreassets/marketing/turbo_race_gameplay.gif`, `generate_gif.py` |
| Promo GIF (from mp4) | `../playstoreassets/marketing/promo_video.gif` |
| Real device captures (2048×920, menus) | `../Marketing/WhatsApp Image *.jpeg` |
| Game sprites | `resources/assets/*.png` |
| Game font (letters+digits only) | `resources/fonts/Carton_Six.ttf` |
| Store copy (EN + 5 locales) | `docs/store-listing/*.md` |
| Review service (code) | `autoload/review_service.gd` |
| Web build + preset | `builds/web/`, `export_presets.cfg` (preset.2 "Web") |

Note: repo root is `turbo-race-godot/`; `playstoreassets/` and `Marketing/` are one
level **up** (`../`). This repo is **not** a git repo — no commits needed.

## Conventions (must follow)

- GDScript, **static typing everywhere** (`var x: float`, `-> void`). Match style of
  neighbouring files.
- Physics/collision stay pure functions. Don't change gameplay behavior (parity project).
- Run tests headless:
  `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gprefix=test_ -gsuffix=.gd -gexit`
  Expect **all pass** before and after any code change.
- **Never** commit or paste the contents of `export_presets.cfg` (holds keystore path).
- Image work uses Python + Pillow (installed). ffmpeg is available via
  `python3 -c "import imageio_ffmpeg;print(imageio_ffmpeg.get_ffmpeg_exe())"`.

---

## Tasks (each self-contained; do one at a time)

### Task 1 — Real captures → clean 16:9 backups  *(assets, ~10 min)*
The 5 device captures are 2048×920 (2.22:1) — too wide for Play (needs 16:9). Pad
them to 1920×1080 with a blurred-fill background (no stretching).
- Input: `../Marketing/WhatsApp Image 2026-07-19 at 17.39.02*.jpeg`
- Output: `../playstoreassets/marketing/real/real_0[1-5].png` (1920×1080)
- Method (Pillow): scale each to fit width 1920 (→1920×864), center vertically on a
  1920×1080 canvas filled with a Gaussian-blurred, upscaled copy of the same image.
- Accept: 5 PNGs, exactly 1920×1080, content undistorted. These are spare backups
  only (the 6 composites remain the primary set).

### Task 2 — Two more composite screenshots (reach 8 phone shots)  *(assets)*
Extend `../playstoreassets/marketing/generate_frames.py` with two new frames in the
same faithful style:
- `07_speed.png` — vehicle low on the track, dense speed-lines, caption `FEEL THE SPEED`.
- `08_nearmiss.png` — vehicle just clearing an `obstaculo_1` with a high HUD score,
  caption `ONE MORE RUN`.
- Reuse existing helpers (`base_scene`, `player_shadow`, `caption_bar`, `hud_score`).
- Caption font has **letters + digits only** — no `/`, `·`, or dashes.
- Accept: two new 1920×1080 PNGs render via `python3 generate_frames.py`, on-brand,
  no tofu glyphs. Verify by eye.

### Task 3 — Finalize the web build  *(build; only after templates installed)*
Prereq (human does this): install matching **4.7.1** web export templates
(Godot → Editor → Manage Export Templates).
- Command:
  `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --export-release "Web" builds/web/index.html`
- Smoke test: `cd builds/web && python3 -m http.server 8080`, curl `index.html`,
  `index.wasm`, `index.pck` → all 200.
- Accept: export completes, three files serve 200. Details in `docs/WEB_BUILD_SETUP.md`.

### Task 4 — Wire a specific in-app-review plugin  *(code; only if a plugin is chosen)*
If a Godot in-app-review Android plugin is added under `android/plugins/`:
- Add its singleton name to `_PLUGIN_CANDIDATES` and its review method to the loop in
  `_launch_review()` in `autoload/review_service.gd`.
- Keep the `market://` fallback intact.
- Run the test suite — `tests/unit/test_review_service.gd` must still pass.
- Accept: tests green; no behavior change on non-Android. See `docs/IN_APP_REVIEW_SETUP.md`.

### Task 5 — Localized "what's new" + copy QA  *(text)*
For each file in `docs/store-listing/*.md`, verify title ≤30, short ≤80. For
`hi.md`/`ru.md` note that non-Latin counts must be checked in Play Console. Fix any
overflow by trimming. Accept: every title/short within limits (Latin locales exact).

---

## NOT delegatable (human only — no model can do these)
- Uploading screenshots/copy/translations to **Play Console** (needs login).
- **On-device** tests (review overlay, ads, tilt) — needs a physical Android device.
- **itch.io** upload, YouTube video, Reddit/Discord posting.
- Installing Godot export templates.

## Scope guard
Marketing/assets/docs only. Do **not** touch gameplay logic, obstacle/physics code,
or level data. Don't add features. If a task seems to require gameplay changes, stop
and report instead.
