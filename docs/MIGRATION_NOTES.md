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

---

## Android Play Console follow-ups (out of scope, flagged not built)

### Large-screen resizability / orientation restriction warning (2026-07-24)
- Play Console flags `android:resizeableActivity="false"` + `android:screenOrientation="landscape"` in `android/build/src/main/AndroidManifest.xml` (Godot stock template, driven by project's default landscape orientation).
- **Not fixed.** `project.godot` sets `window/stretch/aspect="ignore"` — flipping `resizeableActivity` to `true` without a matching `aspect="keep"` change + UI anchor audit would visually distort the game on resize/multi-window/tablets, not just letterbox it. Real fix is a scoped responsive-UI pass, not a manifest toggle.
- Confirmed via Google's own guidance: on Android 16 both flags are ignored outright by the OS regardless of manifest value (app stretches/rotates either way) — warning is informational, does not block publishing.
- Landscape lock itself is intentional (endless runner), keep as-is.

### R8 optimization warning (2026-07-24)
- Play Console recommends `minifyEnabled` for release builds. **Not enabled.**
- `android/build/build.gradle` has no `proguardFiles` / `proguard-rules.pro`. Checked every dependency for consumer keep-rules R8 could rely on: `admob-core`/`admob-ads` AAR `proguard.txt` files present but empty; `godot-lib.template_release.aar` (engine itself) ships no consumer proguard rules at all; GPGS and InappReview AARs have none either.
- Risk: Godot's C++ calls into Java via JNI by class/method name — invisible to R8's reachability analysis. `GodotPlayGameServices` uses `Engine.get_singleton()` and AdMob uses dynamic `load()` (see [[feedback_gpgs_integration]], [[feedback_admob_integration]]) — both reflection-by-string lookups, another blind spot. Enabling R8 with zero keep-rules on a live monetized app risks a silent prod crash (ad load, GPGS sign-in, or core engine call) that only surfaces on real devices.
- Not blocking (technical-quality recommendation only). Revisit as scoped work: write full `proguard-rules.pro` covering `org.godotengine.godot.**`, GPGS/AdMob/InappReview plugin classes, then real-device QA pass (ads, GPGS sign-in, achievements, core gameplay) before shipping.

---

## Parity defect sweep (2026-08-05)

Line-by-line re-diff of the shipped 1.3.0 port against `Classes/models/*.cpp`,
`Classes/common/*.hpp` and `Classes/ui/game/GameLayer.cpp`, triggered by
player-facing reports of "collisions feel wrong", "the game is too easy", and
"floating obstacles have no shadow". Six defects found; all six fixed on branch
`fix/collision-parity`, covered by `tests/regression/test_collision_parity_fixes.gd`.

### 1. `ObstaclePool.acquire()` growth path never parented the new node
`scripts/data/obstacle_pool.gd`

C++ `ObstaclePool<T>::acquire()` falls back to `new T()`, which is a fully
constructed object. The GDScript port returned `_scene.instantiate()` without
`add_child()`. A node that never enters the tree never runs `_ready()`, so
`content_size` stayed `Vector2.ZERO` and `_local_rects` stayed empty. Result:

- the obstacle rendered nothing (never in the tree)
- `collision()` iterated an empty rect array — **it could never kill the player**
- `has_passed()` still fired — **it still scored**
- `dist = content_size.x * DT_DISTANCE * dt_factor` evaluated to 0, so the rest
  of the group stacked at one X
- `recycle()` pushed the broken node back into `_free`, so once triggered the
  pool stayed poisoned for the rest of the session
- the orphan node leaked

Reachable on every level. Worst-case concurrent obstacles per pool over
`MAX_OBSTACLE_GROUPS` consecutive map entries: single 13, ground 13, air 14 —
against prefills of 12 / 6 / 6. Normal mode overran the ground and air pools by
roughly 2x.

Fixed by storing the parent in `setup()` and parenting on the growth path.
Prefills raised to 16 / 16 / 16 so the growth path is a safety net, not a
routine occurrence.

### 2. `_spawn_initial_obstacles()` counted obstacles, not groups
`scenes/main/game_scene.gd`

`GameLayer::_initElements` loops `MAX_OBSTACLES` (10) times calling
`_spawnObstacleGroup` — that is 10 *groups*, 10–30 obstacles. The port used
`while _obstacles.size() < MAX_OBSTACLES`, which on hard mode (groups of 3)
stopped after 4 groups. Since exactly one obstacle per group carries `tag == 1`
and only a `tag == 1` recycle spawns a replacement, the group count is invariant
for the whole run — hard mode ran the entire session with 4 groups in flight
instead of 10. Renamed to `MAX_OBSTACLE_GROUPS` and restored the `for` loop.

### 3. Vehicle collision rects were "tuned" 38% narrower
`scripts/physics/vehicle_physics.gd`

1.0.0 shipped `x = w*0.355, width = w*0.34` against the C++ (and `SPEC.md` §5)
values of `w*0.30 / w*0.55`, described in the changelog as "matches C++ feel".
On the frog (175px wide) that is a 96.25px hitbox cut to 59.5px, with the front
edge pulled back from `+61.25` to `+34.1`. Measured against a `DoubleObstacle`,
the lethal X window narrows from 172px to 135px (-21%), which at easy-mode
start speed is ~53 ms of extra grace per obstacle. This was the single largest
contributor to the port playing easier than the original.

The four unit tests covering these rects had been rewritten to assert the tuned
values, so CI stayed green while the game diverged from its own spec. Values
restored to the C++ ones and hoisted into named constants; tests re-derived from
`SPEC.md`.

### 4. Jump arc was tweened from a frozen launch Y
`scenes/vehicles/base_vehicle.gd`

Cocos2d-x `JumpBy::update` folds external position changes into `_startPosition`
each frame and adds its arc on top, so a lane change made mid-jump both applies
immediately and survives the landing. The port tweened `position.y` absolutely
from a `_jump_start_y` captured at takeoff. While airborne this left the air
hitbox (derived from `position.y`) in the lane the player left, while the ground
hitbox (derived from `player_y`, which `do_move` kept updating) tracked the lane
the player moved to — the two hitboxes and the sprite all disagreed. On landing,
`player_y` was recomputed from the frozen `position.y`, silently reverting the
lane change.

Replaced with a `_jump_t` accumulator advanced by `advance_jump(delta)`, called
from `GameScene._physics_process` *after* `do_move()` so the arc always rides the
current `player_y`. Driven explicitly rather than via `_physics_process` so pause
and game-state gating stay in one place.

### 5. Y limits had the lane transform applied twice
`scenes/main/game_scene.gd`

`VehiclePhysics.compute_y_limits(player_start_y, wall_height)` already applies
the `-wallHeight*0.1` / `+wallHeight*0.9` transform from
`GameLayer::_createPlayer`. `_create_player()` passed pre-adjusted values into
it, so the transform ran twice and the playfield became `[201, 282]` instead of
`[210, 300]` — 9 units of headroom lost at the top lane, 9 spurious units gained
below the bottom lane. Now passes the raw lane values.

### 6. `do_move()` was skipped when input was neutral
`scenes/main/game_scene.gd`

`GameLayer::_updatePlayer` calls `updateControl()` → `doMove()` every frame
regardless of stick deflection. `doMove`'s zero-velocity path is what clamps
`player_y` into `[limit_bot, limit_top]` and re-syncs `position.y` to it. The
port only called `do_move` when a control was actually deflected, so a player who
never touched the stick rested at `player_y = 206` — 4 units below the intended
floor of 210 — for the whole run. Movement input is now folded into a single
`vel` vector and `do_move` is called unconditionally.

### 7. Shadows were never ported
`scenes/vehicles/base_vehicle.gd`, `scenes/obstacles/air_double_obstacle.gd`

`shadow.png` and `sombra_obstaculo_1c.png` were imported into
`resources/assets/` but referenced nowhere in the project.

**Player shadow** (`BaseVehicle.cpp` ctor + `updateShadow()`) is not decoration:
it is the only visual indicator of `player_y`, which is exactly the value the
ground hitbox and `SingleObstacle`'s lane-band test key off. Without it the
player cannot see which lane they are in while airborne, which reads as unfair
collisions. Cocos2d-x child coordinates are relative to the parent's bottom-left
corner, so the C++ local `(w*0.5, _playerY - posY + h*0.55)` resolves to world
`(posX, _playerY + h*0.05)`; the Godot equivalent in local space is
`(0, player_y + h*0.05 - position.y)`.

**Air-obstacle shadow** (`AirDoubleObstacle.cpp` ctor + `doUpdate()`) is scrolled
a second time on top of its parent's movement, so it travels at 2x world speed.
That drift is the fake-perspective cue that reads as "this obstacle is airborne";
without it a floating obstacle is indistinguishable from a ground one until the
player is already committed to a jump. `reset()` restores the offset on pool
reuse.

`BaseVehicle::dead()`'s mid-air fall was ported at the same time. Note its target
Y is `spriteShadow->getPositionY() + getPositionY()`, which mixes child-local and
world Y and lands at `player_y + h*0.55` rather than the shadow's true world Y of
`player_y + h*0.05`. Ported verbatim — the original ships this and it reads as a
normal fall.

### 8. Jump arc was a sine; `JumpBy` is a parabola
`scripts/physics/vehicle_physics.gd`

`cocos2d/2d/CCActionInterval.cpp` (cocos2d-x-4.0), verified against the tagged
engine source rather than recalled:

```cpp
void JumpBy::update(float t)
{
    // parabolic jump (since v0.8.2)
    float frac = fmodf( t * _jumps, 1.0f );
    float y = _height * 4 * frac * (1 - frac);
```

The port shipped `MAX_PLAYER_JUMP * sin(t * PI)`. The two agree at t = 0, 0.5
and 1 — which is exactly the set of points the existing unit tests checked — and
disagree everywhere between: at t = 0.25 the parabola gives 0.75 of peak, the
sine 0.7071. Practical effect is on `AirDoubleObstacle`, whose guard fires above
`MAX_PLAYER_JUMP * 0.45`: time spent above that threshold is 72.4% of the jump
under the parabola versus 70.2% under the sine, so the sine was marginally
safer. Now `fmod(t, 1.0)` + `4 * frac * (1 - frac)`, with a test at the quarter
point.

The same source read settled a second question: `CC_ENABLE_STACKABLE_ACTIONS`
defaults to `1` in `cocos/base/ccConfig.h`, and the guarded branch folds external
position changes into `_startPosition` every frame. That confirms defect 4 above
— `JumpBy` really is additive over concurrent movement.

`.claude/skills/cocos2dx-to-godot/SKILL.md` §2 asserted the opposite ("JumpBy is
sine, not parabola") and has been corrected. `docs/SPEC.md` §2 was right all
along ("a parabolic Y trajectory").

### 9. z_index quantised to 10px buckets
`scenes/main/game_scene.gd`

C++ spawns with `int(WIN_H - z_param) + toZ(GameDeep::GameElements)`. The port
divided by 10, collapsing a 768-value range into ~8 buckets: the player (z 37–46)
tied with bottom-lane single obstacles (fixed 46), and `JUMP` obstacles pinned at
38 rendered in front of the player whenever `player_y` reached the top of its
range (player z 37). Depth ties then fell to tree order, so the player popped in
front of and behind obstacles in visible steps.

Godot clamps `z_index` to ±4096, which is the only real constraint. The
per-node term is now the C++ formula verbatim — `int(WIN_H - z_param)`, landing
in 372…768 with 1px granularity — while the `GameDeep` layer bases (-9999 …
-2500, out of range) are rescaled into ordered constants `Z_SKY … Z_TRACKS`
(-600 … -550). Nothing is interleaved between layers, so only their ordering
matters. Background sprites now carry explicit z values instead of relying on
tree order at z = 0.

Player depth is also set at spawn, restart and home-reset via `_update_player_z()`,
not only from `_physics_process` — otherwise the player renders at the default
z = 0 for the frame before the first physics tick.

Measured live ranges after the change (headless, 40s per level): easy 393–463
(singles only early in its map), normal/hard/story 384–768.

### Process guard added

`tests/regression/test_spec_constants_match_code.gd` reads `docs/SPEC.md` at
runtime and asserts the collision-rect fractions, jump constants, arc shape,
level map lengths and per-level multipliers all match the code. Verified to fail
by temporarily setting `RECT_WIDTH` back to `0.34`.

The hitbox regression and the level-map redesign shared one root cause: values
in code drifted from `SPEC.md`, and the tests were rewritten to assert the
drifted values, so CI certified the divergence green for three releases. Editing
code or spec without the other now fails the build.

### Not fixed — flagged only

**Tilt control is a redesign.** C++ `didAccelerate` computes
`accel * speed² * 0.25` ≈ `accel * 30.25`; the port uses a normalised dead-zone
curve plus `TILT_X_MULT`. Deliberate and documented, but tilt and joystick
players sit on different difficulty curves while sharing leaderboards.

**Map repetition.** At the restored 133 entries the map loops roughly every 133
obstacles. Matches the original. If it becomes a complaint, the honest fix is a
seeded shuffle over the C++ pattern distribution — which keeps the difficulty
curve verifiable — not hand-authored long maps.

### Level-design decision (2026-08-05): 665-entry maps reverted to C++ 133

1.1.0 (a Google Play Games Services phase) replaced `easy/normal/hard.json`
with 665-entry "difficulty-tuned" maps. Those maps are a redesign, not a port,
and they front-load trivial patterns. Time to the first obstacle that *requires*
a jump, derived from each level's own speed/acceleration/distance constants:

| level  | C++ map | 1.1.0–1.3.0 map |
|--------|---------|-----------------|
| easy   | 25.4s (entry #12) | **142.5s** (entry #82) |
| normal, first triple-ground | 73.6s (#94) | **145.6s** (#200) |
| hard, first must-jump (type 2) | 3.5s (#7) | **never — type 2 absent entirely** |

Mean difficulty weight over the first 100 entries dropped from 1.43 → 1.04 on
easy and 1.80 → 1.57 on normal.

**Decision: restore the C++ 133-entry maps verbatim.** `story.json` was already
identical; all four levels' speed/distance/acceleration multipliers were already
identical and were asserted equal before overwriting, so only the `map` arrays
changed.

Rationale:
- The project's stated goal is parity, not redesign, and level content was
  changed during a phase scoped to leaderboards.
- The collision fixes in this sweep do not touch content. No hitbox correction
  rescues an easy level that contains nothing but single walls for 2m22s.
- Leaderboard impact cuts the safe way: the C++ maps are harder, so existing
  records become harder to beat rather than trivially beatable. No player's
  standing is devalued.
- Hard mode shipping zero type-2 obstacles is a content regression, not a
  tuning choice.

Accepted trade-off: at 133 entries the map loops roughly every 133 obstacles, so
long runs repeat sooner than they did at 665. That is what the original ships.
A longer-form map variant is a possible future milestone, not built here.

Pool prefills were re-sized for the restored maps (worst-case concurrent count
over a 10-group window: single 20, ground 14, air 13) to 24 / 18 / 18.
