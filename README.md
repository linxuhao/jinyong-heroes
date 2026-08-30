# jinyong — Wuxia Crossover Tactics (Godot 4)

**▶ Play it in your browser: https://linxuhao.github.io/jinyong-heroes/**
(中文/English — auto-detected from your browser language, switchable in 设置/Settings)

A time-scrambled wuxia world: characters, sects and martial arts from different
parallel timelines collide in one jianghu. This is a fan-crossover brawler, not
a recreation of any single novel. You create your own nobody, borrow the fully
mastered body of Yang Guo for a tutorial duel against the Five Masters on
Mount Hua's summit, then fall from the sky, receive a chance to join a great
sect, spend three in-game years (36 cultivation periods) training, and finally
walk the jianghu map to an ending (`design/00_overview.md`).

Visuals use **placeholder art** (96×128 portraits on 64 px tiles are the frozen
art contract). UI text is Chinese, rendered with the bundled NotoSansSC font
(SIL OFL, see `assets/fonts/LICENSE_OFL.txt`). The project is at roadmap
stage 3 (game content); the board's visibility belongs to a **following
camera**, and sprites only stand on their own tiles.

## Latest round: jinyong-roster — the roster panel: what you own, finally visible (taps only)

Everything the profile already stored but nothing ever rendered — five
attributes, silver, innate traits, current year/month and sect, every learned
gongfa (grade / practice / mastered), and every inventory item resolved to its
Chinese name — is now one tap away.

**What landed:**

- **`RosterOpenButton`「角色」** (top-right, `focus_mode = 0`) in BOTH stable
  segments — `scenes/segments/cultivation.tscn` and `scenes/segments/map.tscn`
  each instance `scenes/ui/roster_panel.tscn` as a node named `RosterPanel`.
  `scripts/ui/roster_panel.gd` reads `SaveManager.profile` and writes nothing:
  open/close never autosave, never consume a month or action, never touch a
  phase (each host's `_unhandled_input` gates on `RosterPanel.is_open`).
- **The panel** is a centered read-only box over a tap-outside dim layer:
  「人物」 (根骨/内力/身法/悟性/福缘, 银两, 先天特质, 第 N 年 N 月, 门派),
  「功法」 (per art: name, grade, 练度 practice/cap from
  `ProgressionGongfaData.PRACTICE_TO_MASTER`, 大成 marker), and 「物品」 (each
  `profile.inventory` id through the frozen `CardData.display_name_of`; an
  unknown id degrades lazily to the raw id — never a crash, never a
  `push_error`; empty sections render 「（无）」). Close via the 「关闭」
  button or by tapping outside. The panel has zero internal selectables, so it
  publishes `cursor_markers_visible == false` exactly like every segment.
- **Contract (append-only)**: four `Roster*` surface blocks in
  `playtest/_common.yaml`; two new scenarios at the `scenario_order` tail
  (73 → **75**) mirrored in `tests/test_playtest_contract_smoke.py::ROUND_SCENARIOS`;
  GDScript unit pins in `tests/test_roster_panel.gd` (compose purity, item
  name resolution, unknown-id degradation, honest empty states, read-only
  `to_dict()` invariance); every new string in the `scripts/autoload/i18n.gd`
  EN dictionary.
- **The correspondence nail, MEASURED red-first** (TEMPORARY RED-FIRST REVERT
  applied to `roster_panel.gd open()`, direct sidecar run, restored
  byte-identical): failing frame **f70**, first failing assert
  **`RosterPanel.is_open: is_open == true`**, exact error
  **`FAIL f70 RosterPanel.is_open: is_open == true` / `observed=false`**,
  **8** green asserts before red. The nail drives the REAL grant path (map
  `merchant` event → `EventLogic.apply_option_effects` → `eq_sword_3`
  青锋剑) and then clicks the panel open and asserts 「青锋剑」 inside
  `RosterBodyLabel.text`.
- **Design record**: `design/30_presentation.md` (roster panel section),
  `design/90_decisions.md` (seven rulings a–g), `design/40_ux_backlog.md`
  (UX-13 no-`equipped` field / UX-14 §9 loadout promise vs auto-equip — both
  OPEN, record-only), and the `design/99_changelog.md` `roster_panel` row.

**Honest status: the two new scenarios are NOT yet green on this tree**
(measured sidecar runs, 2026-08-30 — see "Verification status (honest)"
below): `roster_panel_item_nail` **35/36** (red at f110
`MapScreen.silver: changed` — a fresh boot has silver 0 and the merchant's
option_a is silver −20, clamped to 0, so silver never changes; the 青锋剑 pin
itself measured green) and `roster_panel_cultivation_open_close` **15/16**
plus **6 runtime errors** (red at f110 `CultivationScreen.month: changed` —
`debug_step_month` is gated on `GameManager.current_state`, which a direct
scene boot does not set, and the documented clicks-only fallback was not
implemented; the runtime errors are `Invalid access … 'economy' /
'equipment' / 'growth'` at `save_manager.gd:365/:382`). No official
75-scenario gate run exists yet; the 75 in the counts below is the
`scenario_order` registry count, not a gate-measured green count.

## Round: touch-single-surface — buttons are the option list, every state has a tappable exit (previous round)

The touch-reach round gave every screen a button; player feedback (2026-08-30)
then showed the screens were *doubled*: the same option list rendered twice (a
`▶` cursor text row in `BodyLabel` **and** an identical row of buttons), and
one state had a button count of zero — `GONGFA_PICK` with no unmastered art
hid its whole button box, leaving Enter (`_on_accept`'s empty branch) as the
only exit. On a phone there is no Enter.

**What landed (keyboard branches byte-identical; clicks delegate to the same
handlers; no art assets; `focus_mode = FOCUS_NONE` kept):**

- **One surface, one rendering** — `cultivation.gd` / `map.gd` /
  `sect_select.gd` no longer print option rows (or the `▶` cursor) into
  `BodyLabel`; the button pool is the only option list. Descriptive text
  (event title/prose, facility cost summary, the map overview node list, stats
  header, sect info lines) is untouched. Selection lives **on the button**: the
  focused row is full-bright `modulate`, the rest dimmed (the creation.gd
  precedent) — arrow keys still move the focus var and the highlight follows
  (`map.gd:483/:494/:505/:510`, `sect_select.gd:84`, `cultivation.gd`
  `_rebuild_options_box`). `creation.gd` was already single-surface (parity
  check only). The transition screen's 「继续 ▶」 glyph stays: it lives inside
  the button's own text — one surface, no duplication (recorded in
  `design/90_decisions.md`).
- **GONGFA_PICK empty-list exit** — with no unmastered art the box builds one
  「返回行动」 button (`cultivation.gd:572-576`) whose press walks the SAME
  `_on_option_pressed → _on_accept` chain every other option uses (the existing
  empty branch `:235-238` returns to `ACTION_PICK`; no forked phase logic).
  The on-screen hint states the way out (「暂无未大成武功。点击「返回行动」
  回到本月行动。」), and the self-justifying comment at the old
  `cultivation.gd:529` is rewritten to describe the actual guarantee: every
  player-choice phase leaves the box with ≥ 1 visible, wired button.
- **New observables** (`playtest/_common.yaml` surface, only-add):
  `cursor_markers_visible` (false ⇒ no `▶` anywhere in the rendered body) on
  cultivation / map / sect_select, plus `option_focus` /
  `focused_option_text` on cultivation.
- **The clicks-only nail** — `playtest/clicks_only_gongfa_empty_exit.yaml`
  seeds a fresh no-sect save (the one sanctioned debug seed), loads it by
  CLICKING the menu's 读取存档 entry, then clicks-only through card → 练功 →
  the empty `GONGFA_PICK` (exactly one 返回行动 button, wired, no `▶`),
  clicks it, and asserts `CultivationScreen.phase == "ACTION_PICK"` — the
  phase really changed; a merely-present button would not satisfy it.
  Registered two places (`_common.yaml::scenario_order` tail +
  `ROUND_SCENARIOS` tail) with a new keyboard-free smoke pin; keyboard twin
  `gongfa_pick_empty_keyboard_return.yaml` pins the Enter path of the same fix.
- **Property-based coverage gate** — `tests/test_touch_option_surface_gate.gd`
  (SceneTree script; auto-discovered by `run_tests.sh`'s sidecar scan) drives
  the cultivation / map / sect_select phase machines through their OWN handlers
  and asserts every reached player-choice phase produced ≥ 1 visible, wired
  control and no `▶` marker — not a literal phase-name list. A future phase
  with zero buttons reds the gate with a self-explaining message; the EXEMPT
  table (no-input states only, with its rule text) lives inside the gate.
- **Copy guard maintained, not dodged** (round-owner-granted scope):
  `tests/test_facility_copy_location.py` now detects `tr()` call-site keys
  structurally (`_tr_call_literals`), the map-chrome ALLOWED entries are
  emptied, and the shortened map copy keys land in the same commit as their
  slot-matched `i18n.gd` EN values. No wording was chosen for its CJK count.
- **Design archive**: new `design/31_touch_coverage.md` (every segment × phase
  with file:line — every touch-only exit Y; defensive unreachable zero-button
  branches recorded, not treated as dead-ends); rule (g) in
  `design/30_presentation.md`; the round's rulings in
  `design/90_decisions.md`; the `design/99_changelog.md` row; the
  `design/40_ux_backlog.md` record (UX-11 / UX-12 stay OPEN, nothing newly
  deferred).
- **Tails corrections** (carried over card): the Q6 clause below now carries
  the measured values (good_answers 71 / bad_answers 0 — nothing parked), and
  `final/delivery_notes_touch_reach_walkthrough.md` points at
  `final/delivery_notes_touch_reach_red_first.md` for the authoritative
  measured first-red values while keeping the f180/5 prediction as the
  prediction-vs-measurement record.

**The visibly-fixed dead end:** enter 养成 → tap 练功 with no trainable art →
【练功】 shows one 返回行动 button → tap it once → back at 本月行动 → keep
playing. Zero keyboard.

## Round: touch-reach — the whole storyline is playable with taps only (previous round)

A real player (2026-08-29) hit a wall at the end of the tutorial: 「玩完需要回车继续，
但是我在手机上没有回车」. Investigation showed it was not one missing button — the
main storyline was **pointer-dead from the tutorial-end screen onward**. The
tutorial-end overlay is built in code (`GameManager._show_end_game_overlay`:
CanvasLayer + dim + Panel + Label, zero Buttons), and the five later segment
scenes (`transition` / `sect_select` / `cultivation` / `map` / `ending`) were
`Backdrop + Label` with zero Buttons. This stayed invisible to a 69/69-green
playtest contract because `actions:` key injection (`Input.parse_input_event`)
feeds `_input` directly and **bypasses GUI hit-testing** — a screen with zero
clickable controls still passes a key-driven scenario (same root as the recorded
SegmentHost full-rect swallow). This round closes both halves of that: the
missing controls, and the observation gap that hid them.

**What landed (additive only — every keyboard branch byte-identical; every new
button delegates to the same handler the key shortcut calls; no `*_ClickTarget`
anchors; no art assets; `focus_mode = FOCUS_NONE` everywhere so no double-fire):**

- **Tutorial-end overlay** (`scripts/autoload/game_manager.gd`): the code-built
  overlay now also builds `Panel/ContinueButton` and `Panel/RetryButton`
  (`pressed → request_continue` / `request_retry`, per-state visibility, synced
  in both the construction and the re-show branch). The prompt copy now
  describes a real, tappable action — 「胜利！华山论剑的胜者！点击「继续」进入江湖」 /
  「战败于华山论剑 点击「重试」再战」 — with the call-site literals and the
  `i18n.gd` EN-dictionary keys changed together (the old 「按回车…」 keys were
  used nowhere else).
- **transition**: `NextButton` → `_advance()` · **sect_select**: `SectButton0..4`
  → `focus_index` + `_pick()` · **cultivation**: an `OptionsBox` whose
  `CultOptionButton{i}` pool is rebuilt each render to mirror the current
  phase's options → set the phase's focus var + `_on_accept()` (one handler,
  two triggers; month advancement / gongfa / attr / event logic untouched) ·
  **map**: `TravelButton{i}` → `focus_id` + `_travel()`, `EventOptionButton0/1`
  → `event_focus` + `_resolve_node_event()`, and three **facility delegate
  buttons** `FacilityEnterButton` / `FacilityUseButton` / `FacilityLeaveButton`
  → the existing `_enter_facility()` / `_use_facility()` / `_leave_facility()`
  (delegation only — facility semantics, the F-key gate and the data modules
  are byte-untouched, per the two-outcome protocol in `design/90_decisions.md`) ·
  **ending**: `RestartButton` → `restart_game()`.
- **New surface observables**: `GameManager.end_overlay_pressed_connected`
  (both overlay buttons' wiring, refreshed in both branches) and
  `pressed_connected` on all five previously button-less segment screens —
  the click gate proves hittability for the buttons the route reaches;
  `pressed_connected` proves wiring for **every** button (e.g. `RetryButton`,
  which no WON run clicks).
- **The nail**: `playtest/clicks_only_storyline.yaml` walks the whole storyline
  — menu → creation → tutorial battle → **tutorial-end overlay** → transition →
  sect select → 36-month cultivation → map → events → ending → restart — with
  `clicks:` only (true GUI hit-testing; a screen without a hittable control is
  a hard red, never a silent skip). It contains **zero keyboard actions**: every
  timeline `actions:` entry is empty except one `debug_win_tutorial` battle
  outcome seed (an unbound DEBUG action consumed in `_process`, the same seed
  the keyboard spine uses; adjudicated in `design/90_decisions.md` (a)). The
  battle screen's own clickability is separately proven by
  `battle_end_turn_attack_buttons` / `click_targeting_fixed` /
  `undo_button_retreat` / `click_portrait_body_targets_enemy` plus an in-scenario
  real click on `AttackButton`.
- **Companion scenario**: `playtest/map_facility_buttons_click.yaml` proves the
  three facility delegate buttons by clicks while `facility_use_reusable.yaml`
  stays byte-untouched.
- **The clicks-only path paid for itself twice**: aligning it to screen-ready
  timing re-projected every `at:` frame and grew the tutorial-intro leg to 7
  `Next` clicks (`TutorialManager.STEP_COUNT == 7`), and it exposed a real game
  bug the keyboard path never hits — `cultivation.gd`'s `_rebuild_options_box()`
  called `free()` on the button mid-emission of its own `pressed` signal
  ("Attempted to free a locked object"; measured 21/47 red). Fixed minimally
  with `queue_free()` (no month-advance/phase logic change; seven related
  scenarios re-measured green, `spine_to_ending` 42/42 among them).
- **Contract guards** (append-only): both new scenarios appended to
  `playtest/_common.yaml::scenario_order` **and** `ROUND_SCENARIOS` in
  `tests/test_playtest_contract_smoke.py` (two-place sync); surface whitelist
  grew by the twelve new button blocks + the six `pressed_connected` vars; two
  new smoke pins — `test_clicks_only_storyline_is_keyboard_free` (any keyboard
  action in the clicks-only file is a hard red; self-explaining failure message)
  and `test_touch_reach_surface_contract` (the new observables cannot be
  silently deleted). The stale `*_ClickTarget` example in `_common.yaml`'s
  clicks-grammar docs was corrected to a unit-body anchor.
- **Red-first record (measured)**: the nail is authored to first go red at the
  tutorial-end overlay (`ContinueButton` did not exist pre-fix) — and it DID,
  measured: with the documented TEMPORARY RED-FIRST REVERT applied to
  `game_manager.gd`, a real direct harness invocation
  (`godot_playtest_scenario(scenario="clicks_only_storyline")`) ran
  **RED 8/47** — failing frame **265**, first failing assert
  **`ContinueButton.visible`**, exact error **`aim: node not found:
  ContinueButton (spec: ContinueButton)`**, green asserts before red **8**;
  after the byte-identical restore it re-ran **47/47 green**. Values live in
  `final/delivery_notes_touch_reach_red_first.md`, the scenario header and
  `design/00_roadmap.md` / `90_decisions.md`; the earlier f180/5 numbers were
  the structural prediction and are superseded (same screen, same first
  assert).
- **Measurement-only debts** (`design/40_ux_backlog.md`, no gates):
  **UX-11** — touch-target sizes of every storyline control at the 960×704
  design resolution (measure and record the smallest few; Material 48 dp /
  HIG 44 pt / WCAG 2.5.8 24 px as references only; no size threshold);
  **UX-12** — residual keyboard-only hint copy with re-verified line numbers
  (`i18n.gd` :350/:354/:359/:364/:369/:378/:380/:122-123, scene literals
  `transition.tscn:50` / `sect_select.tscn:49` / `cultivation.tscn:47` /
  `ending.tscn:48`, `sect_select.gd:75`) — every one of those screens *now has*
  a control; only the copy still names the keyboard route.
- **Docs-first archive**: `design/30_presentation.md` new pointer-reachability
  section (incl. the observation conclusion: key injection cannot see this
  defect class, `clicks:` can); `design/00_roadmap.md` Phase 2 update;
  `design/90_decisions.md` rulings (a)–(e); `design/99_changelog.md` row
  dated 2026-08-29.

### The storyline, tapped screen by screen

Recorded in `final/delivery_notes_touch_reach_walkthrough.md` (≈90 clicks,
zero keyboard):

| Screen | What was tapped |
|---|---|
| 主菜单 | `MenuEntry0` (新的冒险) |
| 捏人 · 属性/特质/确认 | `AttrNextButton` → `TraitNextButton` → `ConfirmButton` |
| 教程战 · 开场页 | `Next` ×7 |
| 教程战 · 战斗 | `AttackButton` (one real click; outcome seeded with `debug_win_tutorial` — see above) |
| 教程结算 overlay | `ContinueButton` ← **the first-red screen** |
| 过场 | `NextButton` ×2 |
| 拜师 | `SectButton0` (少林) |
| 养成 · 36 个月 | each month `CultOptionButton0` (选卡/年初培元/岁末留门) + `CultOptionButton2` (做工 → the month advances through the existing path); year-boundary extra clicks; checkpoints at y1m1 / y2m1 / y3m1 |
| 大地图 | `TravelButton0/1…` per leg (无名谷→洛阳→武当→襄阳→昆仑), `EventOptionButton0` at each entry event |
| 结局 | `RestartButton` → back to the tutorial, storyline closed by taps alone |

## Previous rounds

- **jinyong-facility** — the third map-node content type: `FacilityData.TABLE`
  (2 rows, closed effect domain, §433 single prose source), shaolin/wudang
  facility slots `declared → active`, opt-in `FACILITY` phase (F key in TRAVEL,
  never auto-fires on arrival — pinned by the permanent negative assertion in
  `facility_use_reusable.yaml`, red-then-green measured 34/47 → 49/49), effects
  via the shared `EventLogic.apply_option_effects`, plus the
  `test_facility_use_reusable_surface_contract` anti-deletion pin and the
  `test_facility_copy_location.py` §433 guard.
- Earlier: **camera-owns-visibility** (following camera owns visibility, clamp
  deleted, canvas-transform click mapping, portrait-grid alignment),
  **interaction-defects** (floating-bar STOP filter, feet-tile undo, real-input
  coverage, touch undo, nameplate/ground marker, 5-step click priority, trait
  hover preview), **jinyong-nodes** (five main story nodes get content),
  **jinyong-map-events** (node entry-content + shared `EventLogic` + map EVENT
  phase), **jinyong-spend-qi** (real inner-qi costs), **jinyong-clarity**
  (creation-screen information layer), **jinyong-hud** (battle-HUD information
  layer), **jinyong-events** (event pool 4 → 16 rows), plus the owner's
  hand-added 华山 battle node. All recorded in `design/99_changelog.md`.

## Requirements

- Godot 4.x. No external dependencies, no build step.

## Install

```bash
git clone <this repo> jinyong && cd jinyong
# open project.godot in the Godot 4 editor (import happens automatically)
```

## Run

Open the project in the Godot 4 editor and press Play — the game boots into
the main menu (新的冒险 / 读取存档 / 设置 / 退出). Headless:

```bash
godot --path .
```

Flow: main menu → character creation (fixed 30-point budget: five attributes
with live effect explanations and current HP; 13 innate trait/flaw toggles
whose descriptions preview on hover; a confirm page listing the final values)
→ tutorial battle as a fully mastered Yang Guo vs the Five Masters (you are
meant to win) → tutorial-end overlay → transition → sect choice → 36-month
cultivation → the jianghu map → tiered ending → restart. **The whole storyline
is now playable with pointer/touch alone — every screen has a visible, tappable
control** (main menu buttons; creation's plus/minus/toggle/nav buttons; the
HUD's attack/end-turn/undo buttons; the overlay's 继续/重试; transition's 继续 ▶;
the sect list; cultivation's option pool; the map's travel/event/facility
buttons; the ending's 重新开始). The keyboard paths are unchanged and sit
alongside: in battle the **camera follows the acting unit** and keeps it in the
unobstructed band between the top bar and the action bar — left-click a
highlighted empty tile to move, left-click an enemy (its own tile **or** the
drawn portrait body of an enemy in reach) to attack, right-click **or the HUD
「退回」 button** to retreat to the turn-start tile until you act (acting locks
the move), 结束回合 to end the turn; each unit's nameplate rides at its portrait
head and a gold ground marker marks the occupied tile; casting a move spends
its inner-qi cost (内力: N in the top strip; a too-expensive move greys into
「内力不足」; the free basic 重剑无锋 always stays available). On the map,
左右/上下 cycle the adjacent nodes and 回车 travels (or tap `TravelButton{i}`);
every mainline stop opens its node event on arrival (洛阳 行商路过 / 武当 全真抄经 /
襄阳 降龙残谱; 无名谷 fires on the return trip; 少林 off the 洛阳 branch fires
破庙夜雨) — resolve with 上下选择，回车定夺 or by tapping the option buttons.
**At 少林 and 武当 (the two sect nodes), press F — or tap the 进入设施 button — to
enter the sect facility** (木人巷 / 紫霄静修): 回车 or the facility button uses it
once (pays silver, gains an attribute — reusable as long as you can pay),
上下/离开 leaves. The travel hint shows a `门派设施：…（F 使用）` line when a
facility is available at the current node. Entering 昆仑 routes straight to the
tiered ending (end-node routing runs before entry content, so nothing can block
it), and events fire only on travel — never on boot or load, so save/load
roundtrips don't re-trigger.

## Tests

`run_tests.sh` drives the full Godot gate through the `godot-builder` sidecar
(compile check → headless playtest of all scenarios → GDScript unit
suite). It fails loudly when the sidecar is unreachable — the code then ships
unverified, which is the intended behavior.

```bash
GODOT_BUILDER_URL=http://godot-builder:8080 ./run_tests.sh
python3 -m pytest tests/   # static playtest-contract smoke (superset pin, copy-location guard with tr() call-site detection, keyboard-free pins incl. the gongfa empty-exit nail, touch surface contracts)
godot --headless --path . -s res://tests/unit_test_runner.gd  # unit suite (24 files)
godot --headless --path . -s res://tests/test_touch_option_surface_gate.gd  # property-based touch-coverage gate (traverses the cultivation/map/sect_select phase machines)
godot --headless --path . -s res://tests/test_game_manager_fsm.gd  # SceneTree-style suites
```

## Key interfaces

- **Touch-single-surface controls & observables** (2026-08-30 round): buttons
  are the sole option surface in cultivation / map / sect_select — selection is
  the button's own `modulate` (bright focused / dim rest), arrow keys move the
  focus var the highlight follows; `GONGFA_PICK` with an empty unmastered list
  offers the single `CultOptionButton0` 「返回行动」 → the same
  `_on_accept` empty branch → `ACTION_PICK`; observables
  `cursor_markers_visible` (cultivation / map / sect_select), `option_focus` /
  `focused_option_text` (cultivation); scenarios
  `clicks_only_gongfa_empty_exit.yaml` (clicks-only, phase-diff nail) +
  `gongfa_pick_empty_keyboard_return.yaml` (keyboard twin); coverage gate
  `tests/test_touch_option_surface_gate.gd` (traverses the phase machines).
- **Touch-reach controls & observables** (touch-reach round): overlay
  `Panel/ContinueButton` / `Panel/RetryButton` in
  `GameManager._show_end_game_overlay` (delegates to `request_continue` /
  `request_retry`; keyboard branch byte-identical) with the
  `GameManager.end_overlay_pressed_connected` observable; segment buttons
  `NextButton` (transition), `SectButton0..4` (sect_select),
  `CultOptionButton{i}` (cultivation, dynamic per-phase pool in `OptionsBox`),
  `TravelButton{i}` / `EventOptionButton0/1` / `FacilityEnterButton` /
  `FacilityUseButton` / `FacilityLeaveButton` (map), `RestartButton` (ending) —
  each with `pressed_connected` published on its screen; every button is
  `focus_mode = FOCUS_NONE` and delegates to the same handler its keyboard
  shortcut calls.
- **Camera ownership** (`scripts/camera_follower.gd`, attached to the
  `Camera` node of `main.tscn` / `menu.tscn`): follows
  `CombatManager.get_active_unit()` during `STATE_BATTLE`, clamps to the
  no-blank range derived from `GridManager.board_rect()` + viewport + HUD
  rects, and publishes the playtest surface `Camera.camera_position`,
  `camera_x_lo/hi`, `camera_y_lo/hi`, `hud_band_top/bottom`,
  `active_unit_screen_y`, `active_unit_world_y`, `viewport_half_y`,
  `follow_target_id`, `follow_target_is_active`.
- **Coordinate mapping** (`scripts/coord.gd`, `class_name Coord`): pure
  statics `world_to_screen(world, viewport)` / `screen_to_world(screen,
  viewport)` over the **canvas** transform (the one that contains the
  camera). The health-bar follow and the follower's published screen y both
  go through it; click entries already map through
  `get_canvas_transform().affine_inverse()`.
- **Autoload singletons** (`scripts/autoload/`): `GameManager` (scene flow,
  `get_player()`, `get_enemies_alive()`, the end-game overlay +
  `end_overlay_pressed_connected`), `CombatManager` (battle state:
  `tutorial_battle`, `current_round`, `phase`, `is_player_turn()`,
  `get_active_unit()`, the qi spend path `spend_unit_energy(unit, cost)` +
  the `debug_spend_player_qi()` drain fixture), `GridManager` (grid /
  movement planning, `world_to_grid` / `grid_to_world` / **`board_rect()`**),
  `SaveManager` (profile, slots, `rng`, autosave), `InputGate` (real-input
  gate — inert unless the env var `AITELIER_INPUT_GATE_REPORT` is set).
  `SceneManager` must stay the LAST autoload entry (compile ordering).
- **Alignment observables** (`player.gd` / `enemy.gd`): `portrait_ink_rect`,
  `ink_world_dx` / `ink_world_dy`, `camera_offset_y`, `sprite_top`,
  `portrait_sprite_pos` / `portrait_tex_size` / `portrait_bar_pos` /
  `health_bar_screen_y` / `health_bar_world_y`, plus the input-differential
  counters (`debug_input_events`, `debug_click_events`,
  `debug_right_input_events`, `debug_undo_events`, `debug_gui_eater`,
  `Enemy.debug_click_target_fires`).
- **Battle click priority**: `Player.resolve_click_step(...) -> int` and
  `Player.attack_reach_covers(...) -> bool` — pure statics implementing the
  5-step rule (own-tile enemy → attack; in-reach body → attack; reachable
  empty tile → move; out-of-reach body → select/no-op; own tile no-op),
  unit-pinned by `tests/test_click_priority.gd` against the unclamped
  geometry.
- **Floating health bar** (`scripts/ui/health_bar.gd`,
  `scenes/ui/health_bar.tscn`): follows its unit through
  `Coord.world_to_screen`; above-portrait anchor with a flip below the ink
  bottom for top-band units; every node in the subtree is
  `mouse_filter = IGNORE` so it can never eat a board click. Observables:
  `bar_width/height/top/bottom`, `hp_text`, `hp_value`, `hp_max`,
  `hp_text_width_ok`, `empty_area_px`, `empty_cap_px`.
- **Ground markers** (`scripts/ui/tile_markers.gd`): click-inert Node2D
  overlay painting one ellipse per living unit; observables
  `tile_marker_count` / `tile_marker_visible`.
- **Creation / map / events / qi costs / facility**: `creation.gd` (`phase`,
  `points_left`, `attrs`, `trait_ids`, `trait_index`, `trait_hover_index`,
  `hp_value`/`hp_text`, `confirm_summary_text`, `pressed_connected`);
  `MapData.NODES` entry-content + `active_event_id` / `active_battle_id` /
  `active_facility_id` / `declared_gap_types`, `MapScreen` EVENT + FACILITY
  phase + `pressed_connected`; `EventLogic` pure statics over
  `EventData.TABLE` (16 rows); `FacilityData.TABLE` (2 rows) +
  `silver_cost()` / `for_node()` / `def(id)`; `SkillData.cost` /
  `insufficient_energy` / `spend` with `Player.energy` / `energy_max`.
- **i18n** (`scripts/autoload/i18n.gd`): the EN dictionary is the copy
  contract — the overlay keys are the exact call-site literals
  (`胜利！华山论剑的胜者！\n\n点击「继续」进入江湖` / `战败于华山论剑\n\n点击「重试」再战`)
  and every new button label (重试 / 重新开始 / 进入设施 / 离开) is keyed;
  `tests/test_i18n_coverage.py` keeps lookups honest.
- **Playtest contract** (the project's test "API"): `playtest/_common.yaml`
  declares the scene, the allowed actions (incl. debug injections and
  `use_facility` / `debug_grant_silver`), the observable-surface whitelist
  (incl. the twelve new touch-reach button blocks and the six
  `pressed_connected` vars) and `scenario_order`; each `playtest/*.yaml` is
  one scenario (name == basename, single-integer `at:`, a comparison operator
  or changed/unchanged token on every assert line). `clicks:` entries are
  `<Node>[ +dx,dy][ left|right|middle]` — a **true GUI hit test** (aim at the
  control/unit body, never a `*_ClickTarget`); `hovers:` are motion-only.
  75 scenarios, including the keyboard spine `spine_to_ending.yaml`, the
  clicks-only storyline spine `clicks_only_storyline.yaml` and the facility
  click companion `map_facility_buttons_click.yaml`.
- **Unit tests**: GDScript files with a top-level `static func run() -> bool`
  are collected by `tests/unit_test_runner.gd`'s explicit append-only `TESTS`
  registry (24 files), run headless. SceneTree-extending integration suites
  (`test_game_manager_fsm.gd` — extended this round with the overlay-button
  wiring pins — and friends) are driven with their own `-s` invocation. The
  pytest smoke (`tests/test_playtest_contract_smoke.py`) statically pins the
  scenario contract, the two-place sync, the "assertions only added" rule,
  the facility anti-deletion pin, the **keyboard-free pin** and the
  **touch-reach surface contract**. `tests/test_facility_copy_location.py`
  guards the §433 copy-location rule.

## Verification status (honest)

**jinyong-roster (this round, 2026-08-30) — delivery verified by direct read;
both new scenarios measured NOT green, downstream gates pending:**

- **Landed and verified in the tree**: `scripts/ui/roster_panel.gd` +
  `scenes/ui/roster_panel.tscn` instanced as `RosterPanel` into BOTH segment
  scenes; host input gates (`cultivation.gd:149-150`, `map.gd:112-119`); the
  four `Roster*` surface blocks; `scenario_order` 73→75 + `ROUND_SCENARIOS`
  two-place sync; the i18n roster block (`i18n.gd:474-487`);
  `tests/test_roster_panel.gd` registered in the unit-suite registry; the
  facility anti-delete pin's FORM-gate failure message
  (`test_playtest_contract_smoke.py:1078-1086`, additive only); the five
  design-doc updates (30 / 40_ux_backlog UX-13+UX-14 / 90 / 99). MEASURED nail
  red-first: f70 / `RosterPanel.is_open: is_open == true` /
  `FAIL f70 RosterPanel.is_open: is_open == true` + `observed=false` /
  red-before-green **8** (scenario header RED-FIRST EVIDENCE block +
  `final/delivery_notes_roster.md` §1). `design/99_changelog.md` row :126
  re-verified to hold the measured touch_single_surface values verbatim
  (f140 / `CultOptionButton0.visible: visible == true` /
  `aim: node not found: CultOptionButton0 (spec: CultOptionButton0)` /
  red-before-green 9) — no third correction row (append-only archive
  honored).
- **NOT green (measured sidecar runs, 2026-08-30; root causes still in the
  tree)**: `roster_panel_item_nail` **35/36** — f110
  `MapScreen.silver: changed` red (fresh boot `profile.silver = 0`
  (`player_profile.gd:21`); merchant `option_a` is silver −20
  (`event_data.gd:35`); `apply_option_effects` clamps `maxi(0−20, 0) = 0`
  (`event_logic.gd:42`); the 青锋剑 pin at f130 measured green).
  `roster_panel_cultivation_open_close` **15/16** — f110
  `CultivationScreen.month: changed` red (`debug_step_month` early-returns
  unless `GameManager.current_state == "CULTIVATION"`,
  `cultivation.gd:695-696`; autoload default is `STATE_TUTORIAL`; the
  documented clicks-only fallback was never implemented) **plus 6 runtime
  errors** (`Invalid access to property or key 'economy' / 'equipment' /
  'growth'` at `save_manager.gd:365/:382` — deck table not initialized on the
  direct-boot path). Fix direction: fund silver via the sanctioned
  `debug_grant_silver` pipeline action (or a travel-path silver source)
  before the merchant grant; play one real month by clicks instead of the
  gated debug token; root-cause the deck-initialization errors (0 runtime
  errors is an acceptance criterion). `roster_panel_cultivation_open_close.yaml`
  still carries a TEMPORARY PLACEHOLDER RED-FIRST block — that scenario's
  red-first was never measured.
- **Pending downstream evidence (not producible at verification time — not
  guessed, counted as unmet)**: compile 0 errors; GDScript unit suite green;
  `tests/test_i18n_coverage.py` / `tests/test_playtest_contract_smoke.py` /
  `tests/test_facility_copy_location.py` green; the vision gate;
  `spine_to_ending` timing. Their reports (`compile_report.json`,
  `vision_report.json`, `test_report.json`) are pipeline artifacts produced
  after this step. No official 75-scenario playtest gate run exists yet — the
  registry count (75) is not a gate-measured green count; the most recent
  gate-measured count below (73/73) is the previous round's.

**touch-single-surface (previous round, 2026-08-30) — fully evidenced (red-first
MEASURED post-review + official gate run):**

- **Direct-read verified in the tree**: the single-surface renders (`▶` option
  rows deleted from the cultivation / map / sect_select bodies; selection on
  the button via `modulate`; keyboard focus vars and `_unhandled_input`
  branches byte-identical), the `GONGFA_PICK` empty-exit button + rewritten
  hint + rewritten comment (`cultivation.gd:542-550`), the new observables in
  the `_common.yaml` surface (only-add), the two new scenarios + two-place
  registration + the keyboard-free smoke pin, the traversal-based coverage
  gate (SceneTree script; `run_tests.sh` discovers every `extends SceneTree`
  script by property — no list edit needed), the maintained copy-location
  guard (`_tr_call_literals` detection, ALLOWED emptied, anti-triviality floor
  re-based, the two symbol exclusions untouched), the design-archive rows
  (30 (g) / 31 new / 40 / 90 / 99), and the tails corrections (README Q6
  measured 71/0; walkthrough pointer line with the f180/5 prediction
  preserved).
- **MEASURED first-red values landed (2026-08-30, after the review round)**:
  the `godot_playtest_scenario` sidecar was invoked with the TEMPORARY
  RED-FIRST REVERT applied to `scripts/segments/cultivation.gd` and the nail
  went RED as the brief requires — failing frame **f140**, first failing
  assert **`CultOptionButton0.visible: visible == true`**, exact error
  **`aim: node not found: CultOptionButton0 (spec: CultOptionButton0)`**,
  **9** green asserts before red (f80 6 + f110 2 + the f140
  `phase == "GONGFA_PICK"` assert, which passes even with the revert). The
  earlier structural prediction (8 green before red) is preserved verbatim in
  the scenario header, explicitly marked superseded by the measured run. The
  revert was restored byte-identically (zero `TEMPORARY RED-FIRST REVERT`
  hits in `scripts/`) and both new scenarios re-ran GREEN on the restored
  tree: `clicks_only_gongfa_empty_exit` **16/16**,
  `gongfa_pick_empty_keyboard_return` **13/13** (hard gate `passed: true`).
  All values live in the scenario header's RED-FIRST EVIDENCE block and in
  `final/delivery_notes_touch_single_surface.md` (Part A §4/§5 + Part B §4/§5) —
  the `implementer.md:23` self-run hard condition is MET.
- **Downstream gates measured (read by `5_review` from the gate artifacts)**:
  compile **89/89** scripts, 0 errors; playtest **73/73** scenarios PASS, 0
  runtime errors, hard gate `passed: true` (including
  `clicks_only_gongfa_empty_exit` 16/16, `gongfa_pick_empty_keyboard_return`
  13/13, `spine_to_ending` 42/42, `clicks_only_storyline` 47/47,
  `facility_use_reusable` 49/49); vision gate **passed** (non-blind, 73
  scenarios / 292 frames, all six questions `failed: false`, Q6 text
  readability 73 good / 0 bad); GDScript unit suite **38/38** green
  (including the traversal coverage gate `tests/test_touch_option_surface_gate.gd`
  and the two re-targeted map unit tests); `tests/test_i18n_coverage.py` +
  `tests/test_playtest_contract_smoke.py` + `tests/test_facility_copy_location.py`
  green.

The rest of this section describes the previous (touch-reach) round.

The only authoritative gate evidence is the pipeline step products —
`5_compile`'s `compile_report.json` / `playtest_report.json` /
`playtest_summary.md`, `5_vision`'s `vision_report.json`, `5_test`'s
`test_report.json` — pipeline artifacts, not repo files. The touch-reach
round's official full-suite run has executed (2026-08-30); its measured
results are transcribed into the design archive (`design/00_roadmap.md`,
`design/40_ux_backlog.md`, `design/30_presentation.md`) and were relayed by
`5_review`. In short:

- **Direct-read verified this round (touch-reach)**: the overlay buttons +
  re-show branch + `end_overlay_pressed_connected` in `game_manager.gd`; the
  five segment scenes' new buttons + `OptionsBox` + facility delegate buttons;
  `pressed_connected` on all six segment scripts; the two-sided copy edit
  (`game_manager.gd:203/:208` ↔ `i18n.gd:104/:105`) plus the new label keys;
  `clicks_only_storyline.yaml` (zero keyboard actions; single
  `debug_win_tutorial` seed) and `map_facility_buttons_click.yaml`; the
  two-place sync (`_common.yaml::scenario_order` tail + `ROUND_SCENARIOS`
  tail); the two new smoke pins; the extended `test_game_manager_fsm.gd`
  overlay pins; the design-archive records (30/40/00/90/99).
- **Red-first status (measured)**: the first-red and the post-fix green are now
  MEASURED — via direct per-scenario invocation of the same external sidecar
  the gate drives (not via the `5_compile` gate): RED 8/47 at f265
  (`ContinueButton.visible`, exact error `aim: node not found: ContinueButton
  (spec: ContinueButton)`, 8 green asserts before red) with the documented
  temporary revert applied, then GREEN 47/47 after the byte-identical restore;
  a second parse-clean measured run (frame-timing re-projection plus the
  `cultivation.gd` `free()` → `queue_free()` fix) re-measured the nail 47/47
  green with seven regression probes green (`spine_to_ending` 42/42,
  `map_facility_buttons_click` 38/38, `facility_use_reusable` 49/49, plus four
  cultivation/sect scenarios). The earlier f180/5 numbers were the structural
  prediction (superseded).
- **Official full-suite gate run (2026-08-30) — MEASURED**, transcribed into
  `design/00_roadmap.md` / `design/40_ux_backlog.md` /
  `design/30_presentation.md` (e) and relayed by `5_review`: playtest
  **71/71 scenarios PASS** (hard gate `passed: true`, `spec_used: true`,
  **0 runtime errors**) — incl. `clicks_only_storyline` **47/47** (zero
  keyboard actions), `map_facility_buttons_click` **38/38**, the keyboard-path
  proof `spine_to_ending` **42/42** (byte-untouched, still fully green),
  `facility_use_reusable` **49/49**, `tutorial_win_routes_to_transition`
  **8/8**, `tutorial_loss_restarts_tutorial` **5/5**; compile **88/88**
  scripts, zero errors; vision gate **passed** (non-blind, 71 scenarios /
  284 frames, all six questions `failed: false`; Q6 text-truncation question
  measured good_answers 71 / bad_answers 0 — no Q6 bad answers that round,
  nothing parked); the pytest smoke
  ran **31/32** in `5_review`'s pass — the single failure was a test-side
  false positive on a comment line, root-caused and fixed after that run
  (bullet below).
- **Gate runs for this round**: `design/99_changelog.md`'s
  `record_parse_lesson_and_reconcile` row records that the round's `5_compile`
  run measured `Parse failed — play-test skipped` (`spec_used: false`,
  `frames: 0`): a parse error in a new `tests/*.gd` file reds Godot's
  project-wide parse check, the playtest is skipped entirely, and the hard gate
  still reads `passed: true` with zero frames. That lesson is closed by the
  official parse-clean full run above (`spec_used: true`, 71/71 PASS).
- **Smoke-gate hardening (post-gate fix, 2026-08-30,
  `final/delivery_notes_fix_at_gate_strip_comments.md`)**:
  `tests/test_playtest_contract_smoke.py::test_timeline_at_values_are_integers`
  false-reded on a `#` comment — `clicks_only_storyline.yaml:99` carries a
  backtick-wrapped `` `at:` `` in prose and the old regex matched comments
  too, capturing the backtick and failing `isdigit()`. Root cause fixed in
  the TEST (the scenario file stays byte-identical): a pure
  `_bad_timeline_at_values()` helper now strips each line's `#` comment
  before applying the original regex + `isdigit()` check, the docstring's
  false "word-boundary-guarded, so `at` inside prose never matches" claim was
  deleted, and two regression pins were added — a real non-integer `at:`
  value still reds, and the exact backtick-in-comment case is inert. Net
  effect: two tests added, the gate property preserved (only comments are
  excluded from matching), no scenario or threshold touched.
- If the downstream playtest gate reddens any scenario, that is reported with
  its cause, never papered over: no assertion is removed or relaxed, no
  frozen yaml is edited to route around a defect, and thresholds are never
  loosened — numbers come from constants or fresh measurement only.

## Repository layout

- `scripts/` — game code: `autoload/` (GameManager incl. the end-game overlay
  buttons, CombatManager, GridManager, SaveManager, InputGate,
  SceneManager-last, …), `camera_follower.gd`, `coord.gd`, `characters/`
  (`player.gd`, `enemy.gd`), `data/` (map/event/facility data,
  `event_logic.gd`, `facility_data.gd`, player_profile, …), `ui/` (HUD,
  health_bar.gd, tile_markers.gd, input_census.gd, highlights, visibility
  probe), `segments/` (creation / cultivation / **map** / **transition** /
  **sect_select** / **ending**, all with tappable controls), `ai/`,
  `battlefield.gd`
- `scenes/` — Godot scenes: `ui/` (hud, health_bar), `segments/`
  (creation, map, transition, sect_select, cultivation, ending),
  `battlefield.tscn`, `main.tscn` / `menu.tscn`
- `playtest/` — 75 headless playtest scenarios + the `_common.yaml` contract
  (72 yaml files); incl. the clicks-only storyline spine and the facility
  click companion; frozen yamls are append-only (authorized edits stay
  machine-pinned by the superset fixture)
- `tests/` — GDScript unit suites (24 files in the TESTS registry),
  SceneTree-style integration suites (incl. `test_game_manager_fsm.gd` with
  the overlay-button pins), `test_playtest_contract_smoke.py` (incl. the
  keyboard-free pin + touch-reach surface contract),
  `test_facility_copy_location.py`, and the frozen
  `fixtures/playtest_assert_superset.json` baseline
- `design/` — the design archive (`00_overview.md` … `99_changelog.md`);
  this round's records: `30_presentation.md` pointer-reachability section,
  `40_ux_backlog.md` UX-11/UX-12 measurement debts, `00_roadmap.md` Phase 2
  update, `90_decisions.md` touch-reach rulings (a)–(e), `99_changelog.md`
  touch-reach row (2026-08-29)
- `final/` — per-round delivery notes and probe notes (this round's
  red-first evidence: `final/delivery_notes_touch_reach_red_first.md`;
  the taps-only walkthrough:
  `final/delivery_notes_touch_reach_walkthrough.md`; the facility round's
  red-then-green record: `final/delivery_notes_facility.md`)
- `assets/` — placeholder textures, seed portraits, NotoSansSC font, audio
