# Play Console release practices

Learned shipping Turbo Race (Godot 4.7, Android). Applies to any Gradle-build
Godot Android project.

## Release workflow

1. `bump_version.sh <code> <name>` — bumps `version/code`/`version/name` in
   every preset of `export_presets.cfg`.
2. `build_release_aab.sh` — exports the signed `.aab`.
3. `verify_release.sh` — confirms the versionCode/versionName actually baked
   into the built manifest match what you intended. Do this **before**
   uploading — "Play Console says version code X already used" almost always
   means the wrong/stale file got selected in the upload dialog, and this
   catches it locally first.
4. `package_native_symbols.sh` — builds the native debug symbols zip from the
   same build's Gradle intermediates (must run after step 2, not before).
5. Upload both the `.aab` and the symbols zip together in the Play Console
   release editor, under the same release.

## Release name format

`{version_name} ({version_code})` — e.g. `1.3.0 (7)`.

## Release notes ("What's new")

Play Console's release-notes editor accepts **all languages in one paste**,
using an XML-ish tag per locale. The tags must match the locales the listing
is actually published in, in the order the console lists them — it pre-fills
the field with empty tags, so copy that skeleton rather than guessing locale
codes (`es-419`, not `es`; bare `id` for Indonesian, no region suffix):

```
<en-US>
...notes...
</en-US>
<es-419>
...notes...
</es-419>
```

- **500 characters per language, hard limit.** Counted per locale block, not
  total. Verify locally before pasting — the console truncates/errors at
  submit time, after you've already filled in the rest of the release.
- Write the notes to a file in `builds/` next to the `.aab` (e.g.
  `app_v8_release_notes.txt`) and verify every block in one shot:

  ```sh
  python3 - <<'EOF'
  import re
  t = open('builds/app_v8_release_notes.txt', encoding='utf-8').read()
  for lang in ['en-US','es-419','hi-IN','id','pt-BR','ru-RU']:
      m = re.search(r'<%s>\n(.*?)\n</%s>' % (lang, lang), t, re.S)
      n = len(m.group(1))
      print(f"{lang:8s} {n:4d} {'OK' if n <= 500 else 'OVER LIMIT'}")
  EOF
  ```

- Keep notes user-facing, not changelog-facing: describe what the player will
  notice ("obstacles could spawn invisible and pass through you"), not the
  internal cause ("pool growth path returned an un-parented node"). The
  `CHANGELOG.md` entry is the engineering record; these are marketing copy
  derived from it.
- Machine-translated notes ship fine for a small game, but say so to the
  project owner — non-Latin-script locales (hi-IN, ru-RU) are the ones where
  an awkward phrasing is least likely to be caught by anyone on the team.

## Safe-to-ignore Play Console warnings (for a Godot game specifically)

- **"No deobfuscation file" / R8 minification recommendation.** Godot's Java
  layer is boilerplate only — real logic is in GDScript/native `.so` code,
  which the symbols zip already covers. Enabling R8 blind is actually
  risky, not just unnecessary: Godot's C++→Java JNI calls and any
  plugin's reflection-based singleton lookups (`Engine.get_singleton()`,
  dynamic `load()` — see `admob-practices.md`, `gpgs-practices.md`) are
  invisible to R8's reachability analysis unless every plugin AAR ships
  correct consumer ProGuard rules. Check each AAR's `proguard.txt` before
  ever turning this on for a monetized/live app.
- **"Remove orientation restrictions" (large-screen/resizability warning).**
  If the game is intentionally landscape-locked (most endless runners are),
  this is informational. Do NOT flip `android:resizeableActivity` to `true`
  without also auditing `project.godot`'s `window/stretch/aspect` mode and
  every UI anchor — on `aspect="ignore"` projects this visually distorts
  the game on resize rather than just letterboxing it. Recent Android
  versions (16+) ignore the manifest flag either way regardless of value,
  so the warning doesn't block publishing.
- **Deprecated edge-to-edge API warning**, when your own `GodotApp.java`
  already calls the modern `EdgeToEdge.enable()`: check whether a bundled
  SDK is the actual source before "fixing" your own code. Google's UMP
  consent SDK (bundled inside `play-services-ads`) has shipped this bug
  itself in some versions — bumping `play-services-ads` to latest is worth
  trying, but may not fully clear until Google patches it. Don't chase your
  own manifest/layout code for a warning that traces to a third-party AAR.

## Target API deadline

Google enforces a rolling "must target within 1 year of latest Android
release" policy — apps that fall behind lose the ability to publish updates
past the deadline. Godot's own gradle template
(`android/build/config.gradle`) usually already defaults `compileSdk`/
`targetSdk` to a current value; check whether `export_presets.cfg`'s
`gradle_build/target_sdk` is pinning it to something older than the
template default before assuming you need an engine upgrade.

## Native debug symbols zip — the two silent-rejection rules

See `package_native_symbols.sh` for the automated version. The rules, if
doing it by hand:

- Zip root must be `armeabi-v7a/` and `arm64-v8a/` directly, not wrapped in
  a `lib/` parent folder (`cd` into `lib/` before zipping, don't zip `lib/`
  itself).
- Only device ABIs — never include `x86`/`x86_64` (emulator-only).
- `zip` **appends** to an existing archive rather than overwriting it —
  always delete the destination file first, or a re-run silently produces a
  corrupt zip with duplicate entries.

Verify before upload: `unzip -l symbols.zip | head` should show
`armeabi-v7a/...` at root, not `lib/armeabi-v7a/...`.
