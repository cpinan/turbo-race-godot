---
name: cocos2dx-to-godot
description: >
  Guide for porting a Cocos2d-x/C++ game to Godot 4 GDScript with full behavioral parity.
  Use when asked to port, migrate, or compare Cocos2d-x code to Godot 4 — or when debugging
  parity issues in an existing migration.
---

# Cocos2d-x → Godot 4 Migration Guide

Learned from porting Turbo Race (endless runner, mobile) from Cocos2d-x/C++ to Godot 4.7 GDScript.
Full reference: `docs/MIGRATION_NOTES.md` and `docs/SPEC.md` in this repo.

---

## 1. Coordinate system — Y-axis flip

Cocos2d-x is **Y-up** (origin bottom-left). Godot 2D is **Y-down** (origin top-left).

**Pattern used in this project:**
- Set the `GameScene` root node: `scale = Vector2(1, -1)`, `position = Vector2(0, WIN_H)`
- This flips the entire scene so C++ world-space positions work unchanged
- Every `Sprite2D` inside needs a counter-flip: `scale.y = -1` (otherwise textures appear upside-down)
- **UI (CanvasLayer) is exempt** — CanvasLayer bypasses the parent transform entirely, so draw all UI on CanvasLayer nodes with normal Y-down coordinates

```gdscript
# game_scene.tscn root node
scale = Vector2(1, -1)
position = Vector2(0, 768)

# each Sprite2D child that should appear right-side up
$Sprite2D.scale = Vector2(1, -1)
```

---

## 2. Jump arc — JumpBy is sine, not parabola

Cocos2d-x `JumpBy::create(duration, offset, height, jumps)` uses:

```
y_offset = height * |sin(π * t)|   where t ∈ [0,1]
```

A parabola `4t(1-t)` looks similar but is wrong — the peak is at different times:
- Sine: peaks at t = 0.5, air-obstacle collision window at t ≈ 0.149
- Parabola: peak also t = 0.5, but collision window at t ≈ 0.129 (earlier)

**Correct Godot implementation:**

```gdscript
static func jump_arc_offset(t: float) -> float:
    return MAX_PLAYER_JUMP * sin(t * PI)
```

Drive it with a timer accumulator in `_physics_process`:

```gdscript
_jump_t += delta / JUMP_DURATION          # 0 → 1
position.y = _player_y + jump_arc_offset(_jump_t)
if _jump_t >= 1.0:
    _is_jumping = false
    position.y = _player_y
```

---

## 3. Pure physics functions — the key architectural rule

All physics and collision logic must be **pure static functions** (no Node tree access, no `_process`).
This enables unit testing without a running scene.

```gdscript
# scripts/physics/vehicle_physics.gd
class_name VehiclePhysics

static func jump_arc_offset(t: float) -> float: ...
static func can_jump(airborne_height: float, is_jumping: bool) -> bool: ...
static func ground_collision_rect(pos_x, player_y, w, h) -> Rect2: ...
static func air_collision_rect(pos_x, pos_y, w, h) -> Rect2: ...
static func clamp_x(pos_x, content_w, win_w) -> float: ...
```

Test them with GUT without instantiating any nodes:

```gdscript
func test_cannot_jump_when_airborne() -> void:
    assert_false(VehiclePhysics.can_jump(10.0, false))
```

---

## 4. Z-depth ordering

Cocos2d-x uses `setLocalZOrder(z)` where higher z = in front.
Map it to Godot `z_index` via the C++ `GameDeep` enum formula:

```
z_index = int((WIN_H - z_param) / 10)
```

| Layer | C++ z_param | Godot z_index |
|-------|-------------|---------------|
| Air obstacles (always in front) | 0 | 76 |
| Player (dynamic, tracks lane_y) | WIN_H * 0.5 ≈ 384 | ~46 (recalculated each frame) |
| Single-lane obstacles (by lane) | lane_y | 39–46 |
| Ground jump obstacles (behind) | WIN_H * 0.5 = 384 | 38 |

Player z_index must update **every frame** based on its current Y position:

```gdscript
func _physics_process(_delta: float) -> void:
    var z_param := _player.player_y + _player.content_size.y * 0.75
    _player.z_index = int((WIN_H - z_param) / 10.0)
```

---

## 5. Collision rectangles — read from C++ exactly

Never guess collision rect offsets. Read `getGroundCollision()` and `getAirCollision()` in the C++ source.
Common pattern — rects are expressed as fractions of `contentSize`:

```gdscript
# From BaseVehicle::getGroundCollision()
static func ground_collision_rect(pos_x, player_y, w, h) -> Rect2:
    return Rect2(
        pos_x - w*0.5 + w*0.3,   # x: 30% inset
        player_y,                  # y: ground level
        w * 0.55,                  # width: 55% of sprite
        h * 0.3                    # height: 30% of sprite
    )

# From BaseVehicle::getAirCollision() — note: height uses WIDTH not height
static func air_collision_rect(pos_x, pos_y, w, h) -> Rect2:
    return Rect2(
        pos_x - w*0.5 + w*0.3,
        pos_y - h*0.5 + h*0.16,
        w * 0.55,
        w * 0.2          # intentional: uses w, not h
    )
```

---

## 6. Obstacle types and collision guards

Three obstacle types, each with its own collision guard before rect intersection:

| C++ class | Guard | What happens on hit |
|-----------|-------|---------------------|
| `SingleObstacle` (lane-band wall) | player Y must be within lane band `[top, top+h*0.37]` | instant death |
| `DoubleObstacle` (ground jump) | none (always collidable) | instant death |
| `AirDoubleObstacle` (air) | player must be **jumping** AND `airborne_height >= MAX_JUMP * 0.45` (= 63 units) | instant death |

```gdscript
# AirDoubleObstacle guard
static func check_air_collision(obs_rect, air_rect, airborne_h, is_jumping) -> bool:
    if not is_jumping:
        return false
    if airborne_h < MAX_PLAYER_JUMP * 0.45:   # 63.0
        return false
    return obs_rect.intersects(air_rect)
```

---

## 7. Input — touch + mouse unified

Cocos2d-x `HudLayer` splits the screen: left half = joystick, right half = jump.
Mirror this with separate event types for mobile (touch) and PC (mouse):

```gdscript
func _unhandled_input(event: InputEvent) -> void:
    var left_half := event.position.x < WIN_W * 0.5

    if event is InputEventScreenTouch:
        if left_half and event.pressed:
            _start_joystick(event.position, event.index)
        elif event.index == _joy_index and not event.pressed:
            _stop_joystick()
        elif not left_half and event.pressed:
            _player.do_jump()

    elif event is InputEventScreenDrag:
        if _joy_active and event.index == _joy_index:
            _update_joystick(event.position)

    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if left_half:
            if event.pressed: _start_joystick(event.position, -1)   # -1 = mouse mode
            else: _stop_joystick()
        elif event.pressed:
            _player.do_jump()

    elif event is InputEventMouseMotion and _joy_active and _joy_index == -1:
        _update_joystick(event.position)
```

`_joy_index = -1` flags mouse mode (vs touch finger index ≥ 0).

**Joystick thumb visual** must be handled independently in the HUD node (mirrors C++ `SneakyJoystickSkinnedBase`). Give HUD its own `_input` handler; don't couple game_scene → HUD for thumb position.

---

## 8. Parallax scroll

Cocos2d-x scrolls multiple background layers at different speeds.
`MAX_PARALLAX = 5` layers, each with a multiplier.

```gdscript
const PARALLAX_SPEEDS: Array[float] = [0.1, 0.2, 0.4, 0.6, 1.0]

func _scroll_parallax(world_speed: float, delta: float) -> void:
    for i in range(_parallax_layers.size()):
        var layer: Sprite2D = _parallax_layers[i]
        layer.position.x -= world_speed * PARALLAX_SPEEDS[i] * delta
        if layer.position.x < -WIN_W:
            layer.position.x += WIN_W * 2.0
```

---

## 9. Obstacle pooling

Cocos2d-x uses `ObstaclePool<T>`. Port directly as a GDScript class:

```gdscript
class_name ObstaclePool

var _scene: PackedScene
var _parent: Node
var _pool: Array[BaseObstacle] = []

func acquire() -> BaseObstacle:
    for obs in _pool:
        if not obs.visible:
            obs.visible = true
            return obs
    var obs: BaseObstacle = _scene.instantiate()
    _parent.add_child(obs)
    _pool.append(obs)
    return obs

func recycle(obs: BaseObstacle) -> void:
    obs.visible = false
```

One pool instance per obstacle type (`_single_pool`, `_double_pool`, `_air_pool`).

---

## 10. Scoring

```
score = obstacles_avoided * kScoreFactor    (kScoreFactor = 100.0)
```

Track `obstacles_avoided` (integer count), multiply on display. This matches C++ `ScoreModel.hpp` exactly.
Do NOT track accumulated distance or time — the C++ game does not.

---

## 11. World speed

```gdscript
const START_WORLD_SPEED: float = 512.0    # designWidth * 0.5
const MIN_DISTANCE:       float = 568.89  # designWidth / 1.8
const START_X_OBSTACLES:  float = 1945.6  # designWidth * 1.9
```

Speed increases over time per level JSON parameters. Apply per frame:

```gdscript
world_speed += level_data.speed_increase * delta
world_speed = minf(world_speed, level_data.max_speed)
```

---

## 12. Parity verification checklist

Before calling a system "ported", verify:

- [ ] All constants read from C++ source (not guessed or approximated)
- [ ] Collision rect fractions match C++ `contentSize` fractions exactly
- [ ] Jump arc uses `sin(πt)`, not parabola
- [ ] Air obstacle guard threshold is `MAX_JUMP * 0.45` = 63.0 units
- [ ] Z-index formula `int((WIN_H - z_param) / 10)` applied to all spawned nodes
- [ ] Joystick passes both X and Y to `do_move(Vector2)` — C++ `doMove(Vec2)` takes full 2D vector
- [ ] Pure physics functions have unit tests with golden-run fixtures
- [ ] Scoring uses `avoided_count * 100`, not continuous distance

---

## 13. GUT test commands

```sh
# Run all tests headless
godot --headless --path . \
  -s addons/gut/gut_cmdln.gd \
  -gdir=res://tests -gprefix=test_ -ginclude_subdirs -gexit

# Run single test file
godot --headless --path . \
  -s addons/gut/gut_cmdln.gd \
  -gtest=res://tests/unit/test_vehicle_physics.gd -gexit
```

Expected output on success: `X passed, 0 failed` with exit code 0.
