# Turbo Race — Full Refactor & Modernization Plan

**Baseline:** `cpinan/Turbo-Race` (Cocos2d-x 4.0, C++, Android/iOS).
**Prior work already planned:** KMM shared engine port (`GameEngine`, `Player`/BaseVehicle, obstacle classes, `CollisionDetector`, `SegmentLibrary`, `LevelGenerator`, `CoinEngine`, `ShopCatalog`, Supabase sync), plus a campaign layer (levels, world map, difficulty, leaderboards).

**Scope of this version:** the refactor and capability extension stand on their own. Monetization (ads/IAP) is deliberately deferred — you've already integrated AdMob before, and worst case ads become a **separate, decoupled project/module** wired in later rather than a blocking phase of this rewrite. The architecture below reserves a clean seam (`AdProvider` interface, Phase 5) for that, but nothing in Phases 1–4 or 6–7 depends on it.

---

## 0. Principles carried forward

- No pay-to-win. Ads and IAP never affect run difficulty or obstacle fairness.
- Every ad must feel like **help offered**, not a gate. Reference point: rewarded video for a second chance, not forced interstitials blocking play.
- Keep the faithful physics/collision port untouched — `MAX_PLAYER_JUMP = 140f`, 0.6s discrete jump arc, `AirDoubleObstacle` 0.45×jump lethal threshold, `_worldSpeed += dt*2`. These are validated; the refactor must not regress them.

---

## Phase 1 — Audit & extraction (1–2 weeks)

- Inventory the C++ codebase: `Classes/models` (BaseVehicle, obstacles), `GameLayer`, `Constants.h`, scenes, asset pipeline (sprite atlases, audio), any ad/IAP code currently present (likely none).
- Extract every gameplay constant into a single source-of-truth table (speed curve, jump timing, spawn rates, obstacle hitbox rects) — this becomes the spec the KMM port is tested against.
- Tag anything Cocos2d-x-specific (scene graph, action system, `CCSprite` batching) that has no 1:1 modern equivalent, so the new renderer is designed intentionally rather than emulating Cocos2d-x idioms in Kotlin.

## Phase 2 — Target architecture

```
shared/ (KMM)
├── engine/        physics, collision, obstacles, level generation — pure Kotlin, no platform deps
├── economy/       coins, shop, sync queue
├── analytics/     event schema (run_start, run_end, purchase) — ad events added later without touching this

└── data/          GameState, PlayerProfile, RunResult, LevelProgress, MapState

androidApp/        Compose UI + SurfaceView/Canvas renderer, AdMob SDK actual impl, Play Billing
iosApp/            SwiftUI/Metal renderer, Google Mobile Ads SDK actual impl, StoreKit
```

- Engine stays **pure Kotlin, platform-agnostic, and fully unit-testable** — this is the actual "modernization": today's C++ mixes physics with Cocos2d-x scene/render calls, making it untestable without a running engine. Splitting engine from renderer is the single highest-value refactor.
- Rendering: Canvas/Compose on Android, Metal or Skia-backed surface on iOS — no shared UI framework needed since the visual style (isometric/pixel-art layered canvas) is simple enough that native renderers are cheaper than fighting Compose Multiplatform's mobile-graphics limitations.
- Structured concurrency: game loop as a `Flow`-driven tick (`GameEngine.tick(dt)`), coroutines for async asset loads and network sync — replaces Cocos2d-x's callback/action-based scheduling.
- DI: Koin (lightweight, KMM-friendly) for wiring `AdProvider`, `BillingProvider`, `NetworkClient`, `StorageDriver`.

## Phase 3 — Migration strategy

Rewrite, not transliterate. Order of porting (each step gets a golden-run regression test replaying recorded input against the extracted constants from Phase 1):

1. Physics/collision core → unit tests against extracted constants
2. Obstacle types + level segment library
3. Level generator (Endless) + campaign level format (fixed segment playlists)
4. Economy (coins, shop) + offline storage
5. Renderer (Android first, then iOS)
6. Campaign UI: world map, level select, star objectives
7. Leaderboards (per-level + Endless), Supabase sync

Ads/billing are intentionally **not** in this sequence — see Phase 5.

## Phase 4 — Modernization checklist

- CI: GitHub Actions running shared-module unit tests + Android instrumented smoke test on every PR.
- Static analysis: detekt/ktlint on `shared` and `androidApp`.
- Crash/perf: Firebase Crashlytics + Play Console vitals (frame time budget for the game loop, since jank in an endless runner directly kills retention).
- Feature flags (simple remote-config table) for ad frequency, Turbo Pass pricing, and level unlock gates — lets you tune monetization without a store release.

## Phase 5 — Ads/monetization seam (deferred)

Ads and IAP are **out of scope for this refactor** and treated as a bolt-on, added after the core game + campaign is proven fun. Two ways this can land, decided later:

- **Option A — in-tree module:** a `shared/ads` module with an `AdProvider` interface (`expect`/`actual` per platform), wired via the same Koin graph as everything else. Low integration cost since you already know AdMob's Kotlin/Swift SDKs from your prior integration.
- **Option B — separate project:** ads/billing built and iterated as its own repo or module, consumed by the game as a dependency (or even a thin wrapper app). Higher isolation, useful if you want to reuse the same ads/IAP scaffolding across Turbo Race, PetPass, or other indie apps rather than rebuilding it per project.

Either way, the game engine and UI have zero dependency on ad state — a run plays identically with or without the module present. When you're ready, this becomes its own short planning conversation rather than a phase gating the rewrite.

## Phase 6 — Rollout timeline (indicative)

| Weeks | Milestone |
|---|---|
| 1–2 | Audit + constant extraction |
| 3–6 | Engine + economy port, unit-tested |
| 7–9 | Android renderer + core loop playable |
| 10–12 | Campaign (map, levels, difficulty) |
| 13–14 | Leaderboards + sync |
| 15 | Closed beta (core loop + campaign feel, no monetization) |
| 16 | Play Store launch (Android), iOS shortly after |
| Later | Ads/IAP module (Phase 5), scoped and scheduled once the core game has retention data |
