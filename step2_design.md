# Step 2 — Technical Architecture Design

**Project:** Huashan Sword Tournament (Godot 4 turn-based grid combat demo)
**Run scope:** (A) eliminate "Trying to cast a freed object" crashes repo-wide, (B) make the terminal battle winnable in rounds 8–12 with player HP in 15–40%, (C) make the battle UI readable + add the four geometric playtest assertions.

---

## 1. Overview

Three independent problem domains, each with a different verification path:

| Domain | Problem | Legal knobs | Verifier |
|---|---|---|---|
| A. Freed-object crashes | `as Node` casts execute **before** `is_instance_valid()` checks on stored references to `queue_free()`-ed enemies | Code, repo-wide | GDScript parse gate + headless playtest (no runtime errors in `playtest_report.json`) |
| B. Terminal balance | Last run: LOST at round 5, player 0 HP (old 360-HP pool) | **Only** `scripts/ai/*.gd` decision tables + `playtest_spec.yaml` button timeline | Deterministic harness: `current_state == "WON"`, `current_round in [8,12]`, `Player.health in [75,200]` at the victory moment |
| C. UI readability | Grid hidden by backdrop, 4 button states pixel-identical, health bar too wide and unrecognizable, truncated names, RoundIndicator overlapping PauseButton | `scripts/ui/*.gd`, `scenes/ui/*.tscn`, `scripts/battlefield.gd`, `scenes/battlefield.tscn`, `playtest_spec.yaml` | Geometric asserts in `playtest_spec.yaml` + external 5_vision visual gate |

**Success criteria → verification mapping**

1. No freed-object errors → harden the four real vectors + repo-wide audit; verified by `run_tests.sh` (compile + headless playtest) producing `playtest_report.json` with zero runtime errors.
2. Terminal victory band → AI engagement policy (§4) + re-timed terminal scenario (§7.6); verified by the terminal scenario asserts at the victory moment.
3. 5_vision gate → UI component changes (§5) + the four mandated geometric assertions (§7.4); recognizability checks (grid visible, button states distinguishable, bar recognizable, no truncation) are the external visual harness's cross-frame questions — never single-frame spatial questions in YAML.

### 1.1 Design-follow note (not a design change)

`design/20_content.md` is authoritative and already records (changelog `jinyong-ux`): Yang Guo **500 HP**, Shen Diao regen **20/round (26 after ×1.3)**, melee DR **−50% (flat, no fhd multiplier)**. The **code is stale** in these places (four functional sites + comment-only wording):

| Site | Code (stale) | Design (authoritative) |
|---|---|---|
| `scripts/battlefield.gd` ~:443 `cd.max_health = 360` | 360 | **500** |
| `scripts/autoload/combat_manager.gd` :1386 `_damage_reduction` `dr += 0.2` | −20% | **−50%** (`dr += 0.5`) |
| `scripts/autoload/combat_manager.gd` :455 `apply_heal(unit, 16)  # round(12 * 1.3)` | 12 base | **20 base** (`apply_heal(unit, 26)  # round(20 * 1.3)`) |
| Stale code comments only (no logic change): `player.gd` :171/:184 "180 of 360" — the gate itself derives from `max_health` and follows to 250 automatically; `combat_manager.gd` :455/:517/:1377 "−20% melee" wording | 360 / −20% | **500 / −50% wording** |
| `playtest_spec.yaml` snapshots: `Player.health: 360`, terminal band `54..144` | 360 / 54–144 | **500 / 75–200** |

This run therefore implements the already-decided design numbers — it adds **no new design change** and does not need a "设计变更" section. All other content numbers (enemy HP/damage/cooldowns, skill values, ×1.3, round() rules) are untouched. The percentage rules hold: **−50% is flat; percentages never take the fhd multiplier.** Victory band: 15–40% of 500 = **75–200**. The 17 Forms HP gate: 50% of 500 = **< 250** (the code computes the gate from `max_health`, so it follows automatically).

**Stale text to ignore:** `design/20_content.md`'s 一阳指 line still says "无视 −20% 减伤" — a reference to the old reduction. Solar Finger is range-2 (ranged) and bypasses the melee DR anyway; the existing `ignore_damage_reduction` flag is **harmless and must not be changed** (do not add any "pierce" that double-applies).

---

## 2. Architecture Diagram (text)

```
                     ┌──────────────────────────────────────────────┐
                     │              playtest_spec.yaml              │
                     │  scene / actions / surface / scenarios       │
                     │  (contract: node & var names verbatim)       │
                     └───────────────┬──────────────────────────────┘
                                     │ drives (external godot_harness)
┌────────────────────────────────────┴───────────────────────────────────┐
│                               main.tscn                                │
│  Battlefield (Node2D)                                                  │
│    ├─ SummitBackdrop (Sprite2D)      ← backdrop painting, fitted       │
│    ├─ Grid (TileMap)                 ← floor/border tiles              │
│    ├─ GridLines (Node2D, NEW)        ← _draw() cell lines ABOVE tiles  │
│    └─ Characters (player + 5 enemies)                                  │
│  HUDLayer (CanvasLayer 10, non-following)                              │
│    └─ HUD (Control FULL_RECT)                                          │
│        ├─ HealthBarContainer ── 6× HealthBar (Control: label + Bar)    │
│        ├─ SkillBar (HBox) ── SkillButton1..8 (4 visual states)         │
│        ├─ RoundIndicator (top-center, no overlap w/ PauseButton)       │
│        ├─ PauseButton (top-right)                                      │
│        └─ EnergyLabel                                                  │
│  TutorialLayer (CanvasLayer 100) ── TutorialOverlay                    │
└────────────────────────────────────────────────────────────────────────┘
         │ autoloads
         ├── GameManager   (state machine, enemies_alive: Array[Node], win/lose)
         ├── GridManager   (occupancy Dict, AStar, movement, AoE queries)
         ├── CombatManager (turn engine, damage pipeline, statuses, passives)
         ├── TutorialManager
         └── AudioManager

Data flow (turn loop):  GameManager.start_battle → CombatManager._begin_round
(snapshot initiative, stable sort) → _next_turn → begin_turn (cooldowns → DoTs
→ regen) → player: event-driven (Space) | enemy: ai_*.gd evaluate() ONCE →
execute_move_path / execute_action → apply_damage (attack-side round × DR-side
round) → _handle_death (unregister_enemy → queue_free) → end_current_turn → _next_turn.
HUD reads CombatManager/Player state every frame (_process) and writes visual
states; geometric observables are computed in hud.gd/health_bar.gd for YAML asserts.
```

---

## 3. Domain A — Freed-object crash hardening

### 3.1 Root cause and the normative pattern

`queue_free()` is deferred: a dead enemy stays *valid* during its death frame and becomes a **freed object** on a later frame. The turn engine `await`s process frames, so it iterates stale references many frames after death. GDScript raises "Trying to cast a freed object" **at the `as` cast itself** — the null/validity check after the cast never runs.

**The only sanctioned pattern — "check-then-cast":**

```gdscript
var raw = container[i]                     # raw Variant read: never crashes
if raw == null or not is_instance_valid(raw):
    container.remove_at(i)                 # or: erase / continue
    continue
var unit: Node = raw                       # typed assignment only AFTER validation
```

Rules, repo-wide:
1. **Never** `as`-cast (or assign to a typed variable / typed `Array[Node]`) an operand that may hold a stored, possibly-freed node reference.
2. `get_node_or_null("path") as X` is **safe by construction** (re-resolves the path each call; returns `null` for freed nodes — casting `null` does not crash) and is left unchanged.
3. Keep `TWEEN_TIMEOUT_SEC = 0.25` and `_await_tween_safe`'s done-flag array pattern **as-is** (killed tweens never emit `finished`; the watchdog bounds enemy rounds).
4. Determinism: hardening must not reorder decisions — the AI remains a pure function of state.

### 3.2 Fix sites

**Mandatory (the four real vectors — freed-reference storage):**

| File | Line | Fix |
|---|---|---|
| `scripts/autoload/combat_manager.gd` | 294 | `_turn_order_units[0] as Node` → check-then-cast; pop-dead-heads loop keeps popping freed heads |
| `scripts/autoload/combat_manager.gd` | 307 | `_turn_order_units.pop_front() as Node` → pop into Variant, validate, then typed assign |
| `scripts/autoload/grid_manager.gd` | 303 | `occupancy[grid_pos] as Node` in `get_units_in_range` → check-then-cast before append |
| `scripts/autoload/grid_manager.gd` | 412 | `occupancy[tile] as Node` in `get_units_in_aoe` → check-then-cast before append |

**Audit-only (documented safe — no code change needed):** `combat_manager.gd:1227/1229`, `game_manager.gd:141`, `enemy.gd:236`, `hud.gd:69/82/120/198`, `health_bar.gd:42/52`, `skill_button.gd:64/80/103`, `round_indicator.gd:42/50/58`, `tutorial_manager.gd:256/261/262` — all operate on `get_node_or_null(...)` results or fresh `instantiate()` output; the audit task records this in code comments where missing, but must not churn the files.

**Structural invariants already correct (do not "fix"):** `GameManager.enemies_alive: Array[Node]` stays clean (`unregister_enemy` removes before `queue_free`); `_turn_order_units` and `occupancy` stay **untyped** containers; `_deduplicate_nodes` only receives validated units.

### 3.3 Verification

`run_tests.sh` (compile + 5 s headless playtest) must show zero runtime errors; all six protected scenarios stay green; `playtest_report.json` error list empty. The freed-object crash reproduces in the terminal scenario (enemies die mid-round), so the terminal scenario is the regression probe.

---

## 4. Domain B — Terminal-battle balance

### 4.1 Authoritative numbers (design/20_content.md; never change these)

Player: HP **500**, regen **26/round** (20 × 1.3), melee DR **−50% flat**, move 4, init 88, basic **39** (30 × 1.3).
Player skills (all ×1.3, `round()` half-away-from-zero): Heavy Edge **59** cd1 · Great Craft (line 3) **49** cd2 · Thousand-Force Cleave (cross 2) **44** cd3 · Boundless Seas (square r2, self) **91** cd6 · Heart Strike **49** cd1 · Mud Drag **33** cd2 (move −2) · Wandering Valley (jump 3, adjacent 3×3) **26** cd3 · Seventeen Forms (adjacent, KB2) **91** cd8, gate **HP < 250**.
Enemy HP total **560**; effective ≈ 700–900 with Central's innate-qi guard, North's −15% Iron Bones, South's sustain (heal 46 cd4 / regen 13 / one-shot 78 below 40%), Qi Aegis shield **65**.

### 4.2 Intake budget (survivability envelope)

Total intake over R rounds must satisfy `500 + 26R − HP_final` → **508–633** for R=8, **612–737** for R=12, target **≈560–685** for R=10. Profile must be **convex — hot early, cool late**:

- **Rounds 1–3: ≥ ~118/round average** — cumulative intake must **exceed 354** by the player's round-4 turn (`500 + 4×26 − intake < 250`), or the 17 Forms gate stays closed and the skill_8 press no-ops.
- **Rounds 4–7: ≈ 60–70/round** as the melee cluster dies.
- **Rounds 8–10: ≈ 25–50/round** from the last straggler.
- **Death bound:** cumulative intake < 500 + 26×r at every round r.

Post-DR melee hits are 12–24 each (West basic 34→17, Ling Snake 31→16, Du Sha 23→12; North basic 36→18, Kang Long 47→24; Central basic 34→17, Quanzhen 42→21, Qixing 34→17) — the design's intended "not deadly" baseline. Ranged hits are **unreduced** and are the budget drivers: East basic **29**@3, Luoying **18**, Yuxiao **26**, Bihai **23** (global), counter **13**; South basic **31**@2, Yiyangzhi **39**, Dianxue **16**, Liu Mai **44**; North Qianlong **62** (r2). Chips feed the budget too: West reflect **16** per melee hit on him, East counter **13** per attack within 3 (max 1/round), poison DoTs unreduced (10×2, 8×2).

### 4.3 Melee vs ranged classification (Architect's ruling)

**Ranged ⇔ the attack's declared reach is > 1.** The enumerated ranged set (bypasses −50%) is exactly: East Heretic **basic attack / falling_petals / tidal_melody** (his jade_flute_acupoint is a control skill whose damage classifies melee — see below), South Emperor **basic / solar_finger / six_pulse_volley**, North Beggar **hidden_dragon (Qianlong)**. **Everything else is melee** — including the borderline reach-based skills: West's **toad_swarm (line 4)** and **basic**, Central's **primal_unity (global)** and **seven_stars (cross 2)**, North's **dragon_in_the_field (line 3)** and **flying_dragon (landing 3×3)**, East's **jade_flute_acupoint**.

Implementation: replace the current distance-at-resolution `_is_melee(unit, target)` heuristic (combat_manager.gd ~:1404) with a **declaration-based** classification — `_is_melee_attack(unit, skill_or_basic)` = `reach <= 1` OR skill id in the borderline-melee set `{toad_swarm, primal_unity, seven_stars, dragon_in_the_field, flying_dragon, jade_flute_acupoint}`. Basic attacks classify by `attack_range <= 1`. This drives both the Shen Diao DR and the West Poison reflect trigger. 弹指神通 counter stays **distance-based** (within 3 tiles, once/round) — unchanged. Solar Finger's `ignore_damage_reduction` flag stays unchanged (no double-apply).

### 4.4 AI engagement policy (the only legal balance knobs, with the timeline)

**Melee trio (West Poison, North Beggar, Central Divine) — attack from adjacency most turns.** Their post-DR hits are affordable AND their presence inside the player's radius-2 envelope feeds Boundless Seas / Cleave / 17 Forms. Preserve the existing "approach then hold-adjacent" behavior. West's Toad Squat (stand + charge at dist 2–4) is a natural small throttle — keep. Central's Qi Aegis is a shield turn — keep (one wasted offensive turn is budget-friendly late).

**Ranged pair (East Heretic, South Emperor) — the throttle that matters.** East Heretic attacks nearly every turn today (Tidal > Petals > Flute > basic). Required behavior:
- **Tidal Melody once, round 1** (its −20 init makes the player act last in rounds 2–3 — that ordering is load-bearing for the intake ramp and the terminal timeline; keep it).
- Rounds 1–3 (the hot ramp): keep attacking — Petals / Flute / basic at range ≤ 3; this is where the ≈118/round intake comes from.
- Rounds 4+ (the cool-down): throttle to ≈ half his turns via **deterministic predicates** (never RNG): e.g. basic only when `current_round % 2 == 0`, else Peach Blossom Maze / hold (action `"wait"`); keep him parked **inside the player's radius-2 envelope** (no retreat) so the late-game Boundless Seas can catch him.
- South Emperor: Primal Breath heal on cooldown is already a throttle turn — keep it first-priority; attack only from range ≤ 2 (Solar Finger / Acupoint / Six-Pulse); do NOT add extra idleness.

The exact predicate thresholds are tuned **iteratively against the harness** (they are pure state functions; every change stays deterministic). The design freezes the *shape* of the policy; the PM's tasks fix the exact predicates, with the harness as oracle.

### 4.5 Frame-budget coupling

More melee actions per round ⇒ enemy phases cost more frames. Keep per-action tween counts small (one move-path tween + one action tween per enemy turn; never add decorative tweens). Monitor `debug_await_total / timeouts / frames`; a full enemy round must stay inside ≈ 150–240 frames. **If an enemy phase overruns a scheduled keypress, the press no-ops and the whole deterministic chain desyncs** — the re-timed timeline (§7.6) must leave ≥ 30-frame margins after each measured round boundary.

### 4.6 Acceptance loop (how B gets green)

1. Implement §4.3 classification + §1.1 number-follow (no AI change yet) → run harness → capture baseline intake/round-boundary frames via `debug_round_frame`.
2. Implement §4.4 AI policy → re-run → read the deterministic HP trace per round; adjust predicates so intake matches §4.2 (convex, > 354 by round-4 player turn, < death bound).
3. Re-time the terminal timeline presses to the measured boundaries (keep skill order: skill_1 → skill_4 → skill_3 → skill_8 → cleanup; skill_4 is ready again at round 8, cd6 from round 2).
4. Sample the victory moment (state stays WON, `current_round`/HP freeze after `end_battle`) and pin the final asserts: WON, round ∈ [8,12], HP ∈ [75,200].

---

## 5. Domain C — Battle UI readability

### 5.1 Grid lines visible (design item 1)

The SummitBackdrop + flat floor tiles hide all cell boundaries. **Fix:** a new overlay node drawn above the tiles.

- **New file** `scripts/grid_lines.gd`: `extends Node2D`, `_draw()` draws the 14 vertical + 10 horizontal cell-boundary lines across [0, 960]×[0, 704] (1 px, semi-transparent dark ink color, e.g. `Color(0.1, 0.1, 0.12, 0.35)`), plus a slightly stronger border ring so the board edge reads. Expose `visible` semantics only — no logic.
- **`scenes/battlefield.tscn`**: add `[node name="GridLines" type="Node2D" parent="."]` with the script, **after** `Grid` and **before** `Characters` (child order = draw order). `z_index` left default.
- **`scripts/battlefield.gd`**: add observable `var grid_lines_visible: bool = true` (set after `_ready` wiring) for the YAML surface.

### 5.2 Health bar (design items 4, 5, 6) — ≤ 64 px bar, label above, no truncation

Current root is 120×40 with the name label inside and `clip_text + overrun 3` (ellipsis — forbidden). Fix in `scenes/ui/health_bar.tscn` + `scripts/ui/health_bar.gd`:

- **Root `HealthBar` Control: 110×30** (mouse_filter 2). `size` asserted on **the Bar, not the root** (see §7.4: expose `bar_width`).
- **`Bar` (ProgressBar): width 64, height 12, centered horizontally at the bottom** of the root. Recognizable bar: dark-red background via `StyleBoxFlat` (`add_theme_stylebox_override("background", ...)`), fill color driven by the existing green/yellow/red `modulate` logic, `show_percentage = false`, 1 px dark border.
- **`NameLabel`: anchored top, full root width (110 px), font 10, `horizontal_alignment = CENTER`, `clip_text = false`, `text_overrun_behavior = TRIM_NONE`** — above the bar, never overlapping it (design: 名字在血条之上).
- **Display aliases (English, no ellipsis, design explicitly allows shorter names):** `Yang Guo`, `E. Heretic`, `W. Poison`, `S. Emperor`, `N. Beggar`, `C. Divine`. The alias mapping lives in `battlefield.gd` where health bars are created (or in `hud.gd setup()`); `character_data.character_name` and node names stay unchanged (turn-order names, `order_names`, and `_name_of` must not change — protected scenario asserts depend on them). `name_text` (surface) carries the alias; the existing assert `HealthBar.name_text == "Yang Guo"` stays green.
- **`health_bar.gd` observables (new):** `var bar_width: float` (= Bar.size.x, refreshed in `setup()` and `_process`) and `var follow_delta: float` = pixel distance between the bar's anchor point (root center) and the character's projected screen position (`get_viewport().get_final_transform() * _char_node.global_position`), computed each frame in `follow_character()` **before** edge clamping. The existing stretch-aware transform + clamping code is preserved verbatim.

### 5.3 Skill buttons — four pairwise-distinct states + cooldown number (design item 2)

The `disabled=true`-only rendering is invisible. Fix in `scenes/ui/skill_button.tscn` + `scripts/ui/skill_button.gd` + `scripts/ui/hud.gd`:

- **New child `CooldownLabel`** (Label, centered, font 18, hidden by default): shows the **remaining rounds as a number** ("3", "2", "1") over the cooldown overlay; overlay keeps the top-fill fraction.
- **New child `StateTag`** (Label, top-right corner, font 8): "LOCKED" / "HP" / "" per state.
- **New observable `state_text: String`** — one of `"ready"`, `"cooldown"`, `"phase_locked"`, `"hp_gated"` — and **`cooldown_remaining: int`**, both written every frame by `hud.gd._refresh_skill_button_states`.
- **Visual states** (implemented as per-state style in `skill_button.gd._apply_state(state)`, driven by the same per-frame refresh that already computes `disabled` — logic unchanged, presentation added):
  1. **ready** — default button style, full modulate.
  2. **cooldown** — dark overlay (existing) + visible `CooldownLabel` number + slight desaturation.
  3. **phase_locked** (buttons 5–8, rounds 1–3) — gray tint (`modulate = Color(0.55, 0.55, 0.6)`), `StateTag = "LOCKED"`.
  4. **hp_gated** (button 8, HP ≥ 50%) — red tint (`modulate = Color(0.85, 0.4, 0.4)`), `StateTag = "HP"`.
  5. **selected** — bright border via a `StyleBoxFlat` override with a golden border color when `player.selected_skill_index == skill_index` (this is the fourth state of the design's 可用/禁用/冷却/已选中 quartet; phase-lock and hp-gate share the disabled family but differ in tint + tag).
- **Button text must not truncate:** shorten skill display names to fit 104 px at font 12: `Heavy Edge`, `Great Craft`, `Cleave`, `Boundless`, `Heart Strike`, `Mud Drag`, `Valley Jump`, `17 Forms` (set in `battlefield.gd`'s `_create_all_skill_data` player section — display-name-only change; skill ids / damage / cooldowns untouched). `Seventeen Melancholy Forms` is the one currently cut off.
- **8th button inside viewport:** SkillBar already spans 880 px at bottom-center; with 104-px buttons + small separation the 8 buttons fit. The geometric guarantee is the §7.4 assertion `HUD.skill8_right_edge <= 960`; if the re-layout overflows, shrink `custom_minimum_size` to 100 px (font 11) rather than moving the bar.

### 5.4 Round indicator vs pause button (design item 6) + compact order text

- **`scenes/ui/hud.tscn`:** RoundIndicator stays top-center but its rect must not reach the PauseButton (top-right, measured rect x ≈ 820–952, y 8–44). Current offsets (−240/+240 → x 240–720) already clear the pause *rect* at scale 1, but the OrderLabel (480 px wide, `clip_text` default-off) overflows its box and paints its text over the pause area — that is the visible 压盖. Set RoundIndicator offsets to a narrower box (e.g. left −180 / right 180 → x 300–660) **and** shorten the order line so the drawn text stays inside the box.
- **`scripts/ui/round_indicator.gd`:** the `OrderLabel` text must fit its box with **no clip/ellipsis**. Compact format using short tokens: `"Order: YG > EH > CD > SE > NB > WP"` (map via the same alias table; `order_names` observable keeps the full names — asserts on `order_names` stay green).
- **Overlap guard in code:** `hud.gd` computes a new observable **`round_pause_overlap: bool`** every frame: `RoundIndicator.get_global_rect().intersects(PauseButton.get_global_rect())`. YAML asserts `false` (plain property read — see §7.4).

### 5.5 Active-actor visibility (design item 3, partial)

`RoundIndicator.ActiveLabel` text becomes `"Active: Yang Guo · Move 4 · Act ✓"` (or `"· End"` after acting), built from `CombatManager.active_unit_name` + the player's `moves_left`/`acted` — one compact line, no new nodes. Full "at a glance" polish is out of scope; the four mandated 5_vision checks are covered by §5.1–5.4 plus the existing sprite-clamp work (item 7 already green from `jinyong-ui`).

---

## 6. Component List & Interfaces

| ID | Component | Files | Responsibility | Key interfaces |
|---|---|---|---|---|
| C1 | Turn engine hardening | `scripts/autoload/combat_manager.gd`, `scripts/autoload/grid_manager.gd` | Check-then-cast on stored refs (§3.2); declaration-based melee classification (§4.3); number-follow (§1.1) | `_next_turn`, `get_units_in_range`, `get_units_in_aoe`, `_is_melee_attack`, `_damage_reduction` |
| C2 | Content factory | `scripts/battlefield.gd` | Player 500 HP / regen 20 / alias table / short skill display names / `grid_lines_visible` | `_create_character_data`, `_create_all_skill_data` |
| C3 | AI controllers | `scripts/ai/ai_base.gd`, `ai_east_heretic.gd`, `ai_south_emperor.gd`, `ai_west_poison.gd`, `ai_north_beggar.gd`, `ai_central_divine.gd` | §4.4 engagement policy; pure functions of state, zero RNG | `evaluate(enemy) -> Dictionary {move_path, action, target, skill_index, params, fsm_state}` |
| C4 | Grid overlay | `scripts/grid_lines.gd` (NEW), `scenes/battlefield.tscn` | Cell lines above backdrop/tiles | `_draw()` |
| C5 | Health bar | `scenes/ui/health_bar.tscn`, `scripts/ui/health_bar.gd` | 64-px bar, label above, aliases, `bar_width`/`follow_delta` | `setup(name, max_hp, char_node)`, `follow_character()`, `update_health()` |
| C6 | Skill buttons | `scenes/ui/skill_button.tscn`, `scripts/ui/skill_button.gd`, `scripts/ui/hud.gd` | 4-state visuals, cooldown number, `state_text`/`cooldown_remaining` | `setup(skill, hotkey, fhd)`, `update_cooldown(remaining, total)`, `_apply_state(state)` |
| C7 | HUD geometry | `scripts/ui/hud.gd`, `scenes/ui/hud.tscn` | `skill8_right_edge`, `round_pause_overlap`, per-frame refresh loop | `_process`, `_refresh_skill_button_states` |
| C8 | Round indicator | `scripts/ui/round_indicator.gd`, `scenes/ui/hud.tscn` | Compact order text, active-actor line | `update_display(round, actor, order)` |
| C9 | Playtest contract | `playtest_spec.yaml` | Number-follow snapshots, geometric asserts, re-timed terminal + dot scenarios | §7 |
| C10 | Docs | `README.md` | Document new nodes/observables/aliases and re-run instructions | — |

**New files:** `scripts/grid_lines.gd`. **No scene/script deletions; no node renames** (surface names are a hard contract).

---

## 7. Playtest Contract (scene / actions / surface + scenario skeletons)

### 7.1 scene & actions

Unchanged: `scene: "res://scenes/main.tscn"`; the existing 16 actions in `project.godot [input]` cover every press the scenarios need. No new input actions.

### 7.2 Surface additions (additive — never rename/remove existing entries)

```yaml
CombatManager: [current_round, phase, active_unit_name, turn_order, turn_log,
                last_turn_actor, debug_await_total, debug_await_timeouts,
                debug_await_frames, debug_round_frame]   # + debug_round_frame (new: frame at which _begin_round ran)
HUD:          [visible, size, skill8_right_edge, round_pause_overlap]   # + 2 geometric observables
HealthBar:    [visible, global_position, size, name_text, bar_width, follow_delta]  # + 2
SkillButton1: [visible, text, fahui_text, disabled, hp_gated, state_text, cooldown_remaining]  # + 2 (all 8 buttons)
Battlefield:  [board_aligned, grid_lines_visible]   # + 1
```

`debug_round_frame` (int, `Engine.get_process_frames()` in `_begin_round`) exists purely to let the PM re-time press frames against measured round boundaries.

### 7.3 Geometric-assertion pattern (mandated by the brief)

The YAML Expression evaluator reads **live-node properties** — do not put method-call expressions (`get_global_rect().intersects(...)`) in asserts. Instead, every geometric question is answered by a **GDScript-computed observable** refreshed each frame:

| Brief requirement | Observable | Assert |
|---|---|---|
| Health-bar follows character | `HealthBar.follow_delta` (px from projected screen pos, pre-clamp) | `follow_delta <= 24` after a scripted move |
| Health-bar size ≤ 64 px, one cell | `HealthBar.bar_width` | `bar_width <= 64` |
| 8th button right edge in viewport | `HUD.skill8_right_edge` (= `SkillButton8.get_global_rect().end.x`) | `skill8_right_edge <= 960` |
| Round indicator vs pause non-intersection | `HUD.round_pause_overlap` (= `RoundIndicator.get_global_rect().intersects(PauseButton.get_global_rect())`) | `round_pause_overlap == false` |

All four are computed every `_process` frame at scale-1 viewport where HUD coordinates equal pixels.

### 7.4 New scenario skeleton — `ui_geometry_readability` (PM fills thresholds/frames)

```yaml
- name: ui_geometry_readability
  description: "Grid overlay exists; health bar <= 64 px and tracks the player across a move; 8th skill button inside the viewport; round indicator never overlaps the pause button; four button states are data-distinct."
  timeline:
    - { at: 3, actions: [ui_accept] }   # ... tutorial x7 (same preamble as other scenarios)
    # ...
    - at: 30
      actions: []
      assert:
        Battlefield.grid_lines_visible: true
        HealthBar.bar_width: 'bar_width <= 64'
        HUD.skill8_right_edge: 'skill8_right_edge <= 960'
        HUD.round_pause_overlap: 'round_pause_overlap == false'
        SkillButton5.state_text: 'state_text == "phase_locked"'
        SkillButton8.state_text: 'state_text == "phase_locked"'
        SkillButton1.state_text: 'state_text == "ready"'
        HealthBar.follow_delta: 'follow_delta <= 24'
    - { at: 40, actions: [move_up] }
    - { at: 55, actions: [move_up] }
    - { at: 70, actions: [move_up] }
    - at: 85
      actions: []
      assert:
        HealthBar.follow_delta: 'follow_delta <= 24'
        HealthBar.global_position: "changed"
```

State-visual *distinguishability* (the actual look) remains the external 5_vision visual gate's cross-frame question; the YAML asserts the data distinction the visuals are built from.

### 7.5 Scenario updates — content snapshots (mechanical design-follow)

- `two_phase_skill_unlock_and_hp_gate`: `Player.health: 360` → **500** at frame 30. All other asserts (disabled/hp_gated/current_round) unchanged — gate math follows `max_health` automatically (< 250).
- `terminal_victory_8_12_rounds_hp_15_40`: `Player.health: 360` → **500**; final band `health >= 54 and health <= 144` → **`health >= 75 and health <= 200`**; description text updated (15–40% of 500).
- `dot_resolves_at_victim_turn_start`: the exact-HP asserts 144/150 are stale against the 500-HP model and **must be recomputed, not preserved**. Method: after C1/C2 land, run the scenario, capture `Player.health` at the round-4 West Poison turn and at the round-5 player turn, **verify the round-5 value equals round-4 + 16** (26 regen − 10 poison tick), then pin both captured values. Structure stays: `status_names.has("poison")`, tick = `round(8×1.3) = 10`, description net-delta updated to +16.
- The other four protected scenarios (`round_one_snapshot_and_turn_order`, `enemy_acts_only_after_player_ends_turn`, `each_unit_acts_once_per_round_initiative_order`, `cooldowns_decrement_by_round`, `fahui_du_multiplies_damage`, `central_divine_innate_qi_fatal_guard`) keep every assert byte-identical — they are player-action-driven and AI-invariant; their enemy-HP numbers are unchanged by this run.

### 7.6 Terminal scenario re-time (skeleton — PM pins frames after measuring)

Keep the action skeleton and the frame-2999 victory assert; **re-time every press** to measured round boundaries (≥ 30-frame margin after each player-turn start; ≥ 15 frames between skill and basic):

```
tutorial x7 (3..15) → assert Player.health == 500
R1 (player first):  move_up ×3 → skill_1 → basic_attack → end_turn      [cluster on Central Divine]
R2 (player last, Tidal -20):  skill_4 (Boundless, 91, r2) → basic → end_turn
R3 (player last):  skill_3 (Cleave, 44) → basic → end_turn
R4 (player first, HP < 250):  skill_8 (17 Forms, 91, adjacent) → basic → end_turn
R5-R7:  skill_1 / skill_5 / skill_7 cleanup + basic + end_turn
R8:     skill_4 (Boundless ready again, cd6) → basic → end_turn
R9-R10: cleanup + end_turn
at 2999: current_state == "WON"; current_round in [8,12]; Player.health in [75,200]
```

`current_state` stays `"WON"` and `current_round`/`Player.health` **freeze at the victory moment** (`_next_turn` returns early once WON), so the frame-2999 sample is the victory-moment sample. If WON lands before round 8 (cluster dies too fast) → add South/East sustain predicates; if the player dies first (intake too hot) → strengthen the ranged-pair throttle; if the HP band is missed high/low → move straggler engagement, never content numbers.

---

## 8. Tech Stack

Godot 4.4 GDScript only (no third-party libraries): `is_instance_valid()` + untyped-Variant-first access (domain A); pure-function AI decision tables + the deterministic harness as oracle (domain B); native Control/Theme (`StyleBoxFlat`, `ProgressBar`, `ColorRect`, `Label` without clip/ellipsis), `Node2D._draw()` grid overlay, `get_global_rect()`/`get_final_transform()` geometry (domain C). `.gd` files are excluded from the linter manifest — the `gdscript_check` gate parses them with `godot --check-only` after every implementation step.

## 9. Extensibility & Non-Goals

- The alias table (`battlefield.gd`) is the single place future rosters extend health-bar/short display names; `character_name` (turn-order identity) stays canonical.
- The geometric-observable pattern (GDScript computes, YAML reads) is the reusable template for all future spatial asserts — never raw `get_global_rect()` expressions in YAML.
- The melee/ranged classification table (`_is_melee_attack`) is the one place reach semantics live; future content declares reach and gets the right DR for free.
- **Non-goals preserved:** no cultivation system / faction select / world map; no learning-prerequisite logic (fa hui du stays 1.3); no elemental counters; no CJK fonts; no change to enemy content numbers; no change to the six protected scenarios' behavior asserts; no removal of `TWEEN_TIMEOUT_SEC`/`_await_tween_safe`.

## 10. Rollback & Validation Strategy

No irreversible operations exist (no DB, no batch data rewrite; all edits are text-file edits under git). Validation order per task: (1) `gdscript_check` parse gate, (2) `run_tests.sh` headless playtest — the six protected scenarios must stay green at every intermediate commit; the terminal/dot scenarios are re-pinned only after the engine changes land and are measured. If an AI predicate overshoots, revert that single `scripts/ai/*.gd` edit — the git history keeps the prior decision table. `playtest_spec.yaml` edits are additive-first: new surface entries and new scenarios are appended; stale numbers are edited in place only where §7.5 lists them.

## 11. Task Decomposition Guidance (for PM)

1. **T1** — Freed-object hardening (C1, §3): the four mandatory sites + audit comments. Gate: parse + playtest zero errors.
2. **T2** — Design-follow numbers (C1/C2, §1.1): 500 HP / −50% DR / regen 20; update the §7.5 content snapshots. Gate: protected scenarios green with 500.
3. **T3** — Melee/ranged classification (C1, §4.3). Gate: protected scenarios still green (they don't exercise the new classification edge cases); terminal run still deterministic.
4. **T4** — AI engagement policy (C3, §4.4). Gate: terminal intake trace matches §4.2; WON in [8,12], HP in [75,200].
5. **T5** — Terminal + dot scenario re-time (§7.6, §7.5). Gate: full `run_tests.sh` green.
6. **T6** — Grid overlay (C4, §5.1). Gate: `grid_lines_visible` assert + 5_vision grid check.
7. **T7** — Health bar (C5, §5.2). Gate: `bar_width <= 64`, `follow_delta <= 24`, `name_text` aliases, 5_vision bar checks.
8. **T8** — Skill button states (C6, §5.3). Gate: `state_text`/`cooldown_remaining` asserts + 5_vision cross-frame button check.
9. **T9** — Round indicator + pause overlap (C7/C8, §5.4/§5.5). Gate: `round_pause_overlap == false`, no truncated text.
10. **T10** — Docs (C10): README update + final full-gate verification.

Tasks 1–3 are order-dependent (T3 builds on T2); T4–T5 depend on T3; T6–T9 are independent of each other and of T4/T5 (UI vs balance), so they can run in parallel lanes.

## 12. Assumptions & Decisions Record

- **Design overrides the brief's stale HP snapshot:** victory band is **75–200 (15–40% of 500)**, not 54–144; the 17 Forms gate is **< 250**, not < 180. (`step1_goals.json` / brief text still cite 360 — pre-change snapshots.)
- "Health-bar size ≤ 64 px" targets the **Bar width** (`HealthBar.bar_width`), not the root control (the name label above may be wider); the alias table guarantees no label truncation.
- `_is_melee` becomes declaration-based (§4.3); 弹指神通 counter stays distance-based; Solar Finger's `ignore_damage_reduction` is untouched.
- The 5_vision recognizability checks are external and cross-frame; this repo only supplies the geometric/data asserts.
- `GameManager.current_round` and `Player.health` freeze at victory (engine early-returns after WON) — the frame-2999 assert is the victory-moment sample by construction.
