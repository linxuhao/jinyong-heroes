#!/bin/bash
# Godot test gate for subagent/fix_tests pipelines.
# Runs compile check then a headless playtest to catch parse + runtime errors.
set -euo pipefail

HARNESS="/app/docker/godot/godot_harness.py"
PROJ_DIR="$(cd "$(dirname "$0")" && pwd)"

# Resolve the godot binary ONCE, before any gate runs. The harness calls bare
# `godot` internally and the unit-test step needs a real binary; a bare `godot`
# is not on PATH in the test environment, so defaulting to it crashed with a
# FileNotFoundError traceback instead of a test result. Resolution order:
# GODOT_BIN env override -> absolute-path probe -> `command -v godot`.
# Every probe is written inside an `if` condition so a failed lookup skips to
# the next option instead of aborting the script under `set -e`.
if [ -z "${GODOT_BIN:-}" ]; then
	for p in /app/docker/godot/godot /usr/local/bin/godot /usr/bin/godot /opt/godot/godot; do
		if [ -x "$p" ]; then
			GODOT_BIN="$p"
			break
		fi
	done
fi
if [ -z "${GODOT_BIN:-}" ]; then
	if command -v godot >/dev/null 2>&1; then
		GODOT_BIN="$(command -v godot)"
	fi
fi
if [ -z "${GODOT_BIN:-}" ]; then
	echo "godot binary not found; set GODOT_BIN=/path/to/godot" >&2
	exit 1
fi
export GODOT_BIN
# Prepend the binary's directory to PATH so the harness's internal bare
# `godot` call also resolves (must happen before the first harness call).
export PATH="$(dirname "$GODOT_BIN"):$PATH"

echo "=== Godot compile check ==="
python3 "$HARNESS" --compile "$PROJ_DIR"
echo ""

echo "=== Godot playtest (5s) ==="
python3 "$HARNESS" --playtest "$PROJ_DIR"
echo ""

echo "=== Godot unit tests ==="
"$GODOT_BIN" --headless --path "$PROJ_DIR" -s res://tests/unit_test_runner.gd
"$GODOT_BIN" --headless --path "$PROJ_DIR" -s res://tests/test_save_manager.gd
"$GODOT_BIN" --headless --path "$PROJ_DIR" -s res://tests/test_game_manager_fsm.gd
"$GODOT_BIN" --headless --path "$PROJ_DIR" -s res://tests/test_cultivation.gd
"$GODOT_BIN" --headless --path "$PROJ_DIR" -s res://tests/test_encounter.gd
echo ""

echo "All Godot checks passed."
