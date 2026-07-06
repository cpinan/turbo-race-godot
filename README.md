# Turbo Race — Godot 4

Godot 4.7 / GDScript port of the original Cocos2d-x/C++ endless-runner mobile game.
Goal: **behavioral parity** with `cpinan/Turbo-Race` — same jump physics, collision rules, scoring. No new mechanics.

## Requirements

- Godot 4.7.x (download from [godotengine.org](https://godotengine.org/download))
- No other dependencies — GUT test framework is vendored in `addons/gut/`

## Setup

```sh
git clone <this-repo> turbo-race-godot
# Open Godot editor → Import → select turbo-race-godot/project.godot
```

## Running tests

```sh
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
```

CI runs this on every push via `.github/workflows/tests.yml`.

## Project structure

```
addons/gut/          GUT test framework (vendored)
autoload/            GameManager, ScoreModel, LevelLoader singletons
scenes/
  vehicles/          Vehicle scenes (CharacterBody2D wrappers)
  obstacles/         Obstacle scenes (Area2D wrappers)
  ui/                Menu, HUD, game-over screens
  main/              Main game scene
scripts/
  physics/           Pure functions: jump arc, collision checks (no node deps)
  data/              Data helpers
resources/levels/    Level JSON files
tests/
  unit/              GUT unit tests for pure logic
  regression/        Golden-run replay tests vs. C++ expected outcomes
docs/                Architecture, migration notes, spec, level format
```

## Migration phases

See `docs/TurboRace_Godot_ClaudeCode_Migration_Plan.md` for the full phase plan.

| Phase | Focus | Status |
|-------|-------|--------|
| 0 | Repo & environment setup | ✅ Done |
| 1 | Spec extraction from C++ → SPEC.md | ⏳ Next |
| 2 | Physics/collision core (pure functions + tests) | — |
| 3 | Core loop, content, pooling, level generator | — |
| 4 | Extensibility: schema versioning, external levels | — |
| 5 | Android leaderboard (Google Play Games Services) | — |
| 6 | Docs finalization, full regression pass | — |

## Reference implementation

The original Cocos2d-x source lives in `../Turbo-Race/`. Do not modify it — it is the reference until Phase 6 is verified.
