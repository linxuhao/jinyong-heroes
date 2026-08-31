# Gate self-run notes — round `wuxia-shrimp-portraits` (2026-08-31)

Task: `gate_self_run` (Step `gate_self_run.json`).

This note records what this task can **locally verify in-tree** and the full-gate
status. The implementer has **no shell and no network**: it cannot run `run_tests.sh`,
cannot reach the godot-builder sidecar (`godot-builder:8080`), and cannot run `pytest`.
It therefore produces **NO measured gate / playtest / unit-suite / spine / roster
counts**. Fabricating any such count here would violate the repo's honesty contract
(see the `final/regression_run_notes.md` precedent). Actual gate execution is the
downstream host-executable **5_compile / 5_test** step; its artifacts
(`compile_report.json` / `playtest_summary.md` / `test_report.json`) are cited by the
delivery notes and 5_design — not produced here.

## 1. Dependencies finalized (verified in-tree)

Both dependency files read from the repo (working tree) and confirmed finalized:

### `assets/characters/roster.json`
- Six rows, **all** `art_status: "completed"`.
- Four formerly「待定虾种」rows filled with the owner-ruled species strings (non-empty):
  - `east_heretic` → 樱花虾(正樱虾)
  - `south_emperor` → 罗氏沼虾
  - `central_divine` → 玻璃虾
  - `yang_guo` → 枪虾
- The two pre-written rows (`west_poison` 皮皮虾, `north_beggar` 龙虾) retain their
  species strings; `yang_guo`'s `title` (`待定称号(去名化)`) and `note` are unchanged
  (de-naming is a separate round, per the brief).

### `assets/seed_manifest.json`
- Two-layer structure: `subjects` (six cast identities: `id` / `name` / `species` /
  `appearance`) + `images` (six derived images: `subject` / `scene` / `path` /
  `transparent`). No `seed` on any subject/image.
- `style_block` is the split-register sentence (cartoon head / semi-realistic body).
- The 9 non-character `assets` records (terrain floor/border, backdrop summit, 6 audio)
  are preserved with their `seed`/`prompt`/`transparent` fields.
- `subjects[].id` == `images[].subject` == the six PNG stems == the six roster keys.

## 2. Guard tests unchanged by this task

This task makes **zero writes** to any of the four guard tests (it does not `create` or
`edit` them; they are verified present on disk and left untouched):

- `tests/test_shrimp_roster.py`
- `tests/test_playtest_contract_smoke.py`
- `tests/test_facility_copy_location.py`
- `tests/test_i18n_coverage.py`

No `playtest/*.yaml`, surface whitelist, `scripts/`, or `i18n.gd` edits were made; no UI
strings added. No thresholds were loosened.

## 3. Full-gate status — pending host gate run

> Full gate status: **`pending host gate run (5_compile / 5_test artifacts)`**
> (wording copied verbatim from the `final/regression_run_notes.md` precedent §6/§9).

Nothing here is measured by this task. The authoritative counts land in the downstream
host-executable step artifacts:

- **5_compile** → `compile_report.json` (compile error count) and `playtest_summary.md`
  (playtest scenario total, pass/fail counts, runtime-error count, hard gate `passed` /
  `spec_used`).
- **5_test** → `test_report.json` (pytest suite, incl. the four guard tests; the GDScript
  unit suite result; the `spine_to_ending` pass count).

If the host gate later reports a red nail, that red belongs to the downstream step's
record scope (5_compile / 5_test), not to this note. This note reports the gate status as
pending and does not pre-judge red or loosen any threshold.

## 4. Honest-state note

First-round all-pending is the correct honest state for an evidence task whose measured
gate products arrive only through the host `5_compile` / `5_test` step — it is not a
failure. No count is fabricated in this file.