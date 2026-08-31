# Red-First Evidence — shrimp_guard_red_first

Round: `jinyong-shrimpcopy2` · Task: `shrimp_guard_red_first` · Date: 2026-08-31

## Toolset limitation (explicit)

This step's available tools (read / list_tree / create / edit / test_write /
read_test_written / repo_remove_file) have **no shell and cannot execute
commands**. The baseline commands below are recorded verbatim for the record;
they were NOT run by this step. The pipeline's `5_test` gate (which IS a
pytest runner — `.aitelier/knowledge.md`) executes the full suite and produces
the authoritative `test_report.json`. No predicted value is written down as a
measurement.

## Baseline commands (verbatim, not executed this step)

```bash
git rev-parse HEAD
pytest tests/ -v
godot --headless --path . -s res://tests/unit_test_runner.gd
```

## Baseline-green evidence (cited, not re-run)

The base codebase is the previous round `jinyong-event-pool-36` delivery,
verified green at its 5_compile / 5_test gates:

- 95/95 GDScript files compile (zero errors)
- 78/78 playtest scenarios PASS
- GDScript unit suite: all green (28-file registry incl. `test_event_data.gd`)
- pytest static guards: all green (`test_shrimp_roster.py`, `test_i18n_coverage.py`,
  `test_playtest_contract_smoke.py`, `test_facility_copy_location.py`,
  `test_roster_equipment_guards.py`)

Source: `step2_design.md` §2 header and §16 (success-criteria mapping);
`final/delivery_notes_event_pool.md` (previous round's unit-gate evidence).

## Guard file landed

`tests/test_event_prose_shrimp.py` — four pytest functions over frozen token
lists (HUMAN_TOKENS ×38, UNDERWATER_TOKENS ×12, SPECIES_TOKENS ×13,
PROTECTED ×4). Stdlib-only (`pathlib`), no import-time side effects, no pytest
fixtures. The guard adds zero new dependencies and cannot perturb any other
test by construction.

## Expected red inventory (derived from the pre-edit 36-row corpus)

**Derivation method:** each HUMAN_TOKEN was checked as a CJK substring against
the full source of every row (title + text + both option labels + effects
strings) in `scripts/data/event_data.gd` as read on 2026-08-31. The
`_rows()` function splits on `'"id": "'` and attributes each hit to the row
whose id immediately precedes the hit.

### test_no_human_tokens — EXPECTED FAIL

**39 failing (row_id, token) pairs across 28 rows.** Full inventory:

| row_id | tokens found (count) |
|--------|---------------------|
| `bandits` | 劫匪, 之人, 手提 (3) |
| `merchant` | 行商 (1) |
| `beggar` | 老丐, 伸手 (2) |
| `snake_bile` | 弟子 (1) |
| `dragon_scrap` | 书贾 (1) |
| `flood_ferry` | 艄公 (1) |
| `escort_job` | 镖头, 人手 (2) |
| `dali_market` | 掌柜, 拍着胸脯 (2) |
| `night_rain` | 老僧 (1) |
| `gambling_den` | 有人 (1) |
| `quanzhen_scripture` | 老道 (1) |
| `lost_purse` | 无人, 失主 (2) |
| `riverside_duel` | 剑客 (1) |
| `poisoned_well` | 药翁 (1) |
| `tiger_pass` | 头目 (1) |
| `lantern_festival` | 人声 (1) |
| `pawnshop` | 刀主 (1) |
| `storyteller` | 说书人 (1) |
| `chess_stall` | 无人 (1) |
| `smithy` | 老铁匠 (1) |
| `cliff_herbs` | 招人 (1) |
| `night_inn` | 掌柜, 揉眼 (2) |
| `snow_pass` | 向导 (1) |
| `drunken_fist` | 醉汉, 手舞足蹈 (2) |
| `river_god` | 巫师, 村民 (2) |
| `plague_village` | 郎中 (1) |
| `young_disciple` | 少年 (1) |
| `fallen_rider` | 客商, 寻人, 揉着腰, 搭手 (4) |

**Total: 39 pairs · 28 affected rows · 8 rows clean** (ruins, tomb_bed,
wounded_eagle, peach_maze, ancient_bell, wedding_train, sword_mound,
wild_goose_letter — the Class-B rows).

### test_no_underwater_tokens — EXPECTED PASS

No UNDERWATER_TOKEN appears in the pre-edit corpus. The only water-crossing
phrase is 泅水而过 (flood_ferry option_b), which is deliberately NOT in the
banned list (land-world river feat, §4.5 tie-breaker).

### test_no_species_tokens — EXPECTED PASS

No SPECIES_TOKEN appears in the pre-edit corpus. No shrimp species name is
written in any event row.

### test_protected_literals_present — EXPECTED PASS

All four PROTECTED literals are present in the pre-edit corpus:
- `"title": "崖上采药"` — cliff_herbs row ✓
- `"重金购芝"` — cliff_herbs option_b label ✓
- `"泅水而过"` — flood_ferry option_b label ✓
- `"破财消灾"` — bandits option_a label ✓

## Expected outcome at this commit

| test function | expected | reason |
|---|---|---|
| `test_no_human_tokens` | **FAIL** | 39 (row_id, token) pairs in the pre-edit corpus |
| `test_no_underwater_tokens` | PASS | no underwater tokens present |
| `test_no_species_tokens` | PASS | no species tokens present |
| `test_protected_literals_present` | PASS | all 4 literals present |

## Deferral of measured red

The **measured** red — actual pytest output, exact failing-test names, exact
failing (row_id, token) count, affected row ids — is captured by the
pipeline's **5_test pytest gate** (`test_report.json`), NOT by this task.
This step's toolset cannot execute pytest. The inventory above is explicitly
labeled **EXPECTED** (derived by structural inspection of the pre-edit
corpus on 2026-08-31), never "measured". Per the repo's no-fake-measurement
rule, no predicted value is written down as a measurement.

## All other tests stay green (by construction)

The guard file `tests/test_event_prose_shrimp.py`:
- imports only `pathlib.Path` (stdlib)
- has no import-time side effects (no file writes, no network, no global
  mutation)
- reads only `scripts/data/event_data.gd` (which is not modified by this task)
- adds no new pytest fixtures or conftest entries

Therefore, all pre-existing pytest files (`test_shrimp_roster.py`,
`test_i18n_coverage.py`, `test_playtest_contract_smoke.py`,
`test_facility_copy_location.py`, `test_roster_equipment_guards.py`) and the
full GDScript unit suite remain green by construction. This is verified by
the 5_test gate, not by a local run.

## Files modified by this task

- `tests/test_event_prose_shrimp.py` — NEW (the guard)
- `final/shrimp_guard_red_first_notes.md` — NEW (this note)

No prose, mirror, EN entry, or token list was modified. No other file
touched.
