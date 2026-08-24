# Step 2 — Technical Architecture Design
## Round goal: “全按钮化 — UI that explains itself” (five verified UX defects + movement-range highlight)

This design implements the five defects verified in the Step 1 SOTA report plus the movement-range
highlight gap, on top of the existing Godot 4.7 repo machinery. Every file path, node name, and
signal cited below was verified against repo code on the 2026-08-24 baseline (see the "Verified
baseline" appendix). Nothing in this design changes game logic, combat balance, or any of the
32 existing playtest scenario files.

---

## 1. Overview

### 1.1 Goals (from the round brief, mapped to components)

| # | Defect (SOTA) | Fix (component) |
|---|---|---|
| 1 | Click-targeting reads the cached pointer (`get_global_mouse_position()`), not the click event → mouse attack untestable/unusable | **C1** event-driven world-coordinate conversion in `player.gd` |
| 2 | Creation screen buttons: no Back in TRAITS/ATTRS, no Next in ATTRS/TRAITS (keyboard-only) | **C2** four nav buttons delegating to existing handlers |
| 3 | Skill descriptions exist but are invisible (tooltip-only) and the data is English (violates the archive's Chinese-UI hard rule) | **C5** visible `SkillDescLabel` + Chinese 文案 |
| 4 | Trait descriptions do not exist in data | **C3** `description` field in `trait_data.gd` + `TraitDescLabel` |
| 5 | Attribute descriptions do not exist in UI | **C4** static attr-description table + `AttrDescLabel` |
| 6 | Battle button coverage: no End-Turn button, no attack-execution button (J/Space keyboard-only) | **C7** `EndTurnButton` + `AttackButton` in the HUD |
| 7 | Movement-range highlight is a fresh gap (only selected-skill reach highlights) | **C6** `MoveRangeHighlight` node, BFS mirroring `_try_move` |
| — | New observables + coverage for all of the above | **C8** `_common.yaml` surface append + 6 new scenario files |

### 1.2 Non-goals / protected invariants (do not touch)

- The **32 existing scenario files stay byte-identical**. `playtest/_common.yaml` is **append-only**
  (surface entries + `scenario_order` entries only). New coverage = new scenario files.
- `project.godot` is **not modified**: no new input actions, no new autoloads, no scene changes.
  Buttons are driven by real mouse clicks (`pressed` signal) and the existing `click:`/`clicks:`
  harness — no new debug actions are needed.
- `move_*` actions stay movement-only in battle; `attack_confirm` (J), `end_turn` (Space) keyboard
  paths are untouched. Buttons are additive delegates — "keyboard degrades to shortcuts".
- No combat-engine, AI, balance, or data-value changes. `_try_move` stays the single authority for
  movement rules; the movement highlight is a read-only mirror.
- `terminal_victory_8_12_rounds_hp_15_40` stays red (difficulty contract); GDScript unit-suite
  wiring, art rework, 穿越 演出, and `playtest_spec.yaml` monolith rebuild are all out of scope.
- `playtest_spec.yaml` must NOT reappear at repo root (the `playtest/` directory is authoritative).

### 1.3 Architecture diagram (text)

```
                    ┌────────────────────────── GameManager (autoload) ─────────────────────────┐
                    │ states MENU / CHARACTER_CREATION / TUTORIAL / BATTLE / ...                │
                    │ enter_menu() ── state_changed ──▶ SceneManager.swap_to("menu")            │
                    └───────────────────────────────────────────────────────────────────────────┘

 InputEventMouseButton (harness `clicks:` or real mouse)
        │
        ▼
 ┌──────────────────────────┐        ┌──────────────────────────────────────────────────────────┐
 │ player.gd                │        │ HUD (CanvasLayer 10, persistent shell)                  │
 │ _unhandled_input         │        │  ├─ SkillBar: SkillButton1..12 (pressed→_on_skill_selected)│
 │   click →                 │        │  ├─ ActionHintLabel (rejection reasons, existing)        │
 │   _handle_click_targeting │        │  ├─ PauseButton (existing)                              │
 │   (event)                 │        │  ├─ EndTurnButton ──pressed──▶ HUD handler               │
 │   world =                 │        │  │        └─ gate(is_player_turn, !paused)               │
 │   canvas_transform⁻¹ ·    │        │  │           └─ CombatManager.end_current_turn()         │
 │   event.position          │        │  ├─ AttackButton ──pressed──▶ HUD handler                │
 │   → world_to_grid         │        │  │        └─ gate(…) └─ player._try_keyboard_attack()    │
 │   → enemy match           │        │  ├─ SkillDescLabel (selected skill.description)          │
 │   → _try_attack_target    │        │  └─ geometry observables (new_button_overlap etc.)      │
 └────────────┬─────────────┘        └──────────────────────────────────────────────────────────┘
              │ (identical gates)
              ▼
        CombatManager.execute_action / end_current_turn        (engine — untouched)

 Battlefield (Node2D) world layer
  ├─ RangeHighlight      (existing: skill reach, blue REACH / red TARGET; NEW: fill_color observable)
  └─ MoveRangeHighlight  (NEW: movement reach, green; BFS mirroring player._try_move,
                          reads player.grid_pos / moves_left / acted / traits / GridManager)

 CreationScreen (segment Control; creation.tscn direct-bootable)
  ├─ MouseBox/AttrBox:   AttrMinus0..4 / AttrPlus0..4 (existing), AttrDescLabel (NEW),
  │                      NavRow: AttrBackButton → GameManager.enter_menu() (NEW),
  │                              AttrNextButton → _on_accept (NEW)
  ├─ MouseBox/TraitBox:  TraitToggle0..12 (existing), TraitDescLabel (NEW, TraitData.description),
  │                      NavRow: TraitBackButton → _on_move_left (NEW),
  │                              TraitNextButton → _on_move_right (NEW)
  └─ MouseBox/ConfirmBox: ConfirmButton / BackButton (existing, unchanged)
```

---

## 2. Component list

### C1 — Click-targeting fix (`scripts/characters/player.gd` only)

- **Responsibility:** make the world-click attack path driven by the click event's own coordinates
  instead of the cached pointer position.
- **Verified baseline:** `_unhandled_input` (L379-383) dispatches
  `_handle_click_targeting()` with no argument; the method (L462-463) reads
  `get_global_mouse_position()`. The unified input gate (L299-307: state == BATTLE,
  `is_player_turn()`, not paused, not `is_moving`) already protects the path — keep it byte-identical.
- **Change (two lines of code):**
  1. `L382`: `_handle_click_targeting(event)` — pass the `InputEventMouseButton` that the
     `elif` branch already narrowed.
  2. `L463`: replace `var click_world: Vector2 = get_global_mouse_position()` with
     `var click_world: Vector2 = get_canvas_transform().affine_inverse() * event.position`.
- **Coordinate contract:** `event.position` is viewport-space. `get_canvas_transform()` on the
  player node maps viewport → battlefield world. Today that transform is identity
  (`main.tscn` has a Camera2D at (480,352) — viewport center — with no offset/zoom;
  `battlefield.tscn` itself has none), so `event.position` equals world coordinates and existing
  behavior for real mouse users is unchanged; the expression stays correct if a camera moves later.
  `GridManager.world_to_grid` then maps world → grid cell, exactly as before.
- **No other change:** enemy matching loop, `_try_attack_target` gates (acted / tutorial /
  range / HP gate), auto-deselect — all untouched.
- **Interface for C8:** a new scenario (`click_targeting_fixed.yaml`) must click an enemy node
  and observe `Player.acted == true` + enemy health loss. This is the re-proof demanded by the
  brief: the fixed path must be proven harness-drivable, not assumed.

### C2 — Creation-screen navigation buttons (`scripts/segments/creation.gd` + `scenes/segments/creation.tscn`)

- **Responsibility:** expose every keyboard-only step transition as a mouse button, delegating to
  the SAME handlers the keyboard uses (convergence pattern, `_wire_mouse_widgets` L85-100).
- **Verified phase semantics (handler reuse matrix):**

  | Phase | `_on_move_left` | `_on_move_right` | `_on_accept` |
  |---|---|---|---|
  | ATTRS | **decrements attr** (must NOT be Back) | increments attr | → TRAITS |
  | TRAITS | → ATTRS (no trait mutation) | → CONFIRM | toggles trait |
  | CONFIRM | → TRAITS | no-op | confirm+route |

- **New nodes** (added to the `.tscn`; visibility is inherited from the parent box's existing
  per-phase `visible` logic in `_render()`, but the per-leaf `visible` sync pattern must be
  extended to them so node-level asserts hold):

  | Node path | Handler | Label |
  |---|---|---|
  | `MouseBox/AttrBox/AttrNavRow/AttrBackButton` | NEW `_on_creation_back_to_menu()` | `返回菜单` |
  | `MouseBox/AttrBox/AttrNavRow/AttrNextButton` | `_on_accept` (ATTRS → TRAITS) | `下一步` |
  | `MouseBox/TraitBox/TraitNavRow/TraitBackButton` | `_on_move_left` (TRAITS → ATTRS, safe reuse) | `上一步` |
  | `MouseBox/TraitBox/TraitNavRow/TraitNextButton` | `_on_move_right` (TRAITS → CONFIRM) | `下一步` |

- **`_on_creation_back_to_menu()` (new, ~5 lines):**
  `if confirmed or SceneManager.pending_swap: return` → `GameManager.enter_menu()`.
  `enter_menu()` (game_manager.gd L254) is idempotent and unguarded; it emits
  `state_changed("MENU")`, and SceneManager's `SCENE_MAP` swaps to the menu scene.
  Do NOT reuse `_on_move_left` here — in ATTRS it decrements the focused attribute.
- **`_wire_mouse_widgets()` additions:** connect the four buttons; extend the `pressed_connected`
  snapshot with keys `AttrBackButton`, `AttrNextButton`, `TraitBackButton`, `TraitNextButton`
  (same `get_signal_connection_list("pressed").size() > 0` pattern).
- **Edge cases (from SOTA):** TRAITS Back must not mutate trait state (`_on_move_left` TRAITS arm
  only changes phase — verified L129-132); the keyboard `move_left` in ATTRS stays
  "decrement attr" (unchanged); `menu_to_creation_to_tutorial_order` stays keyboard-driven and
  byte-identical because no keyboard handler is touched.
- **Important boot caveat:** the back-to-menu walk must run under `main.tscn` (SceneManager needs
  the persistent shell; a direct `creation.tscn` boot has no `/root/Main` hosts and would log
  `host_missing`). The direct-boot scenario only exercises TRAITS/CONFIRM/ATTRS phase navigation.

### C3 — Trait descriptions in data (`scripts/data/trait_data.gd`) + `TraitDescLabel`

- **Responsibility:** add the authoritative 机制 文案 to the trait registry and render it.
- **Data change:** add `var description: String = ""` to `TraitDef`; add a `"description"` key to
  each of the 13 `TABLE` rows; copy it in `_build()`. Additive only — `all()` / `get_def()` /
  `cost_of()` / `is_flaw()` / `positive_ids()` signatures unchanged, so
  `tests/test_trait_data.gd` and every consumer keep working.
- **文案 source (verbatim from `design/40_progression.md` §2.2 机制 column — the only allowed
  source, no invented numbers):**

  | id | display_name | description |
  |---|---|---|
  | ambidextrous | 左右互搏 | `技能栏可装 3 门外功(12 格),而不是 2 门 8 格` |
  | self_taught | 无师自通 | `可以在前置不齐时直接学高一级功法(发挥度照旧按缺几门算,依然失常)` |
  | gifted_bones | 骨骼清奇 | `可同时主修两门内功(常规只能一门)` |
  | photographic_memory | 过目不忘 | `见过敌人用过的招式,可在无师门的情况下自学该门类的低级功法` |
  | iron_shirt | 铁布衫 | `每场战斗第一次受到的致命伤转为剩 1 气血` |
  | swallow_lightness | 身轻如燕 | `战斗中可穿过敌人所在格(不能停留其上)` |
  | worldly_experience | 江湖阅历 | `大地图多一个行动:打听,揭示相邻节点的内容` |
  | deep_fortune | 福缘深厚 | `游历事件每年可重掷一次` |
  | sha_po_lang | 杀破狼 | `永远单人上阵,不能带同伴;同时领杀·破·狼三星` |
  | old_wound | 旧伤 | `无法使用绝招(每门外功的第 4 招)` |
  | inner_demon | 心魔 | `气血低于 30% 时,每回合有一次行动失控(随机移动,不攻击)` |
  | lone_bane | 孤煞 | `门派只教你外功,不教内功;内功得另想办法` |
  | dull_sinews | 筋骨迟钝 | `学不了轻功门类的任何功法` |

- **UI:** new `Label` node `MouseBox/TraitBox/TraitDescLabel` (autowrap, `mouse_filter = 2`).
  `_render()` sets `TraitDescLabel.text = _traits[trait_index].description` when TRAITS is active
  (guard `trait_index` in range), and syncs its `visible` with the phase. Surface: `text`, `visible`.

### C4 — Attribute descriptions (`scripts/segments/creation.gd`)

- **Responsibility:** show what each attribute derives, from the authoritative formulas.
- **Change:** a small `const` dictionary in `creation.gd` keyed by `PlayerProfile.ATTR_KEYS`,
  plus a `_attr_desc(key)` accessor. **文案 from `design/40_progression.md` §7.1 formulas and
  `design/10_systems.md` §1 meanings (verbatim formulas, no paraphrase):**

  | key | label | description |
  |---|---|---|
  | bone | 根骨 | `气血 = 根骨 × 5` |
  | inner | 内力 | `内力值 = 内力 × 2` |
  | agility | 身法 | `移动力 = 2 + 身法 ÷ 20(向下取整);先攻 = 身法` |
  | wisdom | 悟性 | `决定学功法的速度(修习查表)` |
  | fortune | 福缘 | `影响事件与奇遇(游历事件可重掷)` |

- **UI:** new `Label` node `MouseBox/AttrBox/AttrDescLabel` (autowrap, `mouse_filter = 2`).
  `_render()` sets `AttrDescLabel.text = _attr_desc(ATTR_KEYS[attr_index])` in ATTRS phase and
  syncs `visible`. Surface: `text`, `visible`.

### C5 — Visible skill description in battle (`scripts/battlefield.gd` + `scripts/ui/hud.gd` + `scenes/ui/hud.tscn`)

- **Responsibility:** make the selected skill's description readable without hovering (the
  click-only harness cannot hover), and align the description DATA with the archive's Chinese-UI
  hard rule (`design/30_presentation.md`: 界面文字一律中文; CJK font already global).
- **Data alignment (declared change):** the `desc` arguments in
  `battlefield.gd:_create_all_skill_data` are currently English (verified: e.g. "Ranged finger
  strike that ignores damage reduction…"). They are data (only ever surfaced via tooltips, never
  asserted), so switching them to Chinese breaks no scenario. The 8 player skills become the
  exact 文案 below (numbers verbatim from `design/20_content.md` §1 — they ARE the contract, do
  not paraphrase). Enemy-skill `desc` strings are switched to Chinese from the same tables
  (`20_content.md` §2.1-2.5) for consistency; they are not asserted.

  | skill (key unchanged) | Chinese description (visible text) |
  |---|---|
  | heavy_edge 重剑无锋 | `单体 45 伤害,击退 1 格。冷却 1 回合。` |
  | grand_simplicity 大巧不工 | `直线 3 格 38 伤害。冷却 2 回合。` |
  | thousand_force_cleave 力斩千钧 | `十字 2 格 34 伤害。冷却 3 回合。` |
  | boundless_seas 绝招·四海无量 | `以自身为心,半径 2 格全体 70 伤害。冷却 6 回合。` |
  | startle_heart 心惊肉跳 | `单体 38 伤害。冷却 1 回合。` |
  | mud_drag 拖泥带水 | `单体 25 伤害,目标下一回合移动力 −2。冷却 2 回合。` |
  | wander_valley 徘徊空谷 | `位移:跳 3 格,落点相邻全体 20 伤害。冷却 3 回合。` |
  | seventeen_forms 绝招·黯然销魂十七式 | `相邻全体 70 伤害,击退 2 格。需气血低于 50%。冷却 8 回合。` |

- **UI:** new `Label` node `SkillDescLabel` in `hud.tscn` (anchored top-right, below the new
  button column: `offset_left -352 / offset_top 140 / offset_right -8 / offset_bottom 320`,
  autowrap, `mouse_filter = 2`). It sits on HUD layer 10, below the tutorial panel's layer 100 —
  satisfying the archive rule that HUD never draws ON the tutorial panel.
  - Default text (no skill selected): `点击招式按钮,查看招式说明` — always visible, so the
    "no introduction in battle" gap is closed even before a selection.
  - `hud.gd:_on_skill_selected(index)`: after the existing `select_skill` call, re-read
    `GameManager.get_player()` and set `SkillDescLabel.text` to `player.skills[index].description`
    (guarded); if the same index is toggled off (`selected_skill_index < 0`), restore the default.
  - `setup()` resets the label to the default text; `clear_battle_refs()` resets it too.
  - Keep `tooltip_text = skill.description` in `skill_button.gd` (hover is a bonus, not the only path).

### C6 — Movement-range highlight (new `scripts/ui/move_range_highlight.gd` + `scenes/battlefield.tscn`)

- **Responsibility:** show every tile the player could still reach with the remaining movement
  budget, using the exact `_try_move` rules. The displayed set must **equal** the executable set:
  it must never suggest a move `_try_move` would refuse, **and it must never omit a move
  `_try_move` would allow**. Over-showing and under-showing are both the interface lying about
  the rules; under-showing is the more insidious one — the player just believes a tile is
  unreachable and stops trying.
- **Pattern reuse:** a sibling of `RangeHighlight` (`range_highlight.gd` — self-driving
  `_process`, cheap-diff keys, `_hide()` as the only writer of `visible = false`, observables).
  Node: `Battlefield/MoveRangeHighlight` (Node2D) with the new script, added to `battlefield.tscn`
  next to `RangeHighlight`. Dies with the battlefield on scene swap — no teardown.
- **Reachability model (BFS, display-only, mirrors `player.gd:_try_move` L391-439 exactly):**
  ```
  budget   = player.moves_left
  slide_ok = player.traits.has("swallow_lightness")
  dist = {grid_pos: 0}; queue = [grid_pos]
  while queue:
      v = pop_front(); d = dist[v]
      for dir in 4 directions:
          nxt = v + dir
          if GridManager.is_walkable(nxt) and not GridManager.is_occupied(nxt) and d+1 <= budget:
              relax(nxt, d+1)                       # normal step, cost 1
          elif slide_ok and GridManager.is_occupied(nxt) and d+2 <= budget:
              beyond = nxt + dir
              if GridManager.is_walkable(beyond) and not GridManager.is_occupied(beyond):
                  relax(beyond, d+2)                # 身轻如燕 slide-through, cost 2
  ```
  The origin tile is included (cost 0). The occupied slide-through tile itself is NOT in the set
  (it is never a legal landing tile). Border ring is excluded by `is_walkable` automatically.
- **Visibility rule:** show only while `GameManager.get_state() == BATTLE` **and**
  `CombatManager.is_player_turn()` **and** `player.moves_left > 0` **and** the player is valid.
  **`acted` is deliberately NOT a condition.** Design §5.1 makes move and action order-free
  (≤ 移动力格 of movement + one action, either order), and `_try_move` (player.gd L391-400) gates
  only on the tutorial `move` allowance and `moves_left <= 0` — it never reads `acted` (the only
  two readers of `acted` in the file are the attack paths, L494/L537). A unit that has acted but
  still has movement budget can still walk; hiding the highlight then would show the player a
  board that says "you cannot move" while the engine accepts the move — the exact
  interface-lies-about-the-rules defect this round exists to eliminate, in the over-conservative
  direction. What governs movement is `moves_left`, so `moves_left > 0` is the only budget
  condition. No tutorial gating: during TUTORIAL state `is_player_turn()` is false → hidden.
- **Diff keys:** `grid_pos`, `moves_left`, `acted`, and an occupancy signature
  (sorted join of `GridManager.occupancy.keys()`), mirroring the RangeHighlight cheap-diff so
  `empty_round_stalls` can never be triggered by this node. Recompute → `queue_redraw()` only on
  change. `acted` may stay in the diff-key set (it cannot change the reachable set, so it cannot
  hurt), but it must never enter the visibility condition — see the visibility rule above.
- **Colors (assertable distinctness — success criterion 5):**
  - `MOVE_FILL = Color(0.35, 0.85, 0.30, 0.16)`, `MOVE_EDGE = Color(0.35, 0.85, 0.30, 0.45)`
    (green family) — vs skill REACH blue (0.30,0.65,1.00) and TARGET red (1.00,0.30,0.20).
  - Observables: `visible`, `tile_count`, `fill_color` (the FILL constant).
- **Supporting change:** add `var fill_color: Color = REACH_FILL` to `range_highlight.gd`
  (observable only — zero behavior change), so the new scenario can assert both colors and prove
  inequality numerically (`green: g > r and g > b` vs `blue: b > r and b > g`).

### C7 — Battle buttons: End Turn + Attack (`scenes/ui/hud.tscn` + `scripts/ui/hud.gd`)

- **Responsibility:** give every battle action a clickable button; keyboard stays a shortcut.
  Skills already have buttons (SkillButton1..12); PauseButton exists. Missing: end turn, and the
  J attack confirmation.
- **New nodes in `hud.tscn` (authored, so they exist from scene parse — no programmatic
  instantiation, no `SkillButton`-style naming work):** right column under PauseButton
  (`anchor preset 3` — top-right; same width as Pause: `offset_left -140 / offset_right -8`):

  | Node | Position (offsets) | Text | Wires to |
  |---|---|---|---|
  | `EndTurnButton` | top 52 / bottom 88 | `结束回合` | NEW `_on_end_turn_pressed` |
  | `AttackButton` | top 96 / bottom 132 | `出招 (J)` | NEW `_on_attack_pressed` |

  Verified non-overlap: PauseButton y 8..44; RoundIndicator spans x 280..680; tutorial Panel
  starts at y 152 and x ≤ 780. So y 52..132 at x 820..952 is clear of everything.
- **Wiring in `hud.gd:setup()`** (idempotent: disconnect-first like `_wire_action_hint`), and a
  `pressed_connected: Dictionary` snapshot `{"EndTurnButton": true, "AttackButton": true}` after
  the connects (same proof-of-middle-chain pattern as `creation.gd`).
- **Handlers (gates live here — `CombatManager.end_current_turn()` has NO internal turn gate;
  `player._try_keyboard_attack()` expects the battle gate from its caller):**
  ```
  func _battle_input_allowed() -> bool:
      return CombatManager.is_player_turn() and not CombatManager.get_is_paused()
  func _on_end_turn_pressed():
      if not _battle_input_allowed(): return
      CombatManager.end_current_turn()                     # same engine call the Space key makes
  func _on_attack_pressed():
      if not _battle_input_allowed(): return
      var player = GameManager.get_player()                # live lookup — never a stored ref
      if player != null and is_instance_valid(player) and player.has_method("_try_keyboard_attack"):
          player._try_keyboard_attack()                    # same call the J key makes
  ```
  `AttackButton` mirrors J exactly: fires the selected skill at the nearest valid target, or a
  basic attack when none is selected (`_try_keyboard_attack`, player.gd L536). The label `出招 (J)`
  also closes the documented gap "the J key is written nowhere on screen"
  (design/30_presentation.md).
- **Per-frame state:** in `hud.gd:_process` (BEFORE the existing `player == null` early-return,
  next to `_update_geometry_observables`), set
  `EndTurnButton.disabled = AttackButton.disabled = not _battle_input_allowed()`. A click on a
  disabled button emits nothing — double protection; the visible disabled state also satisfies
  the "current action must be visible" readability rule.
- **Geometry observables (new, computed every frame in `_update_geometry_observables`):**
  - `hud_button_overlap: bool` — EndTurnButton/AttackButton rects intersect any of
    (PauseButton, RoundIndicator, SkillBar, ActionHintLabel).
  - `hud_desc_overlap: bool` — SkillDescLabel rect intersects any of the above or the two new
    buttons.
  Both must be `false` whenever the HUD is visible; asserted in the new scenario and left on the
  surface so any future button added on the HUD is guarded by an existing assert pattern.

### C8 — Playtest contract (append-only) + 6 new scenarios

- **`playtest/_common.yaml` additions** (append-only; the 32 scenario files untouched):

  ```yaml
  surface:
    RangeHighlight:
    - visible
    - tile_count
    - target_count
    - fill_color              # NEW (Color observable on the existing script)
    MoveRangeHighlight:       # NEW node
    - visible
    - tile_count
    - fill_color
    HUD:
    # (existing entries unchanged)
    - pressed_connected       # NEW (Dictionary)
    - hud_button_overlap      # NEW (bool)
    - hud_desc_overlap        # NEW (bool)
    EndTurnButton:            # NEW node
    - visible
    - size
    - mouse_filter
    - disabled
    AttackButton:             # NEW node
    - visible
    - size
    - mouse_filter
    - disabled
    SkillDescLabel:           # NEW node
    - visible
    - text
    AttrBackButton:           # NEW node
    - visible
    - size
    - mouse_filter
    AttrNextButton:           # NEW node
    - visible
    - size
    - mouse_filter
    TraitBackButton:          # NEW node
    - visible
    - size
    - mouse_filter
    TraitNextButton:          # NEW node
    - visible
    - size
    - mouse_filter
    AttrDescLabel:            # NEW node
    - visible
    - text
    TraitDescLabel:           # NEW node
    - visible
    - text
  scenario_order:
    # (existing 32 entries unchanged; append:)
    - click_targeting_fixed
    - creation_traits_back_next_buttons
    - creation_back_to_menu_walk
    - skill_description_visible
    - movement_range_highlight
    - battle_end_turn_attack_buttons
  ```

- **New scenario skeletons** (frame numbers and numeric thresholds marked PROBE are estimates to
  be confirmed with a real run; behavioral asserts are fixed). `clicks:` is the harness key for
  real `InputEventMouseButton` at the node's rect center.

  1. **`click_targeting_fixed.yaml`** — boots default (main.tscn). 7× `ui_accept` at f3..f15
     (the proven battle-boot cadence), 3× `tutorial_next` at f20/f25/f30 to complete
     WELCOME→MOVEMENT→ATTACK (`attack_confirm` becomes allowed; extra presses are no-ops once the
     tutorial is inactive). `move_up` ×3 at f40/f55/f70 → player at (7,2), adjacent to
     Central_Divine (7,1). `clicks: [Central_Divine]` at f100. Assert at f140:
     `Player.acted == true`; `Central_Divine.health: health == max_health - 39` (PROBE —
     basic attack 30 × fa_hui_du 1.3 → round → 39; Central has no damage reduction; verify via
     probe, do not soften the assert to `changed` unless the probe proves the number wrong).
     Click-point safety verified: Central's sprite center (480,96) is above the tutorial Panel
     (y ≥ 152) and clear of HUD widgets (RoundIndicator ends y 72).
  2. **`creation_traits_back_next_buttons.yaml`** — `scene: res://scenes/segments/creation.tscn`
     (direct boot, proven at f30). Asserts at f30: `phase == "ATTRS"`;
     `pressed_connected` true for all four new buttons; `AttrNextButton.visible/size.x > 0/mouse_filter == 0`;
     `AttrBackButton.visible == true`; `TraitBackButton.visible == false`; `AttrDescLabel.visible`
     and `AttrDescLabel.text: text.contains("气血") == true` (bone is focused at index 0).
     Then: `clicks: [AttrNextButton]` f40 → f60 `phase == "TRAITS"`; `clicks: [TraitBackButton]`
     f70 → f90 `phase == "ATTRS"` and `attrs["bone"] == 10` (proves the Back button mutated no
     trait state); `clicks: [AttrNextButton]` f100 → f120 `phase == "TRAITS"` and
     `TraitDescLabel.visible == true`, `TraitDescLabel.text: text.contains("技能栏") == true`
     (trait 0 = 左右互搏); `clicks: [TraitNextButton]` f130 → f150 `phase == "CONFIRM"`;
     `clicks: [BackButton]` f160 → f180 `phase == "TRAITS"`.
  3. **`creation_back_to_menu_walk.yaml`** — boots default (main.tscn; the menu claims the boot).
     Assert f30 `MenuPanel.visible == true`. `clicks: [MenuEntry0]` f40 → f100 (PROBE)
     `GameManager.current_state == "CHARACTER_CREATION"` and `CreationScreen.visible == true`.
     `clicks: [AttrBackButton]` f110 → f170 (PROBE) `GameManager.current_state == "MENU"` and
     `MenuPanel.visible == true`. `clicks: [MenuEntry0]` f180 → f240 (PROBE)
     `CreationScreen.visible == true`, `CreationScreen.phase == "ATTRS"`,
     `CreationScreen.points_left == 30` (fresh state — the 进入→返回→再进入 walk).
     Must NOT disturb `menu_to_creation_to_tutorial_order` (keyboard-driven, byte-identical files).
  4. **`skill_description_visible.yaml`** — 7× `ui_accept` f3..f15. Assert f30:
     `SkillDescLabel.visible == true`; `SkillDescLabel.text: text != "" and text.contains("点击") == true`
     (default guidance). `skill_1` f35 → f50: `SkillDescLabel.text: text.contains("击退") == true`
     (heavy_edge 文案) and `text.contains("点击") == false`. `skill_1` again f55 (toggle-off) →
     f70: default text restored (`text.contains("点击") == true`).
  5. **`movement_range_highlight.yaml`** — 7× `ui_accept` f3..f15; then 3× `tutorial_next`
     f20/f25/f30 so `attack_confirm` is allowed (needed by the act-then-look segment below).
     Assert f35 (round 1, player turn, moves_left 4): `MoveRangeHighlight.visible == true`;
     `tile_count > 0` (PROBE: expect 40 — the |dx|+|dy| ≤ 4 diamond from (7,5) lies fully inside
     the border ring and loses only the occupied (7,1));
     `MoveRangeHighlight.fill_color: fill_color.g > fill_color.r and fill_color.g > fill_color.b`
     (green-dominant); `RangeHighlight.fill_color: fill_color.b > fill_color.r and fill_color.b > fill_color.g`
     (blue-dominant) — together the color-distinctness proof. `move_up` ×3 f40/f55/f70 → f85
     `Player.moves_left == 1` and `MoveRangeHighlight.tile_count: changed`. **Act without
     moving:** `skill_1` f90, `attack_confirm` f95 (heavy_edge from (7,2) hits the adjacent
     Central_Divine at (7,1)) → f110 **the regression assert for this rule**:
     `Player.acted == true` **and** `Player.moves_left == 1` **and**
     `MoveRangeHighlight.visible == true` **and** `tile_count > 0` — the highlight must stay
     visible after acting, because an action does NOT spend the movement budget (design §5.1:
     move and action are order-free; `_try_move` never reads `acted`). This is the pin for the
     reviewer-flagged rule: a run that hides the highlight on `acted` fails here.
     `end_turn` f140 → f240 (PROBE) `MoveRangeHighlight.visible == false` and `tile_count == 0`
     (enemy turn). Optionally at ~f1500 (PROBE) round changed and highlight visible again on the
     next player turn.
  6. **`battle_end_turn_attack_buttons.yaml`** — 7× `ui_accept` f3..f15; 3× `tutorial_next`
     f20/f25/f30. Assert f35: `EndTurnButton.visible == true`, `size.x > 0`,
     `mouse_filter == 0`, `disabled == false`; `AttackButton` same; `HUD.pressed_connected`
     both true; `HUD.hud_button_overlap == false`; `HUD.hud_desc_overlap == false`.
     `clicks: [EndTurnButton]` f40 → f120 (PROBE) `CombatManager.active_unit_name: active_unit_name != "Player"`
     and `EndTurnButton.disabled == true` (enemy turn). At ~f1500 (PROBE) `current_round: changed`
     and `EndTurnButton.disabled == false` (player turn again). `move_up` ×3 at f1560/f1575/f1590
     (PROBE) → `clicks: [AttackButton]` f1660 → f1750: `Player.acted == true`
     (target-agnostic — the button attacks the NEAREST valid target, like J; if a specific enemy
     is adjacent in the probe run, add `X.health == max_health - <n>` with the probed value).

---

## 3. Interface contract (implementation-ready summary)

| File | Change | Interface |
|---|---|---|
| `scripts/characters/player.gd` | edit | `_handle_click_targeting(event: InputEventMouseButton)`; world = `get_canvas_transform().affine_inverse() * event.position` |
| `scripts/segments/creation.gd` | edit | +`_on_creation_back_to_menu()`, +`_attr_desc(key)`, +`_ATTR_DESCS` const; wire/snapshot 4 new buttons; `_render()` updates `AttrDescLabel`/`TraitDescLabel` |
| `scenes/segments/creation.tscn` | edit | +`AttrNavRow(AttrBackButton, AttrNextButton)`, +`TraitNavRow(TraitBackButton, TraitNextButton)`, +`AttrDescLabel`, +`TraitDescLabel` |
| `scripts/data/trait_data.gd` | edit | `TraitDef.description: String`; TABLE rows + `_build()` copy |
| `scripts/battlefield.gd` | edit | `desc` args of all skills → Chinese 文案 from `design/20_content.md` (8 player skills exact strings in §C5) |
| `scenes/ui/hud.tscn` | edit | +`EndTurnButton` (y 52..88), +`AttackButton` (y 96..132), +`SkillDescLabel` (y 140..320) — all top-right column x 820..952 (label x 608..952) |
| `scripts/ui/hud.gd` | edit | +`_battle_input_allowed()`, +`_on_end_turn_pressed()`, +`_on_attack_pressed()`, +`pressed_connected` snapshot, +desc-label update in `_on_skill_selected`/`setup`/`clear_battle_refs`, +`disabled` refresh in `_process`, +2 geometry observables |
| `scripts/ui/range_highlight.gd` | edit | +`var fill_color: Color = REACH_FILL` (observable only) |
| `scripts/ui/move_range_highlight.gd` | NEW | Node2D; BFS per §C6; observables `visible`/`tile_count`/`fill_color`; cheap-diff keys |
| `scenes/battlefield.tscn` | edit | +`MoveRangeHighlight` node (sibling of `RangeHighlight`) |
| `playtest/_common.yaml` | append-only | surface + scenario_order per §C8 |
| `playtest/<6 new files>` | NEW | per §C8 skeletons |

Data flow summary: mouse/button input → Button `pressed` → existing handler → existing engine API
(single source of truth); the only new engine-adjacent paths are the two HUD button handlers,
both thin delegates with a turn/pause gate. All new per-frame code (`MoveRangeHighlight`,
HUD geometry/disabled refresh) is read-only observation.

---

## 4. Tech stack

- **Godot 4.7** (in use, `config/features=PackedStringArray("4.7")`), **GDScript**, built-in
  `Button` / `Label` / `Node2D._draw()` / existing autoloads. **Zero new dependencies, zero new
  autoloads, zero new input actions, no new assets or fonts.** This keeps the 32-scenario
  contract and the headless gate intact.
- Reused repo-proven machinery: Button+`pressed` convergence (creation/menu/settings panels),
  `pressed_connected` snapshot, RangeHighlight cheap-diff highlight pattern, `get_canvas_transform()`
  coordinate conversion, per-scenario `scene:` direct boot, `clicks:` harness.

## 5. Extension considerations (deliberately minimal)

- `TraitDef.description` is a plain data field — future screens (companion cards, event UI) read
  the same rows; no new table needed.
- `MoveRangeHighlight` mirrors `_try_move`; if movement rules grow (e.g. hazards), the BFS gains
  the same arm `_try_move` gains — keep them adjacent in review.
- The two HUD button handlers are the single place future "clickable battle verbs" (wait,
  cancel-selection) plug in: add a Button + a gate-guarded delegate.
- No new abstraction layers were introduced — the design intentionally reuses existing patterns
  instead of generalizing them.

## 6. Migration / rollback plan (no destructive operations exist, but the protocol is followed)

1. **Snapshot first:** commit the current tree as a baseline (git) before any edit.
2. **Execute** in dependency order C1 → C3/C4 → C2 → C5 → C7 → C6 → C8 (see §7).
3. **Validate before declaring done:**
   - Whole-repo GDScript parse gate (sidecar `/compile`) green.
   - Existing playtest run: the 32 files are byte-identical; compare failures against the
     baseline snapshot — **zero new failures** allowed (the documented baseline reds like
     `terminal_victory` 5/6 stay exactly as they are).
   - The 6 new scenarios green; the two click scenarios specifically must show observed values
     (damage number, frame numbers) in the delivery notes — asserts must not be relaxed to pass.
   - `_common.yaml` diff is append-only (surface entries + scenario_order tail only).
   - `ui_geometry_readability` stays green (new HUD widgets proven non-overlapping by the new
     `hud_button_overlap`/`hud_desc_overlap` observables + the existing asserts).
4. **Rollback path:** every change is an additive/line edit to git-tracked text files; revert the
   touched file set (`git revert`/checkout of the baseline) restores the previous state exactly.
   Nothing is deleted, renamed, or rewritten in bulk anywhere in this design.

## 7. Suggested task decomposition (for PM, 8 tasks)

| Task | Components | Depends on |
|---|---|---|
| T1 | C1 click fix + `click_targeting_fixed.yaml` (probe) | — |
| T2 | C3 trait data + C4 attr desc + labels in creation (tscn+gd) | — |
| T3 | C2 creation nav buttons + `creation_traits_back_next_buttons.yaml` / `creation_back_to_menu_walk.yaml` | T2 |
| T4 | C5 skill 文案 + SkillDescLabel + `skill_description_visible.yaml` | — |
| T5 | C7 battle buttons + geometry observables + `battle_end_turn_attack_buttons.yaml` | T4 (same files) |
| T6 | C6 MoveRangeHighlight + RangeHighlight.fill_color + `movement_range_highlight.yaml` | — |
| T7 | C8 `_common.yaml` append + scenario_order (can be authored incrementally per scenario) | T1..T6 |
| T8 | Integration: full-suite regression vs baseline, compile gate, geometry re-check, delivery notes with observed values | all |

## 8. Design decisions log (rationale for PM/implementer)

- **D1 (C1):** use the event, not the pointer cache. The harness cannot move a real pointer; the
  event carries the truth. `get_canvas_transform().affine_inverse()` is identity today
  (`main.tscn` has a centered Camera2D with zero offset) and correct if a camera ever moves.
- **D2 (C2):** ATTRS Back must be a NEW handler — `_on_move_left` in ATTRS decrements an
  attribute, so reusing it for "back to menu" would silently eat a point on every back-press.
- **D3 (C2):** TRAITS Back/TRAITS Next reuse `_on_move_left`/`_on_move_right` (safe arms),
  ATTRS Next reuses `_on_accept` — maximal convergence with keyboard, minimal new logic.
- **D4 (C7):** gates live in the HUD handler because `CombatManager.end_current_turn()` has no
  turn gate and the player's `_unhandled_input` gate is on the keyboard path. Clicking End Turn
  during ENEMY_TURN or pause is a silent no-op, mirroring the keyboard behavior exactly.
- **D5 (C7):** `AttackButton` = J, not "basic attack only": `_try_keyboard_attack` fires the
  selected skill or falls back to basic attack. Label `出招 (J)` advertises the key.
- **D6 (C6):** BFS mirrors `_try_move` bit-for-bit (walkable, unoccupied landing, 身轻如燕
  slide cost 2 with budget ≥ 2); the displayed set equals the executable set — it must neither
  suggest a move `_try_move` would refuse, nor omit a move `_try_move` would allow.
- **D7 (C6):** movement-highlight visibility is governed by `moves_left > 0` (plus BATTLE state
  and player turn), NOT by `acted`. Design §5.1 makes move and action order-free and `_try_move`
  never reads `acted`; hiding the highlight after acting would show the player a board that says
  "cannot move" while the engine accepts the move — an over-conservative lie. `acted` stays in
  the diff-key set only.
- **D8 (C6):** green/blue color distinctness is asserted numerically via `fill_color` observables
  on both highlight nodes ("just visible" proves nothing).
- **D9 (C5):** the description label is always visible (default guidance → selected skill's
  description); tooltips remain as a secondary path.
- **D10 (C5):** switching skill `desc` data from English to Chinese is code aligning with the
  archive hard rule (`design/30_presentation.md` 界面文字一律中文, CJK font bundled), not an
  archive change — declared here so no later run "fixes" it back to English.
- **D11 (C7):** new HUD widgets are placed in the top-right column (y 52..132 for buttons,
  y 140..320 for the label) — verified clear of PauseButton (y ≤ 44), RoundIndicator (x ≤ 680),
  SkillBar (y ≥ 648), ActionHintLabel (y ≥ 618), and the tutorial Panel (y ≥ 152, x ≤ 780); the
  two new geometry observables make this a running assert instead of a one-time measurement.
- **D12 (C2):** the back-to-menu walk boots `main.tscn` (SceneManager needs the persistent
  shell); the direct-boot scenario covers phase navigation only.
- **D13 (C5):** description text appends `冷却 N 回合` from each skill's own cooldown field
  (data from `design/20_content.md`'s 冷却 column) — never invented numbers.
- **D14 (language note):** in-game UI strings are Chinese per the project archive
  (`design/30_presentation.md` hard requirement + bundled CJK font); node names, signal names,
  action names, skill ids, and all code identifiers stay English. Design-doc prose is English.

## Appendix — Verified baseline (file:line references, 2026-08-24)

- `scripts/characters/player.gd`: input gate L299-307; click dispatch L379-383; broken click
  targeting L462-463; `_try_move` L391-439 — gate at L391-400 reads ONLY the tutorial `move`
  allowance and `moves_left <= 0`, never `acted` (`acted` is read only on the attack paths
  L494/L537); then walkable, occupied, 身轻如燕 slide cost 2;
  `_try_keyboard_attack` L536; `_try_attack_target` L490-529; `can_skill_hit` L605-634.
- `design/10_systems.md` §5.1 回合结构: a unit's turn = movement (≤ 移动力格) + one action
  (普攻/招式/等待), either order — the authority D7 and the movement-highlight visibility rule cite.
- `scenes/main.tscn`: Camera2D (480,352) current — identity screen transform; SceneHost;
  SegmentLayer/SegmentHost; HUDLayer(layer 10)/HUD; TutorialLayer(layer 100)/TutorialOverlay.
- `scenes/ui/tutorial_overlay.tscn`: Dim full-rect `mouse_filter = 2`; Panel 600×400 centered
  (x 180..780, y 152..552).
- `scripts/autoload/tutorial_manager.gd`: `is_input_allowed` L219; `_update_allowed_actions`
  L330-346 (attack_confirm allowed once STEP_ATTACK is completed).
- `scripts/segments/creation.gd`: `_wire_mouse_widgets` L85-100; `_on_move_left` L120-137;
  `_on_move_right` L140-154; `_on_accept` L157-170; `_render` L217-288.
- `scenes/segments/creation.tscn`: MouseBox/AttrBox/AttrRow0..4/AttrMinus{i}/AttrPlus{i};
  TraitBox/TraitToggle0..12; ConfirmBox/ConfirmButton+BackButton.
- `scripts/data/trait_data.gd`: TraitDef fields; 13 TABLE rows.
- `scripts/ui/hud.gd`: setup L114; clear_battle_refs L162; `_update_geometry_observables` L84;
  `_process` L335; `_on_skill_selected` L465; `_refresh_skill_button_states` L370.
- `scenes/ui/hud.tscn`: HUD (mouse_filter 2), SkillBar (y 648..688), ActionHintLabel
  (y 618..644, hidden), RoundIndicator (x 280..680, y 8..72), EnergyLabel, PauseButton
  (x 820..952, y 8..44).
- `scripts/autoload/combat_manager.gd`: `is_player_turn` L301; `get_is_paused` L267;
  `end_current_turn` L650 (no internal turn gate).
- `scripts/autoload/grid_manager.gd`: GRID 15×11, TILE 64, GRID_ORIGIN (32,32); `is_in_bounds`
  L117; `is_walkable` L126 (border ring excluded); `is_occupied` L156.
- `scripts/autoload/game_manager.gd`: `enter_menu` L254 (unguarded, emits state_changed);
  `finish_creation` L324; STATE_MENU L59.
- `scripts/autoload/scene_manager.gd`: SCENE_MAP/SCENE_PATHS L35-60 (MENU → menu panel);
  `_do_swap` pending_swap guard L143; host resolution needs `/root/Main`.
- `scripts/ui/range_highlight.gd`: REACH_FILL/TARGET_FILL L24-29; `_hide`/diff-keys L51-107.
- `scripts/battlefield.gd`: `_skill()` L384-396; English desc data (verified samples L301-375);
  `_wire_hud` L861.
- `playtest/_common.yaml`: header rules (append-only, per-scenario `scene:`, direct-boot proof,
  frame cap 3000); actions list; surface list; scenario_order L511-543.
