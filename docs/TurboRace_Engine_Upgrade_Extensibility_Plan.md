# Turbo Race — Engine Upgrade, Modernization & Extensibility Plan

**Scope:** in-place work on `cpinan/Turbo-Race` (Cocos2d-x 4.0, C++17). Update the engine, modernize legacy code, make the game extensible (new features, custom levels), and integrate leaderboards using your existing GPGS wrapper. Ads/monetization stay deferred, per earlier decision.

---

## Phase 0 — Engine upgrade: the actual options

**Key fact:** Cocos2d-x has no newer official release than v4.0 (2020). The upstream repo now states it no longer recommends new projects start with Cocos2d-x at all — active development moved to Cocos Creator (a different, editor-centric engine, not a drop-in for a C++ codebase like this one). So "update to the latest Cocos2d-x" has three real answers, not one:

| Option | What it means | Cost | When it makes sense |
|---|---|---|---|
| **A. Stay on Cocos2d-x 4.0, sync latest patches** | Pull any 4.0 branch fixes, keep current engine | Low | If you just need current NDK/Xcode SDK compatibility, not new engine features |
| **B. Migrate to Axmol Engine** | Actively-maintained community fork of Cocos2d-x 4.0, same core API, adds current toolchain (C++20, Metal/Vulkan, current Android/iOS SDK support), ongoing fixes | Medium — mostly a namespace/build-system swap, not a rewrite, since the API surface is intentionally compatible | Recommended if you want a maintained engine going forward without changing your code's shape |
| **C. Port to Cocos Creator** | Different engine/editor entirely, JS/TS-first with C++ native layer | High — real rewrite | Only worth it if you want the Creator editor workflow; not implied by "update the engine" |

**Recommendation: Option B.** It gets you an actively maintained engine, current Android/iOS toolchain compatibility, and keeps your `Classes/models`, `Classes/common`, `Classes/ui` structure and JSON level format intact. This plan assumes B from here on; flag if you'd rather stay on A (cheaper, but you inherit an unmaintained engine going forward).

---

## Phase 1 — Audit & baseline (few days)

- Confirm exact build toolchain versions currently in use (NDK, Android Gradle Plugin, Xcode SDK) against what the engine migration target requires.
- Check `Classes/models` (`BaseVehicle`, `BaseObstacle`) for engine-call leakage — do physics/collision live in plain C++ or interleaved with `cocos2d::Node`/scene calls? This determines how much Phase 3 costs.
- Audit `ObstaclePool<T>` for `cocos2d::Ref` retain/release balance (ref-counted pooling is a classic leak source if release timing is off).
- Inventory `Resources/levels/*.json` — any schema validation today, or does malformed JSON just crash at runtime?

## Phase 2 — Engine migration (Axmol)

- Swap engine dependency from `cocos2d-x` to `axmol` per its migration guide (largely a `#include`/namespace and build-script change given API compatibility).
- Update `CMakeLists.txt` to target-based modern CMake if not already, matching Axmol's recommended setup.
- `proj.android`: bump Android Gradle Plugin, target/min SDK, and NDK to what Axmol currently supports — this also resolves any current Play Console target-SDK-floor risk.
- iOS: rebuild via Axmol's current Xcode project generation; confirm Metal rendering path (already required since 4.0) still works unchanged.
- Add CI (GitHub Actions): Android APK build + iOS Simulator build on every push, so future engine/toolchain drift is caught automatically instead of at release time.

## Phase 3 — Legacy code modernization

- Where physics/collision math is mixed with engine calls, extract it into plain C++ (position, velocity, jump arc, collision rects as simple structs/functions) with a thin adapter applying results to sprites. This is what makes the core loop testable and — more relevant to your "extend it" goal — reusable when you add new vehicle/obstacle types without touching rendering code.
- Add unit tests (Catch2 or GoogleTest) for `ScoreModel`, `LevelLoader`, `ObstaclePool<T>`, and the extracted physics — the four places a regression is both likely and expensive to catch by hand.
- Add `.clang-format` matching the codebase's existing good patterns (scoped enums, no macros) so extension work doesn't drift from it.
- Replace ad-hoc singletons (audio, level state) with explicit dependency passing into `GameLayer` — this is also what gives the leaderboard service (Phase 5) one clean seam instead of another global.

## Phase 4 — Extensibility & custom levels

This is the core of "be able to extend it":

- **Content-driven extension points:** anything that's currently a JSON field (speed curve, obstacle density, world theme) should stay data-driven; anything hardcoded in `GameLayer` that plausibly varies per level (spawn timing, background theme, music track) gets promoted to the JSON schema.
- **Schema versioning:** add a `schemaVersion` field to level JSON now, before you have many custom levels, so future format changes don't break existing content.
- **Validation on load:** reject/report malformed level files at startup with a clear error, not a runtime crash mid-run.
- **New obstacle/vehicle types:** subclass `BaseObstacle`/`BaseVehicle` following the existing hierarchy — no new abstraction needed, the pattern already supports it once Phase 3's extraction is done.
- **Level authoring:** once you're producing custom levels beyond a handful, a small standalone JSON validator/editor script (doesn't need to be in-app) removes the main friction point — hand-editing raw JSON doesn't scale much past a dozen levels.
- **Feature flags for extended features:** a simple config table (local JSON or remote-config-style) for turning new mechanics on/off per level or per build, so experimental features don't have to ship globally the moment they compile.

## Phase 5 — Leaderboard integration

Reuse what you've already built rather than re-solving it:

1. **Android:** update [`cpinan/Cocos2dX-GooglePlayGamesServices`](https://github.com/cpinan/Cocos2dX-GooglePlayGamesServices) against the current GPGS SDK (check for a v1→v2 Games Sign-In API migration if not already done).
2. Define a small platform-agnostic interface — `ILeaderboardService { submitScore(id, score); unlockAchievement(id); }` — implemented by:
   - Android: your GPGS wrapper (JNI bridge, as today)
   - iOS: a small `GameKitBridge.mm` (Objective-C++) wrapping Game Center
3. Wire `ScoreModel`'s end-of-run score into `submitScore(...)` from `GameLayer`'s run-end flow; add achievement hooks for milestones (distance, story completion, no-hit run).
4. Silent sign-in on launch, explicit "Leaderboard" entry in `HomeScene`/`PauseLayer`; the game must stay fully playable signed-out.

This same interface-behind-a-bridge pattern is what future ads work would reuse — no need to design that seam twice.

## Phase 6 — Ads/monetization (deferred, unchanged)

Out of scope here, as agreed. Same bridge pattern as leaderboards when it's time.

## Phase 7 — Rollout timeline (indicative)

| Weeks | Milestone |
|---|---|
| 1 | Audit (Phase 1) |
| 2–3 | Axmol migration + CI (Phase 2) |
| 4–5 | Physics extraction + unit tests (Phase 3) |
| 6–7 | Extensibility framework + schema versioning + custom level validation (Phase 4) |
| 8–9 | Leaderboard integration, Android then iOS (Phase 5) |
| 10 | QA pass, release |

---

**Open question:** do you want Phase 4's extensibility work to also cover a *content pipeline* (e.g. exporting levels from Tiled or a spreadsheet into your JSON format), or is hand-authored JSON still fine for the volume of custom levels you're planning?
