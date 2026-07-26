# AdMob practices (Godot 4)

Learned integrating `poingstudios/godot-admob-plugin` in a Godot 4 project.
Patterns are plugin-agnostic where noted.

## Dynamic `load()` pattern — never reference plugin classes directly (critical)

GDScript 4 parses **every** autoload at startup, including in headless/CI
test runs. If an autoload references an AdMob plugin class by name at
parse time, and the plugin's Android-only classes aren't available in that
run (headless CI has no Android runtime), the whole autoload fails to
parse — breaking every test, not just ad-related ones.

Always defer the reference to runtime, gated behind a platform check:

```gdscript
var _AdView = null

func _ready() -> void:
    if not OS.has_feature("android"):
        return
    _AdView = load("res://addons/admob/gdscript/src/api/AdView.gd")
```

Same pattern applies to any Godot plugin with Android/iOS-only native
bindings touched from an autoload — see `gpgs-practices.md` for the GPGS
equivalent and `godot-addon-headless-gotcha.md` for the related
`class_name` parse trap.

## Banner size — use explicit dimensions, not a plugin's static size constant

Some plugins expose `AdSize.LEADERBOARD` etc. as a pre-built **instance**
(a `static var`), not an enum/int you can pass to a constructor. Passing it
into `AdSize.new(...)` is a runtime error, not a compile error — it'll
pass headless tests and fail on device.

```gdscript
# Correct — explicit width/height:
var ad_size = _AdSize.new(728, 90)

# Wrong — passing a pre-built instance into a constructor:
var ad_size = _AdSize.new(_AdSize.LEADERBOARD)
```

## Camera notch / safe area

An adaptive full-width banner starts drawing at the safe-area inset (e.g.
`x=161` on a device with a 161px landscape notch inset), leaving a visible
gap on the other side. A **fixed-size** banner (e.g. 728×90dp Leaderboard)
gets centered by the SDK regardless of the notch, which reads as
intentional instead of misaligned. If a banner looks off-center only on
notched devices, this is almost always why — check fixed vs. adaptive
sizing before touching layout code.

## Interstitial ad flow

```
InterstitialAdLoader.load(unit_id, AdRequest, callback)
  → callback.on_ad_loaded(InterstitialAd)
    → set full_screen_content_callback.on_ad_dismissed_full_screen_content
    → call .show() when ready
      → on_ad_dismissed → reload immediately (so the next trigger has an ad ready)
```

## Show/hide timing

- Banner: drive visibility off your game's state-changed signal, not a
  poll loop — hide during active gameplay, show on menu/pause/game-over.
- Interstitial: gate on a modulo of a persisted counter (e.g. every Nth
  game), and check it **after** the counter increments for that game, not
  before.
- Both: fire-and-forget from the game loop's perspective — never `await`
  an ad call, never let an ad failure block gameplay progression.

## UMP/GDPR consent error code 3

"Publisher misconfiguration" — the AdMob account has no GDPR message
configured in AdMob console → Privacy & messaging. The SDK typically falls
through to loading ads anyway rather than hard-failing, but the message
won't show to EEA users until this is configured server-side; it's not a
client bug.

## Plugin AARs must be committed, not gitignored

Plugins often ship a `.gitignore` that excludes their own `bin/`
(build-artifact convention from the plugin author's dev workflow) — but for
a Godot Android export, those AARs *are* required source, not build output.
Patch the plugin's `.gitignore` and force-add: `git add -f
addons/<plugin>/android/bin/`. Without this, CI and fresh clones can't
produce a working Android build.
