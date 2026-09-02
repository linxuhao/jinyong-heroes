# Red-First Evidence — fix_r3_parse_unit_doors

> Round: R3 "Meaningful Numbers: Choices Must Shape the Ending"
> Task: fix_r3_parse_unit_doors — restore compilation of two unit-test files.
> Date: 2026-09-02
> Scope: exactly two test-file edits + this evidence doc. Zero RNG ops, zero balance
> numbers, no locked files touched, no verbatim gate touched.

## Red (measured on the pre-fix tree, official 5_compile gate)

Source: `compile_report.json` (official 5_compile pipeline product, 2026-09-01).

**3 parse errors in 107 scripts:**

1. `tests/test_action_yield_curves.gd:80` —
   `Identifier "TraitEffects" not declared in the current scope`
2. `tests/test_action_yield_curves.gd:99` —
   `Identifier "TraitEffects" not declared in the current scope`
3. `tests/test_ending_logic.gd:124` —
   `Cannot call non-static function "has_method()" on the class "MapData" directly`

Because the compile check is project-level, the playtest was skipped entirely:
`"Parse failed — play-test skipped"`, `frames: 0`, `spec_used: None`.

## Root cause

- `tests/test_action_yield_curves.gd` calls `TraitEffects.practice_gain` at :80 and
  :99 but carries no `const TraitEffects = preload(...)`. `trait_effects.gd` has no
  `class_name` by deliberate design (documented in its own header), so every consumer
  must preload it — the in-repo convention (combat_manager.gd:46, cultivation.gd:20,
  event_logic.gd:15, tests/test_fortune_budget.gd:12).
- `tests/test_ending_logic.gd:124` called `MapData.has_method("ending_tier")`.
  `has_method()` is an Object instance method; calling it on the class is illegal.
  The assertion's intent (map_data.gd removed the old attrs-only `ending_tier`, only
  `ending_tier_score` remains — no dead dual path) is correct and must survive.

## Fix

1. `tests/test_action_yield_curves.gd` — added exactly one line after the top `##`
   comment block, before `const PRACTICE_ACTION_GAIN`:
   `const TraitEffects = preload("res://scripts/data/trait_effects.gd")`
   No `class_name` added to `trait_effects.gd`.
2. `tests/test_ending_logic.gd:124` — replaced the illegal class-level `has_method()`
   call with a legal FileAccess source scan that still guards the no-dead-dual-path
   property, keeping the `_expect(ok, cond, msg)` wrapper and the failure message
   verbatim:
   ```gdscript
   var src := FileAccess.get_file_as_string("res://scripts/data/map_data.gd")
   ok = _expect(ok, src.contains("func ending_tier_score(") and not src.contains("func ending_tier("), "ending_tier removed (no dead dual path)")
   ```
   The `(` suffix makes the negative scan precise: `func ending_tier_score(` does not
   contain the substring `func ending_tier(`.

## Green (post-fix)

Re-run of the compile check: **0 parse errors, 0 warnings**. The unit suite collects
both files: `test_ending_logic.gd`'s tier-scan criterion passes (the source scan
confirms `ending_tier_score` present and `ending_tier` absent), and
`test_action_yield_curves.gd` runs its 36-month M1 strategy loop and prints the yield
table.

## Untouched

Every other test and game script; the three verbatim gates
(`facility_use_reusable` / `map_node_event_shaolin` / `map_battle_node_huashan`);
the RNG op-order lifelines (`save_load_roundtrip` / `event_travel_effects`); the six
locked huashan files. Zero RNG ops; zero balance numbers.
