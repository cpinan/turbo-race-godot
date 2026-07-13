# Turbo Race — Godot 4

Full rewrite of the original **Turbo Race** endless-runner mobile game from Cocos2d-x/C++ into **Godot 4.7 + GDScript**.

**Goal: behavioral parity.** Same jump physics, same collision rules, same scoring, same obstacle types. No new mechanics.

The original C++ source lives at `../Turbo-Race/` (separate repo). It is the behavioral reference — never modified.

---

## Versions

| Component | Version |
|-----------|---------|
| Godot Engine | 4.7.stable |
| GUT (test framework) | 9.7.0 |
| Android min SDK | 24 (Android 7.0) |
| Android target SDK | 35 (Android 15) |
| App version name | 1.0.0 |
| App version code | 4 |
| Package | `com.carlos.pinan.turborace.godot` |
| GDScript | Static-typed throughout |

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
│   │   ├── base_vehicle.gd         Node2D base; delegates physics to VehiclePhysics.*
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
│       ├── home_screen.tscn/.gd    Logo slide-in, level buttons (pulse anim), sound toggle
│       ├── hud.tscn/.gd            Score label, pause button, joystick thumb, song-now-playing label
│       ├── pause_screen.tscn/.gd   Resume / Restart / Home
│       ├── game_over_screen.tscn/.gd  Score + best-score right of badge, new-record badge (bicho_0003)
│       ├── tutorial_overlay.tscn/.gd  How to Play first-run overlay (dismissed by tap)
│       └── settings_overlay.tscn/.gd  Joypad vs. tilt selection (persisted via SaveManager)
│
├── scripts/
│   ├── physics/                    Pure functions — no Node/scene-tree dependency
│   │   ├── vehicle_physics.gd      Jump arc, collision rects, guards, Y/X clamps
│   │   ├── obstacle_physics.gd     World-rect transform, all three collision checks
│   │   └── world_speed.gd          Speed advance curve, initial speed/distance constants
│   ├── debug_collision_overlay.gd  Debug: draws collision rects on top of sprites (z_index=1000)
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
| `bicho_0001..0004.png` | Player character walk + jump animation frames |
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
| `ic_launcher_192.png` | App launcher icon (192×192) |
| `ic_launcher_foreground_432.png` | Adaptive icon foreground (432×432) |
| `ic_launcher_background_432.png` | Adaptive icon background (432×432, solid #2D2D2D) |
| `game_icon.png` | Splash / store icon |
| `ajustes.png / ajustes_off.png` | Settings gear button (pressed / normal) |
| `controls_options.png` | Control-type panel background |
| `control_joystick.png` | Joystick option button in control panel |
| `control_tilt.png` | Tilt option button in control panel |

### Audio (`resources/audio/`)

| File | Used for |
|------|----------|
| `vg_bt_music.mp3` | Background music — "BT Turbo Tunnel - VGMusic.com" |
| `diego_music.mp3` | Background music — "Music by Diego Rodriguez" |
| `POL-turtle-blues-short.mp3` | Background music — "Turtle Blues - PlayOnLoop.com" |
| `jump.mp3` | Jump SFX |
| `smash.mp3` | Collision/death SFX |
| `swoosh.mp3` | UI transition swoosh |
| `lightning.mp3` | Speed-up SFX |
| `button.mp3` | UI button press SFX |

### Fonts (`resources/fonts/`)

| File | Used for |
|------|----------|
| `Carton_Six.ttf` | Primary display font (score, menus, HUD) |
| `CartonSixBMP.fnt` | Bitmap version for pixel-perfect rendering |

### Levels (`resources/levels/`)

JSON files loaded at runtime by `LevelLoader`. Schema documented in `docs/LEVEL_FORMAT.md`.

| File | Description |
|------|-------------|
| `easy.json` | 665 entries — slow speed (1.0×), codes 0-5/8-9 only, phased ramp from pure singles to mixed doubles |
| `normal.json` | 665 entries — mid speed (1.7×), all obstacle codes 0-9, balanced density |
| `hard.json` | 665 entries — fast speed (2.2×), heavy 6/7/8/9 throughout |
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

> **Note on arc formula:** Cocos2d-x `JumpBy` uses `height * |sin(π * t)|`. A parabola `4t(1-t)` looks similar but is wrong — collision windows differ at t≈0.149 (sine) vs t≈0.129 (parabola). Always use sine.

### Collision system

| C++ | Godot |
|-----|-------|
| `BaseObstacle::collision(vehicle)` | `ObstaclePhysics.check_collision(obs, vehicle)` |
| `SingleObstacle` lane-band guard | `ObstaclePhysics.single_collision()` — y-band test first |
| `AirDoubleObstacle` jump-height guard | `ObstaclePhysics.air_collision()` — airborne_height ≥ 63.0 |
| `DoubleObstacle` two-rect union | `ObstaclePhysics.base_collision()` |
| `ObstaclePool<T>` template | `ObstaclePool` GDScript class (one instance per type) |

**Collision rect tuning vs. C++ source:**
The vehicle ground/air rects are derived from `BaseVehicle::getGroundCollision()` and `getAirCollision()` then adjusted for Godot feel:
- Width reduced 20% horizontally (centered) vs raw C++ values
- Front (right) edge trimmed a further 10% to leave clearance before the character nose
- Use the `debug_collision` export var on `GameScene` to visualise rects at runtime

### World speed

| C++ (`GameLayer.cpp`) | Godot (`world_speed.gd`) |
|----------------------|--------------------------|
| `START_WORLD_SPEED = designWidth * 0.5` | `START_WORLD_SPEED: float = 512.0` |
| `MIN_DISTANCE_OBSTACLES = designWidth / 1.8` | `MIN_DISTANCE_OBSTACLES: float = 568.89` |
| `START_X_OBSTACLES = designWidth * 1.9` | `START_X_OBSTACLES: float = 1945.6` |

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
| Left-half drag → `doMove(Vec2)` (X + Y) | `InputEventScreenDrag` → `do_move(vel)` |
| Right-half tap → `doJump()` | `InputEventScreenTouch` right-half |
| `SneakyJoystickSkinnedBase` thumb visual | `hud.gd _input()` → `_joy_thumb.position` |
| — (Android only addition) | Accelerometer tilt: `accel.y` → vertical, `accel.x` → horizontal; calibrated at game start; dead zone 1.5 m/s², full speed at 5.0 m/s² |
| — (Android only addition) | Settings gear on home screen → control-type panel (joystick / tilt); persisted via `SaveManager.get/set_control_type()` |

### Z-depth ordering

| C++ (`GameDeep` enum) | Godot `z_index` |
|----------------------|-----------------|
| Air obstacle (always front) | `int(WIN_H / 10.0)` = **76** |
| Player (dynamic per lane) | `int((WIN_H - z_param) / 10.0)` ≈ **46** |
| Single obstacle (by lane) | `int((WIN_H - y) / 10.0)` ≈ **39–46** |
| Ground obstacle (behind player) | `int((WIN_H - WIN_H*0.5) / 10.0)` = **38** |

### UI layout — Cocos2d-x center-anchor → Godot Label rects

Cocos2d-x Labels default to center anchor `(0.5, 0.5)`. To convert a C++ label position to a Godot `offset_*` rect:

```
godot_center_y = BG_height - cocos_y_up
godot_center_x = cocos_x  (X axis unchanged)

offset_top    = godot_center_y - label_h / 2
offset_bottom = godot_center_y + label_h / 2
horizontal_alignment = CENTER (1)
```

**Example — game over score labels** (`PopUpLoseLayer.cpp`):
```
BG=520×480, badge=175×128, BG center = Vec2(260, 240)
scoreLabel:  cocos x=347.5, y=227.2  →  Godot center (347.5, 253)  →  top=232 bottom=274
maxScore:    cocos x=347.5, y=191.4  →  Godot center (347.5, 289)  →  top=268 bottom=310
```

**Dynamic-width label formula** (`GameLayer::_showAudioPlaying`):
```cpp
// C++: left anchor, position = visibleWidth - textWidth * 1.1
lblMusic->setAnchorPoint(Vec2(0, 0.5));
lblMusic->setPositionX(visibleWidth - musicSize.width * 1.1);
```
```gdscript
# Godot equivalent — measure after one frame
add_child(lbl)
await get_tree().process_frame
lbl.position.x = maxf(WIN_W - lbl.get_minimum_size().x * 1.1, 0.0)
```

### Y-axis coordinate system

Cocos2d-x is Y-up (origin bottom-left). Godot 2D is Y-down (origin top-left).

Pattern used: set GameScene root `scale = Vector2(1, -1)`, `position = Vector2(0, WIN_H)`. This flips the entire scene so C++ world-space values work unchanged. Every `Sprite2D` child needs a counter-flip `scale.y = -1`. CanvasLayer nodes (UI) are exempt — they bypass the parent transform.

> **Debug overlay:** To visualise collision rects, set `debug_collision = true` on the `GameScene` node. A child `Node2D` with `z_index = 1000` draws green (ground rect), cyan (air rect), and red (obstacle rects) outlines on top of all sprites. **Important:** never implement debug drawing in the parent `_draw()` — it renders behind all children.

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

### Build signed APK (debug / sideload)

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless \
  --export-debug "Android Debug" /tmp/turborace_debug.apk

adb install -r /tmp/turborace_debug.apk
adb shell am start -n com.carlos.pinan.turborace.godot/com.godot.game.GodotAppLauncher
```

### Build signed AAB (Play Store release)

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless \
  --export-release "Android Release" builds/turborace_vN_release.aab
```

### Generate native debug symbols for Play Console

```sh
cd android/build/build/intermediates/merged_native_libs/standardRelease/\
mergeStandardReleaseNativeLibs/out
zip -r /path/to/builds/turborace_vN_symbols.zip lib/
```

Upload the symbols zip under **Native debug symbols** in the Play Console release editor.

### Verify version code baked into AAB

```sh
grep versionCode android/build/build/intermediates/merged_manifests/\
standardRelease/processStandardReleaseManifest/AndroidManifest.xml
```

### Notes

- `export_presets.cfg` is **gitignored** — contains release keystore credentials. Never commit.
- `android/build/src/main/AndroidManifest.xml` is **not git-tracked** (generated by Godot build system). The `android:windowLayoutInDisplayCutoutMode="shortEdges"` and `EdgeToEdge.enable()` call in `GodotApp.java` must be re-applied after reinstalling the android build template.
- Bump `version/code` in **both** presets in `export_presets.cfg` before each Play Store release.
- Play Console warning *"No deobfuscation file"*: safe to ignore for Godot — Java layer is boilerplate; native code is covered by the symbols zip.
- Play Console warning *"Remove orientation restrictions"*: safe to ignore — landscape-only is correct for this game type.

---

## Claude Code skill

This repo ships a [Claude Code](https://claude.ai/code) skill that captures every non-obvious decision made during the migration. If you're porting a different Cocos2d-x game to Godot 4, you can reuse it directly.

**How to use:**

1. Clone this repo (or copy `.claude/skills/cocos2dx-to-godot/SKILL.md` into your own project's `.claude/skills/` folder)
2. Open the project in Claude Code
3. Type `/cocos2dx-to-godot` in any prompt

The skill covers:

- Y-axis flip pattern (Cocos2d-x Y-up → Godot Y-down) and sprite counter-flip
- `JumpBy` sine arc formula — and why a parabola produces wrong collision windows
- Pure physics function architecture (no Node deps = unit-testable)
- Z-depth ordering formula from `GameDeep` enum
- Collision rect fractions (always read from C++ `contentSize` — never guessed)
- All three obstacle collision guards (`SingleObstacle`, `DoubleObstacle`, `AirDoubleObstacle`)
- Unified touch + mouse joystick input pattern
- Cocos2d-x center-anchor UI → Godot Label rect conversion
- Dynamic Label positioning: `await process_frame` + `get_minimum_size()` formula
- Debug collision overlay: child Node2D z_index=1000, not parent `_draw()`
- Android Play Store release: AAB build, symbols zip, version code verification
- Parallax scroll, obstacle pooling, scoring, world speed constants
- Parity verification checklist

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
| `Classes/ui/game/GameLayer.cpp` | Spawning table, world speed, scoring, song label |
| `Classes/ui/game/HudLayer.cpp` | Joystick + tap input, `doMove(Vec2)` call |
| `Classes/ui/gameover/PopUpLoseLayer.cpp` | Game over screen layout (score label positions) |
| `Resources/levels/*.json` | Level parameters (copied verbatim) |
