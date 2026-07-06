# Leaderboard & Achievement Setup

## Plugin

Uses [`godot-sdk-integrations/godot-play-game-services`](https://github.com/godot-sdk-integrations/godot-play-game-services) v3.2.0.

**iOS/Game Center is deferred.** The `LeaderboardService` autoload is platform-agnostic — when an iOS backend is added later it goes in `leaderboard_service.gd` and calling code stays unchanged.

---

## Installation (Android only)

1. Download `godot-play-game-services-v3.2.0.zip` from the [releases page](https://github.com/godot-sdk-integrations/godot-play-game-services/releases/tag/v3.2.0).
2. Extract and copy the `addons/godot-play-game-services/` folder into this project, replacing the stub currently there.
3. In Godot editor → **Project → Project Settings → Plugins** → enable **Godot Play Game Services**.
4. In **Project → Export → Android**, add `USE_CREDENTIALS_JSON=1` and set the path to your `google-services.json`.

---

## Google Play Console setup

1. Create a game in Google Play Console → **Play Games Services → Setup and Management**.
2. Add your Android app (package name matches `proj.android/` build config).
3. Create leaderboards and achievements with the IDs below.

---

## Leaderboard IDs

| Mode   | Android ID                  |
|--------|-----------------------------|
| Easy   | `CgkIyb_B9_4ZEAIQAg`        |
| Normal | `CgkIyb_B9_4ZEAIQAw`        |
| Hard   | `CgkIyb_B9_4ZEAIQBA`        |

Story mode has no leaderboard (returns empty string from `_leaderboard_id_for_level`).

---

## Achievement IDs (Android)

| Achievement                              | ID                          |
|------------------------------------------|-----------------------------|
| More than 3000                           | `CgkIyb_B9_4ZEAIQBQ`        |
| Play 10 times                            | `CgkIyb_B9_4ZEAIQCg`        |
| Play 100 times                           | `CgkIyb_B9_4ZEAIQCQ`        |
| Play 1000 times                          | `CgkIyb_B9_4ZEAIQCw`        |
| Avoid 25 in Hard                         | `CgkIyb_B9_4ZEAIQBg`        |
| Avoid 50 in Normal                       | `CgkIyb_B9_4ZEAIQBw`        |
| Avoid 100 in Easy                        | `CgkIyb_B9_4ZEAIQCA`        |
| Jump 50 obstacles                        | `CgkIyb_B9_4ZEAIQDA`        |
| Jump 1000 obstacles                      | `CgkIyb_B9_4ZEAIQFg`        |
| Score ≥ 10000 Easy                       | `CgkIyb_B9_4ZEAIQDQ`        |
| Score ≥ 8000 Normal                      | `CgkIyb_B9_4ZEAIQDg`        |
| Score ≥ 5000 Hard                        | `CgkIyb_B9_4ZEAIQDw`        |
| Score ≥ 30000 Easy                       | `CgkIyb_B9_4ZEAIQGw`        |
| Score ≥ 15000 Normal                     | `CgkIyb_B9_4ZEAIQHA`        |
| Score ≥ 10000 Hard                       | `CgkIyb_B9_4ZEAIQHQ`        |
| Avoid 100 in Hard                        | `CgkIyb_B9_4ZEAIQFw`        |
| Play in accelerometer mode               | `CgkIyb_B9_4ZEAIQEg`        |
| Accelerometer + score ≥ 3000             | `CgkIyb_B9_4ZEAIQEw`        |
| Average ≥ 1000 in 50+ games              | `CgkIyb_B9_4ZEAIQEA`        |
| Total score ≥ 100000                     | `CgkIyb_B9_4ZEAIQEQ`        |

---

## Sign-in flow

`LeaderboardService._ready()` calls `initialize()` on the plugin if available.
The plugin emits `user_authenticated(bool)` — `LeaderboardService` sets `_signed_in`.

All score submission and achievement unlock calls are silent no-ops if:
- The plugin singleton doesn't exist (non-Android build), OR
- `_signed_in == false` (sign-in failed or pending)

A failed sign-in never blocks gameplay. The degradation test in
`tests/unit/test_leaderboard_service.gd` verifies this.

---

## iOS / Game Center (future)

When adding iOS support: implement `_try_sign_in()`, `submit_score()`, and
`unlock_achievement()` for iOS in `leaderboard_service.gd` using a platform check:
```gdscript
if OS.get_name() == "Android":
    # use GodotPlayGameServices plugin
elif OS.get_name() == "iOS":
    # use Game Center plugin
```
No changes to `GameManager` or calling code are needed.
