#!/bin/bash
# Godot test gate for subagent/fix_tests pipelines.
# Runs compile check then a headless playtest to catch parse + runtime errors.
set -euo pipefail

HARNESS="/app/docker/godot/godot_harness.py"
PROJ_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== Godot compile check ==="
python3 "$HARNESS" --compile "$PROJ_DIR"
echo ""

echo "=== Godot playtest (5s) ==="
python3 "$HARNESS" --playtest "$PROJ_DIR"
echo ""

echo "All Godot checks passed."
