# Delivery notes — `r3c_ending_divergent_repin`

> Date: 2026-09-02 · Card: `r3c_ending_divergent_repin` · Outcome: **door re-derived to the
> self-contained property carrier** — zero game-code edits, zero assertion changes, zero property
> weakening. Only the anti-weakening door's carrier moves, plus one documenting yaml comment.

## (a) Measured red (official gate, quoted verbatim)

`tests/test_ending_gate_pins.py::test_ending_divergent_playstyles_load_bearing_lines_present` is
red because the door pins the cross-node literal

    first_ending_evaluation != evaluation_text

which **no longer appears anywhere in `playtest/ending_divergent_playstyles.yaml`**.

Source of the red: the official 2026-09-02 `test_report.json` (a pipeline step product — 5_test —
NOT a file in the repo; per `final/verify_report.json.superseded_history.note` the authoritative
reports are step products, not repo artifacts). The card's red is quoted here verbatim; it was not
re-derived in this step. In-repo corroboration: `final/verify_report.json` →
`official_gate.playtest.reds.ending_divergent_playstyles = "19/27"`.

`green over absence = no gate`: the door exists precisely to redden when a load-bearing line
disappears. The correct fix is to re-derive the door to a carrier that CAN resolve — not to delete
the pin, and not to move a failing run to green.

## (b) The re-derivation

The old literal is a **cross-node expression the harness can never evaluate**: an assert runs
against the node named in its KEY, but `first_ending_evaluation` lives on `SaveManager` while
`evaluation_text` lives on `EndingScreen` — two different nodes, so the expression could never
resolve. The tree already replaced it with the **self-contained mirror**

    EndingScreen.diverged_from_first: diverged_from_first == true

which is present in the yaml at the Leg B ENDING block (line 584). The mirror is written on every
render at `scripts/segments/ending.gd:128`:

    diverged_from_first = summary != SaveManager.first_ending_evaluation

(G4 2026-09-02 rebaseline; the writer's own comment at `ending.gd:120-127` explains why the old
cross-node expression could never resolve — the harness evaluates an assert against the node in its
KEY). This is a pure string comparison — zero RNG ops.

This card re-derives the `ending_divergent_playstyles` entry in
`tests/test_ending_gate_pins.py` to pin exactly that self-contained carrier line, and adds one
documenting comment at the Leg B ENDING block in the yaml (wording discipline of
`playtest/ending_last_month_choice.yaml:29-36`, which already passed the same door only because its
yaml comments still quote the old literal). The five other entries, `COMMON_SURFACES`, the module
docstring, and all helper functions are byte-identical to the pre-edit file. `diverged_from_first`
was deliberately NOT added to `COMMON_SURFACES` (that tuple stays untouched).

## (c) Property statement — unchanged, only its carrier moved

The module docstring property line stays verbatim:

    * `ending_divergent_playstyles`  — two playstyles reach DIFFERENT evaluations

The property "two playstyles reach DIFFERENT evaluations" is unchanged; only its carrier moved from
an unresolvable cross-node expression to the self-contained mirror that actually evaluates.
**Zero assertion loosening**: no assert added, removed, softened, or retyped in the yaml; the door
still reddens if the differential carrier disappears. The cross-node literal
`first_ending_evaluation != evaluation_text` no longer appears in the `ending_divergent_playstyles`
door entry — replaced by `EndingScreen.diverged_from_first: diverged_from_first == true`.

## (d) Timeline provenance

The official 93-scenario run measured `ending_divergent_playstyles` at **19/27**, with boot-desync
reds at **f925 / f1075 / f1225** (frames live outside the workspace). Those timeline reds are owned
by the landed `fix_scenario_boot_rebaseline` card (pending official re-run) and are **independent of
this card's door line** — this card touches only the door entry and one yaml comment, not the boot
sequence or any `assert:` / `at:` / `clicks:` / `actions:` line. In-repo corroboration:
`final/verify_report.json` → `cards.fix_scenario_boot_rebaseline.red_first` ("ending_divergent_playstyles
19/27 ... stuck at TUTORIAL / phase misalignment").

## (e) Static verification (no shell available)

The implementer has no shell (`godot` is only in the `godot-builder` HTTP sidecar, reached via
`run_tests.sh`), so this section records the OFFICIAL run numbers above plus the static door
verification — no fresh run numbers are invented and the scenario timeline is never claimed green.

- The door check is a `line in text` substring scan of the scenario yaml
  (`tests/test_ending_gate_pins.py:123-140`). The re-derived pinned line
  `EndingScreen.diverged_from_first: diverged_from_first == true` is a **verbatim substring** of
  `playtest/ending_divergent_playstyles.yaml` (line 584), so the door passes **textually**.
- The old literal `first_ending_evaluation != evaluation_text` is now absent from the
  `ending_divergent_playstyles` entry, matching the yaml's actual content.
- The timeline red (**19/27**, f925/f1075/f1225) is **RECORDED, not moved to green**. This card
  does not touch the boot sequence, so the scenario stays red until `fix_scenario_boot_rebaseline`'s
  official re-run. Green over absence = no gate; a re-derived door that claimed a failing timeline
  was green would be exactly the weakening this discipline forbids.

## Hard-rules compliance

- Six-file lock (`scripts/battlefield.gd`, `scripts/autoload/game_manager.gd`,
  `scripts/autoload/scene_manager.gd`, `scripts/segments/map.gd`,
  `scripts/data/map_battle_data.gd`, `playtest/map_battle_node_huashan.yaml`) — untouched.
- Three verbatim gates (`facility_use_reusable`, `map_node_event_shaolin`,
  `map_battle_node_huashan`) — untouched.
- Zero RNG ops; no game-code edits anywhere in this task. No other door entry touched.
