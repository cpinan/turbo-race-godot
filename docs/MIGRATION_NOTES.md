# Migration Notes — C++ → Godot

Running log of every C++ symbol ported to GDScript. Updated in the same PR as the code.

Format per entry:
```
## <OriginalFile.cpp>
- `CppSymbol` → `godot_equivalent` — one-line note on any semantic decision
```

---

## Phase 0 — Repo setup

No C++ symbols ported this phase. Folder structure, GUT, and CI established.

---

## Phase 1 — Spec extraction

### Constants.h
- `kScoreFactor = 100.0f` → `ScoreModel.K_SCORE_FACTOR: float = 100.0`
- `MAX_PARALLAX = 5`, `MAX_OBSTACLES = 10` → direct GDScript constants
- `START_WORLD_SPEED = designWidth * 0.5 = 512.0` → constant (not macro; design res fixed at 1024)
- `MIN_DISTANCE_OBSTACLES = designWidth / 1.8 = 568.89` → constant
- `START_X_OBSTACLES = designWidth * 1.9 = 1945.6` → constant
- Notification strings → Godot signals (no string-based events)
- Achievement/Leaderboard IDs → preserved as GDScript constants in Phase 5

### GameTypes.hpp
- `ActorState` → `enum ActorState { NOTHING, IDLE, JUMP, RUN, BACK }` in GDScript
- `ObstacleType` → `enum ObstacleType { NORMAL, JUMP, SIMPLE }`
- `GameLevel` → `enum GameLevel { EASY, NORMAL, HARD, STORY, NONE }`
- `GameMode` → `enum GameMode { HOME, PLAY, END, REPLAY_VIEW, PLAY_AGAIN }`

### BaseVehicle.cpp / .hpp
- `MAX_PLAYER_JUMP = 140.0f` → `BaseVehicle.MAX_PLAYER_JUMP: float = 140.0`
- `JUMP_DURATION = 0.6f` → `BaseVehicle.JUMP_DURATION: float = 0.6`
- `_speed = 11.0f` → `BaseVehicle.speed: float = 11.0`
- `JumpBy(0.6, Vec2(0,0), 140, 1)` → GDScript tween parabola over 0.6s, peak 140 units
- `getGroundCollision()` / `getAirCollision()` → pure functions in `scripts/physics/vehicle_physics.gd`
- `doJump()` guard (`y <= 1 AND state != Jump`) → pure function
- `doMove()` clamping logic → pure function

### BaseObstacle.cpp / .hpp
- `BaseObstacle::collision()` — tests BOTH rectAir AND rectFloor intersection → pure function
- `currentCollisionArea()` — world-space transform of local rect → pure function
- `doUpdate(x, speed)` → `setPositionX(x - speed)` — direct port

### SingleObstacle.cpp
- Lane-band guard (`y_effective = playerY + playerH*0.15; return false if out of [top, top+h*0.37]`) → pure function
- Local collision rect `(w*0.25, h*0.1, w*0.6, h*0.8)` → constant in GDScript class

### DoubleObstacle.cpp
- Two collision rects → constants in GDScript class
- No custom collision override; uses BaseObstacle logic

### AirDoubleObstacle.cpp
- Guard 1: state != Jump → false — pure function guard
- Guard 2: airborne_height < MAX_PLAYER_JUMP*0.45 (=63.0) → false — pure function guard
- Five staircase collision rects → constants in GDScript class
- Only checks rectAir (not rectFloor) — key semantic difference from other types

### ScoreModel.hpp
- `totalScore() = obstaclesAvoided * 100` → `ScoreModel.total_score()` pure function
- `obstaclesJumped` tracked separately (for achievements, not shown score) → preserved

### LevelLoader.hpp
- JSON fields: `speedMultiplier`, `distanceMultiplier`, `speedAcceleration`, `maxWorldSpeed`, `map`
- `maxWorldSpeed <= 0` = uncapped (no level currently uses this; all have caps)
- Map array wraps cyclically → port exactly
- File paths: `levels/easy.json`, `levels/normal.json`, `levels/hard.json`, `levels/story.json`

### LayoutUtils.hpp (LaneLayout::compute)
- All Y-position formulas → `LaneLayout` struct in GDScript, same proportional math
- `trackOffsetY = visibleOrigin.y * 0.5` depends on runtime; will use Godot viewport math

### GameLayer.cpp
- `kObstacleTable[0..9]` map-code → obstacle definition table → GDScript dictionary/array
- `DT_DISTANCE = 0.8` (intra-group spacing multiplier) → constant
- Scoring event: `obsX + obsContentWidth < playerPosX AND !passPlayerSFX` → pure predicate
- `_checkAchievements()` → `GameManager._check_achievements()` Phase 5
