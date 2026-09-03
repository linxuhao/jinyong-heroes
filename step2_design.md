# Technical Architecture Design — R4: Shrimp-Nickname Display Layer + R4 Bundle Cards

**Author:** Architect (Step 2) · **Date:** 2026-09-03 · **Input:** Project Brief (R4), Step 1 SOTA report (+ Step 1 review, all 5 suggestions incorporated), direct repo verification performed this run.

---

## 1. Overview

R4 flips every on-screen character name to the owner-locked shrimp nicknames (杨过→独臂大虾, 黄药师→东邪虾, 欧阳锋→西毒虾, 段智兴→南帝虾, 洪七公→北丐虾, 王重阳→中神通虾) by editing **only the display layer**, then lands four bundled cards: Card 0 (enemy-turn wall-clock, L1), Card N+1 (README slimming — already landed in R3d, residual only), Card N+2 (design-ledger slimming with verbatim archive moves), and the record-only roadmap card.

The architecture is deliberately **no-new-abstraction**: the rename edits four existing display dictionaries/copy sites in place; the new guarantees are pins (one pytest denylist, three surface observables + two playtest scenarios, one ledger-budget pytest), not new runtime systems. Card 0's fix stays inside the existing `combat_manager.gd` watchdog mechanism and Godot 4 `Tween` parallelism.

**Prime directive (restated from the brief, drives every section below):** `character_name`, node names (`East_Heretic`…), `turn_order` tokens, and the three verbatim gates (`facility_use_reusable`, `map_node_event_shaolin`, `map_battle_node_huashan`) are untouchable. If any display string is ever found sharing a field with an internal key, **stop and report** — never edit the key.

---

## 2. Verified repo state (facts this design stands on — all checked this run, 2026-09-03)

| # | Fact | Anchor |
|---|------|--------|
| 1 | Health-plate alias dict maps canonical→zh display, unknown names **pass through unchanged** (leak path) | `scripts/ui/hud.gd:17-24` (`_DISPLAY_ALIASES`), `:35` (`_alias_for`) |
| 2 | Order-bar token dict, `tr()`-wrapped; `active_actor` observable is the *tokenized* actor | `scripts/ui/round_indicator.gd:62-68` (`_ORDER_TOKENS`), `:97` (`_token_for`), `:137` |
| 3 | Active-line builder maps actor through `_token_for`, format contract "移动"/"行动 ✓"/"结束" | `scripts/ui/round_indicator.gd:99+`, exercised by `tests/test_skill_button_states.gd:197,207` |
| 4 | Tutorial + five-great `display_name` assignments (values only; `character_name` sits on the adjacent line) | `scripts/battlefield.gd:486, 505, 524, …` (same helper block through `:581`) |
| 5 | Hero walk-ons: `display_name = "侠客"` (ProgressionHero); `"陪练弟子"` (Sparring Partner, `character_name` on `:14`) | `scripts/data/battle_setup.gd:102`; `scripts/data/encounter_data.gd:14-15` |
| 6 | i18n: tutorial welcome zh key + EN value contain "Yang Guo"; character EN values are transliterations; walk-on EN values exist | `scripts/autoload/i18n.gd:122-123`, `:137-144` |
| 7 | Tutorial welcome body zh string | `scripts/autoload/tutorial_manager.gd:103-104` |
| 8 | AI scripts contain the six names **only in line-1 `##` comment headers** (never rendered) | `scripts/ai/ai_{east_heretic,west_poison,south_emperor,north_beggar,central_divine}.gd:1` |
| 9 | **Exactly two** playtest literals pin personal names (search re-run untruncated) | `playtest/round_one_snapshot_and_turn_order.yaml:41`; `playtest/ui_geometry_readability.yaml:42` |
| 10 | GDScript unit tests asserting display strings (tests/, not gates) | `tests/test_trait_effects.gd:204` (`display_name == "陪练弟子"`); `tests/test_skill_button_states.gd:197,207` (input `"杨过"`, **format-only** asserts) |
| 11 | README pin already exists and asserts: ≤ 200 lines, no round headings in README, exactly one 本轮变更 section, **12 verbatim heading constants in docs/ROUNDS.md** | `tests/test_readme_is_a_manual.py:22-35` |
| 12 | `docs/ROUNDS.md` carries **all 12** headings (`## Latest round: R3b` at :7, `## Previous round: R3` at :157, + 10 `## Round:`). Step 1's "10 vs 12" mismatch was a grep-pattern artifact (`^## Round` misses the Latest/Previous prefixes) | `docs/ROUNDS.md` |
| 13 | Root `README.md` is ~72 lines (4,906 B) — the brief's 1,712-line/119 KB premise is a stale pre-R3b snapshot | `README.md`, `final/delivery_notes_r3d_readme_manual.md` |
| 14 | Broken roadmap link confirmed (`见 ;` — missing filename) | `design/00_roadmap.md:3` |
| 15 | Ledger sizes: `90_decisions` 97,131 B · `40_ux_backlog` 109,879 B · `30_presentation` 79,408 B · `40_progression` 58,142 B · `20_content` 62,442 B · `00_roadmap` 27,874 B · `99_changelog` 162,824 B (append-only) | `design/` |
| 16 | Round pacing: 0.25 s tween watchdog + `_await_tween_safe()` + additive counters `debug_await_total/timeouts/frames`; round 1 ≈ 14–16 awaited tweens, local worst ≈ 240 frames/round | `scripts/autoload/combat_manager.gd:21-42, 124-135` |
| 17 | Surface registration point: `debug_await_*` at `playtest/_common.yaml:191-193`; append-only additions precedent (`map_battle_id` :210, `map_events_resolved_count` :211) | `playtest/_common.yaml` |
| 18 | Camera follower exists; camera scenario exists; occlusion watch + top-band flip observable exist (`STRIP_BOTTOM = 92.0`, `bar_anchors_below_portrait`) | `scripts/camera_follower.gd`; `playtest/camera_transform_follows_unit.yaml`; `scripts/ui/health_bar.gd:49,112` |
| 19 | Denylist prior art (token-level CJK list, scope docstring, hit reporting); i18n coverage guard extracts dict keys vs `tr()` call sites | `tests/test_event_prose_shrimp.py`; `tests/test_i18n_coverage.py` |
| 20 | `scenes/*.tscn` contain zero personal names (Step 1 verified; no scan hits expected) | `scenes/` |

---

## 3. Architecture (component map and data flow)

```
                     ┌── INTERNAL (frozen): character_name, node names, turn_order tokens,
                     │   map_battle_data.gd rosters, enemy.gd, the 3 verbatim gates
                     │
 OWNER RULING ──►    │                                    PLAYTEST HARNESS (Expression asserts)
 zh nickname table   │                                                ▲
 (C1, verbatim)      ▼                                                │
        ┌─────────────────────────────┐   new counters    ┌────────────────────────────┐
        │ DISPLAY LAYER (C2 edits)    │──────────────────►│ surface observables        │
        │ battlefield.gd display_name │   (C5.1)          │ (playtest/_common.yaml)    │
        │ hud.gd _DISPLAY_ALIASES     │                   └────────────────────────────┘
        │ round_indicator.gd _ORDER…  │                             ▲
        │ tutorial_manager.gd copy    │   new/extended scenarios    │
        │ battle_setup.gd / encounter │─────────────────────────────┘
        │ i18n.gd (zh keys + EN vals) │   (C5.2, C5.5, C8 frame proofs)
        └─────────────────────────────┘
                     │
                     ▼
        ┌─────────────────────────────┐      ┌──────────────────────────────────────┐
        │ PINS                        │      │ RECORD CARDS (no game code)          │
        │ C4 denylist pytest (new)    │      │ C6 README residual (R3d already landed)
        │ C7 ledger-budget pytest(new)│      │ C7 design/ slimming + archive moves  │
        │ C3 two yaml literal flips   │      │ C7.4 roadmap backlog + link fix      │
        └─────────────────────────────┘      └──────────────────────────────────────┘
```

Data flow of a rendered name: `character_name` (frozen) → display dict lookup (`_alias_for` / `_token_for`) → zh string = i18n **key** → `tr()` → zh locale renders the key byte-identically, EN locale renders the coined EN value. The rename therefore changes (a) dict **values** in the two UI dicts, (b) `display_name` values, (c) tutorial zh copy, (d) i18n **keys+values** — and nothing on the frozen side.

---

## 4. Component specs

### C1 — Nickname table (the single naming decision, locked here)

**zh (owner-locked, verbatim):**

| On screen now | New (verbatim) | Where rendered |
|---|---|---|
| 杨过 | **独臂大虾** | tutorial copy, plate, order bar, i18n key |
| 黄药师 | **东邪虾** | plate, order bar, i18n key, 20_content roster |
| 欧阳锋 | **西毒虾** | same |
| 段智兴 | **南帝虾** | same |
| 洪七公 | **北丐虾** | same |
| 王重阳 | **中神通虾** | same |

**Walk-ons — convention (made explicit per Step 1 review): `[identity noun] + 虾`** (the brief's 刀贩虾 pattern):

| On screen now | New zh | Coined EN | Rendered at |
|---|---|---|---|
| 侠客 (ProgressionHero display) | **侠客虾** | Wanderer Shrimp | plate, order bar (map/encounter battles) |
| 陪练弟子 (Sparring Partner display) | **陪练虾** | Sparring Shrimp | plate, order bar (encounter battle) |
| raw `ProgressionHero` leaking to screen | **侠客虾** (via new alias entry) | Wanderer Shrimp | the 2026-09-02 pt2 frame proves the leak |
| raw `Sparring Partner` leaking to screen | **陪练虾** (via new alias entry) | Sparring Shrimp | the 2026-09-02 pt3 frame proves the leak |

**EN translations (not owner-locked → coined here; primary set, recorded in the archive per C2/20_content):**

| zh key (new) | EN value (primary) |
|---|---|
| 独臂大虾 | One-Armed Prawn |
| 东邪虾 | East Heretic Shrimp |
| 西毒虾 | West Poison Shrimp |
| 南帝虾 | South Emperor Shrimp |
| 北丐虾 | North Beggar Shrimp |
| 中神通虾 | Central Divine Shrimp |
| 侠客虾 | Wanderer Shrimp |
| 陪练虾 | Sparring Shrimp |

**Compact EN fallback set — use ONLY if the EN order-bar frame capture (C8 #4) shows ellipsis/overflow:** Heretic Shrimp / Poison Shrimp / Emperor Shrimp / Beggar Shrimp / Divine Shrimp (+ One-Armed Prawn kept, Wanderer Shrimp kept). The decision (primary vs fallback) is recorded in the delivery notes either way. Rationale: EN order bar worst case ≈ 6 × 19 chars + separators; the compact set drops only the direction prefix, keeps the epithet+shrimp mapping unambiguous in-game.

Old zh display keys (杨过, 黄药师, …, 侠客, 陪练弟子) are **display strings, not internal keys** — they are removed from `i18n.gd` when replaced. Safety net: `tests/test_i18n_coverage.py` turns red on any missed `tr()` call site, so removal is guarded, not blind.

### C2 — Display-layer rename edits (file-by-file, exact; `character_name` lines untouched)

| File | Edit |
|---|---|
| `scripts/battlefield.gd` | 6 × `cd.display_name = "…"` values → zh nicknames (lines 486/505/524 and the same block through :581). Adjacent `cd.character_name = "…"` lines byte-identical. |
| `scripts/ui/hud.gd` | `_DISPLAY_ALIASES`: 6 value flips **+ 2 new entries** `"ProgressionHero": "侠客虾"`, `"Sparring Partner": "陪练虾"` (fixes the raw-name plate leak). Update the :12-16 comment block that claims names "fit the 64 px label" — wording only. |
| `scripts/ui/round_indicator.gd` | `_ORDER_TOKENS`: same 6 value flips + same 2 new entries. `_token_for`/`tr()` mechanism untouched. |
| `scripts/autoload/tutorial_manager.gd` | `:103-104` STEP_WELCOME body → `你是独臂大虾。击败五大高手，夺得华山论剑的胜者！\n\n按「继续」或回车继续。` (structure, punctuation, `\n\n` byte-identical otherwise). |
| `scripts/autoload/i18n.gd` | `:122-123`: the zh **key** becomes the new tutorial string (zh keys ARE display strings) + EN value → `You are the One-Armed Prawn. Defeat the five grandmaster shrimp and claim victory at the Duel at Mount Hua!\n\nPress "Continue" or Enter to continue.` · `:137-144`: 6 name entries → new zh keys + EN values from C1; `侠客`/`陪练弟子` entries replaced by `侠客虾`/`陪练虾`. |
| `scripts/data/battle_setup.gd` | `:102` `display_name = "侠客"` → `"侠客虾"` (`:101` `character_name = "ProgressionHero"` untouched). |
| `scripts/data/encounter_data.gd` | `:15` `display_name = "陪练弟子"` → `"陪练虾"` (`:14` `character_name = "Sparring Partner"` untouched). |
| `design/20_content.md` | Roster/copy occurrences of the six names → nicknames; canonical keys untouched; **append** a dated annotation block (2026-09-03): the owner ruling mapping, the coined EN names (C1), and the two walk-on coinings — this is the archive record for invented nicknames. |

**Explicitly NOT edited (with reason):**
- `scripts/ai/ai_*.gd` — names appear only in line-1 `##` comment headers documenting the canonical→AI mapping; comments never render. The denylist (C4) strips `.gd` comments for exactly this documented reason. Editing them would churn `gdscript_check` for zero on-screen effect.
- `character_name` fields, `scripts/data/map_battle_data.gd`, `scripts/characters/enemy.gd`, node names, `turn_order` tokens.
- `scenes/*.tscn` (zero names, verified), `assets/themes/global_theme.tscn/.tres`, `tutorial_overlay.tscn`, `roster_panel.tscn`, `sect_select.tscn`, `hud.tscn` (R1/R2 frozen).
- `assets/seed_manifest.json` (asset inventory, off-screen; out of scan scope per brief).
- The three verbatim gates.

### C3 — Gate literal updates (exactly two lines + the per-line table for delivery notes)

| File:line | Old (verbatim) | New (verbatim) | Why it yields |
|---|---|---|---|
| `playtest/round_one_snapshot_and_turn_order.yaml:41` | `RoundIndicator.active_actor: active_actor == "杨过"` | `RoundIndicator.active_actor: active_actor == "独臂大虾"` | Pins a display-name literal; the rename flips the tokenized actor. Rest of file byte-identical. |
| `playtest/ui_geometry_readability.yaml:42` | `HealthBar.name_text: name_text == "杨过"` | `HealthBar.name_text: name_text == "独臂大虾"` | Same. This gate's protected meaning is "stays green", not "never edits" — only this name literal may flip; its geometry/color asserts (:39-41, :43-45) are untouchable. |

Two GDScript unit-test display literals (tests/ are not gates; the same "display literal yields" rule applies; `character_name` asserts stay byte-identical):
- `tests/test_trait_effects.gd:204` — `"陪练弟子"` → `"陪练虾"` (**required**, else red).
- `tests/test_skill_button_states.gd:197,207` — input literal `"杨过"` → `"Yang Guo"` (**recommended**): asserts are format-only (`contains("移动")`, `ends_with("行动 ✓"/"结束")`), so the test stays green either way, but passing the canonical key exercises the real `_token_for` alias path and keeps tests/ free of display personal names.

### C4 — Personal-name denylist pin (new `tests/test_display_no_personal_names.py`)

stdlib pytest, mirroring `tests/test_event_prose_shrimp.py` (token-level list, scope docstring, `(file, line, token)` hit report). No new framework, no Godot dependency.

- **Denylist (token-level full names, never single chars):** 杨过, 黄药师, 欧阳锋, 段智兴, 洪七公, 王重阳. No English identifiers — "East Heretic" etc. are internal keys and are **out of scope by definition** (brief). Walk-ons are role nouns, not personal names; they enter the table only via C1's coinings.
- **Scanned (each with reason in the docstring):**
  - `scripts/**/*.gd` — **string literals only; `#` comments stripped before scanning** (documented reason: AI controller line-1 headers name canonical characters by design and never render).
  - `scenes/**/*.tscn` — full text (verified zero hits today; keeps the invariant).
  - `design/20_content.md` — the roster/copy record that feeds display.
- **Excluded (each with reason in the docstring):**
  - `tests/` — test fixtures may legitimately quote names (e.g. red-first records).
  - `assets/` — off-screen inventory (`seed_manifest.json`), per brief.
  - `docs/ROUNDS.md`, `design/99_changelog.md` — append-only round history quoting pre-rename names forever.
  - `design/90_decisions.md` — records the owner ruling itself, which must quote the old names to be meaningful.
  - `design/00_roadmap.md`, `design/40_ux_backlog.md` — task/queue records citing the ruling.
  - `design/30_presentation.md`, `design/40_progression.md` — measurement/round logs.
  - remaining `design/*.md` — verified zero name hits at pin-writing time. **Scope may widen later; narrowing is forbidden** (docstring rule).
- **Red-first:** run the pin BEFORE any rename edit; record the four values (assertion / observed hit list with file:line / frame-or-line context / greens-before-red) in `final/`. Expected pre-fix red: hits in `battlefield.gd`, `hud.gd`, `round_indicator.gd`, `i18n.gd`, `tutorial_manager.gd`, `battle_setup.gd`, `encounter_data.gd`, `design/20_content.md` (exact count measured at run time — do not fabricate).
- **Protected literals:** none required (CJK tokens cannot collide with English internal keys).

### C5 — Card 0: enemy-turn wall-clock (L1 — runs before all nickname cards)

**C5.1 Instrument (pattern = `debug_await_*`, `combat_manager.gd:124-135`).** Add three additive, NEVER-reset observables to `CombatManager`, measured with `Time.get_ticks_msec()` around the enemy-turn dispatch:
- `debug_enemy_turn_msec` — wall-clock ms of the most recently completed single enemy turn;
- `debug_enemy_round_msec` — wall-clock ms from the first enemy turn's start to the last enemy turn's end within one round (0 when no enemy round has completed);
- `debug_enemy_turn_index` — count of completed enemy turns (lets a scenario prove all five tutorial enemies acted).

Register in `playtest/_common.yaml` as **three appended lines immediately after `:193`** (`debug_await_frames`) — additions only, nothing renamed/removed (the :210-211 precedent). These exact names are the hard implementation contract; Expression assertions reference them verbatim.

**C5.2 Measure locally (new `playtest/enemy_turn_wall_clock.yaml`).** Skeleton (implementer mirrors `each_unit_acts_once_per_round_initiative_order.yaml`'s header/route — real tutorial battle):

```yaml
# name: enemy_turn_wall_clock
# timeline:
#   - at: <entry frame>            # battle reached PLAYER_TURN, 5 enemies queued
#     actions: [end_turn]          # hand over to the 5-enemy round
#   - at: <hand-back frame>        # after phase returned to PLAYER_TURN
#     actions: []
#     assert:
#       CombatManager.phase: phase == "PLAYER_TURN"
#       CombatManager.debug_enemy_round_msec: debug_enemy_round_msec <= 10000
#       CombatManager.debug_enemy_turn_msec: debug_enemy_turn_msec <= 2000
#       CombatManager.debug_enemy_turn_index: debug_enemy_turn_index >= 1
```

≥3 seeds: at t_impl, first check how the harness seeds RNG (`seed` handling in `playtest/_common.yaml` + the runner). If a per-scenario seed knob exists, run the scenario 3× with 3 seeds and record all three values. If the harness is deterministic, **record that fact** and instead run the scenario across 3 natural variants (round-1 handover, round-2, post-skill handover) — an honest record, never invented seed numbers.

**C5.3 Web measurement — the meaningful verification.** ⚠️ The local pin is **trivially green by construction**: 240 frames ≈ 4 s at 60 fps ≪ 10 s. Local evidence alone must never be reported as Card 0 completion. Sequence:
1. Re-export the HTML5 build FIRST (hypothesis 1: the published build predates the 0.25 s watchdog — re-measure before changing any code).
2. Run the tutorial battle in-browser at 1280×720; record per-enemy and full-round wall-clock, fps, and the console inventory: `blit_rect` format message ×2, `GL_INVALID_FRAMEBUFFER_OPERATION` ×3 (expected pre-existing noise — record verbatim counts), plus any new messages.
3. Write results + the web-vs-local delta and its source (render-bound fps vs wait-bound) into `design/30_presentation.md` (dated 2026-09-03) and the delivery notes.

**C5.4 Fix — only shorten waits + parallelize (never AI decisions, never numbers).**
- Audit `_await_tween_safe()` call sites and `camera_follower.gd` pan sequencing: wherever the code awaits the move tween and THEN starts the camera pan, start both tweens and await both (`Tween.set_parallel(true)` / `tween.parallel()` / `chain()` as appropriate).
- Replace any frame-counted pacing wait (`await get_tree().process_frame` loops) with a short `SceneTreeTimer` — frame-counted waits scale with web fps, timer waits do not.
- The 0.25 s watchdog stays; no second timing system is introduced.

**C5.5 Camera-clip pin.** Extend `playtest/camera_transform_follows_unit.yaml` (post-pan frames): after the camera settles on a top-band enemy turn (e.g. Central_Divine), assert `UiOcclusionWatch` `violations == 0` and `scan_ok == true`, and the top-band flip path still engaged (`HealthBar.bar_anchors_below_portrait`, `health_bar.gd:112`). Red-first: if the pre-fix run is already green, record "red not reproducible pre-fix" + the measured value + why (the 2026-09-02 web report is the red evidence) — the established honest-record convention.

**C5.6 Red-first discipline (all new pins).** Every new pin (C4, C5.2 asserts, C5.5, C7.6) records its real measured red run (assert / observed / frame-line / greens-before-red) or "not executed + reason". No temporary reverts may remain in the workspace (`repo_apply` is `git add -A`).

### C6 — Card N+1: README slimming — ALREADY LANDED (R3d); residual work only

Verified this run (§2 rows 11-13): the pin exists (`tests/test_readme_is_a_manual.py`: ≤ 200 lines, no round headings in README, exactly one 本轮变更 section, **12 verbatim heading constants** asserted against `docs/ROUNDS.md`); `README.md` ≈ 72 lines; `docs/ROUNDS.md` carries all 12 headings. The brief's 1,712-line premise is a stale pre-R3b snapshot, and Step 1's "10 vs 12 headings" alarm was a grep-pattern artifact.

Residual work (no new pin needed):
1. At delivery, **REPLACE** the 本轮变更 section body with R4's ≤ 20-line summary (replace, never append — the section's own contract).
2. **APPEND** the R4 `## Latest round: …` heading + summary to `docs/ROUNDS.md` (append-only; the previous "Latest" heading stays verbatim).
3. Run the existing pin; record its green run as this card's evidence; note the stale-brief finding in the delivery notes.

### C7 — Card N+2: design/ ledger slimming (+ roadmap record card)

**C7.1 `design/90_decisions.md` 97,131 B → ≤ 25,600 B.** Rebuild as a one-line-per-decision current table (date / scope / current rule / pointer to evidence). ALL superseded or landed long-form derivations move **verbatim** to `design/archive/decisions_2026-08.md` (new directory; per-month naming for future slimming).

**C7.2 `design/40_ux_backlog.md` 109,879 B → ≤ 20,480 B.** Keep OPEN items only; CLOSED items move verbatim to `design/archive/ux_backlog_closed.md`.

**Irreversible-op protocol for C7.1/C7.2 (backup → execute → verify → only then done):** the originals are committed, so git is the backup. (1) verify `git status` clean before starting; (2) perform each move as delete-in-place + archive-add **pairs** in one change; (3) verify: every moved `##`/`###` heading string exists verbatim in its archive file (scripted check, same constant-list pattern as `test_readme_is_a_manual.py`), new sizes ≤ targets, `git diff` shows the delete+add pairs; (4) rollback path: `git checkout -- design/90_decisions.md design/40_ux_backlog.md && rm design/archive/decisions_2026-08.md design/archive/ux_backlog_closed.md`. No "delete first, verify later" step exists anywhere in this plan.

**C7.3 `design/30_presentation.md` + `design/40_progression.md`:** insert a ≤ 15-line "current values/rules quick reference" block at the TOP (dated 2026-09-03); the existing content below is untouched.

**C7.4 `design/00_roadmap.md` (roadmap card — record-only, zero implementation):** append the owner's six 2026-09-02 playtest feedback items **verbatim** to the backlog, and write the queue: R4 外号 (this round) → R5 「点之前知道后果 + 每屏可返回」 (covers items 1/2/3 and 4's entry points) → R6 「江湖有人」 (item 4's gongfa volume, items 5 and 6). Plus the one-token line-3 link fix: `见 ;` → `见 01_process.md;` — nothing else on the line, nothing else in the file changes (`01_process.md` exists, 6,719 B, verified).

**C7.5 `design/99_changelog.md`:** APPEND exactly one line dated 2026-09-03 (covers the ledger slimming + roadmap record). Never rewrite existing lines.

**C7.6 Budget pins (new `tests/test_design_ledger_budget.py`, stdlib pytest).**

⚠️ **Arithmetic correction (design change — see §6):** the brief's `du -cb design/*.md ≤ 180 KB` is unsatisfiable under the brief's own constraints: `99_changelog.md` alone is 162,824 B and append-only-never-rewritten, while `20_content` (62,442 B) + `30_presentation` (79,408 B) + `40_progression` (58,142 B) are fenced by the same brief ("不动内容, 只加速查"). Post-shrink floor ≈ 320 KB excluding the changelog. Pinned formulation:
- `sum(st_size for design/*.md except 99_changelog.md) ≤ 340,000` B — docstring records the arithmetic above and the exclusion reason (append-only history);
- per-file pins: `90_decisions.md ≤ 25,600` B, `40_ux_backlog.md ≤ 20,480` B (both satisfiable);
- archive-completeness pin: every heading moved out of the two source files exists verbatim in its archive file.

**C7.7 Evidence:** red-before = run the new budget pin BEFORE the shrink (red with observed byte totals); git diff must show the delete + archive-add pairs; measured wc/du values recorded in delivery notes.

### C8 — Frame proof set (nickname-length layout risk — concrete captures)

Verdict criteria: `UiOcclusionWatch` `violations == 0` AND `scan_ok == true` on after-frames + visual no-overflow. **No pixel-literal pins** (brief). Captures (before = pre-rename build, after = post-rename build, SAME frame index):

1. **Tutorial order bar** — frame ≈ 1500 of the round-one route: 6 zh nicknames + separators (longest zh case: 独臂大虾 · 中神通虾).
2. **HP name plate crop** — same frame: 独臂大虾 + HP number on the 64 px bar; no ellipsis, no plate-over-portrait occlusion.
3. **Huashan map-battle frame** (pt2 route): order bar incl. the 侠客虾 token — proves the raw `ProgressionHero` leak fix.
4. **EN-locale order bar** (settings → EN): `One-Armed Prawn · East Heretic Shrimp · …` — the longest-string case; on proven ellipsis/overflow, switch to the compact EN fallback set (C1) and re-capture; never touch geometry/theme.
5. **Skill bar frame**: skill names carry no personal names today (verified); one frame proves the rename didn't disturb the bar.

Store pairs under `final/` (harness frame-capture convention), reference from delivery notes. **Escalation:** if the zh order bar overflows, STOP AND REPORT — the owner table is verbatim and geometry/theme are frozen; zh string abbreviation is NOT authorized. (Estimated zh growth is +3 CJK chars total (17 → 20), ≈ +42 px at a 14 px font — low risk; the frame is the proof.)

### C9 — Playtest surface + scenario contract (for PM / implementer)

- **Surface additions** (`playtest/_common.yaml`, append after `:193`): `debug_enemy_turn_msec`, `debug_enemy_round_msec`, `debug_enemy_turn_index`. These strings are the hard contract — implementation node/variable names and assertion expressions must match verbatim.
- **New scenario:** `enemy_turn_wall_clock.yaml` (skeleton in C5.2). At least one real keypress (`end_turn`); asserts prove the game advances (counters > 0) and the timing property holds.
- **Extended scenario:** `camera_transform_follows_unit.yaml` gains post-pan occlusion asserts (C5.5).
- No new input actions; scene stays the default main scene; no threshold may be loosened to pass (PM owns final thresholds; the 10,000 ms / 2,000 ms values here are the brief's own numbers).

---

## 5. Tech stack (from the Step 1 SOTA report; nothing new added)

- **Godot 4.4 built-ins only:** `Tween.set_parallel(true)`/`parallel()`/`chain()`, `SceneTreeTimer`, `Time.get_ticks_msec()` (wall-clock observables), `Font.get_string_size()` + `Label` overrun properties (measurement-only width checks). No addons, zero new dependencies.
- **stdlib pytest + pathlib** for all new pins (denylist C4, ledger budget C7.6) — repo convention (`test_event_prose_shrimp.py`, `test_readme_is_a_manual.py`).
- **The repo playtest harness** (scenario yamls + Expression asserts) for behavioral pins; `playtest/_common.yaml` append-only surface additions.
- **Manual verbatim moves with git as backup/rollback** for C7 (no markdown formatters — they would break the verbatim-move constraint).
- **Godot HTML5 export + browser console** for the one-time Card 0 web measurement.

## 6. Design changes vs the brief (recorded deviations — for 5_design to apply to the档案)

1. **Card N+1 already landed in R3d** (pin + 72-line README + 12 ROUNDS headings all verified). Residual = 本轮变更 replacement + ROUNDS append + evidence run. The brief's 1,712-line premise was a stale snapshot; its "12 headings verbatim" demand is already met.
2. **du budget rebased** to `design/*.md` excluding `99_changelog.md` ≤ 340,000 B (arithmetic impossibility of the 180 KB literal documented in C7.6); per-file targets (≤ 25 KB / ≤ 20 KB) kept satisfiable as specified.
3. **Walk-on coinings locked:** 侠客→侠客虾 ("Wanderer Shrimp"), 陪练弟子→陪练虾 ("Sparring Shrimp"), plus two new `_DISPLAY_ALIASES`/`_ORDER_TOKENS` entries (`"ProgressionHero"`, `"Sparring Partner"`) fixing the raw canonical-name leak visible in the 2026-09-02 frames.
4. **EN nickname translations coined here** (not owner-locked): primary set in C1; compact fallback only on proven EN order-bar overflow.
5. **`ai_*.gd` not edited:** personal names there live only in comment headers (never rendered); the denylist strips `.gd` comments for this documented reason.
6. **Denylist design/ scope = `20_content.md` only**, with every exclusion and its reason in the pin's docstring; widening allowed, narrowing forbidden.
7. **Two tests/ display-literal updates** (C3) — tests are not gates; the same "display literal yields" rule applies; `character_name` asserts stay byte-identical.

## 7. Extensibility

- Denylist pin: a future personal name = one list entry; scope can widen without code change.
- Nickname surface is exactly four dicts + i18n: a future character needs `display_name` + 2 dict entries + 1 i18n key/value — and the denylist forces the 20_content record.
- The three `debug_enemy_*` counters follow the additive `debug_*` pattern — future timing pins reuse them without new plumbing.
- `design/archive/` is the standing landing zone for all future ledger slimming (per-month files).

## 8. Worst-failure forms → design guards

| Failure form | Guard |
|---|---|
| Edited `character_name` / node names / turn_order tokens | C2's file-by-file "values only" table; verbatim gates assert the internal keys; denylist cannot see them (CJK-only) |
| Relaxed a verbatim gate to go green | Nowhere in the plan; `ui_geometry_readability` only :42 flips; C3 table is exhaustive |
| Missed a display surface (tutorial/event/archive) | C4 denylist (red-first) + owner's 2026-09-02 frame census cross-check in delivery notes |
| Longer names overflowed order bar / plates | C8 frame proof set, no pixel pins, zh stop-and-report / EN compact-fallback escalation paths |
| Card 0 declared done on local-only evidence | C5.3 explicit prohibition; web measurement is the acceptance evidence |
| Ledger slimming data loss | C7.1/C7.2 git-baseline protocol: verify → move → verify headings+sizes → rollback path documented |
| Temporary red-first reverts left behind | C5.6 discipline; `repo_apply` is `git add -A` |

## 9. Implementer checklist (decomposition hints for PM)

1. C5 instrument + scenario + web export measurement (L1, first) → 2. C2 rename edits + C3 gate/test literal flips → 3. C4 denylist pin (red-first BEFORE step 2's edits land) → 4. C8 frame captures → 5. C5.4/C5.5 wait shortening + camera pin → 6. C7 ledger slimming + budget pins (red-first) → 7. C7.4 roadmap card + link fix → 8. C6 README residual + ROUNDS append → 9. C7.5 changelog line → 10. Full gate suite re-run + delivery notes (per-line C3 table, red-first records, web measurements, frame pairs).

Note: step 3's red run must be captured against the pre-rename tree — sequence 2 and 3 accordingly (write the pin, run it red, commit nothing intermediate, then apply the rename and run it green).
