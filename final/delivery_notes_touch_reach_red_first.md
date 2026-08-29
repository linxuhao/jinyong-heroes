# Delivery Notes — Touch-Reach Red-First Evidence

**Date:** 2026-08-29
**Task:** clicks_only_contract_nail
**Scenario:** `playtest/clicks_only_storyline.yaml`

## RED-FIRST EVIDENCE (structural analysis — measured confirmation is the downstream gate's verdict)

The Godot playtest harness (`aitelier/tools/godot_playtest/impl.py`) is an external
sidecar image and cannot be invoked from this implementation step. The evidence below
is the **structural prediction** based on direct file reads of the current unfixed
tree; the **measured** confirmation (exact push_error string, frame-accurate green
assert count) is the downstream gate's verdict at `5_compile`.

### Predicted first failure

| Field | Value |
|---|---|
| **Failing frame** | 180 |
| **First failing assert** | `ContinueButton.visible: visible == true` |
| **Exact error (predicted)** | `push_error: clicks target 'ContinueButton' — node not found in the current scene tree` (the harness's unresolvable-node failure mode) |
| **Green asserts before red** | 5 (frame 30: 1 assert, frame 90: 1 assert, frame 110: 0 — it's a click not assert; so frame 30 = 1, frame 90 = 1, then frame 180 block has 4 asserts and the FIRST one is `current_state == "WON"` which passes, the SECOND is `end_overlay_text` which passes, the THIRD is `ContinueButton.visible` which FAILS → so 2 green asserts in the f180 block before the red) |

### Why this is the first red (structural proof)

1. **`ContinueButton` does not exist in the current tree.** `scripts/autoload/game_manager.gd:452-505`
   (`_show_end_game_overlay`) builds:
   - `CanvasLayer("EndGameOverlay", layer 50)`
   - `ColorRect("Dim", full-rect, MOUSE_FILTER_STOP)`
   - `Panel("Panel", 500×250, centered)`
   - `Label("Label", full-rect in panel, text, GOLD, font_size 28)`

   **No Button nodes are created.** The function ends at line 505 after
   `panel.add_child(label)`. There is no `ContinueButton`, no `RetryButton`.

2. **The harness's `clicks:` is a TRUE HIT TEST.** When the scenario's `clicks:
   [ContinueButton]` at frame 190 is processed, the harness searches the scene
   tree for a node named `ContinueButton`. Finding none, it calls
   `push_error` → hard gate red. The assert at frame 180 that references
   `ContinueButton.visible` (via the surface) similarly fails because the node
   does not exist (the Expression evaluator returns null/parse error).

3. **Frames 10–150 pass** (the buttons that DO exist: `MenuEntry0`,
   `AttrNextButton`, `TraitNextButton`, `ConfirmButton`, `Next`, `AttackButton`
   are all real nodes in the scene tree). The `debug_win_tutorial` seed at
   frame 150 fires, `current_state` transitions to `"WON"` by frame 180, and the
   first two asserts (current_state, end_overlay_text) pass. The third
   (ContinueButton.visible) is the first failure.

### Known expected secondary red

`tests/test_playtest_contract_smoke.py::test_whitelisted_observables_exist_in_scripts`
will ALSO turn red in this task's wave because the surface whitelist was extended
with `pressed_connected` (on 5 screen blocks) and `end_overlay_pressed_connected`
(on GameManager) before the game scripts publish those vars (they land in the
end_overlay_buttons task and the wave-3 screen tasks). This is **expected** and
is cleared by the later implementation tasks. **NEVER "fix" that red by deleting
whitelist blocks** (that violates append-only).

### Summary

The nail is correctly authored to go red at the tutorial-end overlay — the exact
screen where the real player got stuck. The scenario walks through 5 green frames
of clicks on existing buttons, seeds the battle win, reaches `WON`, and then
attempts to click/assert a `ContinueButton` that does not yet exist. The first
red is at frame 180, on the `ContinueButton.visible` assert (or equivalently,
the harness push_error at the frame 190 click attempt, depending on which the
harness reports first).

The measured values (exact error string, frame-accurate green count) will be
transcribed from the actual gate run into this file and the scenario header's
RED-FIRST EVIDENCE block.
