# Web (HTML5) build — export, host, embed

A browser build turns "install the APK" into "click and play". Use it as the
top-of-funnel demo on itch.io and embedded on the site; keep Play as the primary
CTA. See `docs/MARKETING_PLAN.md` §3.

## Preset

A **Web** export preset (`preset.2`) is in `export_presets.cfg`:
- `platform="Web"`, `variant/thread_support=false` → uses the **no-threads**
  template, so it runs on any static host **without** COOP/COEP cross-origin
  isolation headers (itch.io, GitHub Pages, etc. work out of the box).
- `export_path="builds/web/index.html"`.

## Build

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --export-release "Web" builds/web/index.html
```

Output (`builds/web/`): `index.html`, `index.js`, `index.wasm` (~39 MB),
`index.pck` (~10 MB), audio worklets, icons.

Test locally (must be http(s), not `file://`):
```sh
cd builds/web && python3 -m http.server 8080   # open http://localhost:8080
```

### Export templates version note
Matching **4.7.1.stable** web templates are installed (alongside an older
**4.7.stable** set, kept for other targets). Re-exported and smoke-tested
2026-07-19: `--export-release "Web"` completed clean, `index.html`, `index.wasm`,
`index.pck` all served 200 from a local `http.server`. Ready to publish.

## Platform safety on web (audited — no code changes needed)

Every Android/native path is guarded by `OS.has_feature("android")`, so on web:
- **AdManager** — early-returns; no AdMob classes loaded, banners/interstitials off.
- **LeaderboardService / AchievementChecker** — `_plugin` stays null; all GPGS
  calls are no-ops.
- **ReviewService** — early-returns (no prompt, no store deep-link).
- **Controls** — `tilt` requires Android; web falls back to the on-screen joystick
  (drag left half = move, tap right half = jump). Confirm this feels right with a
  keyboard/mouse pass; consider adding keyboard bindings later if desired.

## Host on itch.io (free)

1. Zip the **contents** of `builds/web/` (so `index.html` is at the zip root),
   not the folder itself.
2. New project → Kind of project: **HTML** → upload the zip → check
   **"This file will be played in the browser"**.
3. Viewport: set to a landscape size, e.g. **960×540** (16:9), enable
   **Fullscreen button** and **Mobile friendly**.
4. Leave **"SharedArrayBuffer support"** OFF — the no-threads build doesn't need it.
5. Add the Play Store link + screenshots (reuse `playstoreassets/marketing/`) in
   the itch page description; primary CTA = "Get the full game on Google Play".

## Embed on the GitHub Pages site

Either host `builds/web/` under the site repo and iframe it, or embed the itch
build:
```html
<iframe src="https://<user>.itch.io/turbo-race/embed" width="960" height="540"
        frameborder="0" allowfullscreen></iframe>
```
Put a gameplay GIF + "Play in browser" + Play badge above the fold.

## Scope note (per CLAUDE.md)
Web is a marketing demo channel only — it does not change game scope. Leaderboard,
achievements, ads, and tilt remain Android features; web is single-player, local
high-score, joystick. Flag any web-specific divergence in `MIGRATION_NOTES.md`.
