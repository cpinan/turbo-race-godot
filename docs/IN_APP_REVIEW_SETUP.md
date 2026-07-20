# In-App Review — setup & behaviour

Prompts the player to rate Turbo Race at a happy moment (after their 3rd game).
Feeds the Play Store ranking signals (rating count + freshness) that ASO depends
on. See `docs/MARKETING_PLAN.md` §2.

## What ships now

- **`ReviewService` autoload** (`autoload/review_service.gd`), registered in
  `project.godot`, wired into `main_controller._on_game_over()` right after the
  interstitial hook.
- **Trigger gate:** fires exactly once, ever, when
  `SaveManager.get_total_games_played() == 3`. Persisted via
  `SaveManager.was_review_prompted()` / `mark_review_prompted()`.
  - Game 3 is deliberately **not** a multiple of 5, so it never collides with the
    interstitial (`AdManager.INTERSTITIAL_EVERY_N_GAMES`). A unit test enforces this.
- **Native overlay wired in:** the **`godot-mobile-plugins/godot-inapp-review`**
  Android plugin (Play Core `com.google.android.play:review:2.0.2`, auto-declared
  by its export plugin — no manual gradle edits) is installed under
  `addons/InappReviewPlugin/` (+ shared helper `addons/GMPShared/`) and enabled in
  `project.godot`. `ReviewService` loads it by path on Android only and drives its
  async flow: `generate_review_info()` → `review_info_generated` signal →
  `launch_review_flow()`. Any failure signal falls back to the store deep-link.
- **Fallback that always works:** `ReviewService` deep-links to the Play listing
  via `market://details?id=<pkg>` (https fallback) when the native singleton isn't
  present, or if the native flow fails. Android-only; silent no-op on
  desktop/headless/CI.

Tested by `tests/unit/test_review_service.gd` — all calls are safe no-ops off Android.

### Why `load()`-by-path instead of the plugin's `InappReview` class name

The addon's own `InappReview.gd` (and its `GmpLogger` helper) use `class_name`,
which only resolves once Godot has built its **global script class cache** — that
happens on the first editor open or export, not on a bare
`godot --headless -s addons/gut/gut_cmdln.gd ...` run on a fresh checkout. Since
this project's test command is exactly that bare headless invocation,
`ReviewService` never references `InappReview` by class name and only calls
`load("res://addons/InappReviewPlugin/InappReview.gd")` **inside the
`OS.has_feature("android")` guard** — so non-Android test runs never touch the
addon's scripts at all. Real device exports build the cache normally during
export, so the class resolves fine there.

## Already done (nothing further needed here)

~~1. Add a Godot 4 in-app-review Android plugin under `android/plugins/`~~ — done;
this plugin installs under `res://addons/` instead (same pattern as the existing
`admob` and `GodotPlayGameServices` addons), and its export plugin auto-attaches
the AAR + Play Core dependency at build time since
`gradle_build/use_gradle_build=true` is already set in `export_presets.cfg`.

~~2–3. Match singleton/method names~~ — not applicable; this plugin's own
`InappReview.gd` wrapper already does the `Engine.has_singleton("InappReviewPlugin")`
detection and exposes `generate_review_info()`/`launch_review_flow()` directly,
which `ReviewService` now calls.

~~4. Auto-detect on Android~~ — done, via `ReviewService.is_native_available()`.

## On-device verification (required — cannot be verified in CI)

Play throttles the real In-App Review overlay heavily, so it often does **not**
appear on demand. To test:

- **Fallback path:** temporarily set `REVIEW_AT_GAME = 1`, play one game, confirm
  the Play listing opens. Revert to `3`.
- **Native path:** use Google's **Internal App Sharing** track — the overlay only
  renders for builds delivered by Play, and even then may be suppressed by quota.
  A successful call with no crash is the pass condition; the dialog appearing is
  not guaranteed by design.

## Notes / policy

- Never prompt on a loss screen mid-frustration — the gate fires on the game-over
  flow but is capped to a single lifetime prompt, so it is low-friction.
- Do not fake or incentivise reviews (Play policy). This flow only *asks*.
- If you later add a "Rate us" button in the menu, wire it to
  `ReviewService.request_review_now()`.
