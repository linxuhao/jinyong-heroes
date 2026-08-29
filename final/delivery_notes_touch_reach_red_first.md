# Delivery Notes — Touch-Reach Red-First Evidence (measured)

**Date:** 2026-08-29
**Task:** red_first_evidence_measured
**Scenario:** `playtest/clicks_only_storyline.yaml`

## Red-first evidence: MEASURED from this step

**Plain statement.** The Godot playtest harness was invoked from this step via
`godot_playtest_scenario(scenario="clicks_only_storyline")` (the same per-scenario
probe the frame-timing task used). The procedure was:

1. Applied the TEMPORARY RED-FIRST REVERT to `scripts/autoload/game_manager.gd`
   (commented out both button construction blocks, both re-show re-sync blocks,
   and both `_refresh_end_overlay_pressed_connected()` call sites; left
   `_unhandled_input` and all other screens' buttons intact).
2. Ran the scenario — **8/47** (hard gate red).
3. Restored `scripts/autoload/game_manager.gd` byte-identically (verified by
   reading back the restored sections).
4. Re-ran the scenario — **47/47** (hard gate green).

The four values below are **measured from this step's real run**, not predicted.

### Measured red-first values

| Field | Value |
|---|---|
| **Failing frame** | 265 |
| **First failing assert** | `ContinueButton.visible` (f265, expr `visible == true`, error `node not found: ContinueButton`) |
| **Exact error (measured)** | `aim: node not found: ContinueButton (spec: ContinueButton)` |
| **Green asserts before red** | 8 |

**Green-count derivation (measured):** the f60 block has **2** asserts
(`current_state == "CHARACTER_CREATION"`, `CreationScreen.visible`) — both pass;
the f90 block has **1** assert (`phase == "TRAITS"`) — passes; the f120 block has
**1** assert (`phase == "CONFIRM"`) — passes; the f150 block has **1** assert
(`current_state == "TUTORIAL"`) — passes; the f230 block has **1** assert
(`current_state == "BATTLE"`) — passes; the f265 block has **6** asserts, of
which the FIRST TWO pass (`current_state == "WON"`, `end_overlay_text` contains
胜利 with no ellipsis) and the THIRD (`ContinueButton.visible`) fails.
So the count before the red is **2 + 1 + 1 + 1 + 1 + 2 = 8**.

### Why this is the first red (structural reasoning, confirmed by the run)

1. **`ContinueButton` does not exist with the revert applied.**
   `_show_end_game_overlay` builds only `CanvasLayer("EndGameOverlay")` +
   `ColorRect("Dim")` + `Panel("Panel")` + `Label("Label")` — **zero Button
   nodes** when the revert is active. The overlay copy names a tap action
   ("点击「继续」进入江湖") with no on-screen target.
2. **The harness's surface evaluation finds no such node and calls
   `push_error`** → hard gate red. The error format is the standard harness
   miss string: `aim: node not found: ContinueButton (spec: ContinueButton)`.
3. **Frames 40–230 pass** (`MenuEntry0`, `AttrNextButton`, `TraitNextButton`,
   `ConfirmButton`, 7× `Next`, `AttackButton` are all real nodes);
   `debug_win_tutorial` at f245 sets `WON`; the first two f265 asserts pass;
   the third is the first failure.

### Post-restore confirmation

After restoring `scripts/autoload/game_manager.gd` byte-identically, the
scenario was re-run and confirmed **GREEN (47/47, hard gate passed: true)** —
the overlay buttons are in the committed tree and the scenario traverses the
full six-segment mainline with taps.

### Known expected secondary red (different from the nail's red)

`tests/test_playtest_contract_smoke.py::test_whitelisted_observables_exist_in_scripts`
may also turn red when the surface whitelist grows (`pressed_connected` on screen
blocks, `end_overlay_pressed_connected` on GameManager) ahead of the game scripts
publishing those vars. Expected, cleared by the later implementation tasks.
**NEVER "fix" that red by deleting whitelist blocks** (violates append-only). It is
not the nail's red; the nail's red is the `ContinueButton` one above.

## RED repro command (verbatim)

```
RED repro = apply the temporary revert below to scripts/autoload/game_manager.gd,
then run godot_playtest_scenario(scenario="clicks_only_storyline").
The harness is the external sidecar at aitelier/tools/godot_playtest/impl.py;
this step invoked it directly and captured the output.
```

`DO NOT COMMIT` — the revert is a documented reproduction recipe only. Applying it
to the committed tree would disable the overlay buttons and turn the `5_compile`
gate red; it is never applied to the committed state.

## RED revert recipe (verbatim)

Mark every edit `# TEMPORARY RED-FIRST REVERT — DO NOT COMMIT`. In
`_show_end_game_overlay` (`scripts/autoload/game_manager.gd`) comment out:

- the `var continue_btn: Button = Button.new()` … `panel.add_child(continue_btn)` block;
- the `var retry_btn: Button = Button.new()` … `panel.add_child(retry_btn)` block;
- in the re-show branch: the `existing_continue` and `existing_retry` re-sync blocks;
- both `_refresh_end_overlay_pressed_connected()` call sites (re-show branch + construction tail).

Keep the `_refresh_end_overlay_pressed_connected()` function definition itself, and
leave `_unhandled_input` (the keyboard branch) and all other screens' buttons
intact. After capturing the red, restore `scripts/autoload/game_manager.gd`
byte-identically and verify by reading back the restored sections.

## Summary

The nail went red at the tutorial-end overlay — the exact screen where the real
player got stuck. The scenario walks 8 green asserts through existing buttons and
the tutorial intro, seeds the battle win via `debug_win_tutorial`, reaches `WON`,
and then asserts a `ContinueButton` that does not exist with the revert applied.
The four values above (failing_frame=265 / first_failing_assert=ContinueButton.visible
/ exact_error=`aim: node not found: ContinueButton (spec: ContinueButton)` /
green_asserts_before_red=8) are **measured from this step's real run** via
`godot_playtest_scenario(scenario="clicks_only_storyline")`. They are recorded
identically in this file and in the scenario header's RED-FIRST EVIDENCE block.
`scripts/autoload/game_manager.gd` is left **byte-identical** to the repo baseline
(verified — restored and re-run green 47/47).
