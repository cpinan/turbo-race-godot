# Architecture

## The core rule: pure functions + node wrappers

Every piece of gameplay logic that can be unit-tested must live as a **pure static function** in `scripts/physics/` or `scripts/data/`:
- plain inputs (floats, Vector2, Rect2, booleans)
- plain outputs (the same)
- zero dependency on the scene tree, `_process`, or any Node

Scene nodes in `scenes/` call these functions and apply results to their own state.
This is the single most important architectural invariant — it's what makes regression
tests tractable without spinning up a full scene.

---

## Phase 2 — Physics & collision layer

### Pure logic (`scripts/physics/`, `scripts/data/`)

```
VehiclePhysics       Jump arc, can_jump guard, collision rects, Y-limits, X-clamp
ObstaclePhysics      World-rect transform, base/single/air collision, pass predicate
WorldSpeed           Speed advance, initial speed/distance from level params
GameScore            Scoring formula (obstacles × 100), reset
LevelData            JSON loader, level struct
LaneLayout           Track Y-position geometry (playerStartY, wallHeight, lane Ys)
```

### Scene nodes (wrappers)

```
BaseVehicle (CharacterBody2D)
│   Owns state (IDLE/JUMP), player_y, content_size.
│   Calls VehiclePhysics.* for all logic.
│   Tween drives jump arc (parabola: offset = 140 * 4t(1-t), duration 0.6s).
│   Emits: jumped, landed, died.
└── VehicleFrog
        Idle animation: 2-frame toggle at 12 fps.
        Jump frame swap on jumped/landed signals.

BaseObstacle (Node2D)
│   Owns obstacle_type, content_size, _local_rects (set by subclass).
│   collision(vehicle) delegates to ObstaclePhysics.*.
│   do_update(speed_delta) moves obstacle left.
├── SingleObstacle   ObstacleType.SIMPLE, 1 local rect, lane-band guard
├── DoubleObstacle   ObstacleType.JUMP,   2 local rects
└── AirDoubleObstacle ObstacleType.NORMAL, 5 staircase rects, state+height guards
```

### Jump arc

Cocos2d-x uses `JumpBy(0.6s, Vec2(0,0), 140, 1)` — a single-parabola arc.
Godot equivalent: `Tween.tween_method(_apply_jump, 0.0, 1.0, 0.6)` where:
```
offset(t) = 140 * 4 * t * (1 - t)     # peaks at 140 at t=0.5
```
`_jump_start_y` is the sprite-center Y at ground level, so the vehicle returns to exactly that Y when the tween completes.

### Coordinate system

Y increases **upward** to match the Cocos2d-x reference implementation.
`Rect2.position` stores the bottom-left corner of each collision box.
`Rect2.intersects()` is axis-agnostic and works correctly either way.

### Obstacle collision rect transform

All obstacle collision rects are stored in local space (origin = bottom-left of sprite).
`ObstaclePhysics.world_rect(local, pos, size)` translates them to world space by
subtracting half the sprite's size — matching Cocos2d-x center-anchor `(0.5, 0.5)` behavior.

---

## Phase 3 — Core loop, content, pooling, level generator

### Autoloads

```
GameManager      Game state machine (HOME → READY → PLAYING → GAME_OVER).
                 Owns obstacle pool (MAX_OBSTACLES=10), emits game_over signal.
ScoreModel       Holds a GameScore, emits score_changed signal.
LevelLoader      Wraps LevelData.load_level(), exposes current level params.
AudioManager     Music rotation (3 tracks), SFX, mute. play_music() → track name.
SaveManager      ConfigFile persistence: best scores, mute, control type,
                 cumulative stats (total_games, total_score, total_jumps),
                 local achievement unlock state.
```

### Scenes

```
scenes/main/game_scene.gd     Spawning, parallax scrolling, per-frame obstacle updates.
                               Emits entrance_done when opening animation completes.
scenes/main/main_controller.gd Root scene — manages Home→Game→Pause→GameOver transitions.
scenes/ui/home_screen.gd      Logo slide-in, level buttons (easy/normal/hard), sound toggle,
                               Android-only: settings, achievements, leaderboard buttons.
scenes/ui/hud.gd              Score label, pause button, virtual joystick, song-now-playing.
scenes/ui/pause_screen.gd     Resume / restart / home.
scenes/ui/game_over_screen.gd Score + best display, restart / home.
scenes/ui/tutorial_overlay.gd First-run how-to-play overlay; dismissed signal unblocks READY.
```

### Obstacle pool

`GameManager` holds a fixed pool of 10 `BaseObstacle` instances recycled by `game_scene.gd`.
Spawn logic reads obstacle type codes from the level JSON `map` array, cycling when exhausted
(matches `kObstacleTable` cycling in C++ `GameLayer`). Minimum separation enforced via
`MIN_DISTANCE_OBSTACLES = 568.89` (= designWidth / 1.8, from `Constants.h`).

### Level JSON

Three built-in levels (`easy.json`, `normal.json`, `hard.json`) in `resources/levels/`.
Each entry in `map[]` is a 1-digit obstacle-type code; the level wraps cyclically.
Fields: `speedMultiplier`, `distanceMultiplier`, `speedAcceleration`, `maxWorldSpeed`, `map`.
See `docs/LEVEL_FORMAT.md` for the full schema.

---

## Phase 4 — Extensibility

Level files are loaded via `LevelLoader` which first checks `user://levels/` for overrides,
falling back to `res://resources/levels/`. This allows custom level files to be sideloaded
without recompiling the app (author-only — no in-app import UI).

Schema version field (`"version": 1`) reserved in the JSON for future backward-compat handling.
New obstacle or vehicle types: add one new scene file + one GDScript — no base class changes needed.

---

## Phase 5 — Leaderboard & achievements (Android / Google Play Games Services)

### Autoloads

```
LeaderboardService    Platform-agnostic GPGS interface.
                      Uses Engine.get_singleton("GodotPlayGameServices") directly
                      (bypasses GDScript wrapper autoload to avoid double-init).
                      Manages sign-in state (_signed_in, _signing_in loop guard).
                      Methods: submit_score(), show_achievements(), show_all_leaderboards(),
                               show_leaderboard_for_level(), unlock_achievement().
                      All calls are fire-and-forget; failures never block gameplay.

AchievementChecker    Ports GameLayer::_checkAchievements() exactly.
                      Called once per game-over after record_game_result().
                      Reads cumulative stats from SaveManager, evaluates all 20 rules,
                      submits newly-unlocked achievements to LeaderboardService.
                      Guard: only marks achievement locally AND submits to GPGS when
                      is_signed_in() == true (prevents lost achievements when offline).
```

### Sign-in flow

1. `LeaderboardService._ready()` calls `_plugin.isAuthenticated()`.
2. `userAuthenticated` signal fires with `ok: bool`.
3. If `ok == false`, user tapping achievements/leaderboard triggers `_try_sign_in()`.
4. `_signing_in` bool prevents re-entrant calls if `signIn()` returns `userAuthenticated(false)` immediately.

### Achievement deduplication

Local dedup: `SaveManager.is_achievement_unlocked(id)` checked first — skips re-submission
for achievements already confirmed through GPGS. Achievement ID is only written locally
(`SaveManager.mark_achievement_unlocked`) after a successful GPGS submission path (i.e. when
`is_signed_in()` is true). Achievements earned while offline are retried on the next game-over
once the user signs in.

### Leaderboards

Three boards (one per level), IDs from `Constants.h`. Score submitted every game-over;
GPGS deduplicates if not a new personal best. `show_leaderboard_for_level()` opens the
level-specific board; `show_all_leaderboards()` opens the GPGS global board picker.

### Android-only UI

`home_screen.gd` shows three extra buttons only when `OS.has_feature("android")`:
- BtnAchievements (bottom-left) → `LeaderboardService.show_achievements()`
- BtnLeaderboard (bottom-left) → `LeaderboardService.show_all_leaderboards()`
- BtnSettings (bottom-right) → control-type panel (joystick vs tilt)

---

## Control input (Android)

Two modes persisted via `SaveManager.get_control_type()`:

**Joystick:** Virtual joystick overlay. Left-half drag → lane movement (X axis).
Right-half tap → jump.

**Tilt (accelerometer):** Calibration snapshot taken at game start.
- `accel.y` → vertical (top/bottom tilt in landscape) → lane movement
- `accel.x` → horizontal tilt → lane movement (2× multiplier)
- Dead zone: 1.5 m/s². Full speed: 5.0 m/s².
- Jump: right-half screen tap (same as joystick mode).

---

## Test strategy

Framework: **GUT** (Godot Unit Test). 121 tests across 9 scripts.

All pure-logic functions (`scripts/physics/`, `scripts/data/`) are tested directly — no scene
required. Tests run headless in CI on every push.

```
test_vehicle_physics.gd      Jump arc, can_jump, collision rects, Y-limits, X-clamp
test_obstacle_physics.gd     World-rect transform, single/air/double collision predicates
test_world_speed.gd          Speed advance, cap, distance; lane layout proportions
test_score_model.gd          Scoring formula, reset, GameScore struct
test_level_data.gd           JSON load, field parsing, map cycling
test_level_schema.gd         Schema validation, required fields, version field
test_game_manager.gd         State machine transitions, pool management
test_leaderboard_service.gd  Graceful degradation when GPGS unavailable, ID routing
test_achievement_checker.gd  Rule conditions, sign-in guard, local dedup, cumulative stats
```

Run headless:
```
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gdir=res://tests/unit -gprefix=test_ -gsuffix=.gd -gexit
```
