# Level Format

JSON schema for Turbo Race level files.  
All built-in levels are in `resources/levels/*.json`.  
External levels can be loaded from `user://` at runtime without rebuilding.

---

## Fields

### `schemaVersion` *(required, integer)*

Must equal `1` (current). The loader rejects files with a missing or different version.  
Increment this if the schema changes in a future release.

---

### `speedMultiplier` *(optional, float, default: 1.0)*

Multiplied by `START_WORLD_SPEED = 512.0 px/s` to give the initial world speed.

| Value | Initial speed |
|-------|--------------|
| 1.0   | 512 px/s     |
| 1.7   | 870 px/s     |
| 2.2   | 1126 px/s    |

---

### `distanceMultiplier` *(optional, float, default: 1.0)*

Multiplied by `MIN_DISTANCE_OBSTACLES = 568.9 px` to give minimum distance between obstacle groups.  
Higher = more breathing room between obstacles.

---

### `speedAcceleration` *(optional, float, default: 2.0)*

World speed increase per second (px/s²). Applied each frame:
```
world_speed += dt * speedAcceleration
```

---

### `maxWorldSpeed` *(optional, float, default: 0.0)*

Speed cap in px/s. `0` means uncapped. All built-in levels use a cap.

---

### `map` *(required, array of integers [0-9])*

Ordered list of obstacle group codes. Cycles back to the start when exhausted.

| Code | Type               | Count | Notes                        |
|------|--------------------|-------|------------------------------|
| 0    | Single wall        | 1     | Lower lane                   |
| 1    | Single wall        | 1     | Upper lane                   |
| 2    | Ground obstacle    | 1     | Player must jump             |
| 3    | Air obstacle       | 1     | Player must NOT jump too high |
| 4    | Double single wall | 2     | Lower lane, wider spacing    |
| 5    | Double single wall | 2     | Upper lane, wider spacing    |
| 6    | Triple ground      | 3     | Three ground obstacles       |
| 7    | Triple air         | 3     | Three air obstacles          |
| 8    | Double ground      | 2     | Two ground obstacles         |
| 9    | Double air         | 2     | Two air obstacles            |

---

## Example

```json
{
    "schemaVersion": 1,
    "speedMultiplier": 1.2,
    "distanceMultiplier": 1.5,
    "speedAcceleration": 2.0,
    "maxWorldSpeed": 1100.0,
    "map": [0, 1, 2, 3, 0, 1, 2, 3, 4, 5, 8, 9]
}
```

---

## External levels

To load a level from outside the compiled build, place the JSON file in the
Godot `user://` directory (platform-specific path; see Godot docs for location)
and call:

```gdscript
var data: LevelData = LevelData.load_external("user://my_level.json")
if data == null:
    print("Level failed validation")
```

The same schema validation runs for external files. Invalid files return `null`.

---

## Adding a new obstacle type

1. Create a new script extending `BaseObstacle` in `scenes/obstacles/`.
2. Call `_init_obstacle(size)` to set `obstacle_type` and `_local_rects`.
3. Override `collision(vehicle)` only if the default `base_collision` isn't right.
4. No changes to any Phase 2 base class are needed.

See `scenes/obstacles/wide_obstacle.gd` as a minimal example.
