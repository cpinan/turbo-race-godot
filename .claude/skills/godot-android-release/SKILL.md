---
name: godot-android-release
description: >
  Build and release a Godot 4 Android app: signed AAB export, native debug symbols
  zip for Play Console, debug APK build+install for device testing, version bumping,
  and hard-won gotchas for AdMob, Google Play Games Services, and Play Console
  submission. Use when asked to build an Android release, install a debug build on
  a device, package native symbols, or troubleshoot AdMob/GPGS/Play Console issues
  in a Godot project.
usage: /godot-android-release
source: https://github.com/cpinan/turbo-race-godot
---

<!--
  Reusable Claude Code skill — learned shipping Turbo Race (Godot 4.7) to the
  Play Store: 7 release cycles, AdMob banner+interstitial+UMP consent, Google
  Play Games Services leaderboards/achievements, in-app review.

  To use in another Godot Android project:
    1. Copy this whole folder to <your-project>/.claude/skills/godot-android-release/
    2. Open the project in Claude Code
    3. Invoke with /godot-android-release, or just ask to build/release the app —
       the scripts work as-is via env vars, no project-specific edits required.
-->

# Godot Android release

Everything needed to go from "code is ready" to "AAB + symbols uploaded to Play
Console," plus the non-obvious failure modes for the three services most Godot
Android games integrate: AdMob, Google Play Games Services, and Play Console
itself.

## Scripts (`scripts/`)

All scripts are self-contained bash, configured via env vars (documented in a
header comment in each file), with sane defaults so most calls only need one
or two vars set. None hardcode a project name, package id, or path.

| Script | Purpose |
|---|---|
| `bump_version.sh <code> <name>` | Bump `version/code`/`version/name` in **every** preset of `export_presets.cfg` in one shot — the #1 way to accidentally ship a stale version is bumping only the preset you're about to export. |
| `build_debug_install.sh` | Export a debug APK, install on the connected device, launch it. Requires `PACKAGE_NAME`. |
| `build_release_aab.sh` | Export a signed release `.aab`. Requires `OUTPUT_AAB`. |
| `verify_release.sh` | Grep the versionCode/versionName actually baked into the built manifest — confirm before upload, not after Play Console rejects it. |
| `package_native_symbols.sh` | Build the native debug symbols zip with the exact root structure Play Console requires (device ABIs only, no `lib/` wrapper). Requires `OUTPUT_ZIP`. |

Typical release sequence:

```sh
cd path/to/godot-project
export GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot   # if not on PATH

.claude/skills/godot-android-release/scripts/bump_version.sh 8 1.4.0

OUTPUT_AAB=builds/app_v8_release.aab \
  .claude/skills/godot-android-release/scripts/build_release_aab.sh

.claude/skills/godot-android-release/scripts/verify_release.sh

OUTPUT_ZIP=builds/app_v8_symbols.zip \
  .claude/skills/godot-android-release/scripts/package_native_symbols.sh
```

Then upload both build artifacts + release notes through the Play Console
web UI — no tool here does that part, it's manual by design (Google doesn't
offer a first-class unattended upload path worth scripting around for a
solo/small-team project).

Device testing a debug build:

```sh
PACKAGE_NAME=com.example.app \
  .claude/skills/godot-android-release/scripts/build_debug_install.sh
```

If that fails with `INSTALL_FAILED_UPDATE_INCOMPATIBLE`, a release-signed
build is already on the device — the script explains the tradeoff
(uninstalling wipes local app data) rather than doing it for you.

## Reference docs (`references/`)

Deeper, problem-specific notes — read the relevant one when you hit that
territory rather than upfront:

- **`play-console-practices.md`** — release workflow, release-name format,
  which Play Console warnings are safe to ignore for a Godot game and why,
  the native-symbols-zip rejection rules, target API deadline handling.
- **`admob-practices.md`** — the dynamic-`load()`-behind-a-platform-guard
  pattern (critical for headless CI), banner sizing gotcha, notch/safe-area
  behavior, interstitial flow, UMP consent error code 3, why plugin AARs
  must be force-committed.
- **`gpgs-practices.md`** — `Engine.get_singleton()` vs. wrapper autoloads,
  the sign-in infinite-loop trap, debug-vs-release cert registration,
  `game_ids.xml` editing rules, why a Draft (unpublished) game config makes
  sign-in fail silently.
- **`android-build-gotchas.md`** — `export_presets.cfg` security handling,
  Android build template version mismatches, why
  `AndroidManifest.xml` edits don't survive a template reinstall.
- **`godot-addon-headless-gotcha.md`** — why any `class_name`-based addon
  referenced from an autoload breaks headless CI test runs specifically
  (not the editor, not exports), and the load-by-path fix. Applies beyond
  AdMob/GPGS to any similar addon (e.g. in-app review plugins).

## Design notes for reuse

- Scripts assume a standard Godot Gradle Android export (`gradle_build/
  use_gradle_build=true`, default "standard" product flavor). If a project
  defines custom Gradle product flavors, override `FLAVOR`/`TASK_DIR` env
  vars rather than editing the scripts.
- Nothing here assumes a specific package name, keystore location, or
  plugin set — those are always env vars or read from the project's own
  `export_presets.cfg`.
- The AdMob/GPGS reference docs describe patterns learned from specific
  plugins (`poingstudios/godot-admob-plugin`, `Iakobs/
  godot-play-game-services`) but the underlying gotchas (headless parse
  errors, static-var pitfalls, sign-in loops, cert registration) generalize
  to most Android plugins built the same way — reflection/singleton-based
  native binding wrapped in GDScript.
