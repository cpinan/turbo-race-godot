# Turbo Race — Godot 4

Full rewrite of the original **Turbo Race** endless-runner mobile game from Cocos2d-x/C++ into **Godot 4.7 + GDScript**.

**Goal: behavioral parity.** Same jump physics, same collision rules, same scoring, same obstacle types. No new mechanics.

The original C++ source lives at `../Turbo-Race/` (separate repo). It is the behavioral reference — never modified.

---

## Requirements

- Godot 4.7.x ([godotengine.org](https://godotengine.org/download))
- No other runtime dependencies — GUT test framework vendored in `addons/gut/`

---

## Quick start

```sh
git clone git@github.com:cpinan/turbo-race-godot.git
# Open Godot 4.7 editor → Import → select project.godot
# Press F5 to run
```

---

## Running tests

```sh
godot --headless --path . \
  -s addons/gut/gut_cmdln.gd \
  -gdir=res://tests -gprefix=test_ -ginclude_subdirs -gexit
```

CI runs this on every push via `.github/workflows/tests.yml`.
Current status: **116 tests, 116 passing.**

---

## Project structure

```
turbo-race-godot/
├── addons/
│   └── gut/                        GUT test framework (vendored, v9.7.0)
│
├── autoload/                        Godot autoloads (singletons)
│   ├── audio_manager.gd            Music + SFX playback, mute support
│   ├── game_manager.gd             Global game state machine + signals
│   ├── leaderboard_service.gd      Google Play Games Services interface (Android only)
│   ├── level_loader.gd             LevelData cache (JSON → LevelData struct)
│   ├── save_manager.gd             Persistent settings (control mode, mute, best scores)
│   └── score_model.gd              Score autoload: obstacles_avoided × 100, emits score_changed
│
├── scenes/
│   ├── main/
│   │   ├── main.tscn               Root scene — holds GameScene, HUD, PauseScreen, GameOverScreen
│   │   ├── main_controller.gd      Scene orchestration: Home → Game → Pause/GameOver → back
│   │   ├── game_scene.tscn         Gameplay node tree
│   │   └── game_scene.gd           Spawning, parallax, per-frame collision + score, joystick input
│   │
│   ├── vehicles/
│   │   ├── base_vehicle.gd         CharacterBody2D; delegates physics to VehiclePhysics.*
│   │   └── vehicle_frog.gd         VehicleFrog subclass (bicho sprites, 12/10 fps walk/jump anim)
│   │
│   ├── obstacles/
│   │   ├── base_obstacle.gd        Node2D base; collision delegates to ObstaclePhysics.*
│   │   ├── single_obstacle.gd      Lane-band wall (muro_2b.png)
│   │   ├── double_obstacle.gd      Ground jump obstacle (obstaculo_1.png)
│   │   ├── air_double_obstacle.gd  Air obstacle — lethal only at jump apex ≥ 63 units
│   │   └── wide_obstacle.gd        Phase 4 extension proof (no base class changes needed)
│   │
│   └── ui/
│       ├── home_screen.tscn/.gd    Logo slide-in, level buttons, sound toggle, settings overlay
│       ├── hud.tscn/.gd            Score label, pause button, animated joystick thumb
│       ├── pause_screen.tscn/.gd   Resume / Restart / Home
│       ├── game_over_screen.tscn/.gd  Score display, best-score badge, Restart / Home
│       └── settings_overlay.tscn/.gd  Joypad vs. tilt selection (persisted via SaveManager)
│
├── scripts/
│   ├── physics/                    Pure functions — no Node/scene-tree dependency
│   │   ├── vehicle_physics.gd      Jump arc, collision rects, guards, Y/X clamps
│   │   ├── obstacle_physics.gd     World-rect transform, all three collision checks
│   │   └── world_speed.gd          Speed advance curve, initial speed/distance constants
│   └── data/
│       ├── score_model.gd          GameScore data class (class_name GameScore)
│       ├── level_data.gd           LevelData struct + JSON loader + schema validation
│       ├── lane_layout.gd          Track geometry proportions (derived from LaneLayout.hpp)
│       └── obstacle_pool.gd        ObstaclePool<T> — mirrors C++ template pool
│
├── resources/
│   ├── assets/                     Sprites and UI textures (see Assets section below)
│   ├── audio/                      Music tracks and sound effects (see Assets section below)
│   ├── fonts/                      CartonSix TTF + bitmap font
│   └── levels/                     easy.json / normal.json / hard.json / story.json
│
├── tests/
│   ├── unit/                       Pure-function unit tests (VehiclePhysics, ObstaclePhysics, etc.)
│   └── regression/
│       └── fixtures/               Golden-run JSON: fixed input sequences + expected survive/die outcome
│
└── docs/
    ├── SPEC.md                     All game constants extracted from C++ source (no guessing)
    ├── ARCHITECTURE.md             System design and layer explanations
    ├── MIGRATION_NOTES.md          C++ symbol → GDScript mapping for every ported class
    ├── MIGRATION_PLAN.md           Phase-by-phase plan with Definition of Done per phase
    ├── LEVEL_FORMAT.md             Level JSON schema for level authors
    └── LEADERBOARD_SETUP.md        Plugin install, Play Console config, sign-in flow
```

---

## Assets

All assets are direct ports from the original Cocos2d-x `Resources/` folder.

### Sprites (`resources/assets/`)

| File | Used for |
|------|----------|
| `bicho_0001..0004.png` | Player character (frog) walk + jump animation frames |
| `shadow.png` | Player ground shadow |
| `cielo.png` | Sky background (parallax layer 0, slowest) |
| `background_1.png` | Mid background (parallax layer 1) |
| `background_2.png` | Far background detail (parallax layer 2) |
| `pista.png` | Track / road surface |
| `nube.png` | Cloud sprite (parallax decoration) |
| `humo.png` | Exhaust smoke particle |
| `muro_2b.png` | SingleObstacle — lane-band wall |
| `obstaculo_1.png` | DoubleObstacle — ground jump obstacle (variant A) |
| `obstaculo_1_b.png` | DoubleObstacle variant B |
| `obstaculo_1_c.png` | AirDoubleObstacle — air obstacle (variant C) |
| `obstaculo_1_d.png` | AirDoubleObstacle variant D |
| `sombra_obstaculo_1c.png` | Shadow for air obstacle C |
| `sombra_obstaculo_1d.png` | Shadow for air obstacle D |
| `logo.png` | Game logo (home screen) |
| `gameover_screen.png` | Game-over panel background |
| `pause_screen.png` | Pause panel background |
| `pause.png / pause_off.png` | Pause button normal/pressed |
| `pause_play.png / pause_play_off.png` | Resume button |
| `pause_replay.png / pause_replay_off.png` | Restart button |
| `pause_home.png / pause_home_off.png` | Home button in pause screen |
| `easy.png / easy_off.png` | Easy mode button |
| `medium.png / medium_off.png` | Normal mode button |
| `hard.png / hard_off.png` | Hard mode button |
| `sound_on.png / sound_on_off.png` | Sound toggle — on state |
| `sound_off.png / sound_off_off.png` | Sound toggle — off state |
| `joystick.png` | Joystick background ring |
| `joy_L.png` | Joystick thumb (draggable indicator) |
| `control_joystick.png` | Joystick mode icon in settings |
| `control_tilt.png` | Tilt mode icon in settings |
| `controls_options.png` | Settings overlay background |
| `tap.png` | Tap-to-jump hint icon |
| `tilt_icon.png` | Tilt sensor icon |
| `chart.png / chart_off.png` | Leaderboard button |
| `btn_chart_2.png / btn_chart_2_off.png` | Leaderboard button variant |
| `achievement.png / achievement_off.png` | Achievements button |
| `ajustes.png / ajustes_off.png` | Settings button |
| `tablero_title.png` | Leaderboard panel title |
| `fb-icon.png` | Facebook icon (legacy, not wired) |

### Audio (`resources/audio/`)

| File | Used for |
|------|----------|
| `vg_bt_music.mp3` | Background music track 1 |
| `diego_music.mp3` | Background music track 2 |
| `POL-turtle-blues-short.mp3` | Background music track 3 |
| `jump.mp3` | Jump SFX (plays on `do_jump()`) |
| `smash.mp3` | Collision/death SFX (plays on `die()`) |
| `swoosh.mp3` | UI transition swoosh |
| `lightning.mp3` | Speed-up or obstacle hit SFX |
| `button.mp3` | UI button press SFX |

### Fonts (`resources/fonts/`)

| File | Used for |
|------|----------|
| `Carton_Six.ttf` | Primary display font (score, menus) |
| `CartonSixBMP.fnt` | Bitmap version for pixel-perfect rendering |

### Levels (`resources/levels/`)

JSON files loaded at runtime by `LevelLoader`. Schema documented in `docs/LEVEL_FORMAT.md`.

| File | Description |
|------|-------------|
| `easy.json` | Slow speed, fewer obstacles, wide lanes |
| `normal.json` | Mid difficulty |
| `hard.json` | Fast speed, dense spawning |
| `story.json` | Scripted sequence (same schema) |

---

## C++ parity — what was ported and how

This section maps key C++ classes to their Godot equivalents. Full symbol-level log: `docs/MIGRATION_NOTES.md`.

### Jump physics

| C++ (`BaseVehicle.cpp`) | Godot (`vehicle_physics.gd`) |
|-------------------------|------------------------------|
| `JumpBy::create(0.6f, Vec2::ZERO, 140.0f, 1)` | `jump_arc_offset(t) = 140.0 * sin(t * PI)` |
| `MAX_PLAYER_JUMP = 140.0f` | `MAX_PLAYER_JUMP: float = 140.0` |
| `JUMP_DURATION = 0.6f` | `JUMP_DURATION: float = 0.6` |
| `doJump()` guard: `y <= 1 AND state != Jump` | `can_jump(airborne_height, is_jumping)` |
| `getGroundCollision()` | `ground_collision_rect(pos_x, player_y, w, h)` |
| `getAirCollision()` | `air_collision_rect(pos_x, pos_y, w, h)` |

> **Note on arc formula:** Cocos2d-x `JumpBy` uses `height * |sin(π * t)|`. An earlier port used `4t(1-t)` (parabola), which produces a visually similar but physically different arc — the sine peaks earlier and the collision window for air obstacles differs at t≈0.149 (sine) vs t≈0.129 (parabola). The sine formula is correct.

### Collision system

| C++ | Godot |
|-----|-------|
| `BaseObstacle::collision(vehicle)` | `ObstaclePhysics.check_collision(obs, vehicle)` |
| `SingleObstacle` lane-band guard | `ObstaclePhysics.check_single_collision()` — y-band test first |
| `AirDoubleObstacle` jump-height guard | `ObstaclePhysics.check_air_collision()` — airborne_height ≥ 63.0 |
| `DoubleObstacle` two-rect union | `ObstaclePhysics.check_double_collision()` |
| `ObstaclePool<T>` template | `ObstaclePool` GDScript class (one instance per type) |

### World speed

| C++ (`GameLayer.cpp`) | Godot (`world_speed.gd`) |
|----------------------|--------------------------|
| `START_WORLD_SPEED = designWidth * 0.5` | `START_WORLD_SPEED: float = 512.0` |
| `MIN_DISTANCE_OBSTACLES = designWidth / 1.8` | `MIN_DISTANCE_OBSTACLES: float = 568.89` |
| `START_X_OBSTACLES = designWidth * 1.9` | `START_X_OBSTACLES: float = 1945.6` |
| Speed advance per frame | `advance_speed(current, delta, level_data)` |

### Scoring

| C++ (`ScoreModel.hpp`) | Godot (`score_model.gd`) |
|------------------------|--------------------------|
| `kScoreFactor = 100.0f` | `K_SCORE_FACTOR: float = 100.0` |
| `_obstaclesAvoided` | `ScoreModel.get_obstacles_avoided()` |
| `totalScore = avoided * 100` | `ScoreModel.current_score().total` |
| `_bestScore` per level | `SaveManager` → `user://save.json` |

### Input / Controls

| C++ (`HudLayer.cpp` + `SneakyJoystick`) | Godot (`game_scene.gd` + `hud.gd`) |
|------------------------------------------|-------------------------------------|
| Left-half drag → `doMove(Vec2)` (X + Y) | `InputEventScreenDrag` / `InputEventMouseMotion` → `do_move(vel)` |
| Right-half tap → `doJump()` | `InputEventScreenTouch` right-half / `InputEventMouseButton` right-half |
| `SneakyJoystickSkinnedBase` thumb visual | `hud.gd _input()` → `_joy_thumb.position` |
| Accelerometer tilt → `doMove` | `SaveManager.is_using_joypad()` toggles input path (tilt stub, not yet wired) |

### Z-depth ordering

| C++ (`GameDeep` enum) | Godot `z_index` |
|----------------------|-----------------|
| Air obstacle: `z = 0` (front) | `z_index = int(WIN_H / 10.0)` = **76** |
| Player: `z = WIN_H * 0.5` | `z_index = int((WIN_H - z_param) / 10.0)` ≈ **46** (dynamic) |
| Single obstacle: `z = lane_y` | `z_index = int((WIN_H - y) / 10.0)` ≈ **39–46** |
| Ground obstacle: `z = WIN_H * 0.5` | `z_index = int((WIN_H - WIN_H*0.5) / 10.0)` = **38** |

> Formula: `z_index = int((WIN_H - z_param) / 10)` where WIN_H = 768. Higher z_param → lower z_index → rendered behind.

### Parallax

| C++ (`GameLayer` parallax scroll) | Godot (`game_scene.gd`) |
|----------------------------------|-------------------------|
| 5 layers (`MAX_PARALLAX = 5`) | 5 `Sprite2D` nodes scrolled each frame |
| Speed multiplier per layer | `PARALLAX_SPEEDS: Array[float]` |
| Wrap at `designWidth` | `if sprite.position.x < -WIN_W: sprite.position.x += WIN_W * 2` |

---

## Migration phases

| Phase | Focus | Status |
|-------|-------|--------|
| 0 | Repo & environment setup, GUT, CI | ✅ Done |
| 1 | Spec extraction from C++ → `SPEC.md` + golden-run fixtures | ✅ Done |
| 2 | Physics/collision core (pure functions + 66 unit tests) | ✅ Done |
| 3 | Core loop, obstacle pool, level loader, game manager, all UI screens | ✅ Done |
| 4 | Schema versioning, external level loading, WideObstacle extension proof | ✅ Done |
| 5 | Android leaderboard (Google Play Games Services, graceful degradation) | ✅ Done |
| 6 | Docs finalization, full regression pass — 116/116 tests green | ✅ Done |

---

## Android export

See `docs/LEADERBOARD_SETUP.md` for:
- Installing the `godot-play-game-services` plugin
- Google Play Console setup
- Leaderboard and achievement IDs (these are public resource identifiers, same as in original `Constants.h`)

---

## Key source files in the C++ reference

| C++ file | What it defines |
|----------|----------------|
| `Classes/common/Constants.h` | All game constants (speed, jump, scoring, IDs) |
| `Classes/common/LayoutUtils.hpp` | Lane geometry proportions |
| `Classes/common/ScoreModel.hpp` | Score tracking and factor |
| `Classes/models/BaseVehicle.cpp` | Jump arc, collision rects, move clamping |
| `Classes/models/SingleObstacle.cpp` | Lane-band collision guard |
| `Classes/models/DoubleObstacle.cpp` | Ground obstacle two-rect collision |
| `Classes/models/AirDoubleObstacle.cpp` | Air obstacle jump-height threshold (63 units) |
| `Classes/ui/game/GameLayer.cpp` | Spawning table, world speed, scoring event |
| `Classes/ui/game/HudLayer.cpp` | Joystick + tap input, `doMove(Vec2)` call |
| `Resources/levels/*.json` | Level parameters (copied verbatim) |
