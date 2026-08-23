# tests/test_godot_suite.py
#
# Pytest-discoverable shim for the 5_test gate. The repo's real unit-test
# evidence lives in Godot: 14 test_*.gd files under tests/, executed by
# run_tests.sh (compile check + playtest + four headless godot invocations).
# A plain Python pytest run collects zero GDScript tests by itself, so this
# module shells out to run_tests.sh and asserts its exit code. The gate thus
# reports real pass/fail evidence (no_tests_collected:false) and turns red on
# ANY genuine failure: missing godot binary (bash 127), compile error,
# playtest failure, or a failing test_*.gd aborting the script via
# `set -euo pipefail`.
#
# There is deliberately no skip/xfail/mock/exception-swallowing anywhere in
# this module: a non-zero returncode must fail the test, never pass vacuously.
import os
import subprocess

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # module-level constant


def test_godot_suite() -> None:
    result = subprocess.run(
        ["bash", os.path.join(ROOT, "run_tests.sh")],
        cwd=ROOT,
        capture_output=True,
        text=True,
        encoding="utf-8",      # godot/script output may contain CJK; explicit UTF-8
        errors="replace",      # survive a non-UTF-8 gate locale without crashing
        timeout=600,           # guard rail: a wedged playtest fails the test instead of hanging forever
    )
    assert result.returncode == 0, (
        "Godot suite failed (returncode %d)\n--- stdout ---\n%s\n--- stderr ---\n%s"
        % (result.returncode, result.stdout, result.stderr)
    )
