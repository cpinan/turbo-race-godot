---
name: cocos2dx-to-godot
description: >
  Guide for porting a Cocos2d-x/C++ game to Godot 4 GDScript with full behavioral parity.
  Use when asked to port, migrate, or compare Cocos2d-x code to Godot 4 — or when debugging
  parity issues in an existing migration.
usage: /cocos2dx-to-godot
source: https://github.com/cpinan/turbo-race-godot
---

<!--
  Reusable Claude Code skill — learned from porting Turbo Race (endless runner)
  from Cocos2d-x/C++ to Godot 4.7 GDScript.

  To use in another project:
    1. Copy this file to <your-project>/.claude/skills/cocos2dx-to-godot/SKILL.md
    2. Open the project in Claude Code
    3. Invoke with /cocos2dx-to-godot
-->

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

## 2. Jump arc — JumpBy is a PARABOLA (and it is additive)

An earlier revision of this guide claimed `JumpBy` was a sine. It is not.
`cocos2d/2d/CCActionInterval.cpp` (cocos2d-x-4.0), verbatim:

```cpp
void JumpBy::update(float t)
{
    // parabolic jump (since v0.8.2)
    if (_target)
    {
        float frac = fmodf( t * _jumps, 1.0f );
        float y = _height * 4 * frac * (1 - frac);
        y += _delta.y * t;
        float x = _delta.x * t;
#if CC_ENABLE_STACKABLE_ACTIONS
        Vec2 currentPos = _target->getPosition();
        Vec2 diff = currentPos - _previousPos;
        _startPosition = diff + _startPosition;   // <- folds in external moves
        Vec2 newPos = _startPosition + Vec2(x,y);
        _target->setPosition(newPos);
        _previousPos = newPos;
#else
        _target->setPosition(_startPosition + Vec2(x,y));
#endif
    }
}
```

Two things to port, and both were missed in Turbo Race's first pass:

**(a) The curve is `height * 4t(1-t)`, not `height * sin(πt)`.** They agree at
t = 0, 0.5 and 1, which is why endpoint-and-peak tests pass either way. They
disagree in between — at t = 0.25 the parabola gives 0.75 of peak, the sine
0.7071. Write a test at a quarter point, not just the endpoints.

**(b) `CC_ENABLE_STACKABLE_ACTIONS` defaults to `1`,** so the action folds any
external position change into `_startPosition` and adds its arc on top. If the
game also moves the node while the jump runs — lane changes in a runner, say —
those moves apply immediately *and survive the landing*. Tweening `position.y`
absolutely from a launch Y captured at takeoff silently reverts them, and while
airborne it desyncs any hitbox derived from `position.y` from one derived from
the lane variable.

**Correct Godot implementation:**

```gdscript
static func jump_arc_offset(t: float) -> float:
    var frac: float = fmod(t, 1.0)          # _jumps = 1
    return MAX_PLAYER_JUMP * 4.0 * frac * (1.0 - frac)
```

Drive it with an accumulator that re-reads the live lane position every frame:

```gdscript
func advance_jump(delta: float) -> void:
    if state != ActorState.JUMP:
        return
    _jump_t += delta / JUMP_DURATION          # 0 → 1
    if _jump_t >= 1.0:
        _jump_t = 0.0
        state = ActorState.IDLE
        position.y = player_y + content_size.y * 0.5
        return
    # `player_y`, NOT a frozen launch Y — this is what makes it additive.
    position.y = (player_y + content_size.y * 0.5
        + jump_arc_offset(_jump_t))
```

Call it from the game scene's `_physics_process` *after* the frame's movement
update, rather than overriding `_physics_process` on the vehicle — that keeps
pause/state gating in one place and guarantees the ordering.

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

Cocos2d-x uses `setLocalZOrder(z)` where higher z = in front. The spawn call is

```cpp
addChild(node, static_cast<int>(WIN_SIZE.height - z_param) + toZ(GameDeep::X));
```

**Do not rescale the per-node term.** An earlier revision of this guide
suggested `int((WIN_H - z_param) / 10)`; that collapses a 768-value range into
~8 buckets, so nodes that C++ separates by a few pixels of depth end up tied and
resolved by tree order instead. In Turbo Race it made the player tie with
bottom-lane walls and render *behind* ground obstacles it was colliding with.

Godot's `z_index` is clamped to ±4096, which is the only real constraint:

- **Per-node depth** — port `int(WIN_H - z_param)` verbatim, 1px granularity
  intact. For a 768-tall design that lands in roughly 370–768.
- **Layer bases** — the `GameDeep` constants themselves (-9999 … -2500) are out
  of range, so rescale *those* into ordered constants. Only their ordering
  matters, since nothing is interleaved between layers.

```gdscript
const Z_SKY: int = -600
const Z_CLOUD: int = -590
const Z_BG_BACK: int = -580
const Z_BG_MID: int = -570
const Z_BG_FRONT: int = -560
const Z_TRACKS: int = -550
# game elements: int(WIN_H - z_param), i.e. 370-768 — all in front of the above
```

| Layer | C++ z_param | Godot z_index |
|-------|-------------|---------------|
| Air obstacles (always in front) | 0 | 768 |
| Single-lane obstacles (by lane) | lane_y | 393–463 |
| Player (dynamic) | player_y + h*0.75 | 372–462, recalculated each frame |
| Ground jump obstacles | WIN_H * 0.5 = 384 | 384 |

Player z_index must update **every frame** based on its current Y position:

```gdscript
func _physics_process(_delta: float) -> void:
    var z_param := _player.player_y + _player.content_size.y * 0.75
    _player.z_index = int(WIN_H - z_param)
```

Child sprites (shadows) use `z_index = -1` with Godot's default
`z_as_relative = true`, so they sit one step behind their parent wherever the
parent lands — same as C++ `addChild(shadow, -1)`.

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

**Never "tune" these for feel.** Turbo Race 1.0.0 shipped `0.355 / 0.34`
described in its changelog as "matches C++ feel" — a 38% narrower hitbox that
widened jump-timing tolerance by ~21% and was the single biggest reason players
reported the port as too easy. Worse, the four unit tests covering the rects were
rewritten to assert the tuned numbers, so CI certified the divergence green for
three releases.

Put the fractions in named constants and add a test that reads them back out of
your spec document, so editing one without the other fails the build:

```gdscript
const RECT_X_INSET: float = 0.30
const RECT_WIDTH:   float = 0.55
```

If a value genuinely must change, the C++ source is the authority and the spec
document changes in the same commit.

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

**The `add_child` on the growth path is load-bearing.** C++
`ObstaclePool<T>::acquire()` falls back to `new T()`, which is a fully
constructed object; the naive GDScript translation `return _scene.instantiate()`
is not. A node that never enters the tree never runs `_ready()`, so every field
initialised there stays at its default. In Turbo Race that meant
`content_size == Vector2.ZERO` and an empty collision-rect array, producing an
obstacle that **rendered nothing, could never kill the player, still awarded
score when it passed, and poisoned the free list permanently once recycled** —
plus a leak. It reproduced on every level.

Two defences worth having:

- Size the prefill from the actual worst case. Slide a window the width of your
  in-flight group count across each level map and take the peak concurrent count
  per pool type — not a guessed round number.
- Assert in tests that an obstacle acquired past the prefill count is
  `is_inside_tree()` and has non-empty collision rects.

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
- [ ] Collision rect fractions match C++ `contentSize` fractions exactly, and no
      constant was "tuned for feel" anywhere in the port's history
- [ ] Jump arc uses the parabola `4t(1-t)`, not `sin(πt)` — tested at a quarter
      point, not just endpoints and peak
- [ ] Jump/move actions that C++ stacks (`CC_ENABLE_STACKABLE_ACTIONS`) are
      additive in the port: motion applied during an action survives it
- [ ] Air obstacle guard threshold is `MAX_JUMP * 0.45` = 63.0 units
- [ ] Z-index uses `int(WIN_H - z_param)` at full 1px granularity; only the
      layer-base constants are rescaled to fit Godot's ±4096 clamp
- [ ] Pool `acquire()` parents nodes on its growth path, and prefill counts are
      derived from the real worst-case concurrent count per level map
- [ ] Spawn loops count the same unit as C++ (groups vs. individual obstacles)
- [ ] Per-frame updates C++ calls unconditionally are called unconditionally —
      a zero-input `doMove()` still clamps and re-syncs position
- [ ] Every C++ `addChild(sprite, …)` has a counterpart; decorative-looking
      children (shadows) are often the only readout of a gameplay variable
- [ ] Joystick passes both X and Y to `do_move(Vector2)` — C++ `doMove(Vec2)` takes full 2D vector
- [ ] Pure physics functions have unit tests with golden-run fixtures
- [ ] Level content is ported, not authored — map length and per-level
      multipliers asserted against the C++ JSON
- [ ] Scoring uses `avoided_count * 100`, not continuous distance
- [ ] No test asserts a value that contradicts the spec document; add a test
      that reads the spec at runtime so the two cannot drift apart silently

---

## 13. UI layout — converting Cocos2d-x positions to Godot

Cocos2d-x uses center-anchor for Labels by default. To port a label position to Godot:

1. Compute the **Godot Y** of the label center: `godot_y = BG_height - cocos_y`
2. Compute the **Godot X** of the label center: same as cocos_x (X axis unchanged)
3. In Godot, create a Label with a rect that centers on that point:
   - `offset_top = godot_y - label_h/2`
   - `offset_bottom = godot_y + label_h/2`
   - Use `horizontal_alignment = CENTER` (= 1) to match Cocos2d-x center anchor

**Example — PopUpLoseLayer score labels (game over screen):**
```
BG = 520×480, badge = 175×128, o = Vec2(260, 240) (BG center, Y-up)
scoreLabel cocos pos: x = o.x + badge_w/2 = 347.5,  y = o.y - badge_h*0.1 = 227.2
  → Godot center: x=347.5, y=480-227.2=253
maxScoreLabel: y_cocos = 227.2 - badge_h*0.28 = 191.4  → Godot y=289

Godot Label rects:
  ScoreLabel: offset_left=200, offset_top=232, offset_right=500, offset_bottom=274
  BestLabel:  offset_left=200, offset_top=268, offset_right=500, offset_bottom=310
  both: horizontal_alignment=1 (CENTER)
```

---

## 14. Dynamic Label positioning — C++ anchor formula

`GameLayer::_showAudioPlaying()` uses left anchor + formula:
```cpp
lblMusic->setAnchorPoint(Vec2(0, 0.5));
lblMusic->setPositionX(visibleWidth - musicSize.width * 1.1);
```

Godot equivalent — measure text width after one frame, then apply:
```gdscript
func show_song_label(track_name: String) -> void:
    var lbl := Label.new()
    lbl.text = "Playing " + track_name
    lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    lbl.size = Vector2(WIN_W, 50.0)   # max width so layout can measure
    lbl.position = Vector2(0.0, START_Y_OFFSCREEN)
    add_child(lbl)
    await get_tree().process_frame    # wait for Godot to compute natural size
    if not is_instance_valid(lbl): return
    var text_w: float = lbl.get_minimum_size().x
    lbl.position.x = maxf(WIN_W - text_w * 1.1, 0.0)
    # now start tween animation
```

Key: `lbl.size` is zero until after `add_child`. `get_minimum_size()` needs one frame.

---

## 15. Debug collision overlay in Y-flipped scenes

`_draw()` on the root Node2D draws **behind** all child sprites. With Y-flip scenes (`scale=(1,-1)`), this makes debug outlines invisible.

Fix: create a child Node2D with `z_index = 1000`:

```gdscript
# scripts/debug_collision_overlay.gd
extends Node2D
var game_scene: GameScene = null

func _draw() -> void:
    if not game_scene: return
    var p := game_scene._player
    if p:
        draw_rect(p.get_ground_collision(), Color(0,1,0,1), false, 3.0)
        draw_rect(p.get_air_collision(),    Color(0,1,1,1), false, 3.0)
    for obs in game_scene._obstacles:
        for r in obs.get_world_rects():
            draw_rect(r, Color(1,0.2,0,1), false, 3.0)
```

Wire it in `_ready()`:
```gdscript
@export var debug_collision: bool = false
var _debug_overlay: Node2D = null

func _ready() -> void:
    # ... existing setup ...
    if debug_collision:
        _debug_overlay = Node2D.new()
        _debug_overlay.set_script(load("res://scripts/debug_collision_overlay.gd"))
        _debug_overlay.z_index = 1000
        add_child(_debug_overlay)
        _debug_overlay.set("game_scene", self)

func _physics_process(delta: float) -> void:
    # ... existing logic ...
    if debug_collision and _debug_overlay:
        _debug_overlay.queue_redraw()
```

Child inherits parent's Y-flip transform, so world-space Rect2 values draw correctly.

---

## 16. Android Play Store release workflow

**Build signed AAB:**
```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless \
  --export-release "Android Release" builds/turborace_vN_release.aab
```

**Generate native symbols zip** (for Play Console crash symbolication):
```sh
cd android/build/build/intermediates/merged_native_libs/standardRelease/\
mergeStandardReleaseNativeLibs/out
zip -r /path/to/builds/turborace_vN_symbols.zip lib/
```

**Version code in built AAB** comes from `export_presets.cfg` → Gradle property `export_version_code`. Verify with:
```sh
grep versionCode android/build/build/intermediates/merged_manifests/\
standardRelease/processStandardReleaseManifest/AndroidManifest.xml
```

**Play Console upload flow:**
1. Create new release
2. Upload `*_release.aab`
3. Upload `*_symbols.zip` under "Native debug symbols"
4. Release name auto-fills as `{version_name} ({version_code})` e.g. `1.0.0 (4)`

**Safe-to-ignore Play Console warnings for Godot games:**
- *"No deobfuscation file"* — Godot Java layer is boilerplate only; real code is in `.so` (already covered by symbols.zip). R8/ProGuard not worth enabling.
- *"Remove orientation restrictions"* — landscape-only is correct for this game type; portrait would require full UI/gameplay redesign.

**Never commit `export_presets.cfg`** — contains release keystore password. Already gitignored.

---

## 17. Android accelerometer tilt control

Godot's `Input.get_accelerometer()` returns **device-frame (portrait) coordinates** and does NOT adjust for screen orientation. Theoretical axis predictions are unreliable — always verify on-device.

**Enable in project.godot** (disabled by default; without this, returns Vector3.ZERO silently):
```ini
[input_devices]
sensors/enable_accelerometer=true
```

**Empirically confirmed mapping for SCREEN_LANDSCAPE:**
- `accel.y` → vertical player movement (tilt top of screen up/down)
- `accel.x` → horizontal player movement (roll screen left/right)

**Implementation pattern:**
```gdscript
# Constants
const TILT_DEAD_ZONE: float = 1.5   # m/s² — below this: no movement
const TILT_MAX_DIST:  float = 5.0   # m/s² — at this tilt: full speed
const TILT_X_MULT:    float = 2.0   # horizontal axis needs extra speed for feel parity

# Calibration — call at game start and on restart
var _tilt_baseline:   float = 0.0
var _tilt_baseline_x: float = 0.0

func _calibrate_tilt() -> void:
    if OS.has_feature("android") and SaveManager.get_control_type() == "tilt":
        var a: Vector3 = Input.get_accelerometer()
        _tilt_baseline   = a.y
        _tilt_baseline_x = a.x

# Per-frame in _physics_process
func _apply_tilt(delta: float) -> void:
    var accel: Vector3 = Input.get_accelerometer()
    var raw_y: float   = accel.y - _tilt_baseline
    var raw_x: float   = accel.x - _tilt_baseline_x
    var norm_y: float  = 0.0
    var norm_x: float  = 0.0
    if absf(raw_y) > TILT_DEAD_ZONE:
        var t := clampf((absf(raw_y) - TILT_DEAD_ZONE) / (TILT_MAX_DIST - TILT_DEAD_ZONE), 0.0, 1.0)
        norm_y = t if raw_y > 0.0 else -t   # positive accel.y → player UP
    if absf(raw_x) > TILT_DEAD_ZONE:
        var t := clampf((absf(raw_x) - TILT_DEAD_ZONE) / (TILT_MAX_DIST - TILT_DEAD_ZONE), 0.0, 1.0)
        norm_x = t if raw_x > 0.0 else -t   # positive accel.x → player RIGHT
    if norm_y != 0.0 or norm_x != 0.0:
        var spd := VehiclePhysics.DEFAULT_SPEED * delta * PHYSICS_FPS
        _player.do_move(Vector2(norm_x * spd * TILT_X_MULT, norm_y * spd), WIN_W)
```

**Real-time debug overlay** (gate on `debug_collision` export var; remove in release):
```gdscript
var _tilt_dbg_canvas: CanvasLayer = null
var _tilt_dbg_label:  Label       = null

func _setup_tilt_debug() -> void:
    if not debug_collision or not OS.has_feature("android"): return
    if SaveManager.get_control_type() != "tilt": return
    _tilt_dbg_canvas = CanvasLayer.new()
    _tilt_dbg_canvas.layer = 50
    add_child(_tilt_dbg_canvas)
    _tilt_dbg_label = Label.new()
    _tilt_dbg_label.position = Vector2(10.0, 10.0)
    _tilt_dbg_label.add_theme_font_size_override("font_size", 40)
    _tilt_dbg_label.add_theme_color_override("font_color", Color.YELLOW)
    _tilt_dbg_canvas.add_child(_tilt_dbg_label)

# In _physics_process, every frame:
if _tilt_dbg_label != null:
    var a := Input.get_accelerometer()
    _tilt_dbg_label.text = "x=%.1f dx=%.1f\ny=%.1f dy=%.1f" % [
        a.x, a.x - _tilt_baseline_x, a.y, a.y - _tilt_baseline]
```

CanvasLayer bypasses the parent's Y-flip transform, so positions are in screen space — no coordinate conversion needed.

**Tilt mode wiring:**
- Hide joystick in HUD when tilt active: `_joy_bg.visible = not tilt_mode`
- Skip joystick input in `_unhandled_input` when tilt active
- Any screen touch in tilt mode = jump (no left/right split)
- Persist choice via `SaveManager.get/set_control_type()` (values: `"joystick"` / `"tilt"`)

---

## 18. GUT test commands

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
