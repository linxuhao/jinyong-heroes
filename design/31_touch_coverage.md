# 31 — Touch Coverage Survey (Fully Clickable Every-State Touch Reach)

**Date:** 2026-08-30 (touch-single-surface round).
**Method:** every `file:line` below was read from the **post-change tree** (the six code
dependencies — `cultivation_single_surface`, `map_single_surface`,
`sect_select_single_surface`, `nail_scenarios`, `coverage_gate`,
`copy_guard_tr_detection` — are all landed). The property this survey enumerates is the one
the coverage gate (`tests/test_touch_option_surface_gate.gd`) asserts as a traversal:
*every player-choice state the machine reaches must have ≥ 1 visible, wired tappable control,
with no `▶` cursor list in the body text* — a state is EXEMPT only if no input can change it
(pure display / auto-advance).

The four `▶`-duplication sites this round removed: `cultivation.gd` (option rows +
`▶` in `BodyLabel`), `map.gd` (EVENT option rows, FACILITY `▶`-verb, TRAVEL focus
markers), `sect_select.gd` (row `▶`). `creation.gd` was already single-surface (the
precedent). Every "Touch-only exit?" column below is **Y** — no state a touch player can
reach is keyboard-only anymore.

| Segment | Phase/State | Clickable controls (file:line) | Touch-only exit? Y/N | Missing (if N) | Disposition this round |
|---|---|---|---|---|---|
| cultivation | `YEAR_AUGMENT` | `CultOptionButton0..2` (year cards), built+modulate+focused+wired by `_rebuild_options_box` `scripts/segments/cultivation.gd:560-562,603-615`; `option_focus` / `focused_option_text` observables `:859-860` | Y | — | already landed (touch-reach); single-surface + button highlight this round |
| cultivation | `CARD_PICK` | `CultOptionButton0..2` (month cards) `cultivation.gd:563-565,603-615` | Y | — | single-surface this round (`_card_button_label` `:620-624`) |
| cultivation | `ACTION_PICK` | 7 buttons 练功/修习/做工/游历/存盘/读档/删档 `cultivation.gd:566-569,603-615`; click delegates `_on_option_pressed` → `_on_accept` (`:517`→`_on_accept`) | Y | — | single-surface this round (7 space-separated label rows removed) |
| cultivation | `GONGFA_PICK` (non-empty) | `CultOptionButton0..N` (one per unmastered art) `cultivation.gd:570-584,603-615` | Y | — | single-surface this round |
| cultivation | `GONGFA_PICK` (**empty**) | single `CultOptionButton0` 「返回行动」 `cultivation.gd:572-576`; pressed → `_on_option_pressed` → `_on_accept` empty branch returns `phase = "ACTION_PICK"` `:235-238`; empty hint states the exit `:833-838` | **Y** | was N (**the P0 dead-end** — zero buttons, `box.visible = not labels.is_empty()` hid everything, keyboard-only exit) | **FIXED this round**: always-one-button guarantee (`cultivation.gd:542-550` comment documents it); phase-diff pipe pinned by `playtest/clicks_only_gongfa_empty_exit.yaml` |
| cultivation | `ATTR_PICK` | 5 attr buttons (one per attr) `cultivation.gd:585-588,603-615` | Y | — | single-surface this round |
| cultivation | `EVENT` | `CultOptionButton0/1` (option A / option B) `cultivation.gd:589-593,603-615` | Y | defensive `EventData.def(event_id) == null` → zero buttons (`:590-593`,`:601`) — **unreachable through the machine** (every `event_id` comes from a validated pool draw); recorded, not a touch dead-end | single-surface this round; defensive branch retained and documented (`:548-550`) |
| cultivation | `YEAR_END` | 2 buttons 留在本门/另投他派 `cultivation.gd:594-597,603-615` | Y | — | single-surface this round |
| cultivation | `SECT_SWITCH` | 5 sect buttons `cultivation.gd:598-600,603-615` | Y | — | single-surface this round |
| map | `TRAVEL` | `TravelButton0/1/2` (i-th neighbor); wired `map.gd:333-338`, synced + button-highlight `:475-483` (`b.modulate` bright for `nbrs[i] == focus_id` `:483`); node list stays as descriptive overview, `▶`/（可前往） focus markers removed | Y | — | single-surface this round |
| map | `EVENT` | `EventOptionButton0/1` (option A/B); wired `map.gd:340-345`, synced + button-highlight `:484-494`; `_on_event_option_pressed` delegates `:374-378` | Y | defensive null-def → body cleared with no buttons `map.gd:510-512` — **unreachable through the machine** (event_id from validated pool) | single-surface this round; defensive branch retained (`:527-536`) |
| map | `FACILITY` | `FacilityEnterButton` / `FacilityUseButton` / `FacilityLeaveButton` wired `map.gd:346-348`, synced `:495-510`; deletes to existing handlers `_enter_facility`/`_use_facility`/`_leave_facility` (`:380-398`) | Y | — | landed (touch-reach) + single-surface (FACILITY `▶ `-verb row removed) + button-highlight this round |
| map | arrival dispatch | travel arrival routes to `EVENT` via `_resolve_node_event` (or FACILITY by explicit door); controls as TRAVEL/EVENT rows above | Y | — | covered by `map.facility_buttons` + event scenarios; no change |
| battle | combat (`PLAYER_TURN` / `ENEMY_TURN` / …) | HUD buttons `EndTurnButton` `hud.gd:125`, `AttackButton` `:126`, `UndoButton` `:127`, `PauseButton` `:120`, `SkillButton1..8` (`_populate_skill_buttons` `:506`, inst name `:529`); battle HUD already button-first (focus_mode=FOCUS_NONE per `battle_focus_arrow_keys`) | Y | — | outside this round's scope (already clickable; covered by `battle_end_turn_attack_buttons` / `click_targeting_fixed` / `clicks_only_storyline`) |
| battle | `BATTLE` / `WON` / `LOST` overlay | endgame overlay `ContinueButton` (WON) `game_manager.gd:535-537` + `RetryButton` (LOST) `:549-551`, both `focus_mode=FOCUS_NONE`, pressed → `request_continue` / `request_retry`; re-show re-sync `:473-481`; wired-ness observable `end_overlay_pressed_connected` computed `:569-578` | Y | — | landed (touch-reach); **not touched** this round |
| creation | `ATTRS` | `AttrPlus{i}`/`AttrMinus{i}` ×5 + `AttrBackButton`/`AttrNextButton` — wired `creation.gd:413-432`, `pressed_connected` `:438-453`; already single-surface (`cursor_markers_visible` probe `:70`) | Y | — | already single-surface (precedent); parity check only this round |
| creation | `TRAITS` | `TraitToggle{i}` ×5 + `TraitBackButton`/`TraitNextButton` — wired `creation.gd:418-434`; hover preview `:423-424` | Y | — | already single-surface |
| creation | `CONFIRM` | `ConfirmButton` + `BackButton` (`creation.gd:246-248`, wired `:426`) | Y | — | already single-surface |
| menu | main menu (4 entries) | `MenuEntry0..3` (`ENTRY_COUNT=4` `menu_panel.gd:26`), wired `pressed`→`_activate_entry` `:58-59` | Y | — | already clickable (button-first panel); not touched |
| settings | settings (5 rows) | `Button0..4` (`ROW_COUNT=5` `settings_panel.gd:28`), wired `pressed`→`_activate_row` `:54-59` | Y | — | already clickable (button-first panel); not touched |
| tutorial | steps 1..7 | overlay `Next` + `SkipTutorial` (`tutorial_manager.gd:264-270`), `tutorial_next`/`ui_accept` `:375` | Y | — | already clickable; not touched |
| transition | page 1 / page 2 | `NextButton` (`transition.gd:28-33`, `:63-66`) — **「继续 ▶」 glyph kept**: it is inside the button's own text, one surface, no duplication (see `90_decisions.md`) | Y | — | already clickable; glyph kept (decision); not touched |
| ending | ending (tier 1..3) | `RestartButton` (`ending.gd:25-30`, `:59-62`) | Y | — | already clickable; not touched |

## Unreachable-through-the-machine rows (not touch dead-ends)

Recorded defensively, deliberately **not** rows in the table: `cultivation.gd` `EventData.def(event_id) == null` (`:589-593`) and `map.gd` defensively-cleared EVENT body (`:510-512`) — both render zero controls **only** when handed an unresolvable `event_id`, which the phase machine cannot produce (every `event_id` comes from a validated/deterministic pool draw or binding). The coverage gate never reaches them; the constructors keep the defensive branch so the observable stays truthful.

## Deferred items (→ `design/40_ux_backlog.md`)

No **new** state is deferred: every row above is Y. Two **measure-only** OPEN backlog items
carry over unchanged (measured, not in scope to fix): **UX-12** (residual keyboard-only hint
copy on screens that already have tappable controls) and **UX-11** (touch-target size,
measure-only, no size gate). Both stay OPEN — **not** for lack of gate evidence (this round's
gates are green, 73/73 scenarios PASS) but because closing each needs its own action: UX-11's
touch-target measurement run has not yet been transcribed into the backlog table, and UX-12's
residual keyboard-first copy was explicitly left unfixed this round (`90_decisions.md`
2026-08-30 touch-single-surface (a)). See `design/40_ux_backlog.md` record lines of
2026-08-30 (post-gate 收尾 + 修红实测收口).