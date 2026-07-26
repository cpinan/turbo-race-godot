# `class_name` addons vs. headless CI test runs

Applies to any Godot addon that declares GDScript classes with
`class_name` and is referenced from an **autoload** that must also run in
headless/CI test mode (e.g. `godot --headless -s addons/gut/gut_cmdln.gd
...`).

## The gotcha

`class_name` identifiers only resolve once Godot has built its **global
script class cache**. That cache is normally built by opening the project
in the editor, or during an export. A bare headless CLI test run on a
fresh checkout has usually never triggered either of those, so the cache
doesn't exist yet — and referencing the addon's class by name fails to
parse.

This is not a hard, consistent failure: cache timing can vary run to run
(e.g. if some other process happened to open the project first), so it can
look "fixed" after a partial fix and then reappear later. Don't trust a
single green run as proof this is resolved — trust a fresh-checkout
headless run with no prior editor session.

Symptom: the entire autoload fails, not just the addon-specific code —
errors like `Nonexistent function ... in base Nil` on calls that have
nothing to do with the addon, because the parse failure breaks the whole
script.

## The fix

Never reference the addon's class by name directly. Load it by path at
**runtime**, gated behind a platform check so non-target platforms (and
headless CI) never touch the addon's scripts at all:

```gdscript
_reviewer = (load("res://addons/SomePlugin/SomeClass.gd") as GDScript).new()
```

Connect its signals with the string-based form too, not the typed
`.signal_name.connect(...)` form — the variable can't be statically typed
as the addon's class for the same reason it can't be referenced by name:

```gdscript
_reviewer.connect("some_signal", _on_some_signal)
```

## When to apply this preemptively

Any time a new `class_name`-based addon gets wired into an autoload in a
project with a headless-only CI test workflow, apply this pattern from the
start rather than waiting to rediscover the bug — it's the same root cause
every time, and it's easy to miss in local testing if the editor happened
to be open recently (which primes the class cache and masks the bug).
