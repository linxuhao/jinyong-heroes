# step2_design.md — Round: 「战斗要能结束」/ *The Battle Must Be Able to End*

## 1. Overview

This round fixes the one failure mode that poisons every combat conclusion: **a battle that cannot end**. All other combat verdicts (balance, win/lose routing, DoT premise) hang off it. The five goals, mapped to components:

| # | Goal | Approach chosen (from SOTA research) | Component |
|---|------|--------------------------------------|-----------|
| 1 | Player HP = 0 **must** end the battle | Structural (instance-id) death classification + a battle-over invariant seam + a committed regression scenario | C0/C1/C2 |
| 2 | `dot_resolves_at_victim_turn_start` — decide AI defect vs scenario premise | **Branch (b): scenario premise** (code-verified). Rewrite the scenario as a fixture: poison is *injected*, then tick timing is asserted | C3 |
| 3 | `save_load_roundtrip` 13/13 with **non-vacuous** deep-equality asserts | Test-side hardening first: non-empty precondition guards on all three equality asserts; fix the write side only if the probe proves it broken | C4 |
| 4 | Skill-bar waiting state visually distinct (vision Q3 bad votes ≤ 5/19) | Dramatically widen the waiting palette (darker, Δluma ≈ 0.23 vs ready) **and** add a `等待中` tag on all 8 buttons during enemy turns | C5 |
| 5 | Re-evaluate `terminal_victory_8_12_rounds_hp_15_40` | **Strictly gated on goal 1 landing.** Probe the losing line, re-script a correct gather+AoE play; balance change only via explicit design-change declaration | C6 |

Method discipline for the whole round (**先取值,再动手** — probe first, then change): every pin in a rewritten scenario is re-baselined from a probe run against the **current** code, never from memory of old numbers. Two outcomes are known in advance from the SOTA research and drive the design:

1. `_handle_death` in `scripts/autoload/combat_manager.gd` (line 1448) classifies the player **by name** (`target.name == "Player" or target.name == "YangGuo"`), while the engine already has a reference-equality helper `_is_player()` (line 1549) that the rest of the turn engine uses. The stuck-run scan's 8 identical samples (f820–f1100: hp=0, phase=ENEMY_TURN, active=Central Divine) are *byte-consistent with either* "battle stuck" or "battle properly ended LOST" — `end_battle(false)` never resets `phase`/`active_unit_name`, and the scan did not sample `current_state`. **PROBE #1 (current_state at the death window) is the disambiguator**, and the new regression scenario captures it permanently.
2. `ai_west_poison.gd` **can** poison (decision 2 = Spirit Serpent, adjacency-gated) but in 26 sampled frames of the losing battle West Poison was never adjacent to the player, so poison was never applied — the old scenario asserted frames that do not exist. The code-level verdict is **(b) scenario premise**; no AI code changes this round.

**Hard constraints (unchanged, non-negotiable):** `empty_round_stalls == 0`; 0 runtime errors; 0 compile errors; no `Trying to cast a freed object`; the 12 protected battle scenarios and all segment scenarios **not named by a goal** stay byte-identical; `current_state == "WON"` in the terminal scenario is never softened.

## 2. Architecture diagram (text)

```
DEATH PATH (goal 1) — every damage source converges on one pipeline:
  player skill / enemy AI / DoT tick / counter-reflect / debug hooks
    -> CombatManager.apply_damage(target, amount, source, is_melee, ignore_dr)
         DR -> shield absorb -> HP clamp (the ONLY place health reaches 0)
         -> fatal guards (先天罡气 / 铁布衫 clamp lethal to 1, survive)
         -> if still lethal: _handle_death(target)
              [FIXED C1] classify via _is_player(target)  (instance-id, name fallback)
                 + write debug_death_target_name / debug_death_classified_player [C0]
              player  -> GameManager.end_battle(false) -> LOST + 战败 overlay
              enemy   -> GridManager.free_tile + unregister_enemy + queue_free
                         (last enemy gone -> end_battle(true) via unregister_enemy)
    -> [NEW C1] belt-and-braces invariant: _check_battle_over()
         called at _begin_round() entry and end_current_turn() —
         if state is BATTLE and player.health <= 0 -> end_battle(false).
         Idempotent (end_battle no-ops on WON/LOST). Covers ANY future HP-zero
         path that bypasses apply_damage (hazard zones etc.).
    -> turn engine guards (EXISTING, unchanged): _next_turn() re-checks
         WON/LOST before/after every await; a terminated battle stops
         progressing, phase/active_unit_name are left as-is by design.

SAVE/LOAD (goal 3) — pipeline unchanged; only the TEST surface changes:
  cultivation menu -> SaveManager.save_slot(1)  [atomic 5-step write, unchanged]
     success -> has_save = true; snapshot_profile_json / snapshot_rng_state /
                snapshot_decks_string captured  (all-or-nothing)
  cultivation menu -> SaveManager.load_slot(1)
     success -> loaded_profile_json / loaded_rng_state / loaded_decks_string
  scenario asserts (CHANGED C4): non-empty precondition guard on every
     deep-equality assert -> a vacuous "" == "" pass is now impossible;
     has_save == true and last_error == "" pinned at the save frame.

WAITING RENDER (goal 4) — HUD wiring unchanged, palette only:
  HUD._refresh_skill_button_states (unchanged):
     phase != "IDLE" and not is_player_turn() -> btn.state_text = "waiting"
  SkillButton._apply_state -> state_palette("waiting")  [CHANGED C5]
     bg Color(0.12, 0.16, 0.22) (luma 0.1558), border Color(0.30, 0.36, 0.44),
     tag "等待中" on every visible button -> state_luma / state_tag_text observables
  playtest skill_bar_waiting_state (re-pinned) + vision gate Q3 (per-scenario ≤ 5/19)

DOT FIXTURE (goal 2):
  debug_poison_player input action -> GameManager._process -> 
     CombatManager.debug_poison_player() -> apply_dot(player, 8, 2, 1.3)
     (the REAL pipeline; stored tick round(8*1.3)=10, 2 rounds)
  tick at victim's own turn start via begin_turn -> _tick_statuses (unchanged)
```

## 3. Design decisions (rationale for downstream steps)

- **D1 — Death detection becomes structural.** Reference equality (`get_instance_id()`), already implemented as `_is_player()`, is the standard robust node-classification pattern in Godot and the engine already trusts it everywhere else (turn routing, `_begin_round`). Keeping a parallel name-check in one spot is exactly the drift the round theme is about. One-function change closes the whole misclassification class for tutorial ("Yang Guo"/"Player"), encounter ("ProgressionHero"), and sparring ("Sparring_Partner") nodes at once.
- **D2 — The battle-over invariant becomes a seam, not a call sprinkled around.** `_check_battle_over()` at the two turn-transition chokepoints (`_begin_round`, `end_current_turn`) makes "player at 0 HP while BATTLE ⇒ LOST" structural. Rationale for the belt *despite* `apply_damage` already calling `end_battle`: (a) the only unverified HP-zero path (hazard-zone damage site, PROBE #3 in SOTA) is automatically covered; (b) the seam is idempotent and costs nothing on healthy battles; (c) it protects against future damage paths forgetting the loss half — the historical failure was precisely an asymmetric seam (win half exists, loss half implicit).
- **D3 — DoT verdict is branch (b), scenario premise.** Code evidence: poison skills exist and are adjacency-gated; in the 26-point scan West Poison never reached adjacency; the AI's decision order is correct (basic attack, not poison, fires at dist ≤ 1 only after the two poison skills were already checked and not ready). No AI change. The scenario becomes fixture-driven per `design/30_presentation.md`'s pyramid rule ("DEBUG 接口要把状态置成 X"): the first asserted behavior is **poison IS applied**, then timing (victim's own turn start, after cooldown decrement, before regen — `design/10_systems.md` §5.2 order) and duration (2 ticks, then expiry).
- **D4 — Save/load: test-side hardening before any write-side change.** `save_slot()` is a guarded atomic 5-step write and `snapshot_*`/`loaded_*` are captured all-or-nothing on success — the most probable cause of 9/13 is scenario drift (menu navigation or `save_refused` from the pending-swap/stable-state guards), not a broken write path. The guards make failure *visible at the right frame* instead of vacuous-green or late-red. `save_manager.gd` is only touched if the probe proves a write-side bug.
- **D5 — Waiting contrast via dimming + text, not just luma.** Luminance alone cannot separate 5 states (the ready↔hp_gated gap is only 0.1854; the old waiting luma 0.26596 sat 0.12 from ready — below the vision model's threshold). The new palette moves waiting to luma ≈ 0.1558 (Δ ≈ 0.23 vs ready) and — decisively — adds a `等待中` tag on **all 8 buttons** during enemy turns, the same mechanism 锁定/气血 already use. Text appearing on every button is the strongest possible cross-frame signal for the vision model.
- **D6 — Goal 5 re-evaluation has exactly two exits.** After goal 1 lands, either (i) a correct gather+AoE script wins in 8–12 rounds at 15–40% HP → pin the existing asserts; or (ii) it does not → **explicit design-change declaration** (new `20_content.md` values + `99_changelog.md` row), never silent tuning, never softening `current_state == "WON"`.

## 4. Design-change declarations (for `5_design`)

No conflict with the `design/` record for goals 1–4: they are bug fixes and test hardening fully consistent with the record (which itself documents the stuck battle, the non-existent poison frames, and the pairwise-distinctness requirement). The only *potential* record change is **conditional**:

> **Conditional declaration (goal 5):** if, after goal 1 lands, a correct gather+AoE play of the tutorial battle (per `design/10_systems.md` §5.4–5.5 and `20_content.md` roster) still loses, this run changes the balance numbers in `design/20_content.md` §1/§2 — the specific old→new values are determined by the goal-5 probe and listed in the PM task card as an explicit 设计变更 with: what changed, why, which playtest scenarios are impacted (only `terminal_victory_8_12_rounds_hp_15_40`). `5_design` then edits `20_content.md` and appends one row to `99_changelog.md`. If a correct play wins, **no design change is made** and the record's balance section is untouched. The `current_state == "WON"` assertion and the 8–12 round / 15–40% HP band are **never** softened in either exit.

## 5. Component specifications

### C0 — Death-path observables (CombatManager)

- **File:** `scripts/autoload/combat_manager.gd`.
- **Responsibility:** make the death classification observable so the regression scenario can assert *why* the battle ended, not just that it ended.
- **Interface (new surface vars, safe defaults):**
  ```gdscript
  var debug_death_target_name: String = ""   # node .name of the last _handle_death target
  var debug_death_classified_player: bool = false  # what the classifier decided
  ```
  Written at the top of `_handle_death()` on every call (after the `is_instance_valid` guard). Zero behavior impact.

### C1 — Structural death handling + battle-over invariant (goal 1)

- **File:** `scripts/autoload/combat_manager.gd`.
- **Change A — classify structurally.** In `_handle_death()` (line ~1453), replace the name-based block with:
  ```gdscript
  var is_player: bool = target.has_method("is_player") or _is_player(target)
  ```
  (`_is_player` already does instance-id equality with name fallback when `get_player()` is null; the `has_method` OR keeps the belt for any node with the Player script.) Then write the C0 observables and keep the existing player/enemy branches byte-identical.
- **Change B — invariant seam.** Add:
  ```gdscript
  ## Battle-over invariant: while a battle is live, a player at 0 HP MUST be a
  ## LOST state. Idempotent (end_battle no-ops once WON/LOST). Called from the
  ## two turn-transition chokepoints so ANY future HP-zero path (hazard zones,
  ## new damage sources) still ends the battle.
  func _check_battle_over() -> void:
      var state: String = GameManager.get_state()
      if state == "WON" or state == "LOST":
          return
      var player: Node = GameManager.get_player()
      if player != null and is_instance_valid(player) \
              and "health" in player and int(player.health) <= 0:
          GameManager.end_battle(false)
  ```
  Call sites: first statement of `_begin_round()` (after the re-entry guard at line 409) and at the end of `end_current_turn()` before `_next_turn()` (line 617). **Do NOT** touch the empty-round-order branch (line 448–465) — `empty_round_stalls == 0` must stay exactly as protected.
- **Explicitly unchanged:** `apply_damage` pipeline order, `_next_turn` WON/LOST guards, `end_battle` idempotency, `_begin_round`'s dead-unit filter.
- **Acceptance:** `tutorial_loss_restarts_tutorial` stays 5/5; `trait_combat_effects_and_twelve_slots` stays 22/22 (its 铁布衫 survive-at-1 asserts must be unaffected — the fatal guards still fire *before* death handling); `empty_round_stalls == 0`; the new C2 scenario is green.

### C2 — Regression scenario `player_death_ends_battle` (goal 1)

- **File (new):** `playtest/player_death_ends_battle.yaml`.
- **Responsibility:** the permanent regression test for the round's central invariant — from the frame the player reaches 0 HP, `current_state == "LOST"` with the 战败 overlay, forever; no silently continuing BATTLE, no empty-round stalls. This is also **PROBE #1** made permanent.
- **Skeleton:** replay the losing line of `terminal_victory_8_12_rounds_hp_15_40` — identical tutorial preamble (7× `ui_accept` at f3..15), `move_up ×3`, `skill_1`, `attack_confirm`, `end_turn` (f46..121), then `skill_4` / `attack_confirm` / `end_turn` at f620..650, then **no further input** (the player's turn is event-driven; the round-10 enemy phase kills the passive player). Sample the death window:
  ```yaml
  name: player_death_ends_battle
  description: 'Regression for the round invariant "the battle must be able to end": replays the losing line of terminal_victory (preamble + scripted passivity), and asserts that once the player reaches 0 HP the state is LOST with the 战败 overlay at every post-death sample — never a silently continuing BATTLE, empty_round_stalls stays 0.'
  timeline:
  - at: 3
    actions: [ui_accept]
  # ... 7x ui_accept at f3..15, move_up x3 / skill_1 / attack_confirm / end_turn
  #     at f30..121, skill_4 / attack_confirm / end_turn at f620..650
  #     (copy byte-identical from terminal_victory_8_12_rounds_hp_15_40.yaml)
  - at: <PM: pinned first post-death sample — implementer probes the exact frame where health hits 0, then samples every ~40 frames>
    actions: []
    assert:
      Player.health: health == 0
      GameManager.current_state: current_state == "LOST"
      GameManager.end_overlay_text: end_overlay_text.contains("战败") == true
      CombatManager.empty_round_stalls: empty_round_stalls == 0
      CombatManager.debug_death_classified_player: debug_death_classified_player == true
      CombatManager.debug_death_target_name: debug_death_target_name == <PM: pinned player node name>
  # ... 2-3 more identical samples spaced ~80 frames apart, last assert <= 2999
  ```
- **Probe procedure for the implementer (scratch run, not committed):** create a temporary yaml with sample entries at f740..f1100 every 40 frames asserting `GameManager.current_state: current_state == "BATTLE" or current_state == "LOST"` and read the actual values from the playtest report to find the death frame; then pin the committed scenario's frames and the `debug_death_target_name` value (expect `"Player"` — the tutorial node name — but pin what the probe shows).
- **Acceptance:** scenario green; `tutorial_loss_restarts_tutorial` 5/5 (both loss routes now structurally identical).

### C3 — DoT fixture + `debug_poison_player` (goal 2, branch b)

- **Files:** `project.godot` (new input action), `scripts/autoload/game_manager.gd` (wire the action), `scripts/autoload/combat_manager.gd` (the hook), `playtest/dot_resolves_at_victim_turn_start.yaml` (rewrite).
- **Hook** (mirrors the AI's Spirit Serpent values through the REAL pipeline, per `20_content.md` §2.2: 中毒 8/轮 × 2, fhd 1.3 → stored tick `round(8*1.3) = 10`):
  ```gdscript
  ## DEBUG hook (unbound harness action): apply Spirit Serpent poison to the
  ## player THROUGH THE NORMAL apply_dot pipeline (stored tick round(8*1.3)=10,
  ## 2 rounds). No-op when no battle is running. Fixture for the DoT scenario.
  func debug_poison_player() -> void:
      if not _battle_active():
          return
      var player: Node = GameManager.get_player()
      if player == null or not is_instance_valid(player):
          return
      apply_dot(player, 8, 2, DEFAULT_FA_HUI_DU)
  ```
- **Wiring:** `project.godot` `[input]`:
  ```
  debug_poison_player={
  "deadzone": 0.5,
  "events": []
  }
  ```
  `game_manager.gd` `_process` (next to the other debug branches):
  ```gdscript
  if Input.is_action_just_pressed("debug_poison_player"):
      CombatManager.debug_poison_player()
  ```
- **Scenario rewrite** (the brief's branch (b): the first asserted behavior is *poison IS applied*; tick timing and expiry follow; all exact frames/HP pinned by the PM from a probe run):
  ```yaml
  name: dot_resolves_at_victim_turn_start
  description: 'Fixture-driven DoT contract: debug_poison_player applies Spirit Serpent poison (stored tick round(8*1.3)=10, 2 rounds) on the player''s turn; the first asserted behavior is that poison IS applied. The tick then resolves at the VICTIM''s own turn start (after cooldown decrement, before 神雕之力 regen +26 — design/10_systems.md §5.2) and expires after the second tick.'
  timeline:
  - at: 3
    actions: [ui_accept]
  # ... 7x ui_accept at f3..15 (tutorial preamble, byte-identical)
  - at: 20
    actions: [debug_poison_player]
  - at: 40
    actions: []
    assert:
      Player.status_names: status_names.has("poison") == true
  - at: 60
    actions: [end_turn]
  - at: <PM: first player-turn frame after the round-1 enemy phase, pinned from probe>
    actions: []
    assert:
      CombatManager.phase: phase == "PLAYER_TURN"
      Player.status_names: status_names.has("poison") == true
      Player.health: health == <PM: pinned value>
  - at: <PM: +20 frames>
    actions: [end_turn]
  - at: <PM: second player-turn frame, pinned from probe>
    actions: []
    assert:
      Player.status_names: status_names.has("poison") == false
      Player.health: health == <PM: pinned value>
  ```
- **Semantics the pins must respect:** tick #1 at the victim's first turn start (−10, rounds 2→1, poison still present), tick #2 at the second (−10, rounds 1→0, removed). Regeneration +26 fires *after* the tick; enemy damage between the turns is deterministic (zero-RNG engine, fixed script) so the HP pins are exact. The player survives (500 HP, only one enemy phase per tick).
- **Explicitly unchanged:** `ai_west_poison.gd`, `_tick_statuses`, `apply_dot` semantics (tick captured at application; `source = null` so no reflect/lifesteal off poison).
- **Acceptance:** scenario green with a real poison lifecycle; no AI file touched.

### C4 — Non-vacuous save/load asserts (goal 3)

- **File:** `playtest/save_load_roundtrip.yaml` (asserts only; timeline unchanged unless the probe proves navigation drift).
- **Change — frame 310 (save must have REALLY succeeded):** add
  ```yaml
      SaveManager.snapshot_profile_json: snapshot_profile_json != ""
  ```
  keeping `has_save == true` and `last_error == ""`.
- **Change — frame 490 (deep equality, vacuous pass impossible):**
  ```yaml
      SaveManager.loaded_profile_json: snapshot_profile_json != "" and loaded_profile_json == snapshot_profile_json
      SaveManager.loaded_rng_state: snapshot_profile_json != "" and loaded_rng_state == snapshot_rng_state
      SaveManager.loaded_decks_string: snapshot_profile_json != "" and loaded_decks_string == snapshot_decks_string
  ```
  (The profile-snapshot guard is the sound non-vacuity witness for all three: `snapshot_*`/`loaded_*` are captured all-or-nothing on success only. `loaded_profile_json != ""` is folded into the equality side by the guard.)
- **Probe (PROBE #5) + decision tree** — implementer records at f310/f490: `has_save`, `last_error`, `snapshot_profile_json == ""`?, `CultivationScreen.month/year`, `SceneManager.pending_swap`:
  - `has_save == false` or `last_error != ""` → record the **concrete** string. `"save_refused"` ⇒ the menu's save press landed while the stable-state/pending-swap guard refused it (navigation drift) ⇒ **re-baseline the scenario's menu navigation** from a probe (fix the yaml input sequence; `save_manager.gd` untouched). `"io_error"` / `"no_save"` ⇒ write-side bug ⇒ fix `save_manager.gd` (implementation-side, per SOTA).
  - `has_save == true` but `month != 3` ⇒ the month-advance pins drifted ⇒ re-pin from the probe.
- **Explicitly frozen:** splitmix64 constants (`save_manager.gd:65-67`) — known to be wrong (int64 overflow, errors every call) but changing them silently changes the RNG stream; out of scope this round, documented for a future run.
- **Acceptance:** `save_load_roundtrip` 13/13, with the three equality asserts non-vacuously true.

### C5 — Waiting-state contrast (goal 4)

- **Files:** `scripts/ui/skill_button.gd` (palette + doc comments), `playtest/skill_bar_waiting_state.yaml` (re-pin), `tests/test_skill_button_states.gd` (if it pins the old waiting palette — verify during implementation), `README.md` (luma reference).
- **Change — `state_palette("waiting")` entry becomes:**
  ```gdscript
  "waiting":
      # "It is not your turn": dark desaturated cool blue-gray PLUS the 等待中
      # tag on every button (same mechanism as 锁定/气血). bg luma:
      # 0.2126*0.12 + 0.7152*0.16 + 0.0722*0.22 = 0.155828 (raw BT.709,
      # Color.get_luminance()). Δ vs ready 0.3874 ≈ 0.23 (was 0.12 — the
      # vision model could not see the old subtle dim); text appearance is the
      # primary cross-frame signal.
      return {
          "bg_color": Color(0.12, 0.16, 0.22),
          "border_color": Color(0.30, 0.36, 0.44),
          "border_width": 1,
          "tag_text": "等待中",
      }
  ```
  Update the three doc-comment blocks that pin the old numbers (the state table at ~line 210, the `state_luma` var comment at ~line 64, the `state_luma_value` comment at ~line 277).
- **Pairwise distinctness check (all five states, `design/30_presentation.md` item 2):** ready 0.3874 no tag · cooldown 0.0814 + number · phase_locked 0.5306 + 锁定 · hp_gated 0.2020 red + 气血 · waiting 0.1558 + 等待中. Waiting separates from cooldown/hp_gated by tag/text and hue (dark blue-gray vs near-black+number vs dark red), from ready by Δ0.23 luma + tag, from phase_locked by Δ0.37 luma + different text. The four player-turn palettes are **untouched** — their luma pins in `skill_button_visual_states.yaml` stay green.
- **Re-pin `playtest/skill_bar_waiting_state.yaml` frame 210:**
  ```yaml
      SkillButton1.state_luma: state_luma >= 0.14 and state_luma <= 0.17
      SkillButton1.state_tag_text: state_tag_text == "等待中"
  ```
  (`state_text == "waiting"` / `state_text == "ready"` asserts stay byte-identical.)
- **Sampling enrichment (editable scenarios only):** ensure the vision gate captures ≥ 1 enemy-turn frame per scenario it can: `dot_resolves_at_victim_turn_start` and `terminal_victory_8_12_rounds_hp_15_40` (rewrites) and `player_death_ends_battle` (new) each include enemy-turn `actions: []` entries; `skill_bar_waiting_state` already captures f210. **Protected scenarios are not edited** — their Q3 votes come from whatever frames the gate already captures, and the dramatic waiting change makes any captured enemy-turn frame vote YES.
- **Acceptance:** `skill_bar_waiting_state` green (7/7 with re-pinned values); `skill_button_visual_states` green; `vision_report.json` Q3 per-scenario bad votes ≤ 5 of 19 battle scenarios (per-scenario counts are authoritative — the gate aggregate is not).

### C6 — Terminal victory re-evaluation (goal 5, **gated on C1/C2 landing**)

- **File:** `playtest/terminal_victory_8_12_rounds_hp_15_40.yaml` (timeline only; the four final asserts are frozen).
- **Phase 1 (probe):** run the current script after C1. Expected: explicit **LOST at round 10** (the goal-1 fix makes the loss visible instead of a silent stuck state). Record the full losing line (player HP per round, enemy positions).
- **Phase 2 (re-script):** replace the timeline with a correct gather+AoE play per `design/10_systems.md` §5.3–5.5. Hard requirements for the script:
  - Only the 8 tutorial skills, respecting cooldowns and the two-phase unlock (rounds 1–3: 玄铁剑法 skills 1–4 only; round 4+: 黯然销魂掌 skills 5–8; 十七式 additionally HP < 50%).
  - Damage math the script must exploit (all ×1.3, `round()` half-away-from-zero): 四海无量 radius-2 self **91** each (455 on a 5-man cluster — the intended clear), 力斩千钧 cross-2 **44**, 大巧不工 line-3 **49**, 徘徊空谷 landing-adjacent **26**, 重剑无锋 **59** (cd 1 filler), 十七式 adjacent **91**. Enemy HP totals 560; 中神通's 先天罡气 survives the first lethal at 1 (plan an extra hit); 南帝's 一阳续命 heals 78 once below 40% (expect it).
  - Survival math: 神雕之力 +26/turn, melee DR −50% (remote specialists 东邪/南帝 bypass it — kill or out-range them early per the design's own articulation).
- **Phase 3 (decision, exactly two exits):** (i) correct play wins → pin the probe's frames, the four existing asserts (`WON`, round ∈ [8,12], HP ∈ [75,200], `turns_taken` changed) go green → **no design change**; (ii) correct play cannot win in band → **trigger the §4 conditional design-change declaration** with concrete old→new values in the PM task card → `5_design` edits `design/20_content.md` + appends `99_changelog.md`.
- **Acceptance:** scenario 6/6, or a documented design-change declaration with the scenario 6/6 after re-balance. `current_state == "WON"` never softened.

### C7 — Playtest contract updates (`playtest/_common.yaml`)

- **`actions`:** append `- debug_poison_player` (after `debug_enter_encounter`).
- **`surface` `CombatManager`:** append `- debug_death_target_name` and `- debug_death_classified_player`.
- **`scenario_order`:** insert `- player_death_ends_battle` after `terminal_victory_8_12_rounds_hp_15_40` (file basename must equal `name:`).
- **Documentation:** `README.md` — add `debug_poison_player` to the debug-action table; update the waiting-palette luma reference (0.26596 → 0.1558 + 等待中 tag); update scenario count and the testing-section status lines for the three rewritten scenarios + the new one.

## 6. Tech stack

- **Runtime/engine:** Godot 4.4 (unchanged; `config/features=4.7` pre-existing and accepted). No engine or library swaps — every alternative would violate the protected scenarios.
- **Language:** GDScript for all code changes (no new Python; the repo's Python is harness-only).
- **Testing:** existing playtest harness (per-scenario YAML under `playtest/`, `godot_playtest_scenario` via the godot-builder sidecar HTTP, ~50 s/run) — extended, not replaced. Assertion rule enforced throughout (from the design record): every assert value must contain a comparison/logical operator; `changed` is the exception.
- **Linters:** GDScript is parsed by the `gdscript_check` gate (NOT listed in `linter_manifest.json`, per harness convention); `.yaml` / `.json` / `.md` map to `basic`.

## 7. Determinism & protected scenarios

- The combat engine is already zero-RNG (pure functions of state); the new hooks (`debug_poison_player`, death observables) are deterministic state setters/readers through the real pipeline. No new randomness anywhere.
- **Protected (byte-identical, never edited this round):** every playtest scenario **except** the four the goals authorize — `dot_resolves_at_victim_turn_start`, `save_load_roundtrip`, `skill_bar_waiting_state`, `terminal_victory_8_12_rounds_hp_15_40` — plus the two new files (`player_death_ends_battle.yaml`, contract entries). In particular: `each_unit_acts_once_per_round_initiative_order` (15 asserts), `two_phase_skill_unlock_and_hp_gate` (20), `tutorial_loss_restarts_tutorial` (5), `trait_combat_effects_and_twelve_slots` (22), `cultivation_changes_combat` (30), `spine_to_ending`, `central_divine_innate_qi_fatal_guard`, `fahui_du_multiplies_damage`, `cooldowns_decrement_by_round`, `round_one_snapshot_and_turn_order`, `enemy_acts_only_after_player_ends_turn`, `skill_button_turn_overlay`, `ui_geometry_readability`, `skill_button_visual_states`, and all segment/spine scenarios.
- **Hard invariants:** `empty_round_stalls == 0`; 0 compile errors; 0 runtime errors; no freed-object errors; no `input_dead`.

## 8. Irreversible-operation safety

- **No irreversible operations exist in this design.** No database/schema migrations, no bulk data rewrites, no save-format change (existing `user://save_<slot>.json` files remain valid and untouched).
- The only edits are code + test files, all reversible via git. `save_manager.gd` is edited only if the C4 probe proves a write-side bug, and any such edit must preserve the existing atomic 5-step write protocol (write `.tmp` → validate → backup old → rename → re-validate → drop backup, restore-on-failure) — that protocol already implements "backup → execute → validate → then remove old".
- Scenario rewrites are done as *re-baselined replacements*, and each rewritten yaml is verified green before the run reports success; the previous content remains recoverable from git history.

## 9. Task decomposition boundaries (for the PM)

Stages are ordered by dependency; within a stage, tasks are single-responsibility. **Every numeric pin marked `<PM: ...>` is filled from an implementer probe run, never from memory.**

- **T0 — Contract skeleton (C0 + C7):** add the two CombatManager observables + write them in `_handle_death`'s classification site (no branch behavior change yet), add `debug_poison_player` (action + `game_manager` wire + `CombatManager` hook), update `_common.yaml` (actions/surface/order), drop in the two skeleton scenario files with placeholder frames, update `README.md` wiring notes. Expectation: all 26 existing scenarios keep their current status; the new scenario is red until T1.
- **T1 — Goal 1 (C1 + C2):** structural classification + `_check_battle_over()` + complete `player_death_ends_battle` with probe-pinned frames. Verify: new scenario green; `tutorial_loss_restarts_tutorial` 5/5; `trait_combat_effects_and_twelve_slots` 22/22; `empty_round_stalls == 0`.
- **T2 — Goal 2 (C3):** rewrite `dot_resolves_at_victim_turn_start` fixture; probe-pin frames/HP. Verify: scenario green; no AI file touched.
- **T3 — Goal 3 (C4):** guards on `save_load_roundtrip`; run PROBE #5; apply the decision-tree branch (re-baseline navigation OR fix save code). Verify: 13/13 non-vacuous.
- **T4 — Goal 4 (C5):** waiting palette + tag + re-pin yaml + comment/README updates. Verify: `skill_bar_waiting_state` green; `skill_button_visual_states` green; vision Q3 per-scenario bad ≤ 5/19.
- **T5 — Goal 5 (C6):** **starts only after T1 is green.** Probe the losing line, re-script, and either pin the win or produce the conditional design-change declaration. Verify: 6/6 or declared re-balance with 6/6.

T2/T3/T4 are mutually independent and may run in parallel after T0; T5 strictly after T1. Each task's card cites the authoritative `playtest_report.json`/`vision_report.json` per-scenario counts.

## 10. Extensibility

- `_check_battle_over()` is the single invariant seam: any future damage source (hazard zones, environmental damage, new statuses) is automatically covered for the loss half without touching `apply_damage`.
- The debug-hook pattern (`unbound input action → GameManager._process → CombatManager fixture`) is the sanctioned way to inject battle states; future scenarios (buff application, forced adjacency, force HP thresholds) follow the same three-step shape.
- `debug_death_*` observables generalize to any classification-sensitive pipeline (e.g., future companion deaths).
- No new abstraction layers: all changes are local to existing components.

## 11. Out of scope (explicit)

- `each_unit_acts_once_per_round_initiative_order` (6/12, declared legacy) — **untouched**, protected.
- `two_phase_skill_unlock_and_hp_gate` (18/20, protected tutorial) — **untouched**.
- `ui_geometry_readability` / `round_pause_overlap` — **untouched**.
- `cultivation_month_cycle_and_deck_bookkeeping` (15/17) — **untouched**; note for 5_review: if the C4 probe shows a *shared* save-path root cause, the same guard pattern may be proposed in a future round, but this round does not edit it.
- `sect_switch_same_school_connects` — **untouched**.
- splitmix64 constants in `save_manager.gd` — frozen (documented in C4).
- AI code (`scripts/ai/*.gd`) — no changes (branch (b) verdict).
- GDScript unit-suite wiring (`tests/`, unwired) — declared non-goal; only incidental expectation updates if a test pins the old waiting palette.
- 桃花迷阵 zone-entry damage site (PROBE #3) — not hunted; the C1 seam covers its end-of-battle consequence regardless of where it lives.

## 12. Deliverable summary

| File | Change |
|------|--------|
| `scripts/autoload/combat_manager.gd` | C0 observables; C1 structural classification + `_check_battle_over()` + 2 call sites; C3 `debug_poison_player()` |
| `scripts/autoload/game_manager.gd` | C3 wire `debug_poison_player` in `_process` |
| `scripts/ui/skill_button.gd` | C5 waiting palette + tag + comment updates |
| `project.godot` | C3 `debug_poison_player` empty-events input action |
| `playtest/_common.yaml` | C7 actions + surface + scenario_order |
| `playtest/player_death_ends_battle.yaml` | C2 new regression scenario |
| `playtest/dot_resolves_at_victim_turn_start.yaml` | C3 fixture rewrite |
| `playtest/save_load_roundtrip.yaml` | C4 non-vacuous guards (+ navigation re-baseline if probe requires) |
| `playtest/skill_bar_waiting_state.yaml` | C5 luma re-pin + 等待中 tag assert |
| `playtest/terminal_victory_8_12_rounds_hp_15_40.yaml` | C6 timeline re-script (gated on T1) |
| `tests/test_skill_button_states.gd` | C5 expectation update only if it pins the old palette |
| `README.md` | debug action table, waiting luma, scenario counts/status |
| `linter_manifest.json` | `.yaml` / `.json` / `.md` → `basic` (`.gd` handled by `gdscript_check`, not listed) |

**Assumptions (for downstream steps):** (1) The vision gate captures frames at playtest timeline entries, so enemy-turn `actions: []` entries in editable scenarios are what feed Q3 — verify against the harness if per-scenario votes do not move. (2) The tutorial player node's `.name` is `"Player"` (the C2 pin is probe-verified, not assumed). (3) `DEFAULT_FA_HUI_DU == 1.3` in `combat_manager.gd` (already used by the existing poison path). (4) The pre-fix probe (current `terminal_victory` run) will show `current_state == "LOST"` once the battle is truly stuck-versus-ended — if it instead shows BATTLE continuing, C1 is *exactly* the fix that closes it, and C2 still goes green.
