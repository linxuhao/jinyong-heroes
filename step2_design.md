# 技术架构设计 — Touch-Reach Main Storyline (Play Full Game Without Keyboard)

**Step 2 — Architect.** Date of record: **2026-08-29**.
Inputs: Project Brief + Project Spec (verbatim conversation), `step1_sota.md` (Researcher, all in-repo facts verified by direct file read), `design/` archive, current repo tree.

Everything in this design is expressed against repo-root-relative paths (implementers write files at exactly these paths).

---

## 1. Overview

The main storyline is **pointer-dead from the tutorial end screen onward**: the tutorial-end overlay is built in code with zero buttons (`scripts/autoload/game_manager.gd::_show_end_game_overlay`, call sites `:194`/`:199`), and five later segment scenes (`transition` / `sect_select` / `cultivation` / `map` / `ending`) are `Backdrop(Panel) + Label` with zero buttons. A phone player can reach WON/LOST and is then stuck on a screen whose only affordance is "按回车继续".

This round is **additive pointer reachability**, designed around the repo's own twice-proven doctrine (*the button is the convergence point; the keyboard degrades to a shortcut calling the same handler*):

1. **Add `Button` nodes** whose `pressed` delegates to the **existing** single-entry handlers (`request_continue` / `request_retry` / `_advance` / `_pick` / `_on_accept` / `_travel` / `_resolve_node_event` / `restart_game`). Zero gameplay/logic change: month advancement, reachability rules, event option effects are untouched.
2. **Re-align exactly one piece of copy** — the overlay strings (`i18n.gd:101/102` + call sites `game_manager.gd:194/199`) — so the prompt describes a real, tappable action. All other keyboard-flavored hint copy becomes a **measurement-only debt** (`design/40_ux_backlog.md`), per the brief.
3. **Prove it with a `clicks:`-only playtest scenario** (no keyboard action anywhere) that boots `main.tscn` and walks menu → creation → tutorial battle → **tutorial end overlay** → transition → sect select → cultivation (36 months) → map → events → ending → restart. It is authored **before** the fixes and must **first run red** at the overlay; the measured first-failure value goes into the report. `playtest/spine_to_ending.yaml` (keyboard proof) is **not touched** and must stay green — this round adds an input path, it does not replace one.

Non-negotiables carried from the brief: playtest contract append-only (surface whitelist only grows); no numeric changes; no engine-level form gates ("has a Button", "size >= 48" are forbidden as gates); click anchors sit on control bodies, never `*_ClickTarget`; new UI copy is Chinese and every new string lands in `scripts/autoload/i18n.gd`'s EN dictionary (`tests/test_i18n_coverage.py` stays green); frozen camera/Coord layers and the just-landed facility files are not touched.

---

## 2. 设计变更 (declared design-doc changes)

This run **is** a design-doc round (acceptance criteria mandate it). `5_design` will apply:

| File | Change |
|---|---|
| `design/30_presentation.md` | New section "指针可达性 (pointer reachability)": every storyline screen must expose a visible, tappable control delegating to the existing handler; **the observation conclusion** — `actions:`-driven key injection (`Input.parse_input_event`) bypasses GUI hit-testing, so a screen with zero clickable controls can pass a key-driven contract; `clicks:` is the true hit test and is the instrument that sees this defect class. Also: the button-delegate doctrine (focus_mode = 0, keyboard stays byte-identical) and "click anchors sit on control bodies" reaffirmation. |
| `design/40_ux_backlog.md` | Two **measurement-only** debts (UX-11, UX-12, `OPEN`, no gate): (i) touch-target sizes of storyline tappable controls at the 960×704 design resolution — measured values + the smallest few, explicitly no threshold; (ii) residual keyboard-only hint copy with line numbers (list in §3.8 below). |
| `design/00_roadmap.md` | Phase 2 (交互) entry updated: the "storyline unreachable by touch" gap closed this round; what remains in Phase 2 is exactly the two measurement debts (no gate). |
| `design/90_decisions.md` | Five adjudications (§8 of this doc): battle-outcome seed in the clicks-only spine; option-button = focus+accept delegation; copy re-align scope; FACILITY phase out of scope; anchors on control bodies. |
| `design/99_changelog.md` | One row dated 2026-08-29. |

No numeric/content/system rule in `10_systems.md` / `20_content.md` / `40_progression.md` changes.

---

## 3. Architecture

### 3.1 Component map (text diagram)

```
                       playtest contract (verification plane)
   playtest/clicks_only_storyline.yaml ── clicks: ──► real GUI hit test (push_error on miss)
        ▲  registered in _common.yaml scenario_order + tests ROUND_SCENARIOS (two-place sync)
        │  static pins: keyboard-free pin + surface contract pin (tests/test_playtest_contract_smoke.py)
        │
   GAME PLANE (all changes additive; keyboard paths byte-identical)
   ┌─────────────────────────────────────────────────────────────────────────────┐
   │ GameManager (autoload)                                                      │
   │   _show_end_game_overlay(): CanvasLayer(50) → Dim(STOP) → Panel → Label     │
   │        → NEW ContinueButton / RetryButton (focus_mode 0, pressed →          │
   │          request_continue / request_retry — the same calls _unhandled_input │
   │          makes; keyboard branch untouched)                                  │
   │   end_overlay_text (:194/:199 literals re-aligned; i18n.gd:101/102 keys)    │
   ├─────────────────────────────────────────────────────────────────────────────┤
   │ Segment screens (scene + script pairs; button pools mirror phase options)   │
   │   transition.tscn/gd      → NextButton            → _advance()             │
   │   sect_select.tscn/gd     → SectButton0..4        → _pick() (focus then)   │
   │   cultivation.tscn/gd     → OptionsBox/CultOptionButton0..N (rebuilt per    │
   │                             render)               → focus var + _on_accept()│
   │   map.tscn/gd             → TravelBox/TravelButton{i}  → focus_id + _travel()│
   │                             EventBox/EventOptionButton{0,1} → event_focus +  │
   │                             _resolve_node_event(); FACILITY phase: NO buttons│
   │                             (frozen facility files — debt recorded)          │
   │   ending.tscn/gd          → RestartButton          → restart_game()         │
   ├─────────────────────────────────────────────────────────────────────────────┤
   │ i18n (scripts/autoload/i18n.gd)                                             │
   │   replace keys :101/:102 with tap-describing copy; add 继续/重试/重新开始     │
   ├─────────────────────────────────────────────────────────────────────────────┤
   │ Guards: tests/test_game_manager_fsm.gd (overlay wiring, headless-safe)      │
   │         tests/test_i18n_coverage.py (unchanged, must stay green)            │
   │         tests/test_playtest_contract_smoke.py (ROUND_SCENARIOS + 2 new pins)│
   └─────────────────────────────────────────────────────────────────────────────┘
   Docs plane: design/30 (reachability), design/40_ux_backlog (2 debts),
               design/00_roadmap (Phase 2), design/90_decisions (5 rulings),
               design/99_changelog (1 row)
```

**Data flow of a tap (the property the gate asserts):** finger/click → GUI hit test picks the topmost non-IGNORE Control at the point → `Button.pressed` → delegate → the **same** function the keyboard shortcut calls → existing state machine advances. The gate is game-level: "the storyline can be traversed with clicks only", never engine-level ("a Button exists").

### 3.2 Component A — end-game overlay buttons (`scripts/autoload/game_manager.gd`)

**Responsibility:** give the code-built WON/LOST overlay two hit-testable, visible controls, without touching the keyboard branch.

**Interface (exact):**

- Inside `_show_end_game_overlay(text)`, after the existing `Panel` + `Label` construction, add:
  - `var continue_btn := Button.new()`; `continue_btn.name = "ContinueButton"`; `continue_btn.text = tr("继续")`; `continue_btn.focus_mode = Control.FOCUS_NONE`; `continue_btn.custom_minimum_size = Vector2(200, 48)`; positioned in the panel's lower band (panel is 500×250; e.g. offsets `(150, 178) .. (350, 226)`); `continue_btn.pressed.connect(request_continue)`; `panel.add_child(continue_btn)`. Also narrow the label's full-rect to the upper band (set `label.offset_bottom ≈ 170`) so text and button do not visually overlap — layout-only, no theme/font changes.
  - `var retry_btn := Button.new()`; `name = "RetryButton"`; `text = tr("重试")`; same focus_mode/size; `retry_btn.pressed.connect(request_retry)`; `panel.add_child(retry_btn)`.
  - Per-state visibility in the **same** function: `continue_btn.visible = current_state == "WON"`, `retry_btn.visible = current_state == "LOST"`.
- **Re-show branch** (`:456-463`, overlay exists): extend the `get_node_or_null` sync to also re-resolve `"Panel/ContinueButton"` / `"Panel/RetryButton"` and re-apply `text`/`visible`. (Today `clear_battle()` frees the overlay on every retry/segment route and `scene_manager.gd:192` teardown frees it on any scene swap, so re-show is rare — but the branch must not silently leave stale buttons.)
- **New surface observable:** `var end_overlay_pressed_connected: Dictionary = {}` on GameManager, updated in both branches: `{"ContinueButton": continue_btn.pressed.is_connected(request_continue), "RetryButton": ...}`. Whitelisted in `_common.yaml`.
- **Call-site copy** (`:194` / `:199`) and **i18n keys** (`i18n.gd:101/102`) change together (two-sided edit; see §3.7).
- **Keyboard branch `_unhandled_input` (`:515-523`) stays byte-identical.** Only its stale comment ("no focusable controls") is refreshed: the new buttons are `focus_mode = FOCUS_NONE`, so keyboard events still reach `_unhandled_input` untouched.

**Double-fire analysis (must survive review):** a `Button` only activates on `ui_accept` when it *has focus*; `FOCUS_NONE` means it can never grab focus, so `ui_accept` cannot reach the button — exactly one dismissal per key press, via `_unhandled_input` as today. Mouse clicks reach only the button. `request_continue` / `request_retry` already guard on `current_state` (`!= STATE_WON` / `!= "LOST"` → no-op), so even a double delivery cannot advance two segments. This is the same shape the HUD/creation buttons already ship (`focus_mode: 0` is asserted in `playtest/undo_button_retreat.yaml`).

**Overlay lifetime (verified this step):** `request_retry()` and any scene swap (`scene_manager.gd:192` → `GameManager.clear_battle()`) free the overlay, so a stale clickable button never lingers over a later screen. The tutorial WON path (`battle_return_state == "TUTORIAL"`) frees nothing in `request_continue` itself, but the TRANSITION scene swap it triggers runs the teardown that frees the overlay — no dead button over the next screen.

### 3.3 Component B — five segment screens (`scenes/segments/*.tscn` + `scripts/segments/*.gd`)

**Shared shape (per screen):** buttons live in the scene as siblings **after** `Backdrop` (topmost-first picking → buttons win; `Backdrop` gets `mouse_filter = 2` where missing — presentation-layer hygiene mirroring `map.tscn`, not a gate). Every button: global theme (fonts come free), `focus_mode = FOCUS_NONE` (no focus stealing, no double-fire), `pressed.connect(<delegate>)`. Screen scripts gain one observable:

```gdscript
## Surface: button name -> pressed-signal wired (mirror of CreationScreen.pressed_connected).
var pressed_connected: Dictionary = {}
```

(static screens set it in `_ready`; cultivation/map re-sync it whenever they rebuild their pools).

| Screen | Nodes to add | Delegate (existing code, unchanged) | Notes |
|---|---|---|---|
| `transition` | `NextButton` (text `tr("继续 ▶")` — key exists) | `if not done: _advance()` (mirror of the `_unhandled_input` body incl. the `SceneManager.pending_swap` guard inside `_advance`) | `visible = not done`, synced in `_render()` |
| `sect_select` | `SectButton0..4` (labels = `tr(display_name)` of `ProgressionGongfaData.SECTS`, set in `_render()`) | `_on_sect_pressed(i: int)`: `focus_index = i; _render(); _pick()` | exactly 5, static; `_pick()`'s own guards (`selected_sect_id != ""`, `pending_swap`) still apply |
| `cultivation` | `OptionsBox` (VBoxContainer in .tscn, right of/below `BodyLabel`); script **rebuilds** its children each `_render()` as `CultOptionButton{i}` | `_on_option_pressed(i: int)`: set the phase's focus var (`_card_focus` / `_action_focus` / `_gongfa_focus` / `_attr_focus` / `_event_focus` / `_year_choice` / `_switch_focus`) to `i`, then call the existing `_on_accept()` | see pool spec below |
| `map` | `TravelBox` → `TravelButton{i}` per neighbor; `EventBox` → `EventOptionButton0/1` | `_on_travel_pressed(i)`: `focus_id = MapData.neighbors(current_node_id)[i]; _travel()`; `_on_event_option_pressed(i)`: `event_focus = i; _resolve_node_event()` | boxes visible **only** in their phase (mirror `_apply_hint_visibility()`); **FACILITY branch untouched** (frozen files) |
| `ending` | `RestartButton` (text `tr("重新开始")`) | `_on_restart_pressed()`: `if done: return; done = true; if not SceneManager.pending_swap: GameManager.restart_game()` | mirror of the `_unhandled_input` body |

**Cultivation pool spec (the only nontrivial one):**

- In `_render()`, rebuild `OptionsBox` children (free + recreate — pools are ≤ ~10 nodes, renders are event-driven; HUD's per-setup skill-button rebuild is the precedent): one `CultOptionButton{i}` per option of the current phase, labeled from the **same** strings the `BodyLabel` branch renders (card names, action verbs 功法/属性/打工/游历/保存/读取/删除, event option labels, sect rows, year choices) — every label via `tr()`; hide the box entirely in phases with no options (e.g. `GONGFA_PICK` when `_unmastered_ids()` is empty — the keyboard path auto-returns to `ACTION_PICK` there; a player picks another action).
- Delegation is exact: keyboard play is "cycle focus, then accept"; a click is "set that focus, then accept" — one handler, two triggers, zero forked logic. `_on_accept()`'s own `_delete_armed = false` and per-phase guards stay authoritative.
- Buttons per phase: `YEAR_AUGMENT`/`CARD_PICK` 3, `ACTION_PICK` 7, `GONGFA_PICK` dynamic (unmastered ids), `ATTR_PICK` 5, `EVENT` 2, `YEAR_END` 2, `SECT_SWITCH` 5.
- **No 「推进一个月」 extra control is needed**: the month advances through the *existing* path (`card pick → action pick`), and the deterministic click loop is 2 clicks/month (see §4 skeleton) — the mitigation the reviewer suggested is unnecessary at the measured frame budget, and omitting it avoids inventing a verb the screen never had.

**Determinism guards:** option *texts* vary per month (card draws) but the scenario anchors **node names**, never texts; assert blocks pin phase/year/month ladders only (structural facts, precedent: `spine_to_ending` asserts `year: 1` / `month: 1`), never card contents or attribute values.

### 3.4 Component C — i18n (`scripts/autoload/i18n.gd`)

Two-sided edit rule (the dict key **is** the literal Chinese string): change call site + key + EN value together, or the lookup silently falls through to raw Chinese. Exact strings:

```gdscript
# :101/:102 replaced in place (keeps 胜利/战败 tokens the FSM test + spine assert on; no ellipsis):
"胜利！华山论剑的胜者！\n\n点击「继续」进入江湖":
    "Victory! Champion of the Duel at Mount Hua!\n\nTap Continue to enter the jianghu",
"战败于华山论剑\n\n点击「重试」再战":
    "Defeated at the Duel at Mount Hua\n\nTap Retry to fight again",
# new button labels:
"继续": "Continue",
"重试": "Retry",
"重新开始": "Restart",
```

Before deleting any old key, grep for other call sites (the two old overlay strings are used only at `game_manager.gd:194/199`; `按回车继续` at `:343` is a *different* key and stays this round — it is debt, not in scope). All other new labels reuse existing keys (`继续 ▶`, sect display names, node display names, event option labels, action verbs) — implementer greps each; any literal that turns out unkeyed gets an EN entry. Discipline: never assign a raw Chinese literal via `.text =`; go through `tr()`. `tests/test_i18n_coverage.py` (scene `text=`, `tr()` sites, `.text =` direct assignment) is the gate that keeps this honest and must stay green.

### 3.5 Component D — playtest scenario `playtest/clicks_only_storyline.yaml`

One new file, `name:` == basename, `scene:` inherited (`res://scenes/main.tscn`), **zero keyboard actions**. Allowed non-click timeline action: **only** `debug_win_tutorial` (the documented battle-outcome seed — the same instrument the keyboard spine uses at f20; it is an unbound DEBUG action consumed in `_process`, not a keyboard input; the battle *screen's* clickability is separately proven by `battle_end_turn_attack_buttons`, `click_targeting_fixed`, `undo_button_retreat`, `click_portrait_body_targets_enemy`, plus an in-scenario real click on `AttackButton` below). The scenario header documents this adjudication and reserves a "RED-FIRST EVIDENCE" block for the measured first failure.

Skeleton (frame numbers indicative ±; final values are the implementer's, subject to: every `at:` a single integer, **last assert ≤ 2900**, asserts operator-or-`changed`, differential/relational game-level values only — no absolute game numbers beyond structural ladders already precedented like `month`/`events_resolved_count`):

```yaml
# MENU → CREATION (clicks)
- {at: 10,  clicks: [MenuEntry0]}                       # 新的冒险
- {at: 30,  assert: CHARACTER_CREATION; CreationScreen.visible; AttrNextButton liveness}
- {at: 40,  clicks: [AttrNextButton]}                   # ATTRS → TRAITS
- {at: 55,  clicks: [TraitNextButton]}                  # TRAITS → CONFIRM
- {at: 70,  clicks: [ConfirmButton]}                    # → TUTORIAL (battlefield)
# TUTORIAL BATTLE — screen click-path proof + documented outcome seed
- {at: 110, assert: BATTLE; HUD 4 buttons liveness (visible/size/mouse_filter)}
- {at: 120, clicks: [AttackButton]}                     # real click; out-of-range reject is harmless
- {at: 130, actions: [debug_win_tutorial]}              # the ONE non-click action (seed)
# TUTORIAL END OVERLAY — the nail
- {at: 150, assert: current_state == "WON"; end_overlay_text contains 胜利;
            ContinueButton.visible/size/mouse_filter==0/focus_mode==0}
- {at: 160, clicks: [ContinueButton]}                   # ← first-red frame lives here
- {at: 190, assert: TRANSITION; NextButton liveness}
- {at: 200, clicks: [NextButton]}                       # page 1 → page 2
- {at: 220, clicks: [NextButton]}                       # → SECT_SELECTION (creation_done == true)
- {at: 250, assert: SECT_SELECTION; SectButton0 liveness}
- {at: 260, clicks: [SectButton0]}                      # → CULTIVATION
- {at: 300, assert: CULTIVATION year 1 month 1 phase CARD_PICK; CultOptionButton0 liveness}
# 36-MONTH LOOP (uniform: CultOptionButton0 = card/year-augment/year-end-stay,
#                CultOptionButton2 = work → month advances through the existing path)
#   per month: clicks [CultOptionButton0] at f, [CultOptionButton2] at f+3
#   year ends (m12 work click lands in YEAR_END): extra click CultOptionButton0 (留在本门)
#   year starts y2/y3 (YEAR_AUGMENT): extra click CultOptionButton0
#   assert checkpoints at m2 / y2m1 / y3m1 / m36: phase + year + month ladders only
#   ≈ 78 clicks ≈ 320 frames incl. checkpoints
# MAP (reached automatically after month 36's action resolves → _finish_to_map)
- {at: ~1150, assert: MAP; phase TRAVEL; TravelButton0 liveness}
- travel legs: click TravelButton{i} → arrival opens EVENT (assert event_id/current_node_id)
-   → click EventOptionButton0 → assert TRAVEL + events_resolved_count ladder (== 1/2/3)
-   legs: 无名谷→洛阳(merchant)→武当(quanzhen_scripture)→襄阳(dragon_scrap)→昆仑 (endpoint
-   routes to ENDING before any entry event — no event click at kunlun; index resolved from
-   MapData.neighbors order, the current_node_id assert makes a wrong index an honest red)
- {at: ~1500, assert: ENDING; tier >= 1 and tier <= 3; RestartButton liveness}
- {at: 1510, clicks: [RestartButton]}
- {at: 1550, assert: current_state == "TUTORIAL"}        # storyline closed by taps; ≤ 2900
```

Budget: ≈ 90 clicks × ~3–4 frames + ~15 assert blocks ≈ **1500–1700 frames** — comfortably inside the 2900 spine cap; no screen is left undriven, so no escape hatch is exercised (if the real run proves otherwise, the brief's rule applies: report the screen + reason, never inject `ui_accept`).

**LOST/RetryButton click path:** proven at unit level (`tests/test_game_manager_fsm.gd` asserts both buttons exist/visible/wired in headless mode and that the retry delegate lands in `request_retry`) plus the untouched keyboard scenario `tutorial_loss_restarts_tutorial` keeps LOST routing green. A second playtest scenario for it was considered and cut: same code shape as the WON button, marginal gate value, extra registry surface.

### 3.6 Component E — contract registry + pins (`playtest/_common.yaml`, `tests/test_playtest_contract_smoke.py`)

1. **Two-place sync (append-only):** `playtest/clicks_only_storyline` appended at the tail of **both** `_common.yaml::scenario_order` and `ROUND_SCENARIOS` in `tests/test_playtest_contract_smoke.py` (the existing `test_round_scenarios_present_on_disk_and_in_order` enforces the pairing; `test_timeline_at_values_are_integers` auto-covers the new file).
2. **Surface whitelist additions (append-only, adds never remove):**
   - New blocks: `ContinueButton`, `RetryButton`, `NextButton`, `SectButton0`, `CultOptionButton0`, `CultOptionButton2`, `TravelButton0`, `EventOptionButton0`, `RestartButton` — each `[visible, size, mouse_filter, text]` (overlay buttons additionally `disabled, focus_mode`).
   - Existing blocks grow by one var each: `TransitionScreen`, `SectSelectScreen`, `CultivationScreen`, `MapScreen`, `EndingScreen` get `pressed_connected`; `GameManager` gets `end_overlay_pressed_connected`.
3. **New pin `test_clicks_only_storyline_is_keyboard_free`** (stdlib parse of the scenario file, family of `test_facility_use_reusable_surface_contract`): every timeline `actions:` list may contain only `debug_win_tutorial`; the file must contain ≥ 5 `clicks:` entries; no clicks token may end in `_ClickTarget`. Failure message is **self-explaining** per the 2026-08-29 `30_presentation.md` rule: name the correct fix ("if you are legitimately changing the seed or adding a non-keyboard action, update this pin in the same change — do not delete the pin to go green, and never smuggle in `ui_accept`/`tutorial_next`/`move_*`/`skill_*`/`end_turn`/`attack_confirm`/`pause_game`/`use_facility`").
4. **New pin `test_touch_reach_surface_contract`:** the nine new surface blocks + five `pressed_connected` additions exist in `_common.yaml`.
5. **Stale-doc fix (reviewer suggestion):** correct the `_common.yaml` clicks-grammar example (`~L55`) from `Central_Divine_ClickTarget` to the unit-body anchor (`Central_Divine +0,0`), citing the 2026-08-29 `90_decisions.md` ruling — the new scenario's author reads this file first.
6. **Untouched:** `spine_to_ending.yaml`, `tests/fixtures/playtest_assert_superset.json` (its `baselines` key-set check still passes), all frozen camera/visibility scenarios, all facility files.

### 3.7 Component F — unit guard (`tests/test_game_manager_fsm.gd`)

Extend the overlay test (headless `-s` safe — `Button.new()` + `add_child` + `connect` create no scene-tree dependencies): after `end_battle(true)`, assert the overlay contains `Panel/ContinueButton` with `visible == true`, `focus_mode == 0`, `pressed.is_connected(request_continue)`, and `RetryButton` hidden/wired to `request_retry`; mirror after `end_battle(false)`; assert `end_overlay_pressed_connected` values; keep the existing 胜利/战败/no-ellipsis text pins (they stay green under the new copy). Registered in `tests/unit_test_runner.gd`'s suite list as today (same file extended, no new runner entry).

### 3.8 The two measurement debts (data for `design/40_ux_backlog.md`)

**UX-11 (measurement-only, no gate): touch-target sizes.** After the gate run, transcribe each storyline control's `get_global_rect().size` at the 960×704 design resolution (physical size on a phone = design px × content-scale factor) into the backlog row; call out the smallest few (expected: creation `AttrPlus{i}`/`TraitToggle{i}` and the new option buttons). Platform reference points for the record only: Material 48 dp / HIG 44 pt / WCAG 2.5.8 24 px. Asserting a threshold is forbidden (engine-level form gate).

**UX-12 (measurement-only, no gate this round): residual keyboard-only hint copy with line numbers.** Baseline (verified in step 1; re-verify line numbers when transcribing): `i18n.gd:338` + `:339` (ending restart), `:343` (transition), `:348` (sect join), `:353` (map travel), `:358` (event decide), `:367` (facility use/leave), `:369` (facility F-hint — no F on touch), `:111` (tutorial intro names 回车 alongside the existing 继续 button), and scene-file literals `transition.tscn:48`, `sect_select.tscn:46`, `cultivation.tscn:46`, `ending.tscn:46` (+ `scripts/segments/sect_select.gd:56` body tail). After this round each of these screens *has* a control; the copy still names only the keyboard route — recorded as the remaining copy-alignment debt, explicitly not fixed this round (scope = overlay `:101/102` only, per the brief).

---

## 4. Task decomposition proposal (ordered; the red-first ordering is binding)

1. **T1 — nail authored, first red.** Write `playtest/clicks_only_storyline.yaml`, `_common.yaml` surface additions + `scenario_order` append, both smoke pins, and the `_common.yaml` L55 doc fix. Run the playtest gate. **Expected red:** at the f150 block — `ContinueButton` unresolvable (harness `push_error` at aim) and/or the pre-click liveness asserts failing on a missing node, with `current_state == "WON"` where the overlay click was meant to advance. Record the measured value (failing frame, first failing assert line, exact error string, green-assert count before red) into the scenario header + the report.
2. **T2 — overlay.** Component A + i18n keys + FSM unit extension. Overlay leg turns green; `tutorial_win_routes_to_transition` / `tutorial_loss_restarts_tutorial` (keyboard) must stay green untouched.
3. **T3 — transition + sect_select.** Component B rows 1–2 (+ Backdrop `mouse_filter = 2`).
4. **T4 — cultivation.** Component B pool (biggest single piece).
5. **T5 — map.** Travel/Event boxes; FACILITY branch byte-untouched.
6. **T6 — ending.** RestartButton.
7. **T7 — full regression gate.** All scenarios green (incl. `spine_to_ending` 42/42), 0 runtime errors, hard gates `passed: true`, GDScript unit suite green, compile 0 errors, `test_i18n_coverage.py` + `test_playtest_contract_smoke.py` green.
8. **T8 — docs.** All `design/` updates (§2), including UX-11 measured values and UX-12 line-number audit transcribed from the T7 run; changelog row dated 2026-08-29; decisions into `90_decisions.md`.

Rollback: pure file edits in git, no data migration; contract changes are append-only so a revert restores the previous contract byte-for-byte. No irreversible operation is designed.

---

## 5. Tech stack (unchanged; nothing new to install)

Godot 4.4 / GDScript; `Button` + `pressed` delegates; scene files as diffable text; the external `aitelier/tools/godot_playtest/impl.py` harness (`clicks:` true hit test, `push_error` hard-red); stdlib pytest smoke pins; existing `global_theme.tres` + NotoSansSC (no art assets, no engine config, no touch-emulation change). Rejected alternatives and why (from step 1, ratified): tap-anywhere hot-zone (full-rect STOP footgun, cannot express N destinations), Godot focus/`ui_accept` (collapses click and keyboard routes — reopens the observation gap), `_input` mouse route (not per-control hit-testable), `TouchScreenButton`/touch emulation (changes semantics for ~70 scenarios), `AcceptDialog` (new visual idiom + focus/modal behavior), `_draw()` pseudo-buttons (invisible to the hit test).

---

## 6. Invariants & risk register

1. **Additive, not replacement.** Every `_unhandled_input`/`_process` keyboard branch byte-identical; buttons delegate to the same handlers; `spine_to_ending.yaml` untouched and green.
2. **No double-fire.** `focus_mode = FOCUS_NONE` everywhere; state guards in `request_continue`/`request_retry`/`_pick`/`ending` are the second net.
3. **Hit-test ordering.** Overlay: Dim(STOP) → Panel → Label → buttons (buttons last = topmost). Segments: buttons as siblings after `Backdrop`; decorative full-rect hosts get `mouse_filter = 2`; no new full-rect STOP nodes are introduced (`test_every_full_rect_host_is_click_through` family stays meaningful).
4. **Dynamic pools.** Rebuilt per render; unused buttons never linger (a hidden-but-anchored button is an honest red — that is the gate working).
5. **Frame budget.** ≈1500–1700 frames, last assert ≤ 2900; cultivation loop uses only advancing actions (work) so no phase can stall the loop (empty `GONGFA_PICK` never entered).
6. **Frozen surfaces.** No edits to `scripts/camera_follower.gd`, `scripts/coord.gd`, `ink_world_dx/dy`, `camera_offset_y`, `camera_transform_follows_unit.yaml`, `portrait_grid_alignment.yaml`, facility files, or any existing scenario's `at:` frames.
7. **Gate discipline.** Assertions are game-level and differential/relational (state strings, `changed`, ladders `== 1/2/3`, `tier >= 1 and tier <= 3`); no "must contain a Button" form gate, no size gate, no absolute game values.
8. **Copy discipline.** Chinese UI copy; every new literal keyed in the EN dict; two-sided edits; no ellipsis anywhere (repo-wide rule, FSM test polices the overlay).
9. **Environment caveat.** The harness lives outside the repo (sidecar image); before believing any red, confirm the image is fresh (a new surface var can report "unknown key" rather than a game defect).

---

## 7. Extensibility

- The option-pool pattern (`OptionsBox` rebuild mirroring phase options) generalizes to any future dynamic menu (event pool growth, new map nodes) without new machinery.
- Because the gate is game-level ("traverse with clicks only"), a future round may legitimately replace buttons with gestures/hot-zones/self-drawn controls without touching the scenario — exactly what a form gate would have broken.
- UX-11/UX-12 are closeable by a later round by the backlog's own rules (close = an action with evidence, not an inference).

---

## 8. Decisions requiring `design/90_decisions.md` entries (with rationale)

(a) **Battle-outcome seed in the clicks-only spine.** `debug_win_tutorial` is allowed as the single non-click action: the battle screen's clickability is proven by four existing click scenarios plus an in-scenario `AttackButton` click; a full click-fought battle cannot fit the frame cap, and the alternative (splitting the spine) would leave "overlay → … → ending reachable by taps" unproven in one run. The seed is documented in the scenario header and the report.
(b) **Option buttons = focus + accept delegation.** No forked click logic; keyboard branches untouched; this is what makes "adds, not replaces" true by construction.
(c) **Copy re-align scope = overlay only** (`i18n.gd:101/102` + `game_manager.gd:194/199`); all other keyboard-flavored hints become the recorded UX-12 debt — per the brief's explicit split.
(d) **FACILITY phase gets no buttons this round** (frozen facility files); its keyboard-only panel is recorded in UX-12.
(e) **Click anchors on control bodies** reaffirmed for all new buttons (no `*_ClickTarget`); `_common.yaml`'s stale example is corrected in the same change.

---

## 9. Acceptance-criteria mapping

| Criterion | Where satisfied |
|---|---|
| Visible tap-control on every storyline screen | Components A + B (six work sites; menu/creation/HUD/tutorial-overlay already have buttons) |
| Overlay fixed + `i18n.gd:101/102` aligned | Component A + C |
| Keyboard path not regressed; `spine_to_ending.yaml` green untouched | §6.1; T7 |
| New clicks-only scenario green, zero keyboard actions, first-red measured | Component D + E pins; T1 evidence block |
| Measurement debts recorded (sizes; residual copy + line numbers) | §3.8 → `design/40_ux_backlog.md` |
| Docs updated (30/40/00/90/99) | §2 |
| All gates: playtest green + 0 runtime errors + hard gate true; unit suite; compile 0; i18n coverage + contract smoke green | T7 |
