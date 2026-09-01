# Red-first evidence — r3_fortune_reroll (2026-09-01)

## Nail: `playtest/fortune_reroll_budget.yaml` — the fortune reroll budget

The differential nail proves the creation-screen promise 「影响事件与奇遇（福缘越高，
每年游历事件可重掷次数越多）」 is implemented: a travel-event reroll with a
year-scoped budget (design D2).

### Red-first (MEASURED on the pre-fix tree)

The scenario was run on the current tree BEFORE the rerolls_left surface existed
on `CultivationScreen` (the pre-fix script did not publish it). The four house
values:

1. **Failing frame:** `f130`
2. **First failing assertion:** `CultivationScreen.rerolls_left: rerolls_left == 1`
3. **Exact error / observed:**
   ```
   node property not found: CultivationScreen.rerolls_left
   ```
   (the surface was not yet published by the pre-fix script — the node/property
   was absent, exactly the predicted red shape)
4. **Green asserts before red:** 3 (the f130 asserts `current_state ==
   "CULTIVATION"`, `phase == "CARD_PICK"`, `month == 1` precede the rerolls_left
   line in file order)

### Honesty note (leg-1 differential shape)

The task's leg-1 expectation that `event_id` and `events_seen_count` both read
`"changed"` on a reroll is NOT deterministically expressible in this harness:

- `draw_unseen_id` draws from the pool of events NOT in `events_seen`. The
  original travel draw does NOT mark the event seen, so the reroll draws from
  the SAME pool and may redraw the same event (1/36 with the natural pool; the
  seed is a fresh system-clock entropy seed per run, not fixed).
- `events_seen_count` only grows when an event is RESOLVED
  (`_apply_event_option`), never on a draw or reroll.

So leg 1 pins the robust facts (`rerolls_left` 1 -> 0, `event_title`/`event_body`
re-published non-empty, `event_id` non-empty) and leg 2 pins the inert facts
(`rerolls_left == 0`, `event_id`/`events_seen_count` unchanged, non-empty inert
receipt) — the differential that IS deterministic. This is recorded here per the
task's "if neither is expressible, assert rerolls_left == 0 + non-empty inert
receipt and say so honestly" instruction.

### Post-fix green (measured)

After landing the code, the scenario runs green: leg 1 rerolls_left 1 -> 0 with
event_title/event_body re-published non-empty; leg 2 exhausted press is inert
(rerolls_left == 0, event_id/events_seen_count unchanged, status_text non-empty);
leg 3 occlusion-clean on the reroll frame.

## RNG ledger

- Zero new draws on old paths: the travel draw path keeps byte-identical
  semantics (the reroll's `draw_unseen_id` executes ONLY on the player-initiated
  `event_reroll` press).
- Exactly one draw per successful reroll press; the exhausted branch performs
  ZERO RNG draws.
- `save_load_roundtrip` and `event_travel_effects` re-run green (counts recorded
  in the consolidated gate run).

## Key binding

`event_reroll` is bound to the **R** key (physical_keycode 82, unicode 114) in
`project.godot` `[input]`. Grep of the existing `[input]` section confirmed no
collision: R is not used by any existing action (move_up=W, move_down=S,
move_left=A, move_right=D, skill_1..12=1..0/-/=, attack_confirm=J,
end_turn=Space, use_facility=F, pause_game=Escape, tutorial_next=Enter).

## creation_attr_effect_info copy-pin re-derivation (fortune row only)

The fortune row of `_ATTR_DESCS` changed from the old promise to the honest
implemented copy. The scenario's pins assert `福缘` and `奇遇` are present in the
at-rest desc list — both survive in the new copy, so the existing pins stay
green. Before/after table:

| Row | Before | After |
|---|---|---|
| fortune | 影响事件与奇遇(游历事件可重掷) | 影响事件与奇遇（福缘越高，每年游历事件可重掷次数越多） |

No other row was touched. The new copy still contains 福缘 and 奇遇, so
`creation_attr_effect_info`'s `text.contains("福缘")` and `text.contains("奇遇")`
asserts remain green.
