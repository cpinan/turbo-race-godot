# Turbo Race — Behavioral Spec

Extracted from the Cocos2d-x reference implementation (`../Turbo-Race/`).
Every constant here was read directly from source — no guessing.
Phase 2 physics code must match every value in this file exactly.

**Key source files:**
- `Classes/common/Constants.h` — global constants
- `Classes/common/LayoutUtils.hpp` — LaneLayout geometry
- `Classes/common/ScoreModel.hpp` — scoring
- `Classes/common/LevelLoader.hpp` — level JSON schema
- `Classes/models/BaseVehicle.cpp/.hpp` — jump, movement, collision rects
- `Classes/models/BaseObstacle.cpp/.hpp` — base collision logic
- `Classes/models/SingleObstacle.cpp` — wall obstacle collision
- `Classes/models/DoubleObstacle.cpp` — ground jump obstacle
- `Classes/models/AirDoubleObstacle.cpp` — air obstacle (jump-only danger)
- `Classes/ui/game/GameLayer.cpp` — world speed, spawning, scoring event

---

## 1. Design Resolution

```
designResolutionSize = Size(1024, 768)
```

All runtime-computed geometry below is expressed in terms of this resolution.

---

## 2. Jump Physics

Source: `BaseVehicle.hpp`, `BaseVehicle.cpp`

```
MAX_PLAYER_JUMP        = 140.0f          # peak jump height (world units)
JUMP_DURATION          = 0.6f            # seconds (full arc up and down)
JUMP_HORIZONTAL_OFFSET = 0.0f           # no horizontal displacement
JUMP_COUNT             = 1              # single parabola via JumpBy
```

Implemented as Cocos2d-x `JumpBy::create(0.6f, Vec2(0,0), 140.0f, 1)`.
Godot equivalent: a parabolic Y trajectory over 0.6 s with peak 140 units.

**Jump guard** (doJump, only fires when both conditions true):
```
airborne_height = positionY - playerY - contentSize.height * 0.5
guard_1: airborne_height <= 1        # at or near ground
guard_2: state != ActorState::Jump   # not already jumping
```

**State machine:**
- `Idle → Jump`: when doJump fires and both guards pass
- `Jump → Idle`: when JumpBy action ends (detected in doMove when `getActionByTag(kActionJumpTag) == nullptr`)

**PlayerY tracking:**
- While grounded: `_playerY = positionY - contentSize.height * 0.5`  (bottom of sprite)
- While airborne: `_playerY` is frozen at last ground value; only changes from joypad/accel Y input while jumping, subject to `limitBottomY`/`limitTopY` clamp

---

## 3. Player Movement

Source: `BaseVehicle.cpp::doMove`, `GameLayer.cpp::_createPlayer`

```
DEFAULT_SPEED = 11.0f   # player movement speed multiplier (VehicleFrog inherits this)
```

**Position clamps:**
```
x_min = contentSize.width * 0.5
x_max = WIN_SIZE.width * 0.8   (= 1024 * 0.8 = 819.2)
```

**Y limits** (set by `setLimits` in `_createPlayer`):
```
limitBottomY = playerStartY - wallHeight * 0.1
limitTopY    = limitBottomY + wallHeight * 0.9
           (= playerStartY + wallHeight * 0.8)
```

**Y clamping while airborne:** during a jump, if velocity would push `_playerY` outside `[limitBottomY, limitTopY]`, velocity.y is zeroed.

---

## 4. Lane Layout

Source: `LayoutUtils.hpp::LaneLayout::compute`, `GameLayer.cpp::_createMap`

Track offset: `trackOffsetY = visibleOrigin.y * 0.5`

```
playerStartY  = trackHeight * 0.55  + trackOffsetY
wallHeight    = trackHeight * 0.25

simpleBotY    = playerStartY + wallHeight * 0.85   # single-obstacle lower lane
doubleGroundY = playerStartY + wallHeight * 0.70   # double ground obstacle lane
simpleTopY    = playerStartY + wallHeight * 1.55   # single-obstacle upper lane
doubleAirY    = playerStartY + wallHeight * 1.80   # double air obstacle lane
```

`trackHeight` is the `contentSize.height` of the `pista.png` floor sprite.
**Ambiguity:** exact pixel height of `pista.png` is not in source — must be measured from the asset at runtime or read from asset metadata. Document it here once known.

---

## 5. Collision Rectangles

Source: `BaseVehicle.cpp::getGroundCollision`, `BaseVehicle.cpp::getAirCollision`

All rects are in world space. `getBoundingBox().getMinX()` = leftmost X of sprite in world.

### Player — Ground Collision
```
x      = bbox.minX + contentSize.width * 0.30
y      = _playerY
width  = contentSize.width  * 0.55
height = contentSize.height * 0.30
```

### Player — Air Collision
```
x      = bbox.minX + contentSize.width * 0.30
y      = bbox.minY + contentSize.height * 0.16
width  = contentSize.width * 0.55
height = contentSize.width * 0.20    ← uses WIDTH, not height (exact in source)
```

---

## 6. Obstacle Types

Source: `GameLayer.cpp::kObstacleTable` (comment block at top of file, confirmed by constructor code)

### Map code → obstacle definition table

| Code | Kind          | Lane         | Count | dtFactor | Class              |
|------|---------------|--------------|-------|----------|--------------------|
| 0    | Single        | BotSimple    | 1     | 1.0      | SingleObstacle     |
| 1    | Single        | TopSimple    | 1     | 1.0      | SingleObstacle     |
| 2    | Ground        | DoubleGround | 1     | 1.0      | DoubleObstacle     |
| 3    | Air           | DoubleAir    | 1     | 1.0      | AirDoubleObstacle  |
| 4    | Single        | BotSimple    | 2     | 1.5      | SingleObstacle     |
| 5    | Single        | TopSimple    | 2     | 1.5      | SingleObstacle     |
| 6    | Ground        | DoubleGround | 3     | 1.0      | DoubleObstacle     |
| 7    | Air           | DoubleAir    | 3     | 1.0      | AirDoubleObstacle  |
| 8    | Ground        | DoubleGround | 2     | 1.0      | DoubleObstacle     |
| 9    | Air           | DoubleAir    | 2     | 1.0      | AirDoubleObstacle  |

Spacing between units in a multi-obstacle group:
```
distance = obstacle.contentSize.width * DT_DISTANCE * dtFactor
DT_DISTANCE = 0.8
```

Tag convention for multi-obstacle groups (used to gate re-spawning):
- `i==0`: `tag = count` (first obstacle triggers respawn on recycle)
- `i > 0`: `tag = (i-1) * -1` (subsequent; do not trigger respawn)

Only obstacles with `tag == 1` trigger a new spawn when they scroll off screen.

### 6a. SingleObstacle

Type: `ObstacleType::Simple`  
Texture: `muro_2b.png`  
`_sameCollisionArea = true`

Local collision rect:
```
Rect(width*0.25, height*0.1, width*0.6, height*0.8)
```

**Custom collision logic** (`SingleObstacle::collision`):
```
top    = bbox.minY + height * 0.0       (= bbox.minY)
bottom = top + height * 0.37

y_effective = playerY + playerContentSize.height * 0.15   (= playerH * 0.3 * 0.5)

if y_effective < top   → return false   (player below obstacle band)
if y_effective > bottom → return false  (player above obstacle band)
→ delegate to BaseObstacle::collision()
```

`BaseObstacle::collision` returns true if ANY local collision rect (world-transformed) intersects **both** `rectAir` and `rectFloor` simultaneously.

**Meaning:** SingleObstacle is a lane wall; it only kills the player if their ground-Y is inside the lower 37% of the obstacle's bounding box AND their collision rects overlap both rect zones.

### 6b. DoubleObstacle

Type: `ObstacleType::Jump`  
Texture: `obstaculo_1.png`  
`_sameCollisionArea = false`

Local collision rects:
```
Area 1: Rect(width*0.1, height*0.5, width*0.5, height*0.5)   # top half
Area 2: Rect(width*0.3, 0,          width*0.5, height*0.5)   # bottom half
```

Collision: `BaseObstacle::collision` (default). Returns true if ANY area intersects **both** rectAir and rectFloor.

**Score note:** when a DoubleObstacle (`ObstacleType::Jump`) is passed, `obstaclesJumped` increments in addition to `obstaclesAvoided`.

### 6c. AirDoubleObstacle

Type: `ObstacleType::Normal` (default from BaseObstacle; this controls pool routing in `_recycleObstacle`)  
Texture: `obstaculo_1_c.png`  
`_sameCollisionArea = false`

Local collision rects (5 zones, staircase pattern):
```
Rect(w*0.05, h*0.65, w*0.20, h*0.25)
Rect(w*0.20, h*0.50, w*0.20, h*0.25)
Rect(w*0.30, h*0.35, w*0.20, h*0.25)
Rect(w*0.40, h*0.25, w*0.20, h*0.25)
Rect(w*0.50, h*0.10, w*0.20, h*0.25)
```

**Custom collision logic** (`AirDoubleObstacle::collision`):
```
Guard 1: vehicle.state != Jump → return false   (only lethal while airborne)

airborne_height = vehicle.positionY - vehicle.playerY - vehicle.contentSize.height * 0.5
Guard 2: airborne_height < MAX_PLAYER_JUMP * 0.45  (= 63.0) → return false

→ check each local rect: if world-transformed rect intersects rectAir → return true
```

**Critical boundary:** `airborne_height < 63.0` → safe. `airborne_height >= 63.0` → potentially lethal.  
Only `rectAir` is checked (not `rectFloor`).

**Meaning:** jump too high over this obstacle → die. Player must stay low (not jump, or jump only slightly).

---

## 7. World Speed & Acceleration

Source: `GameLayer.cpp::configureGame`, `GameLayer.cpp::_updatePlayer`

```
START_WORLD_SPEED    = designResolutionSize.width * 0.5  = 512.0   (pixels/s)
MIN_DISTANCE_OBSTACLES = designResolutionSize.width / 1.8 = 568.89 (pixels)
```

Per frame:
```
_worldSpeed += dt * _speedAcceleration
if maxWorldSpeed > 0 and _worldSpeed > maxWorldSpeed:
    _worldSpeed = maxWorldSpeed
```

Initial values after level load:
```
initialSpeed   = START_WORLD_SPEED * level.speedMultiplier
initialMinDist = MIN_DISTANCE_OBSTACLES * level.distanceMultiplier
```

Obstacle X move per frame: `obstacle.positionX -= worldSpeed * dt * 1.0`  
(DT_SPEED_OBSTACULOS = 1.0, confirmed in GameLayer.cpp)

---

## 8. Level Parameters

Source: `Resources/levels/*.json` (exact values, no rounding)

| Field               | Easy    | Normal  | Hard    | Story   |
|---------------------|---------|---------|---------|---------|
| speedMultiplier     | 1.0     | 1.7     | 2.2     | 1.5     |
| distanceMultiplier  | 2.0     | 1.3     | 1.0     | 1.6     |
| speedAcceleration   | 2.0     | 2.0     | 2.0     | 1.5     |
| maxWorldSpeed       | 1200.0  | 1400.0  | 1600.0  | 1000.0  |

Derived initial values (using designResolutionSize = 1024×768):

| Level  | initialSpeed | initialMinDist |
|--------|-------------|----------------|
| Easy   | 512.0       | 1137.78        |
| Normal | 870.4       | 739.56         |
| Hard   | 1126.4      | 568.89         |
| Story  | 768.0       | 910.22         |

Map files (wrapped cyclically when exhausted):
- Easy: 133 entries
- Normal: 133 entries
- Hard: 133 entries
- Story: 133 entries

---

## 9. Score Formula

Source: `ScoreModel.hpp`, `GameLayer.cpp::_updateObstacles`

```
totalScore = obstaclesAvoided * 100     (kScoreFactor = 100.0)
```

An obstacle is "avoided" (obstaclesAvoided++) when:
```
obstacle.positionX + obstacle.contentSize.width < player.positionX
AND obstacle.passPlayerSFX == false   (not yet counted)
```
This fires once per obstacle (passPlayerSFX is set to true after).

DoubleObstacle (`ObstacleType::Jump`) additionally increments `obstaclesJumped` when passed.

---

## 10. Obstacle Pool Pre-fill

Source: `GameLayer.cpp` constructor

```
SingleObstacle pool:      prefill(4)
DoubleObstacle pool:      prefill(3)
AirDoubleObstacle pool:   prefill(3)
```

Obstacle recycle routing (from `_recycleObstacle`):
```
ObstacleType::Simple → SinglePool
ObstacleType::Jump   → DoublePool
ObstacleType::Normal → AirPool
```

---

## 11. Parallax Scroll Speeds

Source: `GameLayer.cpp` (DT_SPEED_* constants)

All relative to `worldSpeed * dt`:

| Layer         | Multiplier | Asset          |
|---------------|------------|----------------|
| Floor (track) | 1.0×       | pista.png      |
| Obstacles     | 1.0×       | —              |
| BG Front      | 1.3×       | humo.png       |
| BG Mid        | 1.0×       | background_1.png |
| BG Back       | 0.5×       | background_2.png |
| Cloud         | 0.2×       | nube.png       |

Sky and BG Back/Mid/Front layers receive a `Color3B(c, c, c)` pulse:
```
c starts at 255
c += dt * colorSign * 3
if c < 100: colorSign = +1
if c > 255: colorSign = -1
c clamped to [100, 255]
```

---

## 12. Achievements — Thresholds

Source: `GameLayer.cpp::_checkAchievements`

| Achievement                              | Level  | Metric         | Threshold |
|------------------------------------------|--------|----------------|-----------|
| Avoid 100 obstacles                      | Easy   | obstaclesAvoided | 100     |
| Avoid 50 obstacles                       | Normal | obstaclesAvoided | 50      |
| Avoid 25 obstacles                       | Hard   | obstaclesAvoided | 25      |
| Avoid 100 obstacles                      | Hard   | obstaclesAvoided | 100     |
| Score > 3000                             | Any    | totalScore     | 3001      |
| Score >= 10000                           | Easy   | totalScore     | 10000     |
| Score >= 8000                            | Normal | totalScore     | 8000      |
| Score >= 5000                            | Hard   | totalScore     | 5000      |
| Score >= 30000                           | Easy   | totalScore     | 30000     |
| Score >= 15000                           | Normal | totalScore     | 15000     |
| Score >= 10000                           | Hard   | totalScore     | 10000     |
| Play 10 times                            | Any    | gamesPlayed    | 10        |
| Play 100 times                           | Any    | gamesPlayed    | 100       |
| Play 1000 times                          | Any    | gamesPlayed    | 1000      |
| Jump 50 obstacles                        | Any    | totalJumps     | 50        |
| Jump 1000 obstacles                      | Any    | totalJumps     | 1000      |
| Play in accelerometer mode               | Any    | !isJoypad      | —         |
| Accelerometer + score >= 3000            | Any    | !isJoypad+score| 3000      |
| Average >= 1000 in 50+ games             | Any    | avg+games      | 50 games  |
| Total score >= 100000                    | Any    | cumTotalScore  | 100000    |

---

## 13. Golden Run Fixtures

Fixtures live in `tests/regression/fixtures/`. Each fixture JSON documents a logical
scenario, the collision function called, and the expected boolean result.
Expected values are derived by tracing C++ source — no guessing.

### Fixture GR-001 — AirDoubleObstacle: player not jumping

**Scenario:** Player is grounded (state = Idle). AirDoubleObstacle overlaps player's X position.  
**Call:** `AirDoubleObstacle::collision(vehicle)`  
**Trace:**  
```
Guard 1: vehicle.state != Jump  →  return false immediately
```
**Expected:** `false` (safe)  
**File:** `tests/regression/fixtures/gr001_air_obstacle_ground.json`

---

### Fixture GR-002 — AirDoubleObstacle: player jumping but below lethal threshold

**Scenario:** Player is jumping. Airborne height = 62.0 (< 63.0 threshold).  
**Call:** `AirDoubleObstacle::collision(vehicle)`  
**Trace:**  
```
Guard 1: vehicle.state == Jump  →  pass
airborne_height = 62.0
Guard 2: 62.0 < MAX_PLAYER_JUMP * 0.45 (= 63.0)  →  return false
```
**Expected:** `false` (safe — player jumped but not high enough to hit air obstacle)  
**File:** `tests/regression/fixtures/gr002_air_obstacle_low_jump.json`

---

### Fixture GR-003 — AirDoubleObstacle: player at exact lethal threshold

**Scenario:** Player is jumping. Airborne height = 63.0 (= threshold exactly).  
**Call:** `AirDoubleObstacle::collision(vehicle)`  
**Trace:**  
```
Guard 1: vehicle.state == Jump  →  pass
airborne_height = 63.0
Guard 2: 63.0 < 63.0  →  false, does NOT return early
→ proceeds to rect intersection check
```
**Expected:** guard passes, result depends on rect overlap (ambiguous without sprite sizes — see note below)  
**Note:** The exact rect intersection at this threshold depends on the pixel dimensions of `obstaculo_1_c.png`. This boundary case must be confirmed against the running game or asset measurements. Mark as AMBIGUOUS in test until asset size is known.  
**File:** `tests/regression/fixtures/gr003_air_obstacle_threshold.json`

---

### Fixture GR-004 — Score formula: 30 obstacles avoided

**Scenario:** Game ends with `obstaclesAvoided = 30`, `obstaclesJumped` irrelevant.  
**Call:** `ScoreModel::totalScore()`  
**Trace:**  
```
totalScore = 30 * 100 = 3000
```
**Expected:** `3000`  
**File:** `tests/regression/fixtures/gr004_score_formula.json`

---

### Fixture GR-005 — SingleObstacle: player Y above lane band

**Scenario:** Player at upper lane (`y_effective > obstacle.bbox.minY + obstacle.height * 0.37`).  
**Call:** `SingleObstacle::collision(vehicle)`  
**Trace:**  
```
top    = obstacle.bbox.minY
bottom = top + obstacle.height * 0.37
y_effective = playerY + playerHeight * 0.15

if y_effective > bottom  →  return false
```
**Expected:** `false` (player too high to hit this obstacle — safe by lane separation)  
**File:** `tests/regression/fixtures/gr005_single_obstacle_above_band.json`

---

### Fixture GR-006 — AirDoubleObstacle: player not jumping, above threshold height

**Scenario:** Player in Jump state but airborne_height >= 63.0 AND rects clearly NOT overlapping
(player X is behind obstacle, no X overlap). Confirms rect check is reached but returns false due to no X intersection.  
**Expected:** `false`  
**Note:** This verifies that the guard passing doesn't itself cause a collision — rect check must also pass.  
**File:** `tests/regression/fixtures/gr006_air_obstacle_no_x_overlap.json`

---

## 14. Open Ambiguities

These items require asset measurement or live-game confirmation before the regression
tests for the affected fixtures can be marked as definitive.

1. **pista.png height** — determines all LaneLayout Y positions. Must measure asset.
2. **VehicleFrog contentSize (bicho_0001.png dimensions)** — affects ground/air collision rect sizes and the jump guard threshold (`y <= 1`).
3. **obstaculo_1_c.png and obstaculo_1.png dimensions** — affect obstacle collision rect world positions.
4. **muro_2b.png dimensions** — affects SingleObstacle band calculation.
5. **Fixture GR-003 threshold boundary** — whether airborne_height exactly 63.0 produces a hit depends on rect overlap, which requires asset sizes.
