# Technical Architecture Design — Round: 招式打得出去,门派选得对

> Round theme: make the selected skill actually usable (hint line + six Chinese
> rejection reasons + range/target highlight + meaningful input action name),
> fix the sect pick in the cultivation-combat scenario, and give the skill bar a
> distinct "waiting" presentation on enemy-turn frames.

## 1. Overview

This round implements the four fixes already mandated by `design/30_presentation.md`
§「选了招式之后没法出招」plus the two presentation gaps the round title names:

| # | Work item | New/changed surface |
|---|---|---|
| W1 | HUD hint line with six specific Chinese rejection reasons | `ActionHintLabel` in `scenes/ui/hud.tscn`; `player.gd` emits `action_hint(text)` |
| W2 | Skill range/target highlight overlay on the grid | new `scripts/ui/range_highlight.gd` Node2D in `scenes/battlefield.tscn` |
| W3 | Rename input action `basic_attack` → `attack_confirm` (keycode 74/J unchanged) | `project.godot` [input], `player.gd`, `tutorial_manager.gd`, `playtest_spec.yaml` (29 sites), `README.md` |
| W4 | "waiting" button state for non-player-turn frames | new `state_palette()` arm in `scripts/ui/skill_button.gd`; override moved out of the `hp_gated` branch in `scripts/ui/hud.gd` |
| W5 | Sect-select fix in `cultivation_changes_combat` | `playtest_spec.yaml` rows at frames 160/200 only — zero frame renumbering |
| W6 | Playtest contract: surface additions + 3 scenario skeletons | `playtest_spec.yaml` |

Hard constraints carried from the research step (non-negotiable):

- The **engine action string** `"basic_attack"` (AI decision dicts in
  `scripts/ai/*.gd`, `CombatManager.execute_action`, `player.gd` line ~591) is a
  *different thing* from the input action and **stays byte-identical**.
- Six tutorial battle scenarios stay **green byte-identical**; `spine_to_ending`
  32/32; `empty_round_stalls == 0`; 0 runtime errors; 0 compile errors.
- No `randi()`/global RNG, no damage/HP/cooldown numbers change, no art work.
- GDScript unit suite under `tests/` is NOT wired — this round does not touch it
  and does not rely on it (`design/30_presentation.md` §闸门的接线).
- Verification = playtest spec + vision gate + compile gate only.

## 2. Architecture diagram (text)

```
                        ┌────────────────────────────────────────────┐
                        │ Battlefield (Node2D, per-battle scene)      │
                        │  SummitBackdrop → Grid → GridLines          │
                        │     → RangeHighlight (NEW) → Characters     │  ← tree order = draw order
                        └──────────────┬─────────────────────────────┘
                                       │ setup(player, enemies) / signals
        ┌──────────────────────────────┼──────────────────────────────┐
        │ Player (player.gd)           │                              │
        │  select_skill() ──emit──► action_hint(text) ──► hud.show_hint(text)
        │  _try_attack_target() ─► action_hint("射程不够") …             │
        │  _try_keyboard_attack() ─► action_hint(…)                   │
        │  can_skill_hit(skill, enemy)  ◄── read (zero-duplication) ──┘
        │
        │ RangeHighlight (range_highlight.gd, _process polls)
        │   GameManager.get_player() → selected_skill_index / grid_pos
        │   per living enemy: player.can_skill_hit() → target tiles
        │   reachable tiles ← skill shape/range (GridManager reuse)
        │   queue_redraw() ONLY on change; observables tile_count/target_count
        │
        │ HUD (persists in main.tscn HUDLayer, CanvasLayer 10)
        │   ActionHintLabel (NEW Label, y 618..644, hidden by default)
        │   _refresh_skill_button_states(): waiting override for EVERY
        │     visible button when phase != "IDLE" and not is_player_turn()
        │   clear_battle_refs(): hide hint + disconnect signal
        └───────────────────────────────────────────────────────────────
```

Key structural decisions:

1. **Player → HUD coupling is a signal, not a reference.** Player never resolves
   the HUD; HUD connects `player.action_hint` in `setup()` (same pattern as
   `cooldowns_updated`). Battle exit is cleaned in `clear_battle_refs()`, which
   `SceneManager._teardown_battle_refs` already calls on every swap.
2. **Highlight is self-driving.** It polls `GameManager.get_player()` each frame
   (the same pattern `hud.gd` uses), so `battlefield.gd` needs **zero** code
   changes — only the `.tscn` node insertion. It calls the player's
   `can_skill_hit()` directly, so what is highlighted is exactly what executes
   (single source of truth, no duplicated shape math).
3. **Draw order fixes the layering for free.** `RangeHighlight` sits between
   `GridLines` and `Characters` in `battlefield.tscn`: translucent fills draw
   above the 35%-alpha grid lines (readability #1 preserved) and below character
   sprites. Health bars live on CanvasLayer 10 → always on top.

## 3. Design-change declarations (for `5_design`)

Implementers must NOT edit `design/*.md` this round. Two records drift because
of this run; `5_design` updates them after verification:

- **D1 — input map row.** `design/30_presentation.md` §输入映射 lists the
  J action as `confirm`, but `project.godot` never defined `confirm` (verified)
  and the code uses `basic_attack`. This run renames to **`attack_confirm`**
  (physical_keycode 74 unchanged). `5_design` updates the row
  `确认 / 出手 | J | confirm` → `attack_confirm` and appends the changelog row.
- **D2 — no other design change.** The hint text 「按 J 出招 / 点击目标」, the six
  reasons, the highlight, and the waiting state are implementations of decisions
  already written in `design/30_presentation.md` (可读性硬要求 #2/#3, §选了招式
  之后没法出招). No numbers in `design/20_content.md` change.

## 4. Component specifications

### C1. Action hint line (`ActionHintLabel`) — W1

**Files:** `scenes/ui/hud.tscn` (new node), `scripts/ui/hud.gd` (API + wiring),
`scripts/characters/player.gd` (signal + reject-reason helper + emit sites).

**Node (in `scenes/ui/hud.tscn`, sibling of `SkillBar` under `HUD`):**

```
[node name="ActionHintLabel" type="Label" parent="."]
anchors_preset = 7            ; bottom-center
anchor_left = 0.5
anchor_top = 1.0
anchor_right = 0.5
anchor_bottom = 1.0
offset_left = -240.0
offset_top = -86.0            ; y 618..644 — above SkillBar (top edge 648)
offset_right = 240.0
offset_bottom = -60.0
mouse_filter = 2
horizontal_alignment = 1
clip_text = false
visible = false               ; hidden before any selection (hard assert)
```

- No theme font override — the global theme (NotoSansSC, CJK-covered) applies.
- Placement guarantees zero overlap with `SkillBar` (y 648..688), `RoundIndicator`
  (y 8..72), and `PauseButton` — readability #6. It never covers the skill bar,
  so vision-gate battle classification is preserved (see §9).

**HUD API (`scripts/ui/hud.gd`):**

- `func show_hint(text: String) -> void` — `""` hides; otherwise sets
  `text` + `visible = true`.
- `func hide_hint() -> void` — `visible = false; text = ""`.
- `setup()` additionally wires: if `player.has_signal("action_hint")`, disconnect
  any stale connection then `connect` to `_on_action_hint(text)` (mirror
  `_wire_cooldown_updates`), and stores the player ref for teardown.
- `clear_battle_refs()` additionally: `hide_hint()` and disconnect
  `action_hint` (guarded by `is_instance_valid`). HUD persists across battles
  (main.tscn `HUDLayer`), so this is the battle-exit reset — scene swaps must
  never leave the old hint text on the next battle's screen.

**Player side (`scripts/characters/player.gd`):**

- New signal: `signal action_hint(text: String)`.
- New helper replacing the boolean gate (single source of truth for BOTH select
  and execution re-gate):

```
func _skill_reject_reason(index: int) -> String:
    if index < 0 or index >= skills.size():  return "该招式不存在"
    if CombatManager.tutorial_battle and index >= 4 and CombatManager.current_round < 4:
        return "教程尚未解锁"
    if skill_cooldowns[index] > 0:
        return "冷却中 %d 回合" % skill_cooldowns[index]   # same number the overlay shows
    var skill = skills[index]
    if skill != null and skill.hp_gate_below_ratio > 0.0 \
            and health >= int(round(float(max_health) * skill.hp_gate_below_ratio)):
        return "须在半血以下"
    if _has_restriction_status("no_techniques_next_turn"):
        return "本回合无法用招"
    if not TutorialManager.is_input_allowed("skill_%d" % (index + 1)):
        return "教程尚未解锁"
    return ""
```

- `_skill_selectable(index) -> bool` becomes a thin wrapper:
  `return _skill_reject_reason(index) == ""` (the two existing call sites in
  `select_skill` / `_try_attack_target` keep compiling; the gate ORDER is
  byte-identical to today: bounds → phase-lock → cooldown → HP gate →
  technique seal → tutorial block).
- `select_skill()`:
  - reject → `action_hint.emit(reason)` and return (replaces the silent no-op);
  - toggle-off → `action_hint.emit("")`;
  - success → `action_hint.emit("按 J 出招 / 点击目标")`.
- `_try_attack_target()`: every previously-silent return now emits first:
  - `_skill_reject_reason(skill_index)` non-empty (execution re-gate) →
    emit that exact reason (more specific than the research assumption's bundled
    「本回合无法用招」 — strict improvement, still non-empty/specific);
  - `can_skill_hit` fail → `action_hint.emit("射程不够")`;
  - basic-attack tutorial block → `action_hint.emit("教程尚未解锁")`;
  - basic-attack out-of-range → `action_hint.emit("射程不够")`;
  - after successful skill execution (auto-deselect) and after successful basic
    attack → `action_hint.emit("")`.
- `_try_keyboard_attack()`: when `target == null` (J pressed, no valid target —
  currently a silent dead branch), emit `"射程不够"`.

**The six reasons (Chinese literals, grep-verifiable mapping):**

| # | Reason literal | Site (file · function) |
|---|---|---|
| 1 | `射程不够` | `player.gd` `_try_attack_target` (`can_skill_hit` fail; basic-attack range) + `_try_keyboard_attack` (null target) |
| 2 | `冷却中 %d 回合` | `player.gd` `_skill_reject_reason` cooldown arm (select + execution re-gate); `%d` = `skill_cooldowns[index]` at reject time |
| 3 | `须在半血以下` | `player.gd` `_skill_reject_reason` HP-gate arm |
| 4 | `本回合无法用招` | `player.gd` `_skill_reject_reason` `no_techniques_next_turn` arm |
| 5 | `教程尚未解锁` | `player.gd` `_skill_reject_reason` phase-lock arm + tutorial-input arm; `_try_attack_target` basic-attack tutorial block |
| 6 | `该招式不存在` | `player.gd` `_skill_reject_reason` out-of-bounds arm |

Review acceptance: `grep "action_hint.emit"` in `player.gd` must cover every
`return` in `select_skill` / `_try_attack_target` / `_try_keyboard_attack` that
is not a success path; no silent `return` may remain in those three functions.

### C2. Range/target highlight (`RangeHighlight`) — W2

**Files:** `scripts/ui/range_highlight.gd` (NEW, ~100 lines),
`scenes/battlefield.tscn` (node insertion).

**Node (in `scenes/battlefield.tscn`, between `GridLines` and `Characters`):**

```
[ext_resource type="Script" path="res://scripts/ui/range_highlight.gd" id="4"]
[node name="RangeHighlight" type="Node2D" parent="."]
script = ExtResource("4")
```

(load_steps 4 → 5.) No other scene change; `battlefield.gd` untouched.

**Behaviour (`range_highlight.gd`, extends Node2D):**

- `_process()` resolves `var player := GameManager.get_player()` with
  `is_instance_valid` guard (never stores it, never touches freed nodes):
  - null / `selected_skill_index < 0` / `GameManager.get_state() != "BATTLE"` →
    hide (self.visible = false, `tile_count = 0`, `target_count = 0`), return;
  - otherwise recompute **only when** `selected_skill_index` or `grid_pos`
    changed since the last frame (cheap diff; `queue_redraw()` only then).
- Reachable tile set per skill shape — mirrors `player.can_skill_hit()` exactly
  (reuse, not reimplementation):
  - `aoe_shape == "global"` → no reachable fill; every living enemy is a target
    (`tile_count = 0`).
  - `jump_tiles > 0`, `aoe_origin == "target"`, or `aoe_shape == "single"` →
    Chebyshev ball of radius `skill.range` around the player tile.
  - `aoe_shape == "line"` → cells in the same row or column within `skill.range`.
  - `aoe_shape == "adjacent"` → ring at Chebyshev distance 1.
  - `aoe_shape == "cross"` / `"square"` (self-origin) →
    `GridManager.get_tiles_in_aoe(player.grid_pos, skill.aoe_shape, max(skill.aoe_size, 1))`
    — reuse the existing AoE math, zero new shape code.
  - Unknown shape → radius-`range` ball (same fallback as `can_skill_hit`).
- Target tiles: for each living enemy in `GameManager.get_enemies_alive()`,
  if `player.can_skill_hit(skill, enemy)` → its tile joins the target set.
  Requires promoting `_can_skill_hit` → **public `can_skill_hit`** in `player.gd`
  (3 in-file call sites updated; GDScript underscore is convention-only, but the
  public name is the interface contract here). The engine stays authoritative at
  execution; the highlight is a read-only view.
- `_draw()`: per reachable tile `draw_rect(Rect2(x*64, y*64, 64, 64),
  REACH_FILL)` + 1 px `REACH_EDGE` outline; per target tile `TARGET_FILL` +
  2 px `TARGET_EDGE`. Suggested colors (translucent so grid lines stay visible):
  `REACH_FILL = Color(0.30, 0.65, 1.00, 0.16)`, `REACH_EDGE = Color(0.30, 0.65, 1.00, 0.45)`,
  `TARGET_FILL = Color(1.00, 0.30, 0.20, 0.28)`, `TARGET_EDGE = Color(1.00, 0.30, 0.20, 0.75)`.
  15×11 = at most 121 cells — no allocation concerns.
- Observables (playtest surface): `visible` (built-in), `tile_count: int`,
  `target_count: int` (both updated on recompute, zeroed when hidden).
- Lifecycle: node dies with the battlefield scene on swap (no leak); the
  per-frame `get_player()` null-guard covers battle exit.

### C3. Input action rename `basic_attack` → `attack_confirm` — W3

**Files and sites (complete inventory, verified this round):**

| File | Sites | Note |
|---|---|---|
| `project.godot` `[input]` | line 83: `basic_attack={` → `attack_confirm={` | physical_keycode 74, deadzone 0.5 unchanged |
| `scripts/characters/player.gd` | line 327 `is_action_pressed("basic_attack")`; line 474 `is_input_allowed("basic_attack")` | add `const ATTACK_ACTION: StringName = &"attack_confirm"` and use it at BOTH sites (compile-time-checked) |
| `scripts/autoload/tutorial_manager.gd` | line 27 (default `_allowed_actions`) + lines 338/340/342/344/346 (5 lists) | list literals become `"attack_confirm"` |
| `scripts/autoload/tutorial_manager.gd` | const `STEP_BASIC_ATTACK` (line 16) → `STEP_ATTACK`; identifier uses at lines 93/110/337 | identifier-only rename (compile gate catches misses); the Chinese title `普通攻击` stays byte-identical |
| `playtest_spec.yaml` | line 27 (`actions:` list) + 28 timeline rows | all are `actions: [basic_attack]`; **no assert expression contains the string** (verified) |
| `README.md` | line 216 | line 229 (`execute_action` … `"basic_attack"`) is the engine string — **must stay** |

**Must NOT change (engine action string `"basic_attack"`):**
`scripts/autoload/combat_manager.gd` (resolution at ~line 1118),
`scripts/ai/ai_base.gd` + the five `ai_*.gd` decision dicts,
`player.gd` `_execute_basic_attack` (`execute_action(self, "basic_attack", …)`),
`README.md` line 229.

**Post-rename grep acceptance (run before the compile gate):**
- `basic_attack` in `*.gd` returns ONLY: `combat_manager.gd`, `ai/*.gd`,
  `player.gd` execute-action call — engine sites only.
- `attack_confirm` returns: `project.godot`, `player.gd` (const + 2 sites),
  `tutorial_manager.gd` (6 list sites), `playtest_spec.yaml` (29 sites),
  `README.md` (line 216).
- Keycode 74 unchanged → no scenario renumbers; tutorial timelines keep their
  exact frame numbers.

### C4. "waiting" button state — W4

**Files:** `scripts/ui/skill_button.gd` (palette + luma), `scripts/ui/hud.gd`
(override placement).

**hud.gd change (the actual bug fix):** in
`_refresh_skill_button_states()`, move the waiting override OUT of the
`elif hp_gated:` branch so it applies to **every visible button**:

```
var state := "ready"
if phase_locked: state = "phase_locked"
elif on_cooldown: state = "cooldown"
elif hp_gated:   state = "hp_gated"
# Presentation-only override: on enemy-turn frames EVERY visible button renders
# "waiting" so the bar visibly changes across player -> enemy -> player turns.
# Derivation order and `disabled` are untouched; state_text asserts that fire
# during PLAYER_TURN frames (spec lines 195/482-484/545/553 — all verified
# player-turn) are green by construction.
if CombatManager.phase != "IDLE" and not CombatManager.is_player_turn():
    state = "waiting"
```

**skill_button.gd changes:**

1. New `state_palette("waiting")` arm returning a dimmed desaturated blue-gray
   family: `{ bg_color: <impl-chosen>, border_color: <impl-chosen>,
   border_width: 1, tag_text: "" }` — no tag, thin border, dimmed (semantically
   "it is not your turn").
2. **Luminance rule (hard):** the chosen `bg_color` must satisfy
   `L_wait ≤ 0.2874` **and** `L_wait ≥ 0.1814` (i.e. ≥ 0.10 below ready
   0.3874 and ≥ 0.10 above cooldown 0.0814), computed with the engine's
   `Color.get_luminance()` and the exact value recorded in a comment.
   **Correction of the research step's arithmetic:** its claim that a luma
   "near 0.25–0.28 is outside ±0.10 of every other state" is false — the gap
   between `hp_gated` (0.2020) and `ready` (0.3874) is only **0.1854 < 0.20**,
   so no luma can be ≥ 0.10 from both. The only all-four-states-compliant value
   is a BRIGHT luma ≥ 0.6306, which is wrong for a "waiting" presentation. The
   dimmed zone above keeps ≥ 0.10 from ready/cooldown/phase_locked and reaches
   up to ~0.085 from hp_gated at the upper edge; remaining separation from
   `hp_gated` (dark red + 气血 tag) and `cooldown` (near-black + round number)
   comes from hue + markers, and the playtest asserts the real number.
   Candidate family for the implementer to verify, not copy blindly:
   bg ≈ `Color(0.20, 0.30, 0.40)`-class cool blue-gray — compute
   `get_luminance()` for the exact RGB chosen and adjust until the rule holds.
3. New observables:
   - `static func state_luma(state: String) -> float` — cached dict of
     `state_palette(state)["bg_color"].get_luminance()` per state string;
   - `var state_luma: float = 0.0` written every frame in `_apply_state`
     (`state_luma = state_luma(state)`).
   This turns the visual rule into an assertable rule.

**Side effects to accept (documented, not bugs):** during enemy turns the big
cooldown number hides (`_apply_state` only shows it for `state == "cooldown"`)
while the round-fill overlay stays — the whole bar reads as dimmed/waiting.
`selected` gold border still layers on any state (unchanged).

### C5. Sect-select fix — W5 (spec edit only, no code)

**File:** `playtest_spec.yaml`, scenario `cultivation_changes_combat`.

| Line today | Change |
|---|---|
| 1120-1121 `- at: 160 / actions: []` | `- { at: 160, actions: [move_down] }` |
| 1123-1124 `- at: 200 / actions: []` | keep `actions: []`, add `assert: CultivationScreen.sect_id: 'sect_id == "wudang"'` |

Rationale: frame 160 is the sect-select screen with `focus_index` 0 = shaolin;
`move_down` moves focus to 1 = wudang (order verified against
`ProgressionGongfaData.SECTS`: shaolin / wudang / gaibang / emei / tangmen);
frame 170's existing `ui_accept` then picks wudang. No other timeline row moves
— every later absolute frame number (215/230/…/2999) stays put. Optional (PM
discretion): an extra assert at frame 165 `SectSelectScreen.focus_index == 1`.
Wudang is the sword sect, which is what this scenario's sword-ladder asserts
(0.7 → 21, then 0.85 → 26) actually describe — the current shaolin pick is the
mismatch this round's title names.

### C6. Playtest contract (observable surface + scenario skeletons) — W6

**Contract updates to `playtest_spec.yaml` (PM fills exact thresholds):**

1. `actions:` list: rename `basic_attack` → `attack_confirm` (line 27).
2. `surface:` additions:
   - `ActionHintLabel: [visible, text]`
   - `RangeHighlight: [visible, tile_count, target_count]`
   - `state_luma` appended to each `SkillButton1..12` row.
3. Scenario skeletons (frames suggested below mirror the established cadence;
   PM finalizes):

   **S1 `skill_hint_and_range_highlight`** (selection UX):
   - 3..15 `ui_accept` ×7 (tutorial skip, standard);
   - at 20 assert: `ActionHintLabel.visible == false`, `RangeHighlight.visible == false`
     (hidden before any selection);
   - 25 `skill_1` → at 30 assert: hint `visible == true` and `text != ""`,
     `RangeHighlight.visible == true`, `tile_count > 0`, `target_count == 0`
     (player at (7,5); Heavy Edge range 1; all five enemies ≥ 4 tiles away);
   - 35 `attack_confirm` → at 50 assert: `ActionHintLabel.text == "射程不够"`
     (out-of-range attempt — non-empty AND specific);
   - 55 `skill_1` (toggle off) → at 60 assert: hint hidden, highlight hidden,
     `tile_count == 0`, `target_count == 0`.

   **S2 `skill_rejection_reason_texts`** (specific reasons):
   - 3..15 skip; 20 `skill_5` → at 30 assert `text == "教程尚未解锁"`
     (phase-lock, round < 4);
   - mirror `skill_button_turn_overlay` frames: `move_up` 20/35/50, `skill_1` 65,
     `attack_confirm` 80 (cast lands on 王重阳 at (7,1)) → 90 `skill_1` → at 95
     assert `text == "冷却中 1 回合"`;
   - NOTE for PM: the HP-gate reason 「须在半血以下」 only becomes reachable at
     round ≥ 4 (phase-lock has priority in the gate order — deliberate,
     byte-identical to today's `_skill_selectable` order); PM either appends
     hint-text asserts to the existing `two_phase_skill_unlock_and_hp_gate`
     scenario (round-4 frames already scripted) or extends S2 with
     `end_turn` cycles. The technique-seal reason 「本回合无法用招」 is covered by
     the existing 玉箫点穴 timeline — PM may attach a hint assert there too.

   **S3 `skill_bar_waiting_state`** (W4 verification):
   - mirror `skill_button_visual_states`: skip 3..15, `move_up` 20/35/50,
     `skill_1` 65, `attack_confirm` 80, `end_turn` 130;
   - at an enemy-turn frame (PM picks mid-phase, e.g. 300) assert:
     `SkillButton1.state_text == "waiting"`,
     `SkillButton1.state_luma` in the recorded range — recommended harness-safe
     form `'state_luma >= 0.18 and state_luma <= 0.2874'` (avoids `abs()`);
   - at 500 assert (existing): `state_text == "ready"` — unchanged, proves the
     override is presentation-only.

   **S4** = the C5 edit to `cultivation_changes_combat` (frames 160/200).

4. Everything else in the spec stays byte-identical — in particular the six
   tutorial scenarios, `terminal_victory_8_12_rounds_hp_15_40`,
   `spine_to_ending`, and the other two encounter scenarios.

## 5. Tech stack

- Godot 4.4 / GDScript, `Node2D._draw()` for the highlight (the in-repo
  `grid_lines.gd` pattern — no TileMapLayer, no shader), `Label` on the global
  CJK theme for the hint, `StyleBoxFlat` + cached palettes for the waiting state
  (existing `skill_button.gd` machinery).
- No new dependencies, no new autoloads, no new art/audio assets, no
  `tests/` changes, no `run_tests.sh` changes.

## 6. Vision-gate constraints (battle classification + readability)

- `cultivation_changes_combat` and `trait_combat_effects_and_twelve_slots`
  must stay classified as **battle** in sampled frames: bottom skill bar and
  health bars remain unobstructed. The hint label sits at y 618..644 (above the
  648..688 skill bar, below the top indicator) and is hidden by default; the
  highlight is translucent and draws UNDER character sprites. Implementer must
  re-verify vision classification after landing (frames sampled near the
  encounter battles now also show selection feedback — that is the fix, not a
  regression).
- Readability #1 (grid lines visible): highlight fills use alpha ≤ 0.28.
- Readability #6 (no UI overlap): hint label rect (618..644 × center ±240)
  vs SkillBar / RoundIndicator / PauseButton — all disjoint by construction.

## 7. Determinism & protected scenarios

- No RNG, no new timing, no scene-swap timing changes.
- The rename changes behavior for no scenario: keycode 74 unchanged, and the
  harness validates action names against `project.godot` (unknown action = hard
  failure), so a missed rename cannot pass silently.
- The waiting override only alters `state_text` on frames where
  `not is_player_turn()`; every existing `state_text` assert (spec lines 195,
  482-484, 545, 553) fires on player-turn frames — verified this round.
- The sect-select edit touches exactly two rows; no frame renumbers, so the
  downstream absolute-frame asserts stay valid. Implementer must re-run the full
  scenario and confirm all its asserts (the 0.7/21 and 0.85/26 damage pins
  included) — the wudang pick is what makes the sword-ladder pins consistent.

## 8. Irreversible-operation safety (rollback plan)

No destructive migrations exist; the risk is multi-file string churn. Rules:

1. **Rename (W3):** single-task, all-sites-at-once; verification = the §C3 grep
   acceptance BEFORE the compile gate, then the playtest gate (tutorial
   scenarios byte-identical). Rollback = revert the string in the seven files —
   nothing is deleted, keycode never changes, so rollback is a pure revert.
2. **Spec edits (W5/W6):** surgical row edits on `playtest_spec.yaml`; the
   harness hard-fails on unknown keys/actions (audited contract header), so a
   malformed row fails loudly instead of silently skipping. Rollback = git
   revert of the spec.
3. **Scene edits (`hud.tscn`, `battlefield.tscn`):** additive node insertions
   only — no existing node is reordered, renamed, or deleted. Rollback = remove
   the inserted node block; the rest of the file diffs clean.
4. **Palette change:** additive `match` arm + cached stylebox; the existing
   four arms are untouched. Rollback = delete the arm.
5. **Gate order / `disabled` / cooldowns / damage pipeline:** untouched by
   construction — the reason helper preserves the exact gate order, the waiting
   override never writes `disabled`.

## 9. Task decomposition boundaries (for the PM)

| Task | Files | Depends on | Risky bits |
|---|---|---|---|
| T1 hint + reasons | `player.gd`, `scenes/ui/hud.tscn`, `scripts/ui/hud.gd` | — | every silent return must emit; gate order preserved |
| T2 highlight | `scripts/ui/range_highlight.gd` (new), `scenes/battlefield.tscn`, `player.gd` (`_can_skill_hit` → `can_skill_hit`) | T1 (player.gd stable) | draw order; zero battlefield.gd changes |
| T3 rename | `project.godot`, `player.gd`, `tutorial_manager.gd`, `README.md`, `playtest_spec.yaml` (29 sites) | T1 (player.gd stable) | engine string must stay; grep acceptance |
| T4 waiting state | `scripts/ui/skill_button.gd`, `scripts/ui/hud.gd` | — (independent of T1-T3) | luma rule; override placement |
| T5 sect fix | `playtest_spec.yaml` (2 rows) | T3 (spec already renamed) | no renumbering |
| T6 spec contract | `playtest_spec.yaml` (surface + S1-S3) | T1-T5 | threshold values chosen by PM |

`playtest_spec.yaml` is touched by T3, T5, T6 — sequence them (T3 → T5 → T6),
or fold T5 into T6. T1 and T2 both edit `player.gd` but disjoint regions
(selection/attack paths vs the `can_skill_hit` signature); sequence T1 → T2.

## 10. Extensibility notes

- New skills get highlights and reasons **for free**: both are data-driven off
  `SkillData` fields (`range/aoe_shape/aoe_origin/aoe_size/jump_tiles`) and the
  single `can_skill_hit()` hit test.
- The input-action const (`ATTACK_ACTION`) makes future action renames
  compile-checked instead of grep-dependent.
- `state_palette()` remains a pure static function — new states slot in as one
  more arm + one cached stylebox; `state_luma` extends the same table.
- `show_hint(text)` is a generic one-line HUD primitive — future non-battle
  feedback can reuse it.

## 11. Out of scope (explicit)

- No `tests/` wiring or `run_tests.sh` changes (unit suite stays unwired).
- No art, audio, or `assets/` changes; no `resources.md` changes.
- No damage/HP/cooldown/initiative numbers change (`design/20_content.md`).
- No `design/*.md` edits by implementers — see §3 D1/D2 for what `5_design`
  will update.
- No changes to `CombatManager`, `GridManager`, `GameManager`, `SceneManager`
  logic; no new autoloads.

## 12. Deliverable summary

- Code: `scripts/ui/range_highlight.gd` (new); edits to `player.gd`,
  `scripts/ui/hud.gd`, `scripts/ui/skill_button.gd`,
  `scripts/autoload/tutorial_manager.gd`, `project.godot`, `scenes/ui/hud.tscn`,
  `scenes/battlefield.tscn`, `README.md`, `playtest_spec.yaml`.
- Linter manifest: unchanged (`.gd` excluded by design — `gdscript_check`
  handles it; `.yaml`/`.tscn`/`.md`/`.json` already mapped to `basic`).
