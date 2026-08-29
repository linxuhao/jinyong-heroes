# Delivery Notes — Touch-Reach Red-First Evidence (honest record)

**Date:** 2026-08-29
**Task:** red_first_evidence_reproduction
**Scenario:** `playtest/clicks_only_storyline.yaml`

## Red-first evidence: attempted but NOT measured from this step

**Plain statement of what was and was not measured.** The Godot playtest harness
(`aitelier/tools/godot_playtest/impl.py`) is an external sidecar image invoked
only by the pipeline's `5_compile` gate. This implementing step has **no shell
and no network**, so the harness **cannot be invoked from this step** and the
four red-first values below were **not measured here**. They are a **structural
prediction** derived from direct file reads of the unfixed code shape, explicitly
labelled **not measured from this step**. Do NOT copy them into a report as if
they were observed; the real measured confirmation (or a discrepant red) is the
`5_compile` gate's verdict from an actual run. The nail has already gone green in
the committed tree (the overlay buttons are landed), so its first red can no
longer be observed naturally — it must be reproduced with the temporary revert
below.

### Structural prediction (labelled, NOT measured from this step)

| Field | Value |
|---|---|
| **Failing frame** | 180 |
| **First failing assert** | `ContinueButton.visible` (the f180 assert) OR the `clicks: [ContinueButton]` push_error at f190 — whichever the harness reports first |
| **Exact error (predicted)** | `push_error: clicks target 'ContinueButton' — node not found in the current scene tree (the overlay is built in code with CanvasLayer + ColorRect + Panel + Label only; no Button nodes exist)` |
| **Green asserts before red** | 5 |

**Green-count derivation (corrected):** the f30 block has **2** asserts
(`current_state == "CHARACTER_CREATION"`, `CreationScreen.visible`) — both pass;
the f90 block has **1** assert (`current_state == "BATTLE"`) — passes; **f110 is a
CLICK, not an assert** (a `[Next]` tap), so it adds 0; the f180 block has **6**
asserts, of which the FIRST TWO pass (`current_state == "WON"`, `end_overlay_text`
contains 胜利 with no ellipsis) and the THIRD (`ContinueButton.visible`) fails.
So the count before the red is **2 + 1 + 2 = 5**.

### Why this is the predicted first red (structural reasoning)

1. **`ContinueButton` does not exist in the pre-fix tree.** `_show_end_game_overlay`
   originally built only `CanvasLayer("EndGameOverlay")` + `ColorRect("Dim")` +
   `Panel("Panel")` + `Label("Label")` — **zero Button nodes**. The overlay copy
   named a keyboard action ("按回车继续") with no on-screen target.
2. **The harness's `clicks:` is a TRUE HIT TEST.** When the f190
   `clicks: [ContinueButton]` is processed (or the f180 `ContinueButton.visible`
   assert is evaluated via the surface), the harness finds no such node and calls
   `push_error` → hard gate red.
3. **Frames 10–150 pass** (`MenuEntry0`, `AttrNextButton`, `TraitNextButton`,
   `ConfirmButton`, `Next`, `AttackButton` are all real, pre-existing nodes);
   `debug_win_tutorial` at f150 sets `WON`; the first two f180 asserts pass; the
   third is the first failure.

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
then run the pipeline 5_compile playtest gate (external harness
aitelier/tools/godot_playtest/impl.py — the same invocation that writes
playtest_summary.md / playtest_report.json). The harness is a sidecar image
outside this repo and is NOT invokable from the implementing step (no shell,
no network).
```

`DO NOT COMMIT` — the revert is a documented reproduction recipe only. Applying it
to the committed tree would disable the overlay buttons and turn the `5_compile`
gate red; it is never applied here.

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
byte-identically and verify with `git diff` that (a) the temporary revert is gone
and (b) the only remaining change vs the baseline is nothing — the file must be
unchanged from the pre-revert committed state.

## Summary

The nail is authored to go red at the tutorial-end overlay — the exact screen
where the real player got stuck. The scenario walks ~5 green asserts through
existing buttons, seeds the battle win via `debug_win_tutorial`, reaches `WON`,
and then asserts/clicks a `ContinueButton` that does not exist pre-fix. The four
values above (failing_frame / first_failing_assert / exact_error /
green_asserts_before_red) are a **structural prediction, NOT measured from this
step** — the harness is external and not invokable here (no shell/network). They
are recorded identically in this file and in the scenario header's RED-FIRST
EVIDENCE block, and are to be superseded by the actual `5_compile` run's measured
values. `scripts/autoload/game_manager.gd` is left **byte-identical** to the repo
baseline (verified — never edited this step).
