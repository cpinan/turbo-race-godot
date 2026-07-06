# Turbo Race → Godot Migration — Claude Code Execution Plan

**Audience:** Claude Code, with read access to the existing `cpinan/Turbo-Race` (Cocos2d-x/C++) repo and write access to a new Godot 4.7.x project.
**Ground rules for every phase:**
1. **Read the actual C++ source before writing any Godot code for that system.** Never guess constants, thresholds, or collision semantics — extract them from `Classes/models`, `Classes/common`, `Classes/ui` directly.
2. **One phase = one branch = one PR.** Do not start Phase N+1 until Phase N's tests pass and its Definition of Done is met.
3. **Every phase that ports behavior ships with tests proving behavioral parity with the original**, not just "it runs."
4. **Every phase updates documentation in the same PR that adds the code** — docs are not a final cleanup pass.
5. **Commit messages reference the phase and the original file(s) being ported**, e.g. `feat(phase-2): port BaseVehicle jump arc from Classes/models/BaseVehicle.cpp`.

---

## Scope: what this migration is (and isn't)

**Primary goal: get the game running in Godot with behavior matching the current Cocos2d-x build.** Not a redesign, not new mechanics — parity first.

**Confirmed future milestones, deliberately out of scope here but not architecturally blocked:**
- **Community-submitted levels** (Phase 4 builds author-only levels now; external loading is designed so this slots in later without rework).
- **iOS / Game Center** (Phase 5 is Android-only; the leaderboard interface stays platform-agnostic so iOS is additive later).
- **Advanced level design** — moving obstacles, missing-track/gap sections, and similar new mechanics. These are **not** part of this migration. Because obstacles are built via scene inheritance from a common base (Phase 1/2), adding a `MovingObstacle` or `TrackGap` variant later should mean a new scene + script, not a change to ported code — but do not build these variants now. Building them speculatively risks guessing at mechanics that haven't been designed yet.

If at any point a phase's design decision would make one of these harder later, flag it in `MIGRATION_NOTES.md` rather than silently either building it now or ignoring the constraint.

---

## Phase 0 — Repo & environment setup

**Tasks:**
- Create new repo `turbo-race-godot` (separate from `cpinan/Turbo-Race`, which stays as the untouched reference implementation until Phase 6 is verified).
- Initialize Godot 4.7.x project, GDScript.
- Install **GUT** (Godot Unit Test) addon for testing.
- Set up folder structure:
  ```
  turbo-race-godot/
  ├── addons/gut/                  # test framework
  ├── autoload/                    # GameManager, ScoreModel, LevelLoader
  ├── scenes/
  │   ├── vehicles/
  │   ├── obstacles/
  │   ├── ui/
  │   └── main/
  ├── scripts/
  │   ├── physics/                 # pure logic, no node deps — see Phase 2
  │   └── data/
  ├── resources/levels/             # JSON level files, ported as-is where possible
  ├── tests/
  │   ├── unit/
  │   └── regression/               # golden-run comparisons vs. original
  ├── docs/
  │   ├── ARCHITECTURE.md
  │   ├── MIGRATION_NOTES.md        # running log: C++ symbol → Godot equivalent
  │   └── SPEC.md                   # extracted constants/behavior spec (Phase 1)
  ├── .github/workflows/tests.yml
  └── README.md
  ```
- Set up CI: GitHub Actions running GUT headless on every push:
  ```yaml
  - run: godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
  ```

**Docs produced:** `README.md` (project overview, how to run, how to test), empty `MIGRATION_NOTES.md` scaffold.

**Definition of Done:** empty Godot project boots headless in CI, GUT runs (even with zero tests), README explains setup to a new contributor.

---

## Phase 1 — Spec extraction (no Godot code yet)

**Tasks:**
- Read `Classes/models/BaseVehicle.cpp/.h`, `BaseObstacle`, `SingleObstacle`, `DoubleObstacle`, `AirDoubleObstacle`, `Constants.h` (or wherever constants live in the current repo — confirm actual filenames, don't assume).
- Extract into `docs/SPEC.md`: every gameplay constant (jump height/duration, world speed + acceleration curve, collision rect dimensions, lethal thresholds), and every level JSON field with its meaning and valid range.
- Record at least 3 "golden runs": fixed input sequences (e.g. hardcoded jump timings against known obstacle placements) and their expected outcomes (survive/die, score). **No recorded footage exists — derive expected outcomes purely by tracing the collision logic in the C++ source.** Where the logic is ambiguous or a boundary case isn't obvious from reading it, note the ambiguity explicitly in `SPEC.md` rather than guessing, so it can be confirmed against the running original build if needed.

**Docs produced:** `docs/SPEC.md` (the single source of truth every later phase is tested against).

**Definition of Done:** `SPEC.md` reviewed and confirmed accurate against source; golden-run fixtures committed to `tests/regression/fixtures/`.

---

## Phase 2 — Physics & collision core (highest-risk phase)

**Tasks:**
- Implement vehicle movement and jump arc as pure GDScript functions in `scripts/physics/` — plain inputs/outputs (position, velocity, dt, state), **no node tree dependency**, matching `SPEC.md` exactly.
- Implement each obstacle type's collision check as pure functions in the same style, preserving exact semantics (e.g. `AirDoubleObstacle` lethal only above the documented threshold while airborne).
- Only after the pure logic is tested: wrap in scene nodes (`CharacterBody2D` for vehicle, `Area2D`-based scenes per obstacle type via scene inheritance) that call the pure functions and apply results to node position/state.
- Write GUT unit tests in `tests/unit/` for every pure function (normal case + boundary conditions — e.g. exactly at the lethal threshold).
- Write GUT regression tests in `tests/regression/` replaying Phase 1's golden-run fixtures against the new implementation; must match expected outcomes exactly.

**Docs produced:** `docs/MIGRATION_NOTES.md` entries for every ported class (`BaseVehicle.cpp → scenes/vehicles/base_vehicle.gd`, etc.), with a one-line note on any semantic decision made during porting. `docs/ARCHITECTURE.md` section on the physics/collision layer explaining the pure-function-plus-node-wrapper pattern and why it's structured that way.

**Definition of Done:** all unit + regression tests pass in CI; `MIGRATION_NOTES.md` has an entry for every file touched; no regression test outcome differs from the original.

---

## Phase 3 — Core loop & content

**Tasks:**
- Port `ObstaclePool<T>` pattern (simpler in Godot — no ref-counting needed, but keep pooling for spawn-rate performance).
- Port `ScoreModel`, `LevelLoader` as autoloads, reusing the existing JSON level format (parse via `FileAccess` + `JSON.parse_string`).
- Port `LevelGenerator`/`SegmentLibrary` (Endless mode) logic.
- Port basic scenes: main menu, game scene, pause screen (functional parity, not final visual polish).
- GUT unit tests for `ScoreModel` and `LevelLoader` (including malformed-JSON handling).

**Docs produced:** `MIGRATION_NOTES.md` entries for this phase's ported files; `ARCHITECTURE.md` section on the autoload/data layer.

**Definition of Done:** a full run is playable start-to-death using ported logic; tests pass; docs updated.

---

## Phase 4 — Extensibility & custom levels

**Scope for this migration:** your own authored levels only. Community-submitted levels are a confirmed future milestone, not part of this phase — but the design below (external loading, schema validation) is built so that milestone doesn't require revisiting this phase's architecture.

**Tasks:**
- Add `schemaVersion` field to level JSON if not already present; implement load-time validation with clear error reporting for malformed files.
- Implement external level loading from `user://` (or a designated directory) so new level JSON files can be added without rebuilding the project — build the loading mechanism now, but skip any in-game import UI or moderation flow; those belong to the future community-levels milestone.
- Add at least one new obstacle or vehicle type as a concrete test of the extension pattern (subclass/inherit from the base scene, no changes to base classes required).
- GUT tests: schema validation (valid/invalid JSON fixtures), and a test confirming the new obstacle/vehicle type integrates without modifying ported Phase 2 code.

**Docs produced:** `docs/LEVEL_FORMAT.md` — the level JSON schema, documented field-by-field, intended for future level authors (including the person or any community contributors). `ARCHITECTURE.md` section on the extension pattern.

**Definition of Done:** a hand-authored custom level JSON, dropped into the levels directory, loads and plays without code changes; tests pass; `LEVEL_FORMAT.md` is complete enough that someone unfamiliar with the code could author a level from it alone.

---

## Phase 5 — Leaderboard integration

**Scope for this migration:** Android only. iOS is a confirmed future milestone — do not build a Game Center bridge now; just keep the `ILeaderboardService`-style interface (submit score, unlock achievement) platform-agnostic in `GameManager` so adding an iOS backend later doesn't touch calling code.

**Tasks:**
- Add [`godot-sdk-integrations/godot-play-game-services`](https://github.com/godot-sdk-integrations/godot-play-game-services) as an addon; confirm current version compatibility with the project's Godot version before integrating.
- Wire `ScoreModel`'s end-of-run score into the plugin's score-submission call from `GameManager`.
- Add achievement hooks for at least one milestone (e.g. distance or no-hit run) as a template for adding more later.
- Implement graceful degradation: any leaderboard/sign-in failure must never block gameplay — write a GUT test asserting the game-over flow completes normally when the leaderboard service is unavailable/mocked-as-failing.
- Note in `MIGRATION_NOTES.md` that iOS/Game Center integration is deferred to the iOS milestone, along with a reminder to re-check plugin maintenance status at that time rather than now (plugin landscape moves).

**Docs produced:** `docs/LEADERBOARD_SETUP.md` — credential setup, leaderboard/achievement IDs, and the sign-in flow, so this doesn't have to be re-researched later.

**Definition of Done:** score submission verified against a real (or sandboxed) leaderboard; degradation test passes; setup doc complete.

---

## Phase 6 — Documentation finalization & release readiness

**Tasks:**
- Finalize `README.md`: project overview, setup, build/export instructions for Android (and iOS if in scope), how to run tests.
- Finalize `ARCHITECTURE.md`: full system overview, referencing each phase's section.
- Finalize `MIGRATION_NOTES.md`: complete C++-to-Godot symbol mapping, useful as a reference if bugs are later suspected to trace back to a porting decision.
- Add a `CHANGELOG.md` if not already maintained incrementally.
- Full regression pass: all golden-run fixtures from Phase 1, all unit tests, all integration tests green in CI.

**Definition of Done:** a new contributor (or the person, returning after months away) can read `README.md` + `ARCHITECTURE.md` and understand the system without reading code first; CI green; no open regressions against `SPEC.md`.

---

## Best-practice notes for Claude Code throughout

- Follow the [official Godot GDScript style guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html) (naming, static typing where possible — use typed GDScript (`var x: int`) throughout for the same safety benefits static typing gave the original C++).
- Prefer signals over polling for cross-node communication (idiomatic Godot, avoids the singleton-sprawl issue flagged in the original C++ refactor plan).
- Keep pure logic (Phase 2's physics/collision) free of `_process`/node-tree calls so it stays unit-testable in isolation — this is the single most important architectural rule carried over from the earlier refactor plan.
- Do not delete or modify the original C++ repo — it's the reference implementation until Phase 6 is fully verified.
