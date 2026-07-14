# Changelog

All notable changes to Turbo Race (Godot port) are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

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
