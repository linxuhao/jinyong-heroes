#!/bin/bash
# Godot test gate for subagent/fix_tests pipelines.
# Compile check -> headless play-test -> GDScript unit suite.
#
# ⚠ DO NOT "fix" this back to calling a local `godot` binary.
# There is NO godot binary in the container that runs this script. Godot lives
# only in the `godot-builder` sidecar, reachable over HTTP at
# $GODOT_BUILDER_URL (default http://godot-builder:8080). An earlier version
# resolved GODOT_BIN through a four-step PATH ladder; every step failed, every
# round, and the unit gate reported "godot binary not found" — a repair no
# amount of shell can make, because the binary is not in this filesystem.
# The sidecar mounts this workspace at the SAME absolute path, so the
# project_dir sent below resolves identically on both sides.
set -euo pipefail

PROJ_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILDER="${GODOT_BUILDER_URL:-http://godot-builder:8080}"

python3 - "$PROJ_DIR" "$BUILDER" <<'PY'
import json, sys, urllib.request, urllib.error

proj, builder = sys.argv[1], sys.argv[2].rstrip("/")

SCRIPTS = [
    "res://tests/unit_test_runner.gd",
    "res://tests/test_save_manager.gd",
    "res://tests/test_game_manager_fsm.gd",
    "res://tests/test_cultivation.gd",
    "res://tests/test_encounter.gd",
]


def post(path, payload, timeout):
    req = urllib.request.Request(
        builder + path, data=json.dumps(payload).encode(),
        headers={"Content-Type": "application/json"}, method="POST")
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read())


def die(msg):
    print(msg, file=sys.stderr)
    sys.exit(1)


try:
    print("=== Godot compile check ===")
    rep = post("/compile", {"project_dir": proj}, 600)
    print(rep.get("summary", ""))
    if not rep.get("passed", False):
        for e in (rep.get("errors") or [])[:20]:
            print("  %s:%s %s" % (e.get("file"), e.get("line"), e.get("msg")),
                  file=sys.stderr)
        die("compile gate FAILED")

    print("\n=== Godot play-test ===")
    pt = post("/playtest", {"project_dir": proj}, 900)
    print(pt.get("summary", ""))
    if not pt.get("passed", False):
        for e in (pt.get("errors") or [])[:20]:
            print("  %s" % (e if isinstance(e, str) else json.dumps(e)),
                  file=sys.stderr)
        die("play-test gate FAILED")

    print("\n=== Godot unit suite ===")
    sc = post("/script", {"project_dir": proj, "scripts": SCRIPTS}, 900)
    for r in sc.get("results") or []:
        print("  %-42s %s" % (r["script"], "ok" if r["passed"] else "FAILED"))
        if not r["passed"]:
            sys.stderr.write((r.get("stdout") or "")[-2000:])
            sys.stderr.write((r.get("stderr") or "")[-2000:])
    print(sc.get("summary", ""))
    if not sc.get("passed", False):
        die("unit suite FAILED")

# An unreachable sidecar is an infra fault, not a code defect — but the code
# then ships UNVERIFIED, so this must fail loudly rather than exit 0 quietly.
except (urllib.error.URLError, OSError, TimeoutError) as e:
    die("godot-builder unreachable at %s: %s — gate NOT run." % (builder, e))

print("\nAll Godot checks passed.")
PY
