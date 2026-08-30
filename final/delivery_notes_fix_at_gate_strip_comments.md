# Delivery note — Fix `at:` gate to strip comments (2026-08-30)

## What changed

Single file touched: `tests/test_playtest_contract_smoke.py` (all other products
byte-untouched: `spine_to_ending.yaml` 42/42, `facility_use_reusable.yaml` 49/49,
`map_facility_buttons_click.yaml` 38/38, `clicks_only_storyline.yaml` 47/47, and
every other scenario / test / game file).

1. **New pure helper `_bad_timeline_at_values(text: str, name: str) -> list[str]`**
   (no file I/O, no globals, placed immediately before
   `test_timeline_at_values_are_integers`). It iterates `text.splitlines()`
   (1-based line numbers), strips each line's comment via
   `line.split("#", 1)[0]` (everything from the first `#` to end of line),
   then applies the ORIGINAL regex `re.search(r"\bat\s*:\s*([^,}\s]*)", line)`
   and the original `val.isdigit()` check. Non-integer captures are appended as
   `f"{name}.yaml line {lineno}: non-integer timeline 'at' value {val!r}"`.
   Returns the accumulated list (empty == green).

2. **`test_timeline_at_values_are_integers`** now reads each `ROUND_SCENARIOS`
   file and delegates to the helper (`bad.extend(_bad_timeline_at_values(...))`),
   preserving the existing `assert not bad, ...` message.

3. **Docstring rewritten.** The false guarantee "`\bat\s*:` is
   word-boundary-guarded, so `at` inside identifiers or prose never matches" is
   DELETED. The new docstrings describe what the code actually does: comments
   are stripped per-line before matching; the regex acts on real content lines
   only; range / list / quoted / float / empty captured values fail `isdigit()`
   exactly as before.

4. **Two regression test functions** (separate functions, pinning both
   directions via the shared helper):
   - `test_timeline_at_real_non_integer_still_red` — asserts
     `_bad_timeline_at_values("- at: abc\n", "probe")` returns a non-empty
     list containing exactly one entry starting with `probe.yaml line 1` and
     containing `'abc'` — a real non-integer `at:` value still reds.
   - `test_timeline_at_comment_backtick_at_is_ignored` — asserts
     `_bad_timeline_at_values("#   ... and every `at:`\n- at: 3\n", "probe")`
     returns `[]` — a backtick-wrapped `` `at:` `` inside a comment contributes
     no entry, and the real `- at: 3` still passes. This pins the exact bug
     (`clicks_only_storyline.yaml:99`).

## Root cause fixed (measured, not predicted)

`test_timeline_at_values_are_integers` matched every line, comments included,
with `re.search(r"\bat\s*:\s*([^,}\s]*)", line)`. `clicks_only_storyline.yaml`
line 99 is a `#` comment whose prose contains a backtick-wrapped `` `at:` ``
token. A backtick is a non-word character, so the `\b` word boundary fires on
the `a`, the regex matches, and `[^,}\s]*` captures the closing backtick `` ` ``,
which fails `isdigit()` → false red. The docstring's "word-boundary-guarded,
so `at` inside identifiers or prose never matches" claim did not hold.

## Verification

This task's granted tool set exposes no shell runner, so I could not execute
`python3 -m pytest tests/test_playtest_contract_smoke.py -q` inside this step.
Verification is therefore by exact trace against the shipped code:

- Helper on `"- at: abc\n"`: lines = `["- at: abc"]`; no `#`, line unchanged;
  regex matches `at: abc` → `val == "abc"` → not `isdigit()` → appends
  `probe.yaml line 1: non-integer timeline 'at' value 'abc'` → non-empty. ✓
- Helper on `"#   ... and every `at:`\n- at: 3\n"`: line 1
  `"#   ... and every `at:`"` → `split("#", 1)[0]` == `""` → regex finds no match
  → skipped; line 2 `"- at: 3"` → `val == "3"`, `isdigit()` → passed → `[]`. ✓
- Real `at:` values are integers and never contain `#`, so `split("#",1)[0]`
  drops no true value; inline trailing comments retain their value (e.g.
  `- {at: 3, actions: [ui_accept]}  # advance` still captures `3`). ✓
- Range (`3..15`), list (`20/25/30`), quoted (`'3'`), float (`3.0`), and empty
  values still fail `isdigit()` on real content lines — the property is
  preserved, only comment lines are excluded from matching. ✓
- `clicks_only_storyline.yaml` line 99 (the `` `at:` `` comment) no longer
  produces a spurious entry; its 47/47 assertion count is unchanged by this
  edit (scenario file not touched). ✓

## Test count note

Per t_plan_review (2026-08-30): the file holds 24 test functions; adding the two
regression cases as separate functions makes it **26** (not 32, as the earlier
plan/subtask text incorrectly stated). The full suite is expected green with no
skip/error when run at 5_compile.

## Scope guard

- `tests/test_playtest_contract_smoke.py` is the ONLY file modified.
- The seven other inline uses of the same regex
  (`test_event_content_surface_contract`, `test_hud_info_surface_contract`,
  `test_creation_clarity_surface_contract`, `test_qi_cost_surface_contract`,
  `test_map_node_event_surface_contract`,
  `test_map_node_event_mainline_surface_contract`,
  `test_facility_use_reusable_surface_contract`) are left **byte-untouched**;
  they scan scenarios that contain no backtick-`` `at:` `` comment and stay
  green. The strip-comment fix applies only to
  `test_timeline_at_values_are_integers` (the one test that iterates every
  `ROUND_SCENARIOS` file).
- No scenario `at:` frame, click, action, assert, or node name changed anywhere.