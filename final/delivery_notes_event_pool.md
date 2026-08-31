# Delivery Notes — no_repeat_gate_test

Round: `jinyong-event-pool-36` · Task: `no_repeat_gate_test` · Date: 2026-08-31

## Goal of this task

Add the executable no-repeat gate to `tests/test_event_data.gd` (extend ONLY; no new test
file). The gate runs the real `EventLogic.draw_unseen_id` 36 times on a fresh `PlayerProfile`
with a fixed-seed RNG, marks each id seen exactly as `cultivation.gd:467-469` does
(append-if-absent), and asserts the seen-bag grows monotonically 0→36 with **no mid-journey
reset** and all 36 drawn ids distinct. It must be RED on the current 16-row pool (draw 17
forces the zero-RNG reset branch) and stay red until the follow-up `event_rows_i18n_mirrors`
task lands ≥ 36 rows.

## Files changed (this task only)

- `tests/test_event_data.gd` — appended exactly 3 things; nothing else touched:
  1. two new `const` preloads (`EventLogic`, `PlayerProfileScript`) beside the existing `EventData`;
  2. one new call line `ok = _test_no_repeat_full_journey(ok)` in `run()`, inserted after
     `ok = _test_fresh_instances(ok)` and before `if ok:`;
  3. one new function `static func _test_no_repeat_full_journey(ok: bool) -> bool`.
- `final/delivery_notes_event_pool.md` — this note.
- No other file changed: `scripts/data/event_data.gd`, `scripts/autoload/i18n.gd`,
  `tests/unit_test_runner.gd` (already collects `test_event_data.gd`), and every frozen
  playtest scenario are byte-untouched. The frozen 16 rows are byte-untouched.

## RED-FIRST EVIDENCE (unit gate)

**Method note — toolset limitation:** this step's available tools do not expose the
godot-builder *unit-suite* leg (`run_tests.sh` → `/script` sidecar runner); the only
run-against-a-live-build probe available is `godot_playtest_scenario`, which executes playtest
scenarios, not unit test files. So the four red-first values below are **derived structurally
from the gate's fully deterministic behaviour** (the `draw_unseen_id` reset branch performs
zero RNG ops, so the 16-pool outcome — draw 17 always repeats a previously-drawn id — has no
random component). They are recorded here as the implementer's expectation and MUST be
confirmed-by-conformance by the real unit-suite leg at the next gate run (sequence:
`event_rows_i18n_mirrors` lands 36 rows → gate turns green → `5_compile` confirms the FLOOR:
16-pool logic guarantees `_test_all_rows`-style red at draw 17). No assertion was predicted
loosely; each value below follows directly from the code.

**The four red-first values (16-row pool):**

| # | Value |
|---|---|
| 1. Failing draw iteration | **17** (after draws 1–16 each return one distinct id, the unseen pool is empty at draw 17 → `draw_unseen_id` clears `flags["events_seen"]`, refills from all 16, draws a repeat) |
| 2. First failing assertion text | `"draw 17 repeats id <X> (no-repeat violated)"` (the third per-draw assert: `not drawn.has(id)` is false because the reset branch can only return an already-drawn id) |
| 3. Expected-vs-observed | no-repeat: expected `drawn.has(id) == false`, observed `true` (repeat). Ladder immediately after: expected `seen-bag size == 17`, observed **`1`** (reset cleared the bag to `[]`, then the gate's appendix re-added only the single 17th id) |
| 4. Green asserts before red | **66** = 16 draws × 4 per-draw asserts (non-empty, in-TABLE, no-repeat, ladder) + 2 draw-17 asserts (non-empty, in-TABLE) that still pass before the first failing assert. Matches the t_plan sanity anchor 66 = 64 + 2. |

The red is intentional and is the whole point of this task: it proves the unit gate catches the
exact defect the roadmap item 3 marks ❌ (16 rows ⇒ the 17th roam would repeat). No assertion
was weakened, and the gate is left RED by design for `event_rows_i18n_mirrors` to turn green.

## Gate design (pinned behaviour)

- Pre: `EventData.all()` → build the id-set from the real TABLE (used for `in-TABLE` checks);
  `FROZEN16` baseline named with a self-documenting comment (16-frozen baseline; survives pool
  growth because the pigeonhole bound `new_ids >= 20` holds for any pool ≥ 36).
- Profile: `PlayerProfileScript.new()` (fresh — `flags["events_seen"]` already starts `[]`),
  then defensively reset `profile.flags["events_seen"] = []` to mirror the sanitized bag.
- RNG: `RandomNumberGenerator.new()` with `rng.seed = 20260831` — deterministic and independent
  of any profile/shared stream.
- Loop `i = 1..36`: real `EventLogic.draw_unseen_id(profile, rng)`; per-draw assert order is
  pinned — `id != ""` → `id ∈ all_ids` → `not drawn.has(id)` → mark seen
  (append-if-absent, mirroring cultivation.gd) → `seen-bag size == i` (monotonic ladder =
  no reset, MEASURED).
- Post: `distinct == 36`; pigeonhole `new_ids >= 20` over `FROZEN16`; **size-floor
  `all.size() >= 36` asserted LAST** so the first red on the 16-pool is the draw-17 no-repeat
  failure, not the size floor (matches the four-value template).

## Interfaces required by the gate (satisfied by existing in-tree signatures)

- `EventLogic.draw_unseen_id(profile: PlayerProfile, rng: RandomNumberGenerator) -> String`
  (`scripts/data/event_logic.gd:21`) — pure static, exactly one `rng.randi_range` per draw,
  zero-RNG reset branch clearing `profile.flags["events_seen"]`.
- `PlayerProfile.new()` defaults `flags = {"tutorial_done": false, "events_seen": []}`
  (`scripts/data/player_profile.gd:33`).

## Follow-up note for `event_rows_i18n_mirrors`

The gate requires no change to turn green once TABLE holds ≥ 36 rows with the 16 frozen rows
verbatim: the 36-draw loop, the pigeonhole bound, and the size-floor all pass by construction.
If a future round ever increases the journey length, the `range(1, 37)` loop bound is the
single one-line edit to re-derive.