# Godot Android build gotchas

General Gradle-build Android export issues, independent of any specific
plugin.

## `export_presets.cfg` is sensitive — never commit it

It contains the release keystore path and password in plaintext. Keep it
gitignored. Before any commit that touches Android config, check `git
status` to confirm it isn't staged. If a project needs a checked-in
template for teammates, commit a `.example` copy with placeholder values
instead of the real file.

## Android build template version mismatch

Error: `Android build version mismatch: Template installed: X | Requested
version: Y`

Cause: the Godot **engine** version and the installed **Android build
template** (`android/.build_version` in the project, and the templates
under `~/Library/Application Support/Godot/export_templates/<version>/` on
macOS) have diverged — e.g. only web export templates got updated to a new
point release while Android templates are still on the old one.

Fix: the matching version's `android_debug.apk`, `android_release.apk`,
and `android_source.zip` must be present in that version's export-templates
folder. If a partial (e.g. web-only) template install happened, download
the official `Godot_v<version>-stable_export_templates.tpz` from the
engine's GitHub release, extract the `templates/android_*` files, and drop
them into the folder for that exact version, then retry the export.

**Reinstalling the Android build template wipes local, non-git-tracked
edits** — see the `AndroidManifest.xml` note below. Back those up first.

## `android/build/src/main/AndroidManifest.xml` is not git-tracked

Godot generates/owns this file as part of the Android build system, so it's
excluded from version control by default. Any manual edits made directly
to it (e.g. `android:windowLayoutInDisplayCutoutMode="shortEdges"` for
notch handling) are **local-only** and get silently wiped whenever the
Android build template is reinstalled (see above).

If a manifest edit needs to survive a template reinstall, either:
- Document the exact edit somewhere durable (this file, a project doc) so
  it can be reapplied by hand, or
- Move the customization into a file that Godot *does* track/regenerate
  consistently, e.g. a Gradle task hook in `android/build/build.gradle`
  (which — unlike the manifest — is a real project file you can commit) if
  the customization can be expressed as a build step instead of a static
  manifest edit.
