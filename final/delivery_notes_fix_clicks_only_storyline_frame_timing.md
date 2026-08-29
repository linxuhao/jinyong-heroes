# Delivery Notes — fix_clicks_only_storyline_frame_timing (2026-08-29)

Task: `playtest/clicks_only_storyline.yaml` — align click frames to screen-ready
timing so the clicks-only spine runs green end-to-end. Artifact: the yaml.

## Root cause (measured, not predicted)

The gate reds on `clicks_only_storyline` with 88 `aim: node not found` runtime
errors, the FIRST being `MenuEntry0` at frame 10. The harness `_resolve()` ends
with `get_tree().get_root().find_child(name, true, false)` (a recursive
whole-tree name search), so `node not found` means ONLY "that node is not in
the tree at that frame" — not a naming bug.

The default boot scene is `res://scenes/main.tscn`, a BARE shell (Main / Camera
/ SceneHost / SegmentLayer / SegmentHost / HUD / TutorialOverlay — no
`MenuPanel`, no `MenuEntry0`). The scenario carried no `scene:` override, so it
booted main.tscn: the game starts in `TUTORIAL` from f3, `MenuEntry0` never
exists, the game never leaves the main menu, and every later click aims at a
screen never reached. Measured first failing assert: f30
`current_state == "CHARACTER_CREATION"` observed `"TUTORIAL"`, then
`CreationScreen.visible` -> node not found (all later ladder asserts read
node-not-found / observed TUTORIAL).

## The fix (frame timing + scene override)

1. **`scene: res://scenes/menu.tscn`** added — the documented per-scenario
   override (`_common.yaml:21-44`) that boots this scenario straight into the
   real main menu (`menu.tscn` is main.tscn plus the `MenuPanel`, proven by
   `main_menu_entries` / `menu_to_creation_to_tutorial_order`). Every scenario
   runs in its own fresh Godot process, so this costs nothing.
2. **All `at:` frames re-projected** onto the screen-ready settle latencies so
   each click lands strictly AFTER its target node is in the tree. The
   tutorial-intro leg **grew from 3 to 7 `Next` clicks** (TutorialManager
   `STEP_COUNT == 7`), and the `current_state == "BATTLE"` assert moved to
   strictly after the 7th click.
3. Ladder asserts (state strings, `year`/`month`, `phase`,
   `events_resolved_count == 1/2/3`, `tier >= 1 and tier <= 3`) re-aligned to
   the new frames. The proof is preserved: menu -> creation -> tutorial battle
   -> overlay -> transition -> sect -> 36-month cultivation -> map -> events ->
   ending -> restart, all driven by `clicks:` only, zero keyboard actions, the
   single documented `debug_win_tutorial` seed.

### Second root cause found by the probe (a real game bug, not a frame issue)

The in-step probe first produced **21/47** with a hard runtime error:
`Attempted to free a locked object (calling or emitting)` at
`res://scripts/segments/cultivation.gd:534`. Every CLICK on a `CultOptionButton`
re-enters `_render()` (via `_on_option_pressed -> _on_accept`) which calls
`_rebuild_options_box()`; that did `child.free()` on the very button that is
mid-emission of its own `pressed` signal. `free()` on a locked (emitting) object
throws and corrupts the OptionsBox, so after the first rebuild the cultivation
loop cannot advance (observed at f525: `year == 1`, `month == 2` instead of
`year == 2, month == 1`). The keyboard path never hits this (it calls `_render`
from `_unhandled_input`, not from a button press), which is why 69/69 scenarios
stayed green and the bug shipped unseen — the same observation gap this round
exists to close.

Fix (minimal, behavior-preserving): in `_rebuild_options_box()` change
`child.free()` -> `child.queue_free()`. `remove_child` already detaches every
old button so it is unhittable the same frame; `queue_free` only defers the
memory reclaim to end-of-frame (next click is 5+ frames later), letting the
emission complete. No month-advance / phase / gongfa / attr / event logic
changes. The keyboard path is a superset (queue_free is safe where free was).

## Measured observed values (from `godot_playtest_scenario`, this step)

Probe 1 — after the yaml timing+scene fix only (free-locked bug still present):
`clicks_only_storyline` **21/47**, hard gate False.
- runtime error (x2): `Attempted to free a locked object (calling or emitting)`,
  `res://scripts/segments/cultivation.gd:534`
- runtime errors (many): `aim: node not found: CultOptionButton0/2`, then
  `TravelButton0`, `EventOptionButton0`, `TravelButton1`, `RestartButton`
- `f525 CultivationScreen.year == 2` observed **1**
- `f525 CultivationScreen.month == 1` observed **2**
- `f845 GameManager.current_state == "MAP"` observed **"CULTIVATION"**
- `f975 current_state == "ENDING"` observed **"CULTIVATION"**; `f1005 == "TUTORIAL"` observed **"CULTIVATION"**

Probe 2 — after the `cultivation.gd` free->queue_free fix:
`clicks_only_storyline` **47/47**, hard gate **True** (zero runtime errors).

Regression probe (same staged files):
`spine_to_ending` 42/42, `cultivation_month_cycle_and_deck_bookkeeping` 17/17,
`cultivation_year_end_stay` 8/8, `cultivation_changes_combat` 30/30,
`sect_switch_same_school_connects` 8/8, `map_facility_buttons_click` 38/38,
`facility_use_reusable` 49/49 — **all green, no regressions** from the
`cultivation.gd` change.

## Probe-resolved unknowns (recorded for a later round)

- **Last-work-month -> MAP swap settlement**: the final Year-3 month-12 做工
  click at f795 lands in MAP by f845 (a 50-frame settle) — this is what the
  green run uses. Map leg 4 (襄阳->昆仑, no entry event) settles to ENDING in
  +30 frames.
- **wudang / xiangyang neighbor order** (read from `scripts/data/map_data.gd`):
  `luoyang: [wuming_valley, wudang, shaolin]` -> wudang is index 1;
  `wudang: [luoyang, xiangyang]` -> xiangyang is index 1;
  `xiangyang: [wudang, kunlun]` -> kunlun is index 1. So leg 1 uses
  `TravelButton0`, legs 2/3/4 use `TravelButton1`. A wrong index would be an
  honest red (`current_node_id` assert fails), not a silent miss.

## Notes

- The long RED-FIRST EVIDENCE header block at the top of the yaml is **retained
  as documentation** (the structural prediction from the prior round), not a
  live assertion of this fix. This step's measured evidence lives here in this
  delivery note.
- `clicks:` count >= 5; the only non-click timeline action is the single
  `debug_win_tutorial` seed; no `ui_accept` / `move_*` / `tutorial_next` /
  `end_turn` / `use_facility` anywhere in the timeline; no `*_ClickTarget`
  anchors.
- Other round products are byte-untouched: `spine_to_ending.yaml` (42/42),
  `facility_use_reusable.yaml` (49/49), `map_facility_buttons_click.yaml`
  (38/38), `_common.yaml`, `tests/`. The only files changed this step are
  `playtest/clicks_only_storyline.yaml` (this task's artifact) and the minimal
  `scripts/segments/cultivation.gd` `free()` -> `queue_free()` fix that the
  clicks-only path requires (documented above; all 7 related scenarios still
  green).
