# TurboRace — Godot Port Progress

Last updated: 2026-07-09  
Last commit: `40165c3`  
Branch: `main`

---

## Current state

The game is **fully playable and published on Google Play** (version 1.0.0, code 4).  
All gameplay systems, UI screens, and audio are ported and polished.  
116/116 unit tests passing.

---

## What is done

### Gameplay (Phase 2–3)
- [x] Y-up coordinate system via GameScene root flip (`scale=(1,-1)`, `position=(0,768)`)
- [x] Jump arc: `140 * sin(t * PI)` — matches Cocos2d-x `JumpBy` exactly
- [x] All 3 obstacle types: SingleObstacle, DoubleObstacle, AirDoubleObstacle
- [x] Obstacle pool recycling (one pool per type, no mid-game allocation)
- [x] Collision detection: pure functions in `scripts/physics/`, unit-tested
- [x] Vehicle collision rects tuned: 20% narrower centered + 10% front trim
- [x] Lane-band guard (SingleObstacle), jump-height guard (AirDoubleObstacle ≥ 63 units)
- [x] World speed advance, scoring (`obstacles_avoided × 100`), game-over trigger
- [x] Parallax scroll (5 layers), cloud drift, floor + background tiles
- [x] Virtual joystick (left-half drag) + jump (right-half tap), unified touch+mouse

### UI screens
- [x] HomeScreen: logo slide-in, Easy/Normal/Hard buttons with pulse animations, sound toggle, How to Play button (bottom-right)
- [x] TutorialOverlay: How to Play first-run overlay, dismissed by tap anywhere
- [x] HUD: score label (top-right, avoids nav bar), pause button, joystick thumb visual, song-now-playing label (slides in from bottom, matches C++ `_showAudioPlaying()` formula)
- [x] PauseScreen: Resume / Restart / Home
- [x] GameOverScreen: score + best-score right-aligned to the right of badge, new-record badge (bicho_0003), Restart / Home
- [x] Entrance: player placed immediately at play position, no slide-in animation

### Audio
- [x] 3 music tracks, rotation on each game start/restart
- [x] `play_music()` returns track name String → shown in HUD song label
- [x] SFX: jump, smash, button, swoosh, lightning
- [x] Mute state persisted via SaveManager

### Android
- [x] Adaptive icon: bee/wasp 192px + 432px fg/bg (from `mipmap-xxxhdpi`)
- [x] Edge-to-edge: `screen/edge_to_edge=true` in export_presets.cfg + `EdgeToEdge.enable()` in GodotApp.java
- [x] Display cutout: `android:windowLayoutInDisplayCutoutMode="shortEdges"` in AndroidManifest.xml
- [x] Signed release AAB built and uploaded: `builds/turborace_v4_release.aab`
- [x] Native symbols zip generated and uploaded: `builds/turborace_v4_symbols.zip`
- [x] Package: `com.carlos.pinan.turborace.godot`

### Debug tooling
- [x] `scripts/debug_collision_overlay.gd`: child Node2D z_index=1000, draws green/cyan/red collision rect outlines; toggle via `GameScene.debug_collision` export var (currently `false` in main.tscn)

### Docs + infra
- [x] README with version table, Android export workflow, C++ parity mapping, Play Store notes
- [x] `.claude/skills/cocos2dx-to-godot/SKILL.md`: 16 sections covering all migration decisions
- [x] 116 GUT unit tests, CI via `.github/workflows/tests.yml`
- [x] `export_presets.cfg` gitignored (contains keystore password)

---

## What is NOT done (remaining work)

### Phase 5 — Android leaderboard (only remaining phase)
- [ ] Google Play Games Services plugin wired up — currently stub only (`autoload/leaderboard_service.gd`)
- [ ] Sign-in flow
- [ ] Submit score on game-over
- [ ] Show leaderboard UI (chart button exists in assets, not wired)
- [ ] Show achievements UI (achievement button exists in assets, not wired)
- [ ] See `docs/LEADERBOARD_SETUP.md` for plugin install + Play Console config

### Minor known gaps
- [ ] Joystick thumb visual doesn't animate (BG shows, thumb is static at rest — the `_joy_thumb.position` updates but drag tracking needs verification on device)
- [ ] `CartonSixBMP.fnt` bitmap font not used — plain TTF Label used everywhere. C++ used BMFont for in-game score. Low priority.
- [ ] `android/build/src/main/AndroidManifest.xml` changes are NOT git-tracked. If android build template is reinstalled, must re-add `android:windowLayoutInDisplayCutoutMode="shortEdges"` manually.

---

## Key file locations

| Purpose | Path |
|---------|------|
| Root scene | `scenes/main/main.tscn` |
| Scene controller | `scenes/main/main_controller.gd` |
| Game loop | `scenes/main/game_scene.gd` |
| Vehicle physics (pure) | `scripts/physics/vehicle_physics.gd` |
| Obstacle physics (pure) | `scripts/physics/obstacle_physics.gd` |
| Leaderboard stub | `autoload/leaderboard_service.gd` |
| Leaderboard setup guide | `docs/LEADERBOARD_SETUP.md` |
| Debug overlay | `scripts/debug_collision_overlay.gd` |
| Level JSON files | `resources/levels/` |
| Android manifest (local only) | `android/build/src/main/AndroidManifest.xml` |

---

## Build commands

```sh
# Run tests
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gprefix=test_ -ginclude_subdirs -gexit

# Build + install debug APK
/Applications/Godot.app/Contents/MacOS/Godot --headless --export-debug "Android Debug" /tmp/turborace_debug.apk \
  && adb install -r /tmp/turborace_debug.apk \
  && adb shell am start -n com.carlos.pinan.turborace.godot/com.godot.game.GodotAppLauncher

# Build release AAB (Play Store)
/Applications/Godot.app/Contents/MacOS/Godot --headless --export-release "Android Release" builds/turborace_vN_release.aab

# Generate symbols zip (after release build)
cd android/build/build/intermediates/merged_native_libs/standardRelease/mergeStandardReleaseNativeLibs/out
zip -r /path/to/builds/turborace_vN_symbols.zip lib/

# Verify version code in AAB
grep versionCode android/build/build/intermediates/merged_manifests/standardRelease/processStandardReleaseManifest/AndroidManifest.xml
```

---

## Next session checklist

1. Check `docs/LEADERBOARD_SETUP.md` for plugin status
2. Wire `leaderboard_service.gd` to actual Google Play Games Services plugin calls
3. Connect chart/achievement buttons in HomeScreen and GameOverScreen to leaderboard
4. Test sign-in + score submission on device
5. Bump `version/code` in both presets in `export_presets.cfg` before releasing
6. Build new AAB + symbols → upload to Play Store

---

## Important gotchas

- `export_presets.cfg` has keystore password — **never commit**. Already gitignored.
- `android/build/src/main/AndroidManifest.xml` is **not tracked** by git. Cutout mode edit is local-only.
- When Play Store says "version code X already used" → wrong file being uploaded. Check file size and verify with Gradle intermediates (see build commands above).
- `_draw()` in a Y-flipped Node2D renders **behind** all children. Use a child Node2D with z_index=1000 for any debug drawing.
- `Label.size` is zero until after `add_child()`. Use `await get_tree().process_frame` + `get_minimum_size()` to measure text width dynamically.
- Play Console warnings "No deobfuscation file" and "Remove orientation restrictions" are **safe to ignore** for this Godot game.
