# Turbo Race — Godot 4

Godot 4.7 / GDScript port of the original Cocos2d-x/C++ endless-runner mobile game.
**Goal: behavioral parity** with `../Turbo-Race/` — same jump physics, collision rules, scoring. No new mechanics.

---

## Requirements

- Godot 4.7.x ([godotengine.org](https://godotengine.org/download))
- No other dependencies — GUT test framework vendored in `addons/gut/`

---

## Setup

```sh
git clone <this-repo> turbo-race-godot
# Open Godot editor → Import → select turbo-race-godot/project.godot
```

---

## Running tests

```sh
godot --headless --path . \
  -s addons/gut/gut_cmdln.gd \
  -gdir=res://tests -gprefix=test_ -ginclude_subdirs -gexit
```

CI runs this on every push via `.github/workflows/tests.yml`.  
Current: **116 tests, 116 passing.**

---

## Project structure

```
addons/
  gut/                      GUT test framework (vendored, v9.6.0)
  godot-play-game-services/ Android leaderboard plugin stub (see LEADERBOARD_SETUP.md)
autoload/
  game_manager.gd           Game state machine, spawning, scoring
  score_model.gd            ScoreModel autoload (wraps GameScore, emits score_changed)
  level_loader.gd           LevelData cache
  leaderboard_service.gd    Platform-agnostic leaderboard/achievement interface
scenes/
  vehicles/
    base_vehicle.gd         CharacterBody2D; calls VehiclePhysics.*
    vehicle_frog.gd         VehicleFrog subclass (bicho sprites, 12/10fps animations)
  obstacles/
    base_obstacle.gd        Node2D base; collision delegates to ObstaclePhysics.*
    single_obstacle.gd      muro_2b.png — lane-band wall
    double_obstacle.gd      obstaculo_1.png — ground jump obstacle
    air_double_obstacle.gd  obstaculo_1_c.png — lethal only at jump apex ≥63u
    wide_obstacle.gd        Phase 4 extension example (no base class changes)
  main/
    game_scene.gd           Spawning, parallax, per-frame collision + score loop
scripts/
  physics/
    vehicle_physics.gd      Pure functions: jump arc, rects, guards, clamps
    obstacle_physics.gd     Pure functions: world-rect transform, all collision checks
    world_speed.gd          Pure functions: speed advance, initial speed/distance
  data/
    score_model.gd          GameScore data (class_name GameScore — avoids autoload conflict)
    level_data.gd           LevelData struct + JSON loader + schema validation
    lane_layout.gd          Track geometry proportions
    obstacle_pool.gd        ObstaclePool — mirrors ObstaclePool<T> from C++
resources/
  levels/                   easy/normal/hard/story JSON (copied from C++ Resources/levels/)
tests/
  unit/                     Pure-function unit tests
  regression/               Golden-run replay tests (fixtures/ contains JSON test cases)
docs/
  SPEC.md                   Extracted gameplay constants and golden-run specs
  ARCHITECTURE.md           System design and layer explanations
  MIGRATION_NOTES.md        C++ symbol → GDScript mapping for every ported class
  LEVEL_FORMAT.md           Level JSON schema for level authors
  LEADERBOARD_SETUP.md      Plugin install, IDs, sign-in flow, iOS deferral
```

---

## Migration phases

| Phase | Focus | Status |
|-------|-------|--------|
| 0 | Repo & environment setup, GUT, CI | ✅ Done |
| 1 | Spec extraction from C++ → SPEC.md + golden-run fixtures | ✅ Done |
| 2 | Physics/collision core (pure functions + 66 tests) | ✅ Done |
| 3 | Core loop, obstacle pool, level loader, game manager | ✅ Done |
| 4 | Schema versioning, external level loading, extension proof | ✅ Done |
| 5 | Android leaderboard (graceful degradation + tests) | ✅ Done |
| 6 | Docs finalization, full regression pass | ✅ Done |

---

## Reference implementation

The original Cocos2d-x source lives in `../Turbo-Race/`.
Do not modify it — it is the behavioral reference.

Key files read during Phase 1 spec extraction:
- `Classes/common/Constants.h` — all game constants
- `Classes/models/BaseVehicle.cpp` — jump arc, collision rects
- `Classes/models/SingleObstacle.cpp` — lane-band collision guard
- `Classes/models/AirDoubleObstacle.cpp` — jump-height threshold (63.0)
- `Classes/ui/game/GameLayer.cpp` — obstacle table, world speed, scoring
- `Resources/levels/*.json` — level parameters

---

## Android export

See `docs/LEADERBOARD_SETUP.md` for:
- Installing the `godot-play-game-services` plugin
- Google Play Console setup
- Leaderboard and achievement IDs
