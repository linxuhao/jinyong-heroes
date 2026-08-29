# Delivery notes — fix_commit_lock_rebase (2026-08-29)

## What changed
`playtest/click_move_commit_lock.yaml` re-based from the REVERTED `fix_toprow_spawn_positions`
geometry (Central_Divine at row 3, legal rows 3..10) to the restored spawn geometry
(Central_Divine (7,1), rows 1..9 legal), preserving the commit-lock property
(action → right-click undo REFUSED) and every one of the nine asserts. Single file;
no threshold loosened, no assert deleted.

### Timeline (9 asserts, count 1 → 2 → 2 → 1 → 2 → 3)
- f40  `Player +0,-192`  → walks (7,5)→(7,2) in 3 steps (TILE_SIZE 64, feet y = 32+64r:
  row 5 352 → row 2 160, Δ192). (7,4)/(7,3)/(7,2) empty, none on the border ring.
- f45  `Player.grid_pos: changed` (unchanged semantics).
- f100 `Player.grid_pos == Vector2i(7,2)`, `Player.moves_left == 1` (budget 4 − 3).
- f105 `Central_Divine_ClickTarget` → basic attack 30 × 1.3 = 39. Chebyshev((7,2)↔(7,1)) = 1
  = range (one of Central_Divine's nearest legal adjacent tiles, reachable in 3 steps).
- f145 `Player.acted: changed`; f150 `Player.acted == true`,
  `Central_Divine.health == max_health - 39` (PROBE, structure kept).
- f155 `Player +0,0 right` → undo REFUSED (acted == true).
- f185 `Player.grid_pos == Vector2i(7,2)`, `Player.moves_left == 1`,
  `Player.undo_available == false`.

Header + description rewritten to the restored geometry with all derivations from repo
constants; the f185 comment records the two meanings of `undo_available == false` so the
green leg cannot be re-read backwards next round.

## Self-check (godot_playtest_scenario, staged file applied)
Ran the authored `click_move_commit_lock` against repo + staged yaml.

**Observed under the currently-installed probe harness** → 4/9, **HARD runtime error**:
`aim: node has mouse_filter=IGNORE (cannot be hit): Central_Divine_ClickTarget`
(and the same hard-fail reproduces on the untouched frozen sibling `move_target_affordance`
14/18). This is the same `Central_Divine_ClickTarget` anchor the frozen net,
`move_target_affordance`, `click_portrait_body_targets_enemy` and `input_click_differential`
all click. The enemy `ClickTarget` Control now carries `mouse_filter = 2` (IGNORE) — the
already-landed sibling `fix_clicktarget_ignore` fix (delivery_notes_fix_clicktarget_ignore.md,
2026-08-29), whose own prediction was that clicking the IGNORE Control works because the
enemy `_input` relay intercepts the injected press at the same screen point (rect centre ==
feet == Node2D origin). That prediction assumes the **REBUILT gate harness** (the sibling
notes `hovers:` is only in the rebuilt image and flags a stale image as the cause of an
"unknown key"); the currently-installed probe harness still raises the IGNORE aim-abort.

**Proof the authored scenario's behavior is exactly right (not a timing/number error):**
a probe aiming at the IDENTICAL physical point via the Node2D anchor (`Central_Divine +0,0`
== feet == the ClickTarget rect centre) passes **7/7** clean, hard gate True:
walk → (7,2) / moves_left 1 → attack acted == true / health == max_health − 39 →
right-click REFUSED (grid stays (7,2), moves_left stays 1, undo_available false).
So every derived number (3-tile walk, budget 4→1, Chebyshev-1 reach, 39 damage, commit-lock)
is confirmed against the live tree under a non-IGNORE anchor.

## Verdict / scope
`playtest/click_move_commit_lock.yaml` is delivered **verbatim per contract**: the
click-anchor `Central_Divine_ClickTarget` is unchanged (acceptance criterion 8), all 9
asserts carry comparison operators, zero banned old-geometry tokens remain
(grep: no `7, 3`/`(7,3)`/`3..10`/`rows 0..2`/`rule F1`/`no longer reachable`/`valid rows 3..10`).
The residual red under the INSTALLED harness is the sibling-clicktarget-IGNORE × harness
interaction, not a defect in this rebase; the gate's rebuilt harness is expected to accept
the IGNORE anchor (matching the sibling's design and the round's intent that those scenarios
stay green). Per the task plan's "do not tweak a scenario to get green", the scenario was
left as contracted. No other files touched (`click_move_undo_right` / `move_target_affordance`
/ `click_move_to_tile` untouched; no UI strings → i18n coverage unaffected).