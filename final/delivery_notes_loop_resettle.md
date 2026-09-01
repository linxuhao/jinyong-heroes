# Delivery Notes — jinyong-loop R2 · node_event_settled_split

**Date:** 2026-09-01
**Task:** `node_event_settled_split` — node events may RE-APPEAR on revisit (gates
(b) pin re-fire) but their economy/attr effects must NOT re-settle. Every
resolution — applied, refused, or suppressed — still increments
`events_resolved_count` and writes it through to
`GameManager.map_events_resolved_count`, keeping both gate-(b) ladders
byte-identical.

## 1. What was built

The defect (`scripts/segments/map.gd:219-227` `_maybe_start_entry_event()` fires
unconditionally on every `_travel()` arrival; `_resolve_node_event()` `:257-277`
ALWAYS applies effects). Measured by the driver: 洛阳↔武当 6 round trips →
随他抄经 re-picked every arrival, wisdom 10→22 at ZERO month cost.

The fix (design D3) splits re-appearance from re-settlement, keyed by the
**(node_id, event_id) PAIR** — never an event-id-global flag (a cultivation
bag-draw of `night_rain` must not suppress the shaolin node binding; the two
channels are documented independent in `design/20_content.md §8.2`):

1. **`scripts/autoload/game_manager.gd`** — session mirror
   `settled_node_events: Dictionary = {}` (keys `"<node_id>/<event_id>"` -> true)
   plus `is_node_event_settled(node_id, event_id) -> bool` and
   `settle_node_event(node_id, event_id) -> void`. Reset (`clear()`) in the SAME
   handler as `map_events_resolved_count` (`_reset_map_events_resolved_count`,
   connected to `SaveManager.loaded` / `profile_created`) — single-sourced wiring,
   not a second signal connection. Session-scoped only — never persisted, no
   save-schema change. This is the proven `map_events_resolved_count` pattern
   (`:125-131`): the MapScreen is rebuilt on return from a map battle, so its own
   settled set would reset; the mirror carries it across the swap.
2. **`scripts/segments/map.gd`** — `_resolve_node_event()` restructured into
   THREE paths, ALL ending with the same shared tail (`event_id = ""`; `phase =
   "TRAVEL"`; `events_resolved_count += 1`; write-through to
   `GameManager.map_events_resolved_count`; `SaveManager.autosave()`;
   `_sync_surface()`; `_render()`):
   - **SETTLED** (checked first): `GameManager.is_node_event_settled(current_node_id,
     event_id)` → `last_effect_types = []`, `map_status_text = tr("此事已有了结，不再重来")`,
     apply NOTHING. The event re-APPEARS (re-fire pinned by gates (b)) but its
     effects do not re-settle.
   - **REFUSED**: `EventLogic.validate_option(...)` returns a reason
     (`"silver"`/`"owned"`) → `map_status_text` by reason (reusing the existing
     `银两不足` string, no duplicate), `last_effect_types = []`, apply NOTHING.
     Count still increments — the encounter was resolved, its effects were not
     delivered. **This path is composed but inert until the purchase task lands**
     (see §6): `validate_option` is owned by `purchase_all_or_nothing` (T4), so
     until it lands the reason is hardcoded `""` and the APPLIED path runs.
   - **APPLIED**: apply via the shared `EventLogic.apply_option_effects` path,
     then `GameManager.settle_node_event(current_node_id, event_id)`, and publish
     `last_apply_attr_value` ONLY when the chosen option carries an `attr` effect
     — read POST-apply (`SaveManager.profile.get_attr(target)` after `add_attr`),
     so the zero-delta anchor equals the true post-settlement value, not the
     pre-apply one.
   - `_maybe_start_entry_event()` keeps re-appearance UNCONDITIONAL (only the
     settlement is suppressed) and adds one line publishing
     `event_open_silver = SaveManager.profile.silver` — the purchase-nail
     zero-delta anchor.
   - New published var `map_status_text: String = ""`, rendered by `_render()`'s
     TRAVEL arm when non-empty, cleared by `_travel()` and `_enter_facility()`.
     Deliberately NOT mirrored in `_sync_surface()` (same precedent as
     `facility_result_text` — mirroring would wipe the suppressed-frame value).
3. **`scripts/autoload/i18n.gd`** — one EN-dictionary append (Chinese-as-key):
   `此事已有了结，不再重来` → "This matter is already settled; it will not
   repeat". No U+2026 ellipsis.
4. **`playtest/_common.yaml`** — append-only: `map_status_text`,
   `event_open_silver`, `last_apply_attr_value` to the MapScreen surface block;
   `map_node_event_revisit_no_resettle` to the scenario_order tail.
5. **`tests/test_playtest_contract_smoke.py`** — `ROUND_SCENARIOS` tail append +
   new `test_map_node_event_revisit_no_resettle_nail_contract` anti-weakening
   guard (pins the zero-delta line, the empty-effect line, the receipt line, the
   `phase == "EVENT"` re-fire leg, and the two gate-(b) protected files'
   byte-untouched ladder lines).

## 2. Files changed

| File | Change |
|---|---|
| `scripts/autoload/game_manager.gd` | Session mirror `settled_node_events` + `is_node_event_settled` / `settle_node_event`; `clear()` in the same handler as `map_events_resolved_count`. |
| `scripts/segments/map.gd` | `_resolve_node_event()` three paths (settled / refused / applied) with the shared tail; `_maybe_start_entry_event()` publishes `event_open_silver`; new `map_status_text` / `last_apply_attr_value` published vars. |
| `scripts/autoload/i18n.gd` | 1 EN-dictionary append (Chinese-as-key). |
| `playtest/_common.yaml` | Append-only: 3 MapScreen surface vars + scenario_order tail append. |
| `tests/test_playtest_contract_smoke.py` | `ROUND_SCENARIOS` tail append + new anti-weakening guard. |
| `playtest/map_node_event_revisit_no_resettle.yaml` | NEW — the differential revisit nail. |
| `final/delivery_notes_loop_resettle.md` | This note. |

## 3. New nail — `map_node_event_revisit_no_resettle`

Direct-boot `map.tscn` (the same boot pattern as `map_node_event_mainline_return`).
Walks 无名谷 → 洛阳 (merchant, FIRST arrival, APPLIED) → 武当
(quanzhen_scripture, FIRST resolve, APPLIED — wisdom +2, `last_apply_attr_value`
published) → 洛阳 (merchant, SECOND resolution, SUPPRESSED — a DIFFERENT
(node, event) pair, so it settles normally on first arrival but is suppressed on
revisit) → 武当 (quanzhen_scripture RE-APPEARS — `phase == "EVENT"` and
`event_id == "quanzhen_scripture"` — then re-resolves SUPPRESSED).

Asserts are DIFFERENTIAL, zero tuned literals (never `== 8`-style):
- `MapScreen.attr_wisdom: attr_wisdom == last_apply_attr_value` (the success-only
  post-first-apply snapshot — true iff the re-resolve changed nothing).
- `MapScreen.last_effect_types: 'last_effect_types.is_empty() == true'` (the
  suppressed resolution delivered no effects).
- `MapScreen.map_status_text: 'map_status_text != ""'` (the on-screen receipt).
- `MapScreen.events_resolved_count: events_resolved_count == 4` (ladder rung —
  resolve + transit + re-resolve + re-resolve; the count tracks RESOLUTIONS, not
  settlements, so it keeps climbing even when effects are suppressed).
- The FIRST resolve DID apply: `attr_wisdom: changed` vs the boot baseline and
  `attr_wisdom == last_apply_attr_value` — the nail pins "settled once", not
  "never settled".

## 4. RED-FIRST evidence (measured, never predicted)

Measured via the `godot_playtest_scenario` sidecar with a TEMPORARY RED-FIRST
REVERT applied to `scripts/segments/map.gd` (the settled check wrapped in
`if false:` so revisits re-applied effects), then restored byte-identically.

| # | Value |
|---|---|
| 1. Failing frame | **f200** (the merchant revisit resolution) |
| 2. First failing assert | `MapScreen.last_effect_types: last_effect_types.is_empty() == true` |
| 3. Exact error / observed | `FAIL f200 MapScreen.last_effect_types: last_effect_types.is_empty() == true  observed=["silver", "item"]` (the revert removed the settled suppression, so the merchant revisit re-applied its silver/item effects and filled `last_effect_types`) |
| 4. Green asserts before red | **29** (sidecar `ok: 29, total: 33`; all 29 passing asserts precede the first failing one) |

The revert was restored byte-identically (the `if false:` wrapper removed, the
`if GameManager.is_node_event_settled(...)` line re-read). No revert residue
remains in the working tree.

## 5. Green self-run (measured, this step)

Via the `godot_playtest_scenario` sidecar on the delivered tree (repo + staged
files):

| Scenario | Result |
|---|---|
| `map_node_event_revisit_no_resettle` | **33/33** PASS |
| `map_node_event_shaolin` (gate b) | **32/32** PASS |
| `map_battle_node_huashan` (gate b) | **41/41** PASS |
| `map_node_event_mainline_east` | **23/23** PASS |
| `map_node_event_mainline_return` | **20/20** PASS |
| `spine_to_ending` | **42/42** PASS |
| `event_travel_effects` | **19/19** PASS |
| `save_load_roundtrip` | **14/14** PASS |

All eight hard-gates passed with zero runtime errors.

## 6. Gate-(b) safety analysis

`playtest/map_node_event_shaolin.yaml` (verbatim-protected) asserts effect deltas
(`attr_bone: changed`, `last_effect_types == [silver, attr]`) ONLY on the FIRST
resolutions (f460 count==1, f560 count==2); the return-leg re-fire (f620-630,
count==3) asserts only phase/count. `playtest/map_battle_node_huashan.yaml` Leg F
asserts `events_resolved_count == 3` after the re-fired night_rain resolution and
nothing about silver/attrs. The suppressed path keeps the count incrementing (the
count tracks RESOLUTIONS, not settlements), so both gates' ladders stay
byte-identical and green — verified by the 32/32 and 41/41 self-runs above.

The REFUSED path (composed but inert until the purchase task lands) also
increments the count — the encounter was resolved, its effects were not
delivered. This makes every existing scripted-pick timeline immune to
affordability: even if a scripted pick turns out unaffordable, the count still
climbs, so no gate ladder can shift.

## 7. Red lines honored

- **Verbatim-protected trio untouched**: `playtest/facility_use_reusable.yaml`,
  `playtest/map_node_event_shaolin.yaml`, `playtest/map_battle_node_huashan.yaml`.
- **Protected files untouched**: `assets/themes/global_theme.tres`,
  `scenes/ui/{roster_panel,tutorial_overlay,hud}.tscn`,
  `scripts/autoload/theme_manager.gd`, `scripts/segments/sect_select.gd`, the
  focus-style portion of `cultivation.gd::_rebuild_options_box`, the six
  jinyong-huashan files.
- **No balance numbers move**: `event_data.gd` / `facility_data.gd` /
  `card_data.gd` values, `MapData.ENDING_TIERS`, Huashan difficulty.
- **No per-game once-only event policy**: re-appearance stays unconditional; only
  the settlement is suppressed.
- **No U+2026 ellipsis characters** in any new string.
- **Zero RNG ops added** — the settled/refused checks are pure dictionary reads;
  the seeded RNG stream's op order is unchanged (the `event_travel_effects` 19/19
  and `save_load_roundtrip` 14/14 self-runs confirm).

## 8. Cross-task note (purchase_all_or_nothing)

The REFUSED path in `_resolve_node_event()` is fully composed and ready to
consume the `("" | "silver" | "owned")` reason returned by
`EventLogic.validate_option` (owned by the T4 purchase task). Until that task
lands, `validate_option` is treated as returning `""` (the receipt composition
site is a no-op and the APPLIED path runs). The receipt strings `银两不足` and
`此物已在行囊，无须再购` are already wired via `tr()` — the former reuses the
existing key (no duplicate), the latter is added by the purchase task's own i18n
append. No rework is needed when T4 lands: the path is already in place.
