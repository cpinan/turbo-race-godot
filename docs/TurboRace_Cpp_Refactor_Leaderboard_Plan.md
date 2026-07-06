# Turbo Race — In-Place C++/Cocos2d-x Refactor & Leaderboard Plan

**Correction from earlier drafts:** this is **not** a KMM/Kotlin rewrite. The actual codebase, `cpinan/Turbo-Race`, is Cocos2d-x 4.0 + C++17, and this plan works on it in place.

**Baseline (from the current repo):**

```
Turbo-Race/
├── Classes/
│   ├── common/   LevelLoader, ObstaclePool<T>, ScoreModel, …
│   ├── models/   BaseVehicle, BaseObstacle, obstacles, vehicles
│   └── ui/       HomeScene, GameLayer, PauseLayer, …
├── Resources/
│   ├── levels/   JSON configs (easy / normal / hard / story)
│   ├── assets/, audio/, fonts/
├── proj.android/     Android Gradle project
├── proj.ios_mac/, ios-build/   iOS (CMake + Xcode)
└── CMakeLists.txt
```

Already in decent shape: scoped enums, typed accessors, a `LaneLayout` struct, no raw macros, JSON-driven level config (`speedMultiplier`, `distanceMultiplier`, `speedAcceleration`, `maxWorldSpeed`, obstacle `map` array), and `ObstaclePool<T>` for object reuse. This is a real asset — the refactor should preserve and extend these patterns, not replace them.

Ads/monetization stay **deferred and decoupled**, as agreed — noted briefly in Phase 6, not built here.

---

## Phase 1 — Audit & baseline (few days)

- Diff current `Classes/models` against engine-call leakage: confirm whether `BaseVehicle`/`BaseObstacle` movement and collision math are pure C++ or interleaved with `cocos2d::Node`/scene calls. This determines how testable the core loop already is.
- Check `ObstaclePool<T>` for `cocos2d::Ref` retain/release balance — pooling ref-counted engine objects is a classic leak/dangling-pointer source if release timing is off.
- Confirm current Cocos2d-x 4.0 patch version against latest 4.x, and current Android target/min SDK + NDK version against today's Play Console requirements (Google raises the minimum target SDK yearly — this alone can block a release if stale).
- Inventory JSON level schema versions in `Resources/levels/` — is there any schema validation today, or does a malformed file just crash at runtime?

## Phase 2 — Build & tooling modernization

- `CMakeLists.txt` → modern target-based CMake (≥3.16 already required per repo; move to `target_include_directories`/`target_link_libraries` if not already, avoid global includes).
- `proj.android`: bump Android Gradle Plugin, target SDK, and NDK to current versions; this is likely the single most time-sensitive item since Play Store enforces target SDK floors.
- iOS: confirm `ios-build`/Xcode project generation still works against current Xcode/iOS SDK (the repo's own `BUILD.md` implies this needs redoing per machine — worth scripting fully).
- Add CI (GitHub Actions): one job builds the Android APK, one job runs the iOS Simulator build from `BUILD.md`'s `xcodebuild` command — catches breakage automatically instead of at release time.
- Add `.clang-format` codifying the style already visible in the codebase (scoped enums, no macros) so new code doesn't drift from it.

## Phase 3 — Architecture refactor (in place)

- Where `BaseVehicle`/`BaseObstacle` mix physics/collision math with `cocos2d` calls, extract the math into plain C++ methods (position, velocity, jump arc, collision rects) that take/return simple structs — no `cocos2d::Node` dependency. A thin adapter in the `ui`/`models` boundary applies the result to the actual sprite. This is what makes the physics testable with Catch2/GoogleTest without booting the engine.
- Add unit tests for `ScoreModel`, `LevelLoader` (JSON parsing + validation), `ObstaclePool<T>`, and the newly-extracted physics/collision math — these are the four places a regression is both likely and expensive to catch manually.
- Replace ad-hoc singletons (audio, level state) with a small service-locator or explicit dependency passing into `GameLayer`, mainly so the leaderboard service (Phase 5) has one clean seam to plug into rather than another global.
- `Resources/levels/*.json`: add schema validation at load (reject/report malformed files at startup, not mid-run) and a version field so future schema additions don't silently break old level files.

## Phase 4 — Extended capabilities

- New obstacle/vehicle types: subclass `BaseObstacle`/`BaseVehicle` following the existing pattern — the hierarchy already supports this without new abstractions.
- New difficulty tiers or per-level modifiers (obstacle density curve, visual theme) as additional JSON fields — no code changes needed if the loader is schema-validated per Phase 3.
- Consider a small in-app or standalone level-authoring tool (even a simple JSON editor/validator script) once level count grows past what's comfortable to hand-edit — story mode content authoring becomes the bottleneck, not code.

## Phase 5 — Leaderboard integration

You've already solved this once — reuse it instead of rebuilding:

1. **Android:** update your existing [`cpinan/Cocos2dX-GooglePlayGamesServices`](https://github.com/cpinan/Cocos2dX-GooglePlayGamesServices) wrapper against Cocos2d-x 4.0 and the current Google Play Games Services SDK (check for a GPGS v1→v2 migration if not already done — Google deprecated the older Games Sign-In APIs).
2. Define a tiny platform-agnostic interface, e.g. `ILeaderboardService { submitScore(id, score); unlockAchievement(id); }`, implemented by:
   - Android: your GPGS wrapper (JNI bridge, as it already does)
   - iOS: a small `GameKitBridge.mm` (Objective-C++) wrapping Game Center — same interface, new backend
3. Wire `ScoreModel`'s end-of-run score into `submitScore(...)` from `GameLayer`'s run-end flow; add achievement hooks for milestones (distance, story completion, no-hit run).
4. Sign-in: silent sign-in attempt on launch, explicit "Leaderboard" entry point in `HomeScene`/`PauseLayer`, and the game must be fully playable signed-out — leaderboard failure should never block a run.

Because `GameLayer` only talks to `ILeaderboardService`, this is also exactly the seam future ads work would plug into similarly (platform-native bridge behind a small interface) — no need to design that twice.

## Phase 6 — Ads/monetization (deferred, unchanged from prior decision)

Out of scope here. When you're ready: same bridge pattern as leaderboards — a small interface (`IAdProvider`) with Android (Kotlin/Java AdMob SDK via JNI) and iOS (Obj-C++ bridge) backends. Worth noting: AdMob no longer ships a maintained native C++ SDK, so both platforms go through a JNI/Obj-C++ bridge either way — budget for that regardless of which network you pick.

## Phase 7 — Rollout timeline (indicative)

| Weeks | Milestone |
|---|---|
| 1 | Audit + build/CI baseline fixed (Phase 1–2) |
| 2–3 | Physics/collision extraction + unit tests (Phase 3) |
| 4 | JSON schema validation + service-locator cleanup |
| 5 | New obstacle/vehicle content (Phase 4) |
| 6–7 | Leaderboard integration, Android first then iOS (Phase 5) |
| 8 | QA pass, store release |
