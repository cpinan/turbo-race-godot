#!/usr/bin/env python3
"""Generate the per-portal HTML shells in web/shells/ from Godot's own shell.

Why this exists: a portal build needs its SDK <script> in the page before the
engine starts, and Godot supplies that through a custom HTML shell. Hand-copying
Godot's shell means it silently rots the next time the engine is upgraded, so
the shells are generated from the installed export template instead and the only
hand-written files are the snippets in web/head/.

The generated files ARE committed — export_presets.cfg is gitignored, so if the
shells were generated at build time nothing about the portal builds would be
under version control.

    python3 tools/gen_web_shells.py                  # use default template path
    python3 tools/gen_web_shells.py --check          # verify shells are current

Re-run after every Godot version bump, then rebuild and re-test both variants.
"""

from __future__ import annotations

import argparse
import pathlib
import sys
import zipfile

GODOT_VERSION = "4.7.1.stable"
TEMPLATE_ZIP = (
    pathlib.Path.home()
    / "Library/Application Support/Godot/export_templates"
    / GODOT_VERSION
    / "web_nothreads_release.zip"
)
SHELL_IN_ZIP = "godot.html"

# The engine substitutes this with the preset's html/head_include. Injecting
# immediately before it keeps the portal SDK first in <head> while leaving the
# preset's own head_include working.
ANCHOR = "\t\t$GODOT_HEAD_INCLUDE"

REPO = pathlib.Path(__file__).resolve().parent.parent
HEAD_DIR = REPO / "web/head"
SHELL_DIR = REPO / "web/shells"

VARIANTS = ["crazygames", "gamedistribution"]

BANNER = """<!--
	GENERATED FILE — do not edit.
	Source: Godot {version} {shell} + web/head/{variant}.html
	Regenerate: python3 tools/gen_web_shells.py
-->
"""


def base_shell(zip_path: pathlib.Path) -> str:
    if not zip_path.exists():
        sys.exit(
            f"Export template not found: {zip_path}\n"
            f"Install the {GODOT_VERSION} web export templates, or pass --template."
        )
    with zipfile.ZipFile(zip_path) as z:
        return z.read(SHELL_IN_ZIP).decode("utf-8")


def render(base: str, variant: str) -> str:
    snippet = (HEAD_DIR / f"{variant}.html").read_text(encoding="utf-8").rstrip("\n")
    if ANCHOR not in base:
        sys.exit(
            f"Anchor {ANCHOR.strip()!r} missing from {SHELL_IN_ZIP}. Godot changed its "
            f"shell layout — update ANCHOR in this script and re-verify both variants."
        )
    indented = "\n".join(("\t\t" + ln) if ln.strip() else ln for ln in snippet.split("\n"))
    banner = BANNER.format(version=GODOT_VERSION, shell=SHELL_IN_ZIP, variant=variant)
    body = base.replace(ANCHOR, indented + "\n" + ANCHOR, 1)
    # Banner goes after the doctype so the file still starts with <!DOCTYPE html>.
    return body.replace("<!DOCTYPE html>\n", "<!DOCTYPE html>\n" + banner, 1)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--template", type=pathlib.Path, default=TEMPLATE_ZIP)
    ap.add_argument("--check", action="store_true", help="fail if shells are stale")
    args = ap.parse_args()

    base = base_shell(args.template)
    SHELL_DIR.mkdir(parents=True, exist_ok=True)

    stale = []
    for variant in VARIANTS:
        out = SHELL_DIR / f"{variant}.html"
        want = render(base, variant)
        if args.check:
            have = out.read_text(encoding="utf-8") if out.exists() else ""
            if have != want:
                stale.append(out.relative_to(REPO))
            continue
        out.write_text(want, encoding="utf-8")
        print(f"wrote {out.relative_to(REPO)} ({len(want)} bytes)")

    if args.check:
        if stale:
            print("stale shells: " + ", ".join(str(p) for p in stale))
            print("run: python3 tools/gen_web_shells.py")
            return 1
        print("shells up to date")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
