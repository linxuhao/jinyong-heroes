# 技术架构设计 — Event Pool Expansion: Full Journey Without Repeats (run `jinyong-event-pool-36`)

> Step 2 output, 2026-08-31. English prose; Chinese literals appear only where they ARE the
> deliverable content (event copy), matching the repo convention (界面文字一律中文).

## 1. Overview

Grow the travel-event pool from 16 to **exactly 36 rows** (≥20 new events required; 36 is the
true minimum because a full journey = 3 years × 12 months = 36 roams, and draw #37 — the first
legal reset — never happens inside a 36-month run). Everything else follows from three
verified facts:

1. `EventData.TABLE` (`scripts/data/event_data.gd`) is a pure data array; `all()`/`def()` build
   fresh `EventDef` instances per read, so appending rows needs zero machinery changes.
2. `EventLogic.draw_unseen_id(profile, rng)` (`scripts/data/event_logic.gd:21-31`) already
   implements no-repeat-until-exhausted with **exactly one `rng.randi_range` per draw** and a
   zero-RNG-op reset branch. The no-repeat property is a function of pool size only — this round
   changes **data**, never draw logic or `events_seen` semantics.
3. The published observable `CultivationScreen.events_seen_count` (cultivation.gd:82, synced at
   :828 from `profile.flags["events_seen"]`) is the on-screen no-repeat proof surface; marking
   happens at cultivation.gd:467-469 (append-if-absent, after `apply_option_effects`).

Round deliverables: 20 appended rows + 80 i18n keys, an executable 36-draw no-repeat gate inside
`tests/test_event_data.gd` (brief-mandated: no new test file), an on-screen playtest proving a
**new** event is drawn → rendered → selected → resolved, five design-doc updates, zero regression
on the **77 frozen playtest scenarios** (counted 2026-08-31: `playtest/*.yaml` minus
`_common.yaml` = 77 files; consistent with the 2026-08-31 official gate "77 场景全 PASS" recorded
in the UX-16 evidence row — this round's gate must run **78/78**).

## 2. Architecture (component view & data flow)

```
[scripts/data/event_data.gd]  TABLE 16 → 36 rows   (append-only)
        │ def(id) / all() — fresh instances, unchanged
        ▼
[scripts/data/event_logic.gd]  UNTOUCHED            (1 randi_range/draw; reset branch intact)
        ▲                                            │
        │ roam = ACTION_PICK focus 3 (cultivation.gd:238 area, unchanged)
[scripts/segments/cultivation.gd]                   │
   _draw_event → EVENT phase → _apply_event_option ─┘─→ apply_option_effects → mark seen (append)
   _sync_surface → events_seen_count / event_id / NEW: event_title / event_body
   _process → NEW: debug_seed_events_seen (test-only injection)
        │ tr() at render (cultivation.gd:607-608, 878 — existing)
        ▼
[scripts/autoload/i18n.gd]  EN dict + ~80 keys      (append-only)

[tests/test_event_data.gd]   extended: mirrors (ROW_TITLES/ROW_EFFECTS/NEW ROW_TEXTS/ROW_LABELS)
                             + _test_no_repeat_full_journey (36 real draws, ladder)
                             + EN-membership gate (closes the static-guard blind spot)
[tests/test_i18n_coverage.py] UNTOUCHED, stays green (does NOT scan event_data.gd literals — see §5.3)
[playtest/event_pool_new_event_resolved.yaml]  NEW scenario (78th)
[playtest/_common.yaml]      append-only: 1 action + 2 surface lines
[project.godot]              append-only: 1 debug input action
[design/20_content.md §4]    rewritten: pool 36, new-row list
[design/00_roadmap.md]       completeness item 3 ❌→✅ (gate evidence) + gap-list sentence refresh
[design/90_decisions.md]     2026-08-31 rulings (a)–(e)
[design/99_changelog.md]     one appended row
[design/40_ux_backlog.md]    NEW UX-17 OPEN row + record line (lore inconsistency, owner decision)
```

Data flow of the proof: seed 35 ids → roam draw sees a **1-element unseen pool** → the single
remaining id is drawn with no RNG dependence → EVENT renders it → option resolves →
`events_seen_count` 35 → 36 with **no reset**, on screen.

## 3. Component list

### C1 — `scripts/data/event_data.gd`: append 20 rows (append-only)

Row shape byte-compatible with the frozen 16: `{"id","title","text","option_a","option_b"}`,
options `{"label","effects":[{"type","value","target"}]}`, `battle_id` absent (defaults null).
Effect domain frozen: types ∈ {silver, attr, item, practice, none}; attr targets ∈
{bone, inner, agility, wisdom, fortune}; item targets ∈ the 12 equip ids
(eq_sword_1..4 / eq_armor_1..4 / eq_boots_1..4).

**Content plan (binding at the level of id / title / effects / scene premise; final prose and
option labels are authored in C1's file, register = the frozen 16: 2-line body, `\n` between
lines, 全角 punctuation, species-neutral people, animals-as-animals only where the frozen pool
already has them — 巨雕 / 马车):**

| # | id | title | scene premise (2-line body gist) | option A effects | option B effects | pattern |
|---|---|---|---|---|---|---|
| 17 | `riverside_duel` | 河滩论剑 | two sword schools quarrel on a sandbar, both ask you to judge | `practice+2` | `silver+15` | growth-vs-money |
| 18 | `ancient_bell` | 荒寺晚钟 | ruined temple bell, breathing inscription inside | `attr inner+2` | `silver+12` | attr-vs-money |
| 19 | `poisoned_well` | 荒村毒井 | village well turned bitter; herbalist asks a fee | `silver−10, attr fortune+2` | `attr wisdom+2` | paid-charity vs effort |
| 20 | `tiger_pass` | 虎啸危崖 | tiger howls below the cliff; a caravan sells safe conduct | `silver−8, attr wisdom+1` | `attr agility+2` | pay-vs-effort |
| 21 | `lantern_festival` | 上元灯会 | lantern fair riddle stall; a vendor's monkey escapes | `attr wisdom+2` | `silver+5, attr fortune+1` | study vs serendipity |
| 22 | `pawnshop` | 当铺旧刀 | pawnshop dead-ticket blade; a ruined man cannot redeem it | `silver+16` | `silver−14, attr fortune+2` | money-now vs moral-luck |
| 23 | `storyteller` | 茶馆说书 | teahouse storyteller spins an old swordmaster legend | `silver−5, practice+1` | `attr wisdom+1` | paid-growth vs free-attr |
| 24 | `chess_stall` | 街角残局 | street corner endgame unsolved for ten years | `attr wisdom+2` | `silver−8, practice+2` | time-vs-money |
| 25 | `smithy` | 铸剑回炉 | smith reforges your old blade for a fee | `silver−18, item eq_sword_3` | `attr wisdom+1` | paid-item vs free-knowledge |
| 26 | `cliff_herbs` | 崖上采药 | herb gatherer hiring a climber; cliff-grown lotus for sale | `silver+12, attr agility+1` | `silver−18, attr inner+2` | earn-by-effort vs pay-for-medicine (**showcase event**, see C5) |
| 27 | `wedding_train` | 山道花轿 | wedding procession blocks the road, custom demands gift money | `silver−8, attr fortune+2` | `attr agility+1` | custom-cost vs effort |
| 28 | `sword_mound` | 荒冢埋剑 | mound of broken swords, sword-intent lingers | `practice+3` | `silver+17` | growth-vs-money |
| 29 | `night_inn` | 客栈夜账 | inn keeper buried in accounts | `silver+9, attr wisdom+1` | `silver−10, attr bone+1` | labor vs paid rest |
| 30 | `wild_goose_letter` | 雁足传书 | fallen goose carries a letter; the village is below | `attr agility+1, silver+6` | `attr wisdom+2` | quick-reward vs study (B: copy first, courier fee forfeited) |
| 31 | `snow_pass` | 风雪隘口 | snow seals the pass; a guide names his price | `silver−12, attr wisdom+1` | `attr agility+2` | pay-vs-effort |
| 32 | `drunken_fist` | 醉汉传拳 | drunken vagrant's wild forms hide real fist logic | `silver−9, practice+2` | `attr bone+1` | paid-practice vs toughness (sober sparring hurts) |
| 33 | `river_god` | 河伯娶亲 | shamans extort a village with a river-god wedding | `attr wisdom+2` | `silver+15` | truth-vs-money |
| 34 | `plague_village` | 疫村施药 | sick village, the doctor lacks medicine | `silver−12, attr fortune+2` | `attr wisdom+1` | charity vs detachment |
| 35 | `young_disciple` | 登门求教 | a youth begs for pointers | `practice+1, attr wisdom+1` | `silver+10` | depth (teaching clarifies) vs quick money |
| 36 | `fallen_rider` | 坠马客商 | merchant thrown from his horse, goods scattered | `silver+14` | `item eq_boots_1` (costless) | money vs gear |

Design rules every row satisfies (machine-checked, see C3):
- **Real trade-off**: the two options never draw on the same currency; no option strictly
  dominates (every paid option has a free alternative that still lands a gain; every pure-gain
  option is mirrored by a different-currency option).
- **Zero-silver economy**: opening silver is 0 and negative amounts clamp to 0
  (event_logic.gd:42). No row's only choice is a pure cost; each row keeps ≥1 option that a
  penniless player benefits from. Showcase event's A is a pure gain (works at silver 0).
- **must-land**: every row has ≥1 option with an `attr` effect or a non-zero `silver` effect.
- **Costless-item uniqueness**: the only new costless grant is `eq_boots_1` (#36 B); existing
  costless set = {`eq_sword_2` via tomb_bed} — no collision. `eq_sword_3` (#25 A) is a *paid*
  grant (paired silver), allowed alongside merchant's paid grant.
- **No reskins**: all 20 scenes are absent from the frozen 16 (checked against §4 clusters:
  no second ferry/crossing, no second beggar-purse moral clone, no battle-promising scenes —
  `battle_id` stays null in every option; conflicts resolve through wit/effort/silver).
- **No species claims**: people are species-neutral exactly like the frozen 16; the unresolved
  "all characters are shrimp" ruling is logged, not applied (UX-17, C6).

### C2 — `scripts/autoload/i18n.gd`: append ~80 keys (append-only)

For each new event, exactly 4 EN entries appended in the `# --- Travel events` section:
`"<title>": "<English>"`, `"<text with \n>": "<English, same 2-line shape>"`,
`"<option_a label>": "<English>"`, `"<option_b label>": "<English>"`.
Keys are byte-identical to the literals in event_data.gd (including `\n` escapes and 「」
corner brackets if used). EN register: plain readable wuxia English matching existing entries
("Bandits on the Mountain Road" style); no machine-translation cadence. `tests/test_i18n_coverage.py`
stays untouched and green.

### C3 — `tests/test_event_data.gd`: extend (the only test-file change; no new test file)

1. **Mirror extension (append-only)**: `ROW_TITLES` + `ROW_EFFECTS` gain the 20 new ids;
   NEW consts `ROW_TEXTS` (id → exact body text) and `ROW_LABELS` (id → [label_a, label_b])
   covering **all 36 rows**. Effect: every row's title/text/labels/effects are pinned verbatim —
   the frozen-16-unchanged acceptance criterion becomes machine-enforced (any row edit breaks
   mirror equality). `_test_texts` additionally asserts `def.text == ROW_TEXTS[id]`; a new
   `_test_option_labels` asserts label equality. Existing assertions/thresholds untouched.
2. **`_test_no_repeat_full_journey` — the executable gate** (new preload:
   `const EventLogic = preload("res://scripts/data/event_logic.gd")`):
   - pre: `EventData.all().size() >= 36`; all ids unique (existing check already fails on dups).
   - profile: construct exactly as `tests/test_cultivation.gd` does for its draw pins; explicitly
     `profile.flags["events_seen"] = []` before the loop (defensive; mirrors the sanitized bag).
   - rng: `RandomNumberGenerator.new()` with an explicit fixed seed (e.g. `20260831`) —
     deterministic across runs, independent of the profile's shared stream.
   - loop i = 1..36: `id = EventLogic.draw_unseen_id(profile, rng)`; assert `id != ""`;
     `id` ∈ precomputed TABLE id set; `id` not yet drawn; then mark seen **exactly as
     cultivation.gd:467-469 does** (`seen.append(id)` if absent); assert
     `profile.flags["events_seen"].size() == i` (monotonic ladder ⇒ the zero-RNG reset branch
     never fired mid-journey — measured, not reasoned).
   - post: 36 distinct ids drawn; **pigeonhole assertion** `drawn ∩ new20 >= 20` (36 distinct
     draws, only 16 frozen ids exist ⇒ ≥20 new ids necessarily drawn — durable for any pool ≥36).
   - red-first sequencing: commit the gate FIRST with the 16-row pool → it must red at draw 17
     (first ladder violation: size 1 ≠ 17 after the reset) → measured against the sidecar unit
     leg → then append rows → green. The red is the proof the gate detects the exact defect the
     roadmap ❌ names.
3. **`_test_i18n_entries` — EN-membership gate** (new preload:
   `const I18nScript = preload("res://scripts/autoload/i18n.gd")`): for every row, assert
   `I18nScript.EN.has(def.title)`, `EN.has(def.text)`, `EN.has(option_a.label)`,
   `EN.has(option_b.label)`. Rationale (verified): `test_i18n_coverage.py` scans scene `text=`
   literals, `tr("<zh>")` call sites, and `.text = "<zh>"` assignments — it does **NOT** scan
   `event_data.gd` literals, and the render path passes variables through `tr()`
   (cultivation.gd:607-608, 878), so today nothing machine-checks event copy against EN. This
   closes that blind spot in the brief-mandated file; `EN` is `const EN: Dictionary` (i18n.gd:29),
   statically readable via preload.

### C4 — `scripts/segments/cultivation.gd` (+ project.godot + `_common.yaml`): observables & debug injection

Additive only; `_draw_event` / `_apply_event_option` / phase machine byte-untouched.

1. **Two new surfaces** `event_title: String = ""`, `event_body: String = ""`, mirrored in
   `_sync_surface()` next to `event_id`/`events_seen_count` (locate the exact sync point by
   grepping `event_id =`): `var d = EventData.def(event_id)`; if null → both `""`; else publish
   **what the player sees**: `tr(d.title)` / `tr(d.text)`. Whitelist append in
   `playtest/_common.yaml` under `CultivationScreen:` (`event_title`, `event_body` lines only).
2. **Debug action `debug_seed_events_seen`** (test-only injection, precedent: `debug_win_tutorial`
   pressed in event_travel_effects.yaml / `debug_grant_silver`'s "through the pipeline" rule):
   - `project.godot [input]`: one new action, mirroring the existing `debug_*` block.
   - `_common.yaml` `actions:` list: append `debug_seed_events_seen` (append-only line).
   - cultivation.gd `_process`: `if Input.is_action_just_pressed("debug_seed_events_seen"):
     _debug_seed_events_seen()`; handler: no-op outside CULTIVATION; then
     `for def in EventData.all(): if def.id != SHOWCASE_ID: append-if-absent to
     profile.flags["events_seen"]` — i.e. **marks every id seen except the showcase id, reusing
     the identical append-if-absent branch shape as :467-469** (never a bare flags overwrite);
     end with `_sync_surface()`. Doc comment: DEBUG/TEST-ONLY, never called by gameplay.
   - Why "all-but-one" instead of a literal 35-id list: no fixture data in game code, and the
     resulting single-id pin (C5) survives future pool appends **by construction**.

### C5 — `playtest/event_pool_new_event_resolved.yaml`: on-screen proof (the 78th scenario)

Playtest contract block (surfaces/actions live in `_common.yaml`; this file is scenario-only,
`name:` == basename):

```yaml
name: event_pool_new_event_resolved
description: >-
  Boundary-month proof: after debug_seed_events_seen leaves exactly one unseen id,
  the 36th roam draw is deterministic (1-element unseen pool, no RNG dependence);
  the NEW event is drawn, rendered (title/body/labels), selected, resolved;
  events_seen_count ladder 35 -> 36 with no pool reset.
actions: debug_seed_events_seen            # appended in _common.yaml
surface: CultivationScreen.[event_id, event_title, event_body, events_seen_count,
         phase, month, silver, attr_agility, focused_option_text]   # existing + 2 new
timeline:
- {at: 3..15,  press: ui_accept ×7}        # boot → menu → creation default flow (mirror event_travel_effects)
- {at: 20,     press: debug_win_tutorial}
- {at: 40,60,70,80, press: ui_accept}
- {at: 90,     press: move_right}
- {at: 100,110, press: ui_accept}
- at: 130
  assert: {phase == "CARD_PICK", events_seen_count == 0}       # clean pre-state
- {at: 135,    press: debug_seed_events_seen}
- at: 140
  assert: {events_seen_count == 35}        # seed landed on the published surface
- {at: 150,    press: ui_accept}           # pick card 0
- {at: 160,170,180, press: move_down ×3}   # focus 游历 (ACTION_PICK focus 3)
- {at: 190,    press: ui_accept}           # draw → EVENT
- at: 200
  assert: {phase == "EVENT", event_id == "cliff_herbs", events_seen_count == 35,
           event_title == "崖上采药", event_body != ""}
- {at: 205,    press: move_down}           # focus option B (direction verified against
                                           #  cultivation's EVENT focus handling)
- at: 210
  assert: {focused_option_text == "<authored label B zh>"}      # text contract
- {at: 215,    press: move_up}
- {at: 220,    press: ui_accept}           # resolve option A
- at: 230
  assert: {events_seen_count == 36, phase == "CARD_PICK", month == 2, event_id == "",
           attr_agility: changed, silver: changed}   # diffs only, zero absolute game values
```

- The `event_id == "cliff_herbs"` and title/label pins are **append-proof by construction**
  (the seeder always leaves exactly the showcase id unseen regardless of future pool size) —
  this is why the reviewer's "single default path" resolves to the new-YAML + seeder, not to a
  36-month on-screen walk (rejected: ~10× frame cost, and any mid-journey id pin would break on
  the next pool append).
- Numeric assertions are differential (`changed`) per the repo discipline; the only literals are
  text contracts (HintLabel-precedent) and the count ladder (`== 35` / `== 36`, exact equality).
- **Red-first four values measured, never predicted**: with the C1 row-append temporarily rolled
  back (pool 16), the seeder marks all 16 → `events_seen_count == 35` reds at f140, and even
  past it the draw would reset-and-reuse an old id (`event_id == "cliff_herbs"` unfulfillable).
  Implementer runs `godot_playtest_scenario` directly against the sidecar with
  `# TEMPORARY RED-FIRST REVERT — DO NOT COMMIT` markers, records failing frame / first failing
  assert / exact error / green-before-red into the scenario's RED-FIRST EVIDENCE header + delivery
  notes, then byte-restores. Zero assertions weakened anywhere.

### C6 — design docs (5 files; these are the brief-sanctioned "设计变更")

1. `design/20_content.md` §4: retitle 「游历事件池 (36 条)」; keep the frozen-16 pattern clusters;
   add the 20 new rows grouped by the same pattern vocabulary + the arithmetic note (16 rows
   forced a reset at roam 17; 36 = journey length; reset branch remains as the draw-37 safety
   net); point at the two gates (unit `_test_no_repeat_full_journey`, playtest
   `event_pool_new_event_resolved`). Doc stays 形状-记录 style — no data duplication.
2. `design/00_roadmap.md`: completeness item 3 ❌→✅ citing both gates (numbers filled from this
   round's official gate run, never predicted); refresh the 「下一步的顺序判断」 sentence that
   still lists 事件池 16 条待扩 as an open content gap.
3. `design/90_decisions.md`: new `2026-08-31 jinyong-event-pool-36` section — (a) pool = exactly
   36, append-only, frozen 16 verbatim (machine-pinned by C3 mirrors); (b) gate lives in
   `tests/test_event_data.gd`, real `draw_unseen_id`, ladder assertion; (c) debug injection rule
   (all-but-one seeder through the marking branch — same discipline as `debug_grant_silver`);
   (d) id pin is construction-proof against future appends; (e) species policy: new copy stays
   species-neutral, inconsistency recorded as UX-17 (OPEN, owner decision), no shrimp-ification,
   no consistency claim.
4. `design/99_changelog.md`: append one row
   `| jinyong-event-pool-36 | 2026-08-31 | <pool 16→36, gates, i18n> | <why: roadmap item 3> |`.
5. `design/40_ux_backlog.md`: new queue row **UX-17 | OPEN | 游历事件文案 | 2026-08-28 裁定
   「一切角色都是虾」,而事件文案(既存 16 条与本轮 20 条)写的是劫匪/行商/老丐等不指明物种的人物
   ——两套事实并存 | 读者无法裁定事件人物是否为虾;需所有者统一立场(虾化 or 明示豁免),本轮不擅自处理**
   + one dated 记录 line (record-only, round opened the item per brief; no other OPEN/CLOSED
   status changes).

## 4. Playtest spec summary (contract for PM/implementer)

- `scene`: default (game boots via `main.tscn` path used by all scenarios; timeline mirrors
  `event_travel_effects.yaml` frames 3–130 byte-for-byte where possible).
- `actions` (declared in `_common.yaml`): existing list + `debug_seed_events_seen`.
- `surface` additions (whitelist append-only): `CultivationScreen.event_title`,
  `CultivationScreen.event_body`. All other asserted names already whitelisted.
- Scenario skeleton: §3 C5. At least one press per scenario ✓; the suite's terminal coverage is
  carried by the existing 77 (no new end-to-end requirement here).
- Every new numeric assertion differential; exact-equality only for the count ladder and text
  contracts.

## 5. Invariants, guardrails, and pre-implementation checklist

1. **Append-only everywhere**: frozen 16 rows byte-untouched (C3 mirrors pin them); `_common.yaml`
   appends 3 lines total (1 action + 2 surfaces); no frozen scenario file edited; no threshold
   relaxed; `spine_to_ending.yaml` untouched and must stay 42/42.
2. **T0 grep gate (before any implementation)**: `grep -n "event_id ==" playtest/*.yaml` and
   classify every hit. Expected: all hits are map-node literal bindings
   (`map_node_event_*.yaml`, spine/map scenarios) which read the node channel
   (`MapData.active_event_id`, zero RNG, never touches `events_seen`) — unaffected by pool size.
   Any hit that pins a 游历 bag-drawn id would be an RNG-stream trap: STOP and escalate for
   rebaseline authorization. Record the grep result in delivery notes.
3. **RNG op order lifeline**: appending rows changes only the bag's upper bound (documented,
   sanctioned by Step 1); no new RNG ops anywhere; the seeder performs zero RNG ops;
   `event_travel_effects` (19/19) stays green because it asserts only `event_id != ""` + ladder.
4. **events_seen semantics untouched**: reset branch kept as draw-37 safety net (never fires
   in-journey); seeder appends through the same branch shape; `PlayerProfile.from_dict`
   sanitization untouched; `save_load_roundtrip` (14/14) unaffected (no new persisted keys).
5. **Zero compile errors, zero runtime errors**: the only engine-side changes are two surface
   vars + one debug handler (null-safe); unit-suite registry untouched (runner auto-collects
   `test_event_data.gd`).

## 6. Task decomposition hint (for PM)

| # | Task | Depends | Notes |
|---|---|---|---|
| T1 | C3 step 2 only: add `_test_no_repeat_full_journey` | — | red-first measured (red at draw 17 on 16-pool) |
| T2 | C1 rows + C2 i18n + C3 mirrors/i18n-gate/label test | T1 | one content commit; all unit tests green after |
| T3 | C4 surfaces + debug action + whitelist/project.godot appends | — | independent of T2 |
| T4 | C5 scenario + red-first measurement (rollback C1+seeder) | T2, T3 | four measured values, then byte-restore |
| T5 | C6 five doc updates | T2, T4 (evidence names known) | changelog/backlog/decisions dated 2026-08-31 |
| T6 | Full gates: compile, playtest 78/78, unit suite, pytest | all | hard gate `passed: true` |

## 7. Rollback & safety

No irreversible operations exist in this design: every change is an append or an additive edit to
plain-text files; rollback = `git revert` of the round's commits, restored state machine-checked
by the untouched gates (mirrors, i18n pytest, contract smoke, 77 frozen scenarios). The only
temporarily destructive step is the sanctioned red-first rollback in T1/T4, which is marker-
annotated, sidecar-measured, and byte-restored before commit (repo precedent:
`record_measured_red_first_and_reconcile`, `final/delivery_notes_facility.md`).

## 8. Extensibility (deliberately minimal)

- Future pool growth: append rows + mirror entries + EN keys; the playtest id pin and the gate's
  pigeonhole assertion survive by construction; only `_test_no_repeat_full_journey`'s fixed 36
  iterations would be re-derived (documented in C3) — that is the next round's one-line change.
- No new effect types, currencies, systems, or draw-logic hooks are introduced; the seeder is the
  only debug addition and is inert outside CULTIVATION.
- Rejected alternatives (recorded so they stay rejected): shuffled-deck draw (RNG stream fork),
  external dialogue plugin (copy-location + i18n violation), 36-month on-screen walk (cost +
  brittle pins), literal 35-id fixture list in game code.

## 9. Acceptance traceability

| Acceptance criterion | Carried by |
|---|---|
| TABLE ≥36 rows, unique ids, frozen 16 verbatim | C1 + C3 mirrors (`_test_all_rows` uniqueness + verbatim pins) |
| 36-month no-repeat, measured | C3 `_test_no_repeat_full_journey` (ladder + distinctness) |
| New event drawn/rendered/selected/resolved on screen | C5 scenario (78/78 gate run) |
| All new copy in EN dict, pytest green | C2 + C3 `_test_i18n_entries` + untouched `test_i18n_coverage.py` |
| `test_event_data.gd` extended and green | C3 |
| 77 frozen scenarios zero regression, compile clean, hard gate true | T6 (78/78 run incl. `spine_to_ending` 42/42) |
| Docs updated as specified | C6 |
| Lore inconsistency recorded, not resolved | C6.5 (UX-17 OPEN) |
