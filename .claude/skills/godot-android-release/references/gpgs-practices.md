# Google Play Games Services practices (Godot 4)

Learned integrating `GodotPlayGameServices` (Iakobs/godot-play-game-services)
in a Godot 4 project. Patterns are plugin-agnostic where noted.

## Use `Engine.get_singleton()` directly, not a GDScript wrapper autoload

If the plugin ships a GDScript autoload wrapper around the native plugin,
check whether its `initialize()` has a guard like `if not android_plugin:
return` — a second call to that wrapper's `initialize()` from your own code
can silently return `PLUGIN_NOT_FOUND` even though the native plugin is
fine. The native singleton is reachable directly and skips the wrapper's
state entirely:

```gdscript
const _PLUGIN_NAME: String = "GodotPlayGameServices"
_plugin = Engine.get_singleton(_PLUGIN_NAME)
_plugin.initialize()
```

## Guard against an infinite sign-in retry loop

`signIn()` on failure fires the auth-result signal **synchronously and
immediately** (not just on success). If your failure handler calls
`signIn()` again unconditionally, you get an infinite loop and a crash.

```gdscript
var _signing_in: bool = false

func _try_sign_in() -> void:
    if _plugin == null or _signing_in or _signed_in:
        return
    _signing_in = true
    _plugin.signIn()

func _on_authenticated(ok: bool) -> void:
    _signing_in = false   # always reset first, before branching on ok
    _signed_in = ok
```

## Don't silently drop taps before first sign-in — trigger sign-in instead

A naive guard (`if not _signed_in: return`) on a "show leaderboard/
achievements" button silently eats the user's tap with no feedback. Trigger
sign-in on that same tap instead, so the second tap (after sign-in
completes) actually opens the UI:

```gdscript
func show_achievements() -> void:
    if _plugin == null:
        return
    if not _signed_in:
        _try_sign_in()
        return
    _plugin.showAchievements()
```

## Sign-in flow — connect signals before calling `isAuthenticated()`

```gdscript
func _ready() -> void:
    _plugin.initialize()
    _plugin.userAuthenticated.connect(_on_authenticated)
    _plugin.isAuthenticated()   # checks current state; only call signIn() if this comes back false
```

If already signed in from a previous session, `isAuthenticated()` reports
that via the same signal — no separate `signIn()` call needed on that path.

## `game_ids.xml` — edit the placeholder in place, never create a second resource file

The plugin typically generates a placeholder like
`android/build/res/values/game_ids.xml` on install. Edit it:

```xml
<string name="game_services_project_id" translatable="false">YOUR_NUMERIC_APP_ID</string>
```

**Never** create a second `strings.xml` (e.g. under
`android/build/src/main/res/values/`) defining the same resource name —
Android's resource merger fails the Gradle build with a duplicate-resource
error that doesn't obviously point back to this cause.

## Debug and release builds have different signing certs — both must be registered

- Debug builds use Godot's shared debug keystore (NOT your release
  keystore) — same debug cert across all Godot projects on a machine unless
  configured otherwise.
- Release builds use your project's real release keystore.
- **Both** SHA-1 fingerprints must be added as separate OAuth 2.0 client
  credentials in Play Console → Play Games Services → Setup → Credentials,
  or sign-in fails on whichever build type isn't registered.

Get the debug cert's SHA-1:
```sh
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```

Symptom of a missing/mismatched cert: logcat shows `SignInAuthenticator:
Fetching game player id failed` or `ScopedIdsTransformer: Fetching game
player id failed` — not an obvious "wrong cert" message.

## The GPGS game configuration must be Published, not just Draft

Even for internal/closed testing, Play Console → Play Games Services →
Publishing must show the config as **Published**. A Draft config makes
`signIn()` fire `userAuthenticated(false)` immediately with no error at
all — this looks exactly like a code bug and wastes debugging time if you
don't know to check this first.

## `Error loading configuration for Game Services! Error: 7` during headless export

Every headless export (`--export-debug` / `--export-release`) prints this once
during the editor's plugin-init scan. It is **benign** — the plugin's editor
half tries to read the GPGS config through a resource path that isn't
resolvable in a headless editor context; Error 7 is Godot's
`ERR_FILE_CANT_OPEN`. It does not affect the exported artifact, and
`game_ids.xml` is still packaged correctly.

Do not "fix" it, and do not report it as a build failure. Confirm the export
actually succeeded the normal way: the script's `==> Done:` line plus the
`.aab`/`.apk` file size. If GPGS sign-in genuinely misbehaves on device, the
cause is one of the sections above (cert registration, Draft config), never
this message.
