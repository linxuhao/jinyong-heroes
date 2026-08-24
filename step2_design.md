# Step 2 — Architecture Design: Clearing the Five Red Lines

> Round goal: "这局游戏要能打赢" — make the five red-line scenarios pass on **observed values**
> from the headless playtest harness, and close the residual vision-gate gap (Q3) on the skill bar.
> Inputs: task card (goal definition), `Step_1/step1_sota.md` (SOTA research), `design/` (durable
> design record — all files read and honored). Every verdict in this design is traceable to an
> observed value or an audited contract line; no root cause is asserted from source-reading alone.

---

## 1. Overview / 概述

The game is already built: a **Godot 4.4+** turn-based wuxia tactics game — 15×11 grid tutorial
battle (Yang Guo vs. the Five Greats), a deterministic zero-RNG battle engine, `SaveManager` with
atomic IO, a cultivation segment (36 monthly cycles), and a **26-scenario playtest contract**
(`playtest/` + `playtest/_common.yaml`). This run is **not a feature run**: it is a
verification-and-correction run that makes the five red-line scenarios pass with honest evidence
and widens the waiting-vs-ready perceptual gap of the skill bar.

### The five red lines (from SOTA)

| # | Red line | Observed failure mode (from SOTA) | Fix surface |
|---|----------|-----------------------------------|-------------|
| 1 | `terminal_victory_8_12_rounds_hp_15_40` | Script plays scattered singles; single-target output **cannot** kill the Five by design (`design/10_systems.md` §5.4); skill-8 HP gate silently wastes a turn at frame ~1060 | Scenario script only |
| 2 | `each_unit_acts_once_per_round_initiative_order` | Scenario premise is wrong: `init_minus_20` (碧海潮生) legitimately drops Yang Guo's effective initiative 88→68, so round 2 begins with **East Heretic**, not Yang Guo (observed `turn_order` = [East Heretic, Central Divine, South Emperor, North Beggar, West Poison, Yang Guo] at 1200) | Scenario contract only; engine sort **untouchable** |
| 3 | `dot_resolves_at_victim_turn_start` | Absolute-frame pins (1430/2400) drifted with round pacing; HP pins 152/168 encode a full damage history | Scenario frame re-pin + damage-chain reconciliation |
| 4 | `save_load_roundtrip` + `cultivation_month_cycle_and_deck_bookkeeping` | Three deep-equality asserts (`loaded_* == snapshot_*`) pass vacuously as `"" == ""` when the save never succeeded; `has_save` is session-memory; `last_error` is sticky | Scenario discriminators + conditional `save_manager.gd` load-side fix |
| 5 | Vision Q3 (skill bar changes across enemy/player turns) | Waiting palette luma 0.26596 vs ready 0.3874 is a Δ≈0.12 dim that vision models miss (9 bad votes of 19 battle scenarios) | `skill_button.gd` waiting palette + luma window re-pin |

### Change surface

```
playtest/terminal_victory_8_12_rounds_hp_15_40.yaml          # rewrite script (C5)
playtest/each_unit_acts_once_per_round_initiative_order.yaml # rewrite contract (C2)
playtest/dot_resolves_at_victim_turn_start.yaml              # re-pin frames (C3)
playtest/save_load_roundtrip.yaml                            # add discriminators (C4)
playtest/cultivation_month_cycle_and_deck_bookkeeping.yaml   # add discriminators (C4)
playtest/skill_bar_waiting_state.yaml                        # re-pin luma window (C6)
scripts/ui/skill_button.gd                                   # waiting palette + "等待" tag (C6)
scripts/autoload/save_manager.gd                             # CONDITIONAL: load-side flags only (C4)
```

**Forbidden this round** (explicit non-goals, with rationale in §10): `scripts/autoload/combat_manager.gd`
(initiative sort is verified correct), the splitmix64 constants in `save_manager.gd` (deterministic
two's-complement wrap today — "fixing" them would silently change the RNG stream), any design number
in `design/20_content.md`, and any new dependency.

---

## 2. Architecture / 架构图

### 2.1 Layers

```
┌─────────────────────────────────────────────────────────────────────┐
│ L3 · Evidence layer (read-only, produced by the gate)                │
│   playtest_summary.md (observed column = primary diagnostic input)   │
│   compile_report.json · vision_report.json · final/verify_report.json│
└─────────────────────────────────────────────────────────────────────┘
        ▲  observed values              ▲  screenshots (Q3 votes)
        │                               │
┌───────┴───────────────────────────────┴─────────────────────────────┐
│ L1 · Harness layer (existing, UNCHANGED this run)                    │
│   godot-builder sidecar HTTP: /compile · /playtest · /script         │
│   run_tests.sh (POSTs to the sidecar — no local godot binary)        │
│   playtest/_common.yaml (scene/actions/surface + scenario_order)     │
│   godot_playtest_scenario tool (single-scenario run ≈ 50 s, overlays │
│   the implementer's pending edits over the repo copy before running) │
└───────┬──────────────────────────────────────────────────────────────┘
        │  timeline inputs + assert evaluations (frames ≤ 3000)
┌───────┴──────────────────────────────────────────────────────────────┐
│ L2 · Game layer (Godot 4.4+, GDScript)                               │
│   CombatManager (turn engine — READ-ONLY this run)                   │
│   HUD → SkillButton (state_text/state_luma observables, palette)     │
│   SaveManager (atomic IO, last_error vocabulary, snapshot vars)      │
└──────────────────────────────────────────────────────────────────────┘
        ▲  rewritten by C5/C2/C3/C4/C6
┌───────┴──────────────────────────────────────────────────────────────┐
│ L0 · Contract layer (this run's PRIMARY edit surface)                │
│   playtest/<scenario>.yaml — one file per scenario (blast radius = 1)│
└──────────────────────────────────────────────────────────────────────┘
```

### 2.2 Data flow (one red line, end to end)

```
edit playtest/<scenario>.yaml (or skill_button.gd)
   → godot_playtest_scenario (single-scenario run, ~50 s, headless Godot)
   → observed values per assert land in playtest_summary.md
   → implementer reads the OBSERVED column FIRST, forms a root cause
   → minimal edit (contract or code)
   → re-run until green
   → one full-suite run (~12 min) + vision gate at the end (C7)
```

### 2.3 Design principles (binding on all components)

1. **先取值,再动手** — observed value before every edit; a root cause without an observed value
   is not a root cause.
2. **Design numbers are authority.** `design/20_content.md` is the arithmetic source of truth.
   Never adjust numbers to go green. A genuine numeric mismatch is reported as a root cause
   against the design doc, not silently re-pinned.
3. **Engine correctness is off-limits.** The initiative sort (`combat_manager.gd` decorate-sort-
   undecorate stable insertion sort) and the zero-RNG AI priority lists are verified correct.
4. **Contracts may be fixed; premises may not be smuggled.** When a scenario's premise contradicts
   observed engine behavior, the contract is the bug (red line 2).
5. **Minimal change.** No new scenes, autoloads, assets, or dependencies. No new abstraction
   layers — the harness already provides everything.

---

## 3. Components / 组件列表

### C1 — Playtest contract & harness layer (existing, unchanged)

- **职责**: run scenarios headlessly, evaluate asserts against live nodes, emit
  `playtest_summary.md` (name | expr | actual | observed), `compile_report.json`,
  `vision_report.json`; per-scenario files make edits cheap and auditable.
- **接口**: `playtest/_common.yaml` (scene `res://scenes/main.tscn`, 26 input actions incl.
  `attack_confirm` and the `debug_*` set, `surface` whitelist of node→script-vars, frame cap 3000
  with last assert ≤ 2999). The header declares the schema was audited with zero drift — it is the
  authoritative name registry for this run.
- **涉及文件**: none edited. `run_tests.sh` must **not** be touched (it POSTs to the sidecar; the
  local-`godot`-PATH probe is a documented dead end).

### C2 — Initiative scenario: fix the CONTRACT, not the engine

- **职责**: rewrite `playtest/each_unit_acts_once_per_round_initiative_order.yaml` so the scenario
  asserts the **debuff's effect** instead of a wrong premise. Round 1: Yang Guo (88) first, then
  the five (85/80/76/74/70). Round 2: East Heretic's 碧海潮生 cast during round 1 applied
  `init_minus_20` (2 rounds) to Yang Guo, dropping his effective initiative to 68 — **below all
  five enemies** — so round 2 legitimately begins with East Heretic and Yang Guo acts last.
- **接口 (target contract)** — preamble unchanged (7× `ui_accept`, `end_turn` at 20); the frame-30
  asserts stay (they are correct). Replace the frame-1200 block with:

```yaml
- at: 1200
  actions: []
  assert:
    CombatManager.current_round: 2
    CombatManager.turn_order: turn_order.size() == 6 and turn_order[0] == "East Heretic" and turn_order[5] == "Yang Guo"
    CombatManager.turn_log: turn_log.size() == 11 and turn_log[0] == "Yang Guo" and turn_log[5] == "West Poison" and turn_log[6] == "East Heretic"
    Player.status_names: status_names.has("init_minus_20") == true
    Player.turns_taken: 1
    East_Heretic.turns_taken: 2
    Central_Divine.turns_taken: 2
    South_Emperor.turns_taken: 2
    North_Beggar.turns_taken: 2
    West_Poison.turns_taken: 2
    CombatManager.last_turn_actor: changed
    CombatManager.empty_round_stalls: empty_round_stalls == 0
```

  `turn_log.size() == 11` = round 1 (6 entries) + round 2's five enemies (5 entries) — Yang Guo's
  round-2 turn has **not** happened yet, which is the assertion that pins the reordering.
  A `phase == "ENEMY_TURN"` line at 1200 is optional and must be **pinned from the observed run**,
  not asserted a priori — drop it if the engine has already advanced the phase there.
  Description text must be rewritten to state the debuff-reordering premise.
- **验收标准**: scenario green in a single-scenario run; all values in the observed column match
  the contract above (frame 1200 was already observed to hold per SOTA — if the re-run disagrees,
  re-pin the **frame**, never the expectations).
- **硬约束**: `scripts/autoload/combat_manager.gd` initiative sort MUST NOT be modified. No code
  edits in this component at all.

### C3 — DoT timing: re-pin frames from observed values

- **职责**: re-pin the two assert frames of `playtest/dot_resolves_at_victim_turn_start.yaml`.
  Current pins (1430: round 4, West Poison active, poison applied, HP == 152; 2400: round 5,
  HP == 168) drifted — round pacing is faster than the old pins assumed.
- **接口/方法 (mandated sequence)**:
  1. Single-scenario run; if the existing asserts fire at the wrong rounds, add **temporary**
     diagnostic asserts every ~50 frames capturing `CombatManager.current_round`,
     `CombatManager.phase`, `CombatManager.active_unit_name`, `Player.status_names`,
     `Player.health`; read `playtest_summary.md` observed column.
  2. Locate frame F_a where West Poison applies 灵蛇缠身 (first frame with
     `status_names.has("poison")` while `active_unit_name == "West Poison"`) and frame F_t at the
     player's next turn start (poison tick).
  3. **Re-pin the input frames too** if the end-turn inputs at 400/800/1200 no longer land on the
     player's round-2/3/4 turns.
  4. Replace temporary diagnostics with the real asserts at F_a / F_t; remove the diagnostics from
     the final file.
- **HP pin rule**: the pins encode a full damage history — tick = `round(8 × 1.3)` = 10, 神雕之力
  regen = `round(20 × 1.3)` = 26, net **+16** per poisoned turn start, so 152 → 168. If observed
  HP ≠ 152/168 at the re-pinned frames, **reconcile the entire damage chain** (every enemy action
  on Yang Guo across rounds 1–4, attack side ×1.3 → `round()`, defense side −50% melee DR →
  `round()`, per-turn-start regen) against `design/20_content.md` and write the reconciliation
  into the plan **before** touching the numbers. Never adjust numbers to go green.
- **验收标准**: scenario green; the plan documents the observed F_a/F_t and (if changed) the
  reconciliation that justifies any HP pin difference.

### C4 — Save/load + cultivation: de-vacuate the deep-equality asserts

- **职责**: add non-vacuity discriminators so the three `loaded_* == snapshot_*` asserts mean
  something, and record `last_error` **values** at the failing-gate frames. Conditional code fix
  in `scripts/autoload/save_manager.gd` — only if observed evidence shows saved-but-broken.
- **接口 (new asserts)**:
  - `playtest/save_load_roundtrip.yaml`, frame 310 (post-save):
    `SaveManager.snapshot_profile_json: snapshot_profile_json.length() > 0`
    and `SaveManager.slot: slot == 1`. Keep `has_save == true` (session-memory: it is only legal
    here because the same run performed a successful `save_slot()` at ~285) and
    `last_error == ""` — the observed column records the VALUE if it fails.
  - Frame 490 (post-load): add `SaveManager.snapshot_profile_json: snapshot_profile_json.length() > 0`
    (the discriminator: empty ⇒ the save never succeeded and the deep-equalities are vacuous;
    non-empty ⇒ the save succeeded and any mismatch is a load-side flag bug). Keep
    `has_save == true` and the three deep-equalities.
  - `playtest/cultivation_month_cycle_and_deck_bookkeeping.yaml`, frame 200 (post-autosave): add
    `SaveManager.snapshot_profile_json: snapshot_profile_json.length() > 0`; keep
    `has_save == true`, `last_error == ""`.
- **决策树 (encode SOTA edge cases verbatim)**:
  1. `snapshot_profile_json` empty at 490 ⇒ the save never succeeded ⇒ read the observed
     `last_error` VALUE at 285–310: `"save_refused"` = a gate refused (slot 1..3 /
     `STABLE_STATES` / `SceneManager.pending_swap` in-flight window — never assert inside a swap
     window); `"io_error"` = stringify/file/validate step failed — hunt which key of
     `_build_save_dict()` (profile / decks / rng_state / segment) is unserializable (the
     `json_text == ""` guard maps that to `io_error`); `"no_save"` = file missing at load time.
     `last_error` is **sticky** — find the frame where it was set before attributing.
  2. Snapshot non-empty but `loaded_* != snapshot_*` ⇒ load-side flags broken ⇒ fix the load path
     in `save_manager.gd` only. The atomic 5-step write
     (tmp → validate → backup → rename → re-validate → drop backup, restore-on-failure) must not
     be weakened.
  3. `has_save` is session-memory (set by `save_slot()`, cleared by `new_profile()`, never by
     `load_slot()`) — never assert it after a cold start.
- **硬约束**: splitmix64 constants (`save_manager.gd` lines ~65–67) are **not** a blocker this
  round — they parse as two's-complement wraps and are deterministic; `loaded_rng_state ==
  snapshot_rng_state` passes. Do **not** "fix" them mid-round (it would silently change the RNG
  stream). Leave a comment noting the deferred cleanup.
- **验收标准**: both scenarios green; discriminators non-empty; any `save_manager.gd` edit is
  justified in the plan by an observed `last_error` value + frame.

### C5 — Terminal victory: rewrite the battle script (lure-cluster + AoE)

- **职责**: rewrite `playtest/terminal_victory_8_12_rounds_hp_15_40.yaml` so the script plays the
  one winnable pattern: **lure the Five into a cluster, then clear them with self-origin AoE**
  (四海无量 radius-2 ×2 casts, 力斩千钧 cross-2, 徘徊空谷 landing-adjacent, 黯然销魂十七式 adjacent
  when HP-gated). The current script's singles (重剑无锋/心惊肉跳 singles at 1300–2990) cannot kill
  560 HP + heals by design (`design/10_systems.md` §5.4).
- **接口 (target final asserts at 2999)**:

```yaml
- at: 2999
  actions: []
  assert:
    GameManager.current_state: current_state == "WON"
    CombatManager.current_round: current_round >= 8 and current_round <= 12
    Player.health: health >= 75 and health <= 200
    CombatManager.empty_round_stalls: empty_round_stalls == 0
    Player.turns_taken: changed
```

  `GameManager.current_state == "WON"` is the only win path (`unregister_enemy()` →
  `end_battle(true)` when `enemies_alive` empties) — if it is not WON at 2999, enemies are alive,
  by construction.
- **Script-authoring constraints (binding)**:
  - Inputs: the confirm key is **`attack_confirm`** (J). `"basic_attack"` exists only as the
    ENGINE action string inside AI decision dicts / `execute_action` — never as a timeline action.
  - Tutorial two-phase unlock: skills 5–8 are `phase_locked` until round 4 — do not press them
    before round 4.
  - Skill-8 HP gate: 十七式 requires HP < 250 (50% of 500). Before pressing `skill_8`, assert
    `SkillButton8.hp_gated: hp_gated == false` at that frame; otherwise the press is silently
    rejected and the turn is wasted.
  - 四海无量 cooldown 6 decrements at the player's own turn starts: cast on round r ⇒ ready again
    on the player's round r+6 turn — plan both casts into the 8–12 round window.
  - Keep the tutorial preamble (7× `ui_accept`) — this is the tutorial battle; the tutorial gates
    which actions advance it.
  - Prefer asserts on `current_round` / `phase` / `active_unit_name` / `status_names`; re-pin
    absolute frames from single-scenario runs (~50 s each).
  - Recommended mid-battle evidence anchors (assert, don't just hope): after each 四海无量 cast,
    assert ≥ 3 enemies with `health < max_health` (cluster hit); after the first 十七式 cast,
    assert its knockback/displacement effect.
- **决策树 (encode SOTA)**:
  1. WON fails and all five enemies alive at 2999 ⇒ damage never connected ⇒ cluster/AoE script
     defect or skill-8 gate rejection ⇒ fix the script (this is the expected failure mode).
  2. WON fails and 1–2 enemies alive at low HP ⇒ damage shortfall vs. the enemy heal budget
     (南帝 先天调息 46/use cd 4, 一阳续命 +13/round and +78 once below 40%, 中神通 shield 65/cd 5,
     北丐 −15% DR, 西毒 reflect) ⇒ tighten clustering; **AI engagement is the ONLY legal balance
     knob**, and using it requires an explicit design-change declaration + observed evidence.
  3. Player HP < 75 (or LOST) ⇒ survival pacing broken ⇒ kill early enemies faster / earlier
     first AoE.
  4. Budget: player raw output ≈ 698 × 1.3 if everything connects vs. ~560 HP + ~150+ heals —
     the margin is thin and clustering decides it.
- **验收标准**: WON with round ∈ [8,12] and player HP ∈ [75,200]; scenario green in the full suite;
  no engine/design numbers changed.

### C6 — Skill-bar waiting perceptibility (vision Q3)

- **职责**: widen the waiting-vs-ready perceptual gap so the vision gate's cross-frame Q3 votes
  turn good (current: 9 bad of 19 battle scenarios; target ≤ 5). The wiring is already correct —
  every visible button gets `state = "waiting"` each frame while `phase != "IDLE" and not
  is_player_turn()` (`scripts/ui/hud.gd` `_refresh_skill_button_states`); the residual problem is
  **perceptibility + sampling**, not wiring.
- **接口/改动**: edit **only** the `"waiting"` entry of `state_palette()` in
  `scripts/ui/skill_button.gd`:
  - **Rules (all must hold, verified with `Color.get_luminance()`, raw-component BT.709)**:
    state_text stays exactly `"waiting"` (surface contract stable); `disabled` untouched;
    presentation-only. Waiting must be pairwise distinguishable from all four player-turn states:
    Δluma vs ready (0.3874) ≥ 0.10 **and** a hue-family shift (blue-gray → violet/warm);
    Δluma vs cooldown (0.0814) ≥ 0.15; Δluma vs phase_locked (0.5306) ≥ 0.20; vs hp_gated
    (0.2020) distinguish on **hue** (violet vs red) in addition to luma. Add `tag_text: "等待"`
    (w1 tag weight — the mechanism already used by 锁定/气血) so the change is also textual.
  - **Recommended starting palette**: bg `Color(0.30, 0.20, 0.36)`, border
    `Color(0.50, 0.38, 0.58)`, border width 1, tag `"等待"` (expected luma ≈ 0.23 — implementer
    computes the exact value and re-pins the window). If the implementer finds a palette that
    satisfies the rules better, it wins — the rules are the contract, the palette is a proposal.
  - **Re-pin the derived asserts**: update the `state_luma` window in
    `playtest/skill_bar_waiting_state.yaml` (currently `>= 0.18 and <= 0.2874`) to
    `[luma − 0.02, luma + 0.02]` of the new palette, and update the two palette-table comments in
    `skill_button.gd` (the state table comment and the `state_luma_value` doc comment). The
    `state_text == "waiting"` / `state_text == "ready"` asserts stay byte-identical.
  - **Do NOT** touch the four player-turn palettes (ready/cooldown/phase_locked/hp_gated) — their
    luma asserts in `skill_button_visual_states.yaml` and the ready assert at frame 500 must stay
    green.
- **验收标准**: `skill_bar_waiting_state` and `skill_button_visual_states` green; full-suite
  vision gate per-scenario Q3 bad votes ≤ 5 of 19 battle scenarios; the Q3 fix is visible in
  captured frames (hue shift + 等待 tag), not merely a data-state change.

### C7 — Final verification & reporting

- **职责**: one full-suite run (~12 min) + vision gate after C2–C6 are individually green.
- **验收标准**: all five red-line scenarios green; the other 21 scenarios stay green (no file
  overlap with C2–C6 edits, engine untouched ⇒ zero expected collateral); `empty_round_stalls`
  stays 0; `playtest_summary.md` observed column backs every green; `final/verify_report.json`
  passes. No design file is edited by this run (see §9).

---

## 4. Interfaces / 接口规范

### 4.1 Scenario file schema (authoritative registry: `playtest/_common.yaml`)

- One file per scenario; basename **must equal** `name:`; `scene`/`actions`/`surface`/
  `scenario_order` live in `_common.yaml` only.
- `timeline` entries: `{at: <frame>, press: <action>}` or `{at: <frame>, actions: [...]}`;
  `press`/`actions` are the only keypress key names (an unknown key hard-fails).
- `assert` values: `changed` | YAML literal (scalar equality vs. the live node property) |
  **single-quoted GDScript boolean expression**. Every expression-style assert MUST contain a
  comparison/logical operator (`== != < > and or …`) or it is treated as a scalar string and
  silently never fires (`design/30_presentation.md` rule). Frame cap 3000; last assert ≤ 2999.
- Every scenario keeps ≥ 1 keypress; the terminal scenario ends at a terminal state (WON); the
  surface already contains progress variables (`current_round`, `phase`, `health`,
  `turns_taken`, `turn_log`, `status_names`, `state_text`, `state_luma`, …) — **no surface
  additions are required this round**. If an implementer needs a new observable, it must be added
  to `_common.yaml` `surface` first (one line, no schema change).

### 4.2 Input action names (project.godot `[input]` is authoritative)

`attack_confirm` (J) is the confirm/fire key. Doc-drift note: `design/30_presentation.md`'s input
table still names it `confirm` — the audited contract and `project.godot` use `attack_confirm`;
implementers follow `attack_confirm`. `"basic_attack"` is engine-internal only.

### 4.3 `SaveManager.last_error` vocabulary

`""` | `"no_save"` | `"bad_json"` | `"bad_version"` | `"bad_schema"` | `"save_refused"` |
`"io_error"` — sticky; written by the first failing op, cleared only on the next successful
save/load. Discriminator observables: `snapshot_profile_json` / `snapshot_rng_state` /
`snapshot_decks_string` (set on the save-success path only), `loaded_profile_json` /
`loaded_rng_state` / `loaded_decks_string` (set on load-success only), `has_save` (session-memory).

### 4.4 SkillButton state contract

`state_text` ∈ {`ready`, `cooldown`, `phase_locked`, `hp_gated`, `waiting`} (written every frame
by HUD; `waiting` is the presentation-only override during enemy turns); `state_luma` = the
applied palette's bg luminance, derived every frame via the cached static `state_luma_value()`;
`state_tag_text` renders the palette tag (`锁定`/`气血`/`等待`). Any palette edit automatically
flows into `state_luma` — only the YAML window needs re-pinning.

### 4.5 CombatManager observables used this round

`current_round`, `phase`, `active_unit_name`, `turn_order` (stable-sorted round snapshot),
`turn_log` (turn-end order), `last_turn_actor`, `empty_round_stalls` (must stay 0).

---

## 5. Tech stack / 技术选型

- **Engine**: Godot 4.4+ (stable), GDScript. All verification runs headless via the
  **godot-builder sidecar** HTTP endpoints (`/compile`, `/playtest`, `/script`); the pipeline
  container has no godot binary and never will — `run_tests.sh` stays as-is.
- **Contracts**: YAML scenario files + `_common.yaml`; **reports**: JSON
  (`compile_report.json`, `vision_report.json`, `final/verify_report.json`) and Markdown
  (`playtest_summary.md`).
- **Tools**: `godot_playtest_scenario` (primary — single-scenario ~50 s, overlays pending edits);
  full-suite run (~12 min) at the end. `playtest_summary.md`'s observed column is the mandated
  first read for every red line.
- **No new libraries/frameworks** (GdUnit4 confirmed non-goal; no local godot PATH probe; no new
  assets — the 等待 tag reuses the repo's CJK font). Linting: `.gd` is parsed by the
  `gdscript_check` gate (not in the linter manifest); `.yaml`/`.json`/`.md`/`.tscn`/`.tres` map to
  `basic` in `linter_manifest.json`.

---

## 6. Rollback & irreversible-operation policy

No irreversible operations exist in this run (no schema migrations, no bulk data rewrites, no
asset deletions). Standing rules, stated so implementers do not invent risk:

1. **All edits are text files under git** — revert = `git checkout` of the touched scenario/script.
   Per-scenario files bound every edit's blast radius to one scenario.
2. **SaveManager's atomic write protocol is untouchable**: tmp → validate → backup → rename →
   re-validate → restore-backup-on-failure. Any C4 fix must route through this protocol, never
   around it.
3. **Splitmix64 constants are frozen this round** — changing them is a silent RNG-stream change
   with playtest-wide fallout. Defer to a dedicated future run.
4. **user:// saves are runtime artifacts**; scenario runs must never delete user data. If a future
   run ever changes the save format: backup existing `user://save_*.json` → write new format →
   roundtrip-validate → only then remove backups (documented path, not exercised this round).
5. **Frame/number re-pins are contract fixes with evidence, not design changes** — every re-pin is
   recorded in the plan with the observed value that justified it (see §9).

---

## 7. Extensibility / 扩展性考虑

- **New scenario = new file** (+ optional `scenario_order` line) — the loader picks it up
  automatically; no other edit needed.
- **Palette centralization**: `state_palette()` is the single source for button-state visuals;
  `state_luma` derives automatically, so future state additions cost one palette entry + one
  luma-window re-pin.
- **Snapshot discriminators are reusable**: any future save scenario can import the
  `snapshot_profile_json.length() > 0` pattern to immunize its deep-equality asserts against
  vacuous passes.
- **Deliberately NOT built this round** (avoid over-design): no DEBUG "set state to X" injection
  interfaces (the design/30_presentation.md pyramid direction — future lever, unneeded for these
  fixes); no per-frame logging harness in the repo (temporary diagnostic asserts in a scenario
  file suffice); no refactor of `_common.yaml`.

---

## 8. Task decomposition for PM

All five red lines are file-disjoint (no two work packages touch the same file), so C2–C6
parallelize; C1 is context, C7 is the integration gate.

| # | Task | Files | Depends on | Gate |
|---|------|-------|-----------|------|
| T0 | Diagnostic pass: run the five red-line scenarios, record observed values (round/phase/HP/last_error/snapshot/Q3 votes) | — (read `playtest_summary.md`) | — | observed table in plan |
| T2 | Initiative contract rewrite | `each_unit_acts_once_...yaml` | T0 | single-run green |
| T3 | DoT re-pin + damage-chain reconciliation | `dot_resolves_at_...yaml` | T0 | single-run green |
| T4 | Save/load + cultivation discriminators (+ conditional `save_manager.gd` load-side fix) | `save_load_roundtrip.yaml`, `cultivation_month_cycle_and_deck_bookkeeping.yaml`, (`save_manager.gd`) | T0 | both single-run green |
| T5 | Terminal victory script rewrite (iterate the cluster/AoE plan) | `terminal_victory_8_12_rounds_hp_15_40.yaml` | T0 | single-run green; WON + round + HP pins |
| T6 | Waiting palette + luma window re-pin | `skill_button.gd`, `skill_bar_waiting_state.yaml` | T0 | single-run green + vision Q3 spot-check |
| T7 | Full suite + vision gate + report | — | T2–T6 | 26/26 scenarios green, Q3 bad ≤ 5/19, `final/verify_report.json` |

Expected iteration cost: T2/T3/T4 ≈ 1–3 single runs each (~50 s/run); T5 is the long pole (5–15
runs); T7 ≈ one full run (~12 min).

---

## 9. 设计变更 (design changes)

**No design changes this round.** `design/` files are not edited; `99_changelog.md` gains no row
from this run. Two boundary notes:

1. **Contract/frame re-pins are test-implementation fixes, not design changes.** They change only
   `playtest/*.yaml` frame numbers/asserts, each justified by an observed value recorded in the
   plan. Design numbers (`design/20_content.md`) are authority — any mismatch found in T3/T5 is
   **reported**, not silently absorbed.
2. **One conditional design-change path exists**: if T5 proves a genuine damage shortfall against
   the enemy heal budget, the only legal balance knob is **AI engagement**
   (`scripts/ai/ai_*.gd` priority dicts). Using it requires an explicit 设计变更 declaration with
   observed evidence and the exact new decision list, and it is only sanctioned after the script
   itself is verified to play the lure-cluster pattern. Doc-drift note for `5_design`:
   `design/30_presentation.md`'s input table names J's action `confirm`; the audited contract and
   `project.godot` use `attack_confirm`.

---

## 10. Risks & non-goals

- **Risks**: (a) T5's thin margin (698×1.3 raw vs 560 + ~150 heal/shield) means the script may
  need many iterations — budget accordingly; (b) upstream timing changes can drift frames again —
  the C3 method (assert on round/phase/status, pin frames from observed runs) is the defense;
  (c) vision Q3 votes carry sampling bias — the C6 fix attacks perceptibility so quiet samples
  still show the change; (d) `last_error` stickiness can misattribute — always record the VALUE
  and the frame it was set.
- **Non-goals**: `combat_manager.gd` edits (sort verified correct); splitmix64 constant changes;
  any design-number change; new scenes/autoloads/assets; new dependencies; GDScript unit-suite
  wiring (a separate, already-documented debt, not this round's theme); local godot PATH probing
  in `run_tests.sh`.
