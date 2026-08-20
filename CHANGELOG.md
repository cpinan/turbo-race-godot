# Changelog

All notable changes to Turbo Race (Godot port) are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

## [Unreleased]

### Added
- **Web build variants for portal distribution.** Three web export presets
  selected by Godot custom feature tags: the default one for our own channels
  (itch.io, GitHub Pages) which shows a "Get it on Google Play" button on the
  home, pause and game-over screens, plus `crazygames` and `gamedistribution`
  variants that carry
  that portal's ad SDK and suppress the store link — both portals restrict
  outbound links and forbid third-party ad code, so one build cannot serve both.
  New `autoload/web_portal.gd` (inert off-web, same guard pattern as
  `AdManager`), generated per-portal HTML shells, `tools/build_web.sh`,
  `tools/gen_web_shells.py`, and 17 tests. See `docs/WEB_PORTALS.md`
- `docs/WEB_PORTALS.md` — portal-by-portal requirements, the size analysis, and
  revenue expectations

### Changed
- **Web download cut from 19.4 MB to 13.6 MB gzipped.** The AdMob addon's ~7 MB
  of Android-only `.aar` payload was shipping to every browser player; web
  presets now exclude it along with the test suite and GUT (`index.pck`
  10.9 MB → 5.4 MB). Background music re-encoded 160 → 96 kbps joint-stereo
  (2.83 MB → 1.70 MB), which shrinks the Android build too
- `play/` and `builds/` now carry `.gdignore` — both live inside the project, so
  Godot was re-importing the previous web export's own PNGs and shipping them
  back inside the next `.pck`

---

## [1.4.0] — 2026-08-06

### Fixed
- **Obstacles could spawn invisible and harmless**: once a pool ran past its prefill count, `ObstaclePool.acquire()` returned an un-parented node, so `_ready()` never ran — the obstacle rendered nothing, could never collide, still awarded score, and poisoned the pool for the rest of the session. Reachable on every level (normal mode overran two pools by ~2x). Growth-path instances are now parented; prefills raised to 16/16/16
- **Player hitbox was 38% smaller than the original**: 1.0.0 shipped "tuned" collision rects (`w*0.355 / w*0.34`) against the C++ and `SPEC.md` values of `w*0.30 / w*0.55`, widening jump-timing slack by ~21%. Restored; the four unit tests that had been rewritten to assert the tuned values are re-derived from spec
- **Lane changes made mid-jump were reverted on landing**, and while airborne the air and ground hitboxes tracked different lanes. The jump arc now rides the live `player_y` each frame, matching Cocos2d-x `JumpBy`'s additive behaviour
- **Hard mode ran with 4 obstacle groups in flight instead of 10**: initial spawn counted obstacles where `GameLayer::_initElements` counts groups
- **Playfield was 9 units short at the top lane** (`[201, 282]` instead of `[210, 300]`): `compute_y_limits()` was fed pre-adjusted lane values, applying its transform twice
- **Player rested 4 units below the intended floor** until first input: `do_move()` was skipped on neutral input, but its zero-velocity path is what clamps `player_y` into range
- **Jump arc was a sine, not a parabola**: Cocos2d-x `JumpBy::update` is `height * 4 * frac * (1 - frac)` (verified against the cocos2d-x-4.0 engine source). Sine and parabola agree at t = 0, 0.5 and 1 — exactly the points the old tests checked — and differ everywhere between (0.7071 vs 0.75 of peak at t = 0.25)
- **Depth ordering was quantised to 10px buckets**: the player tied with bottom-lane walls and rendered in front of ground obstacles it was colliding with. Restored to the C++ `int(WIN_H - z_param)` at 1px granularity; background layers now carry explicit z values, and player depth is set at spawn/restart rather than only from the first physics tick

### Added
- **Ground shadows**, ported from C++ and previously missing entirely (both assets were imported but referenced nowhere). The player shadow marks `player_y` — the value the ground hitbox and `SingleObstacle`'s lane-band test both use — so the player can now see which lane they occupy while airborne. The air-obstacle shadow drifts at 2x world speed, the fake-perspective cue that distinguishes a floating obstacle from a ground one
- Mid-air death fall from `BaseVehicle::dead()`
- `tests/regression/test_collision_parity_fixes.gd` — 11 tests, each failing against 1.3.0 behaviour
- `tests/regression/test_spec_constants_match_code.gd` — reads `docs/SPEC.md` at runtime and fails if the document and the physics layer disagree on collision-rect fractions, jump constants, arc shape, map lengths or level multipliers. Both the hitbox regression and the level-map redesign survived three releases because the tests were rewritten to match the drifted code; editing one without the other is now a build failure (166 tests total)

### Changed
- **Level maps restored to the C++ originals** (665 → 133 entries for easy/normal/hard; story was already identical). The 1.1.0 "difficulty-tuned" maps were a redesign that pushed easy's first must-jump obstacle from 25s to 142s into a run and dropped type-2 obstacles from hard mode entirely. Speed/distance/acceleration multipliers were already identical and are unchanged
- Obstacle pool prefills re-sized for the restored maps: 24 single / 18 ground / 18 air

### Known issues
- At 133 entries the map loops roughly every 133 obstacles — sooner than the 665-entry redesign did. Matches the original; a longer-form variant is a possible future milestone
- Tilt control remains a redesign of the C++ accelerometer curve, so tilt and joystick players sit on different difficulty curves while sharing leaderboards

---

## [1.3.0] — 2026-07-25

### Added
- **In-app review prompt** (Google Play Core Review API via `ReviewService` autoload + `InappReviewPlugin`/`GMPShared` addons): shown once-ever, gated to the first game-over on or after the 3rd completed game
- **Playable web demo** hosted on GitHub Pages (`play/`, Godot 4.7.1 web export, no-threads), embedded on the landing page + "Play in browser" CTA — self-hosted, no itch.io dependency
- **Keyboard controls** (WASD/arrows + Space) for web/desktop builds; on-screen joystick and how-to-play button hidden on non-Android where keyboard covers both

### Fixed
- In-app review gate used an exact-match check (`!= 3`) instead of a threshold (`< 3`) — a player already past game 3 at release would never be prompted; now opens on the first eligible game-over
- Game-over/pause buttons showed a stuck focus highlight after returning to the menu (screens are hidden not freed, so Godot's focus outline never cleared) — fixed via `focus_mode=0`
- Android target API bumped 35→36 (Android 16) — required by Google Play policy; apps not within 1 year of the latest Android release lose update ability after Aug 30, 2026

### Technical
- `com.google.android.gms:play-services-ads` bumped 24.9.0→25.0.0 — mitigates a Play Console "deprecated edge-to-edge API" warning traced to Google's own UMP consent SDK
- Privacy policy updated to disclose AdMob/GPGS data collection; `app-ads.txt` added for AdMob authorized-seller verification
- Local Android build template synced to 4.7.1.stable to match engine version
- Play Console's resizability/orientation and R8-minification recommendations evaluated and deliberately deferred — both carry real regression risk for non-blocking warnings; findings in `docs/MIGRATION_NOTES.md`

---

## [1.2.0] — 2026-07-14

### Added
- **AdMob banner ad** (poingstudios/godot-admob-plugin v4.3.1): Leaderboard format (728×90dp), centered at top of screen; hidden during gameplay, shown on HOME/PAUSE/GAME_OVER
- **Interstitial ad** every 5 games: full-screen ad shown after game-over when `total_games_played % 5 == 0`; reloads immediately after dismissal; fire-and-forget, never blocks gameplay
- **GDPR/UMP consent flow** — runs before SDK init; falls through gracefully if AdMob console misconfigured
- **AdManager autoload** — state-driven banner show/hide; Android-only guard ensures headless tests pass
- **133 unit tests** (126 existing + 5 new AdManager interstitial tests + 2 others)
- **GitHub Pages landing site** (`index.html`) — dark theme, Play Store CTA, feature grid, gameplay stats, tech stack
- **README**: Play Store badge, site link, Phase 7 migration entry

### Fixed
- Banner left-margin gap caused by device camera notch: switched from adaptive full-width to fixed 728×90dp (LEADERBOARD) which centers on screen, avoiding the 161px safe-area inset
- Jekyll overriding GitHub Pages `index.html`: added `.nojekyll` to serve raw HTML

### Technical
- Plugin GDScript classes loaded via `load()` at runtime inside `OS.has_feature("android")` guard — prevents parse errors in headless/CI mode
- AARs committed to `addons/admob/android/bin/` for reproducible builds (plugin .gitignore patched)
- Ad unit IDs: banner `ca-app-pub-8297579382369512/5828422617`, interstitial `ca-app-pub-8297579382369512/7768190242`

---

## [1.1.0] — 2026-07-13

### Added
- **Google Play Games Services** (GodotPlayGameServices v3.2.0): sign-in, leaderboard submit, achievement unlock
- **20 achievements** ported from `GameLayer::_checkAchievements()` — exact C++ rule table, same thresholds
- **3 leaderboards** (Easy / Normal / Hard) — score submitted every game-over
- **Achievements + leaderboard buttons** on HomeScreen (Android-only, bottom-left)
- **Settings button** (Android-only, bottom-right) — joystick vs tilt control selector
- **Accelerometer tilt control** — calibrated dead-zone, dual-axis mapping, toggle persisted in SaveManager
- **AchievementChecker autoload** — 20-rule engine, local dedup + GPGS submission with sign-in guard
- **Cumulative stats** in SaveManager: total games, total score, total jumps, average score
- **Levels expanded 5×**: easy/normal/hard each 665 entries (was 133), difficulty-tuned obstacle mix
- **Debug collision overlay** with accelerometer values when tilt mode active

### Fixed
- GPGS sign-in infinite loop: `_signing_in` bool guard prevents re-entrant `signIn()` calls
- Achievement lost when GPGS unavailable: local unlock mark only written when `is_signed_in() == true`
- App ID placeholder in `game_ids.xml` replaced with correct numeric project ID

### Technical
- LeaderboardService uses `Engine.get_singleton("GodotPlayGameServices")` directly (bypasses wrapper double-init guard)
- Both debug (Godot default cert) and release SHA-1 fingerprints registered in Play Console

---

## [1.0.0] — 2026-07-08

### Added
- Full gameplay parity with Cocos2d-x original: vehicle movement, jump arc, obstacle collision, scoring
- Three difficulty levels (Easy / Normal / Hard) loaded from JSON
- All three obstacle types: SingleObstacle, DoubleObstacle, AirDoubleObstacle
- VehicleFrog with idle animation, jump arc (parabola 140-unit peak / 0.6 s), death blink + texture swap
- Y-up coordinate system matching Cocos2d-x center-anchor collision math
- Obstacle pool (10 slots) with automatic recycling
- HomeScreen: logo slide-in, level button pulse animations, sound toggle
- HUD: score label (obstacles_avoided), pause button, virtual joystick, song-now-playing label
- PauseScreen: resume / restart / home
- GameOverScreen: score + best display, restart / home
- How-to-Play tutorial overlay (first-run flow)
- Music rotation (3 tracks), SFX, mute — persisted via SaveManager
- Best score per level persisted via SaveManager
- Android adaptive icon (bee/wasp), edge-to-edge display, cutout mode
- Virtual joystick: left-half drag → lane movement, right-half tap → jump
- 110 unit + regression tests via GUT, CI on every push

### Technical
- Pure-function physics layer (`scripts/physics/`) — zero scene-tree dependency, fully unit-testable
- GUT test framework; headless CI run
- Collision rects tuned: 20% narrower centered, front edge trimmed 10% (matches C++ feel)

---

## [0.x] — Phases 0–2 (internal milestones, not released)

- Phase 0: Repo setup, GUT, CI
- Phase 1: Spec extraction from C++ source → `docs/SPEC.md`, golden-run fixtures
- Phase 2: Physics/collision pure functions + full test suite
