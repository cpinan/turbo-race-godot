# Architecture

## The core rule: pure functions + node wrappers

Every piece of gameplay logic that can be unit-tested must live as a **pure static function** in `scripts/physics/` or `scripts/data/`:
- plain inputs (floats, Vector2, Rect2, booleans)
- plain outputs (the same)
- zero dependency on the scene tree, `_process`, or any Node

Scene nodes in `scenes/` call these functions and apply results to their own state.
This is the single most important architectural invariant — it's what makes regression
tests tractable without spinning up a full scene.

---

## Phase 2 — Physics & collision layer

### Pure logic (`scripts/physics/`, `scripts/data/`)

```
VehiclePhysics       Jump arc, can_jump guard, collision rects, Y-limits, X-clamp
ObstaclePhysics      World-rect transform, base/single/air collision, pass predicate
WorldSpeed           Speed advance, initial speed/distance from level params
GameScore            Scoring formula (obstacles × 100), reset
LevelData            JSON loader, level struct
LaneLayout           Track Y-position geometry (playerStartY, wallHeight, lane Ys)
```

### Scene nodes (wrappers)

```
BaseVehicle (CharacterBody2D)
│   Owns state (IDLE/JUMP), player_y, content_size.
│   Calls VehiclePhysics.* for all logic.
│   Tween drives jump arc (parabola: offset = 140 * 4t(1-t), duration 0.6s).
│   Emits: jumped, landed, died.
└── VehicleFrog
        Idle animation: 2-frame toggle at 12 fps.
        Jump frame swap on jumped/landed signals.

BaseObstacle (Node2D)
│   Owns obstacle_type, content_size, _local_rects (set by subclass).
│   collision(vehicle) delegates to ObstaclePhysics.*.
│   do_update(speed_delta) moves obstacle left.
├── SingleObstacle   ObstacleType.SIMPLE, 1 local rect, lane-band guard
├── DoubleObstacle   ObstacleType.JUMP,   2 local rects
└── AirDoubleObstacle ObstacleType.NORMAL, 5 staircase rects, state+height guards
```

### Jump arc

Cocos2d-x uses `JumpBy(0.6s, Vec2(0,0), 140, 1)` — a single-parabola arc.
Godot equivalent: `Tween.tween_method(_apply_jump, 0.0, 1.0, 0.6)` where:
```
offset(t) = 140 * 4 * t * (1 - t)     # peaks at 140 at t=0.5
```
`_jump_start_y` is the sprite-center Y at ground level, so the vehicle returns to exactly that Y when the tween completes.

### Coordinate system

Y increases **upward** to match the Cocos2d-x reference implementation.
`Rect2.position` stores the bottom-left corner of each collision box.
`Rect2.intersects()` is axis-agnostic and works correctly either way.

### Obstacle collision rect transform

All obstacle collision rects are stored in local space (origin = bottom-left of sprite).
`ObstaclePhysics.world_rect(local, pos, size)` translates them to world space by
subtracting half the sprite's size — matching Cocos2d-x center-anchor `(0.5, 0.5)` behavior.

---

## Phase 3 — Core loop & data (planned)

- `autoload/game_manager.gd` — game state machine, obstacle pool management
- `autoload/score_model.gd` — holds a `GameScore`, emits `score_changed`
- `autoload/level_loader.gd` — wraps `LevelData.load_level()`, exposes current level
- `scenes/main/game_scene.gd` — spawning, parallax, per-frame update

---

## Phase 4 — Extensibility (planned)

Level JSON schema versioning + `user://` external loading.
Extension pattern: new obstacle/vehicle = new scene file + new GDScript, no base class changes.

---

## Phase 5 — Leaderboard (planned)

`godot-play-game-services` addon for Android.
Score submission via `GameManager` → platform-agnostic `ILeaderboardService` interface.
iOS/Game Center deferred.
