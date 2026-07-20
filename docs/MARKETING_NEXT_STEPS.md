# Marketing — status & remaining work

Handoff doc: what's produced, and the exact remaining actions (mostly user-side).
Companion to `MARKETING_PLAN.md` (strategy) and `LAUNCH_KIT.md` (post templates).
As of 2026-07-19.

## TL;DR
Listing is **published** (P0 done). P1, P4, P5 done (user confirmed). What's left:
P2 (device test) and P3 (web demo — bugs fixed 2026-07-20, ready for upload).

---

## Done (produced in-repo)

| Item | Where |
|------|-------|
| 8 gameplay screenshots (1920×1080) | `playstoreassets/marketing/0[1-8]_*.png` |
| Screenshot generator | `playstoreassets/marketing/generate_frames.py` |
| Real device captures, padded to 16:9 (spare backups) | `playstoreassets/marketing/real/real_0[1-5].png` |
| Gameplay GIF (1.74 MB, loops) | `playstoreassets/marketing/turbo_race_gameplay.gif` + `docs/assets/` |
| GIF generator | `playstoreassets/marketing/generate_gif.py` |
| Marketing README (upload order, GIF preview, site link) | `playstoreassets/marketing/README.md` |
| EN listing copy | `docs/store-listing/en-US.md` |
| Localized copy (es, pt-BR, id, ru, hi) — all title/short verified within Play limits | `docs/store-listing/*.md` |
| In-app review: **InappReviewPlugin addon wired + tested** (140/140 unit, 6/6 regression pass) | `autoload/review_service.gd`, `addons/InappReviewPlugin/`, `addons/GMPShared/`, `docs/IN_APP_REVIEW_SETUP.md` |
| Web build: 4.7.1 templates confirmed, re-exported + smoke-tested (200 on all 3 files) | `builds/web/`, `docs/WEB_BUILD_SETUP.md` |
| README gameplay GIF embed | `README.md` |
| Launch posts (paste-ready, filenames attached) | `docs/LAUNCH_POSTS.md` |
| Posting checklist (assets + places, short form) | `docs/POSTING_CHECKLIST.md` |
| Launch posts / devlog / video hooks | `docs/LAUNCH_KIT.md` |
| Review setup guide | `docs/IN_APP_REVIEW_SETUP.md` |

---

## Remaining work (prioritized)

### P0 — Publish the fixed listing — **DONE** *(user confirmed published)*
Listing live with new screenshots + copy.

### P1 — Launch posts — **DONE** *(user confirmed)*

### P2 — Ship the in-app review native overlay  *(code done; needs device test)*
- Code side is done: `godot-mobile-plugins/godot-inapp-review` (Play Core
  `com.google.android.play:review:2.0.2`) is installed under
  `addons/InappReviewPlugin/`, enabled in `project.godot`, and wired into
  `review_service.gd`. 140/140 unit tests + 6/6 regression tests still pass.
  See `docs/IN_APP_REVIEW_SETUP.md`.
  - [ ] On-device test via Internal App Sharing (overlay is quota-throttled by
        Play by design — pass condition is "no crash", not "dialog appears").
  - [ ] Sanity-check the fallback path: temporarily set `REVIEW_AT_GAME = 1`,
        play one game, confirm the Play listing opens; revert to `3`.
- Bundle this in the **next app release**, not the store-listing update (listing
  changes don't need a new build).

### P3 — Web demo on itch.io  *(export + fixes done; upload is user)*
- [x] 4.7.1 web export templates confirmed installed; re-exported and smoke-tested
      2026-07-19. See `docs/WEB_BUILD_SETUP.md`.
- [x] Web-build bugs found 2026-07-20 during local browser test, fixed same day:
      how-to-play button hidden on web/desktop, WASD/arrow+Space keyboard
      controls added, on-screen joystick hidden on non-Android (keyboard covers
      it), left-click now jumps instead of driving a hidden joystick, game-over
      button stuck-focus-highlight bug fixed (`focus_mode=0`, also applied to
      pause screen). 146/146 tests pass. Re-exported + re-tested locally, confirmed
      working by user.
- [x] Zip built (`builds/turbo-race-web.zip`), ready for itch upload if desired.
- [x] **Self-hosted on GitHub Pages instead of itch** — build copied to `play/`
      at repo root, embedded as an iframe on `index.html` above the fold
      (`#play` section) + "Play in browser" CTA in the hero. Committed
      `e91eace`. Smoke-tested locally (root + `play/index.html` + `.wasm` all
      200). Not yet pushed.
- [ ] Optional: also upload to itch.io for extra discovery — zip is ready,
      not required since Pages hosting covers the "try before install" goal.

### P4 — Localized listings — **DONE** *(user confirmed)*

### P5 — Short-form video — **DONE** *(user confirmed; on Play Store + GitHub)*

---

## Metrics to watch (Play Console, weekly)
- Store-listing **conversion rate** (the ASO scoreboard — should move after P0).
- Rating count/average · install sources · D1/D7 retention.
- Rule: low conversion → iterate screenshots/copy. Good installs, low retention →
  gameplay problem, not marketing.

## Notes
- `export_presets.cfg` was modified (added Web preset) — it's gitignored; never commit
  (contains keystore path). Not committing anything here (repo isn't initialized as git).
- Screenshots are faithful composites of real assets, not live captures — see P0 step 1.
