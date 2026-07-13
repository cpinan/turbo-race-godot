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
- `_checkAchievements()` → `AchievementChecker.check()` autoload (Phase 5)

---

## Phase 3 — Core loop & content

### HomeLayer.cpp
- Logo slide-in animation (`MoveTo`) → `Tween.tween_property(position:x, ...)` over 0.9 s
- Level button pulse (`RepeatForever ScaleTo 1.05 / 1.0`) → looping Tween, staggered 1.3 s per button
- "How to Play" wobble (`RotateTo ±2°`) → looping Tween on `rotation_degrees`
- Sound toggle texture swap → `_update_sound_btn()` loads texture by mute state

### GameLayer.cpp (scene/loop)
- `_score.obstaclesJumped = 0` reset after persisting → `ScoreModel` reset on `game_scene.restart()`
- Obstacle spawn loop → `game_scene.gd` spawns from pool; `GameManager` tracks free slots
- `LocalStorageManager::setScore()` on game-over → `SaveManager.record_game_result(score, jumped)`
- `LocalStorageManager::updateObstaclesJumped()` → folded into `record_game_result()`
- parallax (`CCParallaxNode`) → two `TextureRect` layers scrolled with fractional speed in `_process`

### LocalStorageManager.cpp
- `getBoolForKey / setBoolForKey` (UserDefaults) → `ConfigFile.get_value / set_value` + `save()`
- `getTotalGamesPlayed()` → `SaveManager.get_total_games_played()`
- `getObstaclesJumped()` / `updateObstaclesJumped()` → `get_total_obstacles_jumped()` / `record_game_result()`
- `getTotalScore()` → `get_total_score()`
- `getAverageScore()` → `get_average_score()` (computed from total_score / total_games)
- `getScoreInLevel()` / `setScoreInLevel()` → `get_best_score(level)` / `set_best_score(level, score)`
- `isAchievementUnlocked()` / `unlockAchievement()` → `is_achievement_unlocked(id)` / `mark_achievement_unlocked(id)`

### PopUpLoseLayer.cpp (GameOverScreen)
- Score + best labels right-aligned right of badge → `Label` with `HORIZONTAL_ALIGNMENT_RIGHT`, positioned after one `await process_frame` to measure text width
- `_showAudioPlaying()` label → `x = WIN_W - textWidth * 1.1` pattern

### AudioManager (new — no direct C++ equivalent)
- C++ played tracks ad-hoc from `SimpleAudioEngine`; Godot wraps into `AudioManager` autoload
- `play_music()` → picks next track in rotation (3 tracks), returns track name for HUD label

---

## Phase 4 — Extensibility

### LevelLoader.hpp (extended)
- External level override: `user://levels/{name}.json` checked before `res://resources/levels/`
- `"version"` field reserved in JSON schema for future backward-compat handling
- New obstacle/vehicle: add scene + script — no base-class modification required

---

## Phase 5 — Leaderboard & achievements

### Constants.h (IDs)
- All `ACH_*` and `LEAD_*` string constants preserved verbatim in `LeaderboardService` as GDScript `const` strings

### LocalStorageManager::unlockAchievement()
- C++: sets local bool **and** submits to GPGS in one call (always online at game-over in Cocos flow)
- Godot: split into `SaveManager.mark_achievement_unlocked(id)` (local) + `LeaderboardService.unlock_achievement(id)` (GPGS)
- Guard: local mark only happens when `LeaderboardService.is_signed_in()` == true, preventing permanently-lost achievements if GPGS is unavailable

### GameLayer::_checkAchievements()
- Rule table (16 tabular + 4 special-case rules) → `AchievementChecker.check()` with same conditions
- Accelerometer condition: `!_isJoypad` → `used_tilt: bool` parameter derived from `SaveManager.get_control_type() == "tilt"` on Android
- `ACH_MORE_THAN_3000` threshold `>= 3001` preserved exactly (C++ stored threshold as `3001`)
- `ACH_ACCELEROMETER_3000` uses `longScore >= 3000` (not 3001) — preserved

### GodotPlayGameServices plugin (v3.2.0)
- `GooglePlayGames::submitScore()` → `_plugin.submitScore(leaderboard_id, score)`
- `GooglePlayGames::unlockAchievement()` → `_plugin.unlockAchievement(id)`
- `GooglePlayGames::showAchievements()` → `_plugin.showAchievements()`
- `GooglePlayGames::showLeaderboard()` → `_plugin.showLeaderboard(id)` / `showAllLeaderboards()`
- Sign-in: `_plugin.signIn()` → `userAuthenticated(ok: bool)` signal
- `Engine.get_singleton("GodotPlayGameServices")` used directly (not GDScript wrapper autoload) to avoid double-init guard in wrapper
