# Turbo Race — Godot Rewrite Plan

**Decision context:** moving from the Cocos2d-x/Axmol in-place refactor to a full rewrite in Godot 4, based on Godot's decisively larger and more institutionally stable community (Foundation-backed, 110k+ stars, active paid maintainers) versus Axmol's small single-maintainer-led project. This is a real rewrite, not a port — budget accordingly.

**Target:** Godot 4.7.x (current stable branch as of mid-2026).

---

## Phase 0 — Language decision

| Option | Fit |
|---|---|
| **GDScript** | Default recommendation. Godot's plugin ecosystem (GPGS, ads, most tutorials/community code) is GDScript-first; fastest iteration; you already have Godot 4 experience from the EarthBound prototype. |
| **C#** | Statically typed, closer to your Kotlin background syntactically. Viable, but the Mono/.NET export adds build complexity (separate export templates, larger binaries) and community plugins skew GDScript, so you'd sometimes be writing your own bindings. |

**Recommendation: GDScript**, specifically for the plugin-ecosystem alignment — the leaderboard plugin in Phase 5 is GDScript-native, and fighting language mismatch on top of a full rewrite adds risk for no real payoff.

## Phase 1 — Node/scene architecture (mapped from the current C++ classes)

| Cocos2d-x/C++ | Godot equivalent |
|---|---|
| `BaseVehicle` | `CharacterBody2D` scene + script — but movement stays **script-driven position math**, not Godot's built-in physics forces, to preserve the exact discrete jump arc (`0.6s`, `MAX_PLAYER_JUMP`) rather than approximate it with a physics simulation |
| `BaseObstacle` / `SingleObstacle` / `DoubleObstacle` / `AirDoubleObstacle` | Base obstacle scene using **scene inheritance** (Godot's `Inherits` feature), each variant overriding only what differs — mirrors your existing subclass hierarchy directly |
| Collision (`vCollision` rects, air-only lethal thresholds) | `Area2D` + `CollisionShape2D` for detection, but **exact original semantics ported as code**, not left to generic physics layers — e.g. `AirDoubleObstacle`'s "lethal only above 0.45× jump height while airborne" stays an explicit check in the obstacle's script |
| `ObstaclePool<T>` | Godot doesn't need manual pooling the way `cocos2d::Ref` did — reuse of instanced scenes via a simple object-pool pattern is still worth keeping for spawn-rate perf, but no retain/release bookkeeping required |
| `ScoreModel`, `LevelLoader` | Autoload (singleton) scripts — same responsibility, same JSON format if you keep it (see Phase 4) |
| `GameLayer` | Main scene + a `GameManager` autoload holding run state, decoupled from any single scene so menus/pause/game-over can all reference it |

## Phase 2 — Physics/collision porting (highest-risk phase)

- Extract the exact constants and math from the current C++ source first (jump timing, world-speed acceleration, collision rect dimensions) — this is the spec the Godot port is tested against, not re-derived from scratch.
- Write the physics/collision logic as plain GDScript functions taking simple inputs (position, velocity, dt) and returning results, independent of node tree structure — testable in isolation.
- Use **GUT** (Godot Unit Test, the standard GDScript testing addon) for regression tests replaying recorded input against known-good outputs from the original game.
- Do not proceed to Phase 3 until a side-by-side comparison (recorded run in original vs. same input in Godot port) matches frame-for-frame on collision outcomes — this is the phase most likely to introduce subtle bugs if rushed.

## Phase 3 — Core loop & content port

- Vehicle movement, obstacle spawning/pooling, score/coin tracking.
- Level generator (Endless) ported from `LevelGenerator`/`SegmentLibrary` logic.
- Basic UI: `HomeScene`, `GameLayer`, `PauseLayer` equivalents as Godot scenes.

## Phase 4 — Extensibility & custom levels (this is where Godot genuinely helps more than Cocos2d-x did)

- **Keep JSON as the level format** — no reason to switch to `.tres` Resources; your existing schema, editing habits, and any tooling carry over directly. Godot's `FileAccess` + `JSON.parse_string()` handles loading with no custom parser needed.
- **Schema versioning + load-time validation**, same as planned before — reject malformed files at startup with a clear error.
- **External level loading (new capability):** Godot can load JSON (or even whole `.pck` resource packs) from `user://` at runtime without recompiling the game. This means custom/community levels can be distributed as downloadable files post-launch — something the original C++ build couldn't do without a full app update. Worth designing for from the start if "custom levels" means community content, not just your own authored levels.
- **New obstacle/vehicle types:** new scenes inheriting the base obstacle/vehicle scene — same low-friction extension pattern as the class hierarchy gave you in C++, arguably easier since scene inheritance is visual/editor-assisted.
- **Feature flags:** a simple JSON config (or Godot's `ProjectSettings` custom keys) for toggling experimental mechanics per level or build.

## Phase 5 — Leaderboard integration

- **Android:** [`godot-sdk-integrations/godot-play-game-services`](https://github.com/godot-sdk-integrations/godot-play-game-services) — actively maintained Godot 4.x plugin (in the official Asset Library), Node-based (not the old autoload-per-feature pattern), covers sign-in, leaderboards, achievements, and save-game sync. This replaces your Cocos2dX-GPGS wrapper directly; no need to port that library since Godot already has a current equivalent.
- **iOS:** no equivalent first-party-quality plugin is as clearly maintained today — plan on either a community Game Center plugin (verify current maintenance status before committing) or a small custom GDExtension bridge to GameKit if nothing suitable is actively maintained at build time.
- Wire `ScoreModel`'s end-of-run score into the plugin's `submitScore`-equivalent call from `GameManager`; add achievement hooks for milestones.
- Silent sign-in on launch, explicit leaderboard entry point in the menu UI, game fully playable signed-out.

## Phase 6 — Ads/monetization (deferred, unchanged)

Out of scope for this rewrite, as agreed. When ready: Godot has community AdMob plugins (verify current maintenance before adopting, same diligence as the leaderboard plugin) — same bridge-behind-an-interface pattern as everything else here.

## Phase 7 — Rollout timeline (indicative — larger than the Axmol path since this is a real rewrite)

| Weeks | Milestone |
|---|---|
| 1 | Constant/spec extraction from current C++ source |
| 2–3 | Godot project setup, node architecture (Phase 1) |
| 4–7 | Physics/collision port + regression testing against original (Phase 2) — do not compress this |
| 8–10 | Core loop, obstacles, level generator, basic UI (Phase 3) |
| 11–12 | Extensibility framework, JSON schema versioning, external level loading (Phase 4) |
| 13–14 | Leaderboard integration, Android first (Phase 5) |
| 15 | iOS leaderboard + platform QA |
| 16 | Closed beta |
| 17 | Release |

---

**Open question:** for "custom levels," are you designing for *your own* authored content only, or do you want community-submitted levels as a feature (which changes Phase 4's external-loading design from a nice-to-have into a real requirement with its own validation/moderation considerations)?
