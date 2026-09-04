# Delivery Notes — fix_r5_huashan_route_drift

Date: 2026-09-04. Card: re-derive the huashan route + fold-in year-end/sect-switch
month legs after the C2 change (empty 练功 now RETURNS to ACTION_PICK without
burning the month, so the old fixed 3×CultOptionButton0 grammar loops forever once
both starting arts master). Assertions byte-identical; month legs only.

---

## 1. Measured reds — quoted verbatim (from this cycle's `playtest_summary.md`, step 5_compile)

> These are the pre-fix official numbers this card must beat. They are recorded here
> verbatim, not re-tuned.

### huashan_winnable_normal_route — 19/47 (HARD; carries all 28 runtime errors)

The card-calendar got stuck. Failing asserts (observed values verbatim):

- `CultivationScreen.year` @ f575 | expr `year == 2` | observed `1`
- `CultivationScreen.month` @ f575 | expr `month == 1` | observed `5`
- `CultivationScreen.year` @ f770 | expr `year == 3` | observed `1`
- `CultivationScreen.month` @ f770 | expr `month == 1` | observed `5`
- `GameManager.current_state` @ f1010 | expr `current_state == "MAP"` | observed `CULTIVATION`
- `MapScreen.phase` @ f1010 | error `node not found: MapScreen`
- `TravelButton0.visible` @ f1010 | error `node not found: TravelButton0`
- `MapScreen.current_node_id` @ f1055 | error `node not found: MapScreen`
- `MapScreen.current_node_id` @ f1095 | error `node not found: MapScreen`
- `GameManager.current_state` @ f1140 | expr `current_state == "BATTLE"` | observed `CULTIVATION`
- `SceneManager.current_scene` @ f1140 | observed `cultivation`
- `GameManager.map_battle_id` @ f1140 | observed `""`
- (Player/SkillButton/EndTurnButton/East_Heretic/Central_Divine/RetryButton aim
  errors @ f1140..f2220 — **all 28 runtime errors are this scenario**; they are the
  downstream consequence of the calendar being stuck at year 1 month 5, so the route
  never reaches MAP/BATTLE and every later aim misses.)
- f1200/f1400/f1600 `CombatManager.*` observed IDLE / round 0; f2100/f2140
  `current_state` observed CULTIVATION; f2220 `current_scene` observed cultivation.

### cultivation_year_end_stay — 5/8

- `CultivationScreen.year` @ f760 | expr `year == 2` | observed `1`
- `CultivationScreen.month` @ f760 | expr `month == 1` | observed `9`
- `CultivationScreen.gongfa_count` @ f760 | expr `gongfa_count == 4` | observed `2`

(the calendar stuck at year 1 month 9 with both arts mastered — same
empty-练功-burn class as huashan.)

### sect_switch_same_school_connects — 4/8

- `CultivationScreen.year` @ f520 | expr `year == 2` | observed `1`
- `CultivationScreen.sect_id` @ f520 | expr `sect_id == "emei"` | observed `shaolin`
- `CultivationScreen.gongfa_ids` @ f520 | expr `has("emei_emeijian_c")` | observed `["shaolin_yijin_d", "shaolin_luohan_d"]`
- `CultivationScreen.gongfa_grades` @ f520 | expr `has("C")` | observed `["D","D"]`

---

## 2. Per-scenario root-cause verification (frame evidence)

### huashan / year_end_stay = empty-练功-burn class — CONFIRMED, re-derived

Data (verified in repo):
- `ProgressionGongfaData.PRACTICE_TO_MASTER = {"D":4,"C":6,"B":8,"A":10}`
  (`scripts/data/progression_gongfa_data.gd:22`).
- `cultivation.gd:46 const PRACTICE_ACTION_GAIN: int = 2` → a D art masters in
  `4 / 2 = 2` practice months.
- Year 1 = 少林 grants two D arts (`shaolin_yijin_d`, `shaolin_luohan_d`), both
  mastered after 4 练功 months (m1–m4). From m5 the GONGFA_PICK list is empty.
- After fix_c2, the empty GONGFA_PICK accept/button **returns** to ACTION_PICK
  with **month/silver zero delta** (see 90_decisions 2026-09-04 row 「软锁 = 无路可走」).
  The old grammar kept clicking CultOptionButton0 (练功), which now returns without
  advancing → the calendar froze at year 1 month 5 (huashan) / month 9 (year_end_stay).
- ACTION_PICK button indices (`cultivation.gd:990`):
  `["练功","修习","做工","游历","存盘","读档","删档"]` → 练功=0, 修习=1, 做工=2.
  做工 = `CultOptionButton2` commits via `_after_action()` directly (always burns the
  month, never enters the empty GONGFA_PICK). 修习 root-bone = 1×card accept +
  move_down to 修习 + 1×accept into ATTR_PICK + 1×accept on 根骨 (burns the month).

So the re-derivation is legitimate: post-mastery months switch to a month-burning
action the game actually offers (做工 / 修习), assertions unchanged.

### sect_switch_same_school_connects = two-press-confirm class — NOT this class — STOP (see §4)

---

## 3. Per-leg change table (old clicks → new clicks, per post-mastery month)

### huashan_winnable_normal_route (`playtest/huashan_winnable_normal_route.yaml`)

Edit scope: `timeline/at:` + `clicks:` lines ONLY. All `assert:` blocks, header
comments, and `description:` untouched.

| Month (year) | OLD (R3b, burned month via empty 练功) | NEW (R5 re-derived) |
|---|---|---|
| Y1 m1–m4 (练功, arts still trainable) | card+练功+row = `CultOptionButton0 ×3` | **unchanged** `CultOptionButton0 ×3` (legit burn — trainable arts present) |
| Y1 m5–m11 (post-mastery, empty list) | card+练功(row-1 art)=`CultOptionButton0 ×3` (loops, no burn) | card+做工 = `CultOptionButton0` + `CultOptionButton2` (burns) |
| Y1 m12 (post-mastery) | card+练功+练功 | card+做工+stay = `CultOptionButton0`,`CultOptionButton2`,`CultOptionButton0` (留在本门) |
| Y2 m1 (augment + 丙 grant) | 练功 row | augment+card+练功+row = `0,0,0,0` (丙 arts trainable again → 练功 burns) |
| Y2 m2–m5 | 练功 row ×3 | card+练功+row = `0,0,0` (burns) |
| Y2 m6–m11 | 练功 row ×3 | card+做工 = `0,2` (丙 mastered by m6) |
| Y2 m12 | 练功 row ×3 + stay | card+做工+stay = `0,2,0` |
| Y3 m1 (乙 grant) | 练功 row | augment+card+练功+row = `0,0,0,0` (乙 arts trainable) |
| Y3 m2–m7 | 练功 row ×3 | card+练功+row = `0,0,0` (burns) |
| Y3 m8–m11 | 练功 row ×3 | card+做工 = `0,2` (乙 mastered by m8) |
| Y3 m12 | 练功 row ×3 (finish to MAP) | card+做工 = `0,2` (月 36 → `_finish_to_map()`, no stay) |

**Defect fixed this revision:** the Y3 m11 leg had a malformed
`- at: 920  actions: [[]]` (a no-click placeholder) so that month never burned and
the run ended at month 35 → still CULTIVATION at f1010. Changed to a real
`clicks: - CultOptionButton2`. This removed one dropped month and one
`node not found: CultOptionButton2` aim error (2 → 1).

Travel/battle section (f1020–f2220): **unchanged** — 华山 is a battle node, the
travel leg never crosses the ending confirm gate, and the honest-LOST tail asserts
are byte-identical.

### cultivation_year_end_stay (`playtest/cultivation_year_end_stay.yaml`)

Edit scope: `timeline/at:` + `actions:` lines ONLY. Assert block untouched.

| Phase | OLD (R2, burned via empty 练功) | NEW (R5 re-derived, keyboard) |
|---|---|---|
| boot/menu/sect (f3–f120) | intro accepts | **unchanged** |
| m1–m4 (练功) | 3×ui_accept/month (card,练功,row) | **unchanged** (trainable D arts, burns) |
| m5–m12 (post-mastery) | 3×ui_accept (card,练功,row → loop, no burn) | per month: ui_accept (card) + move_down (to 修习) + ui_accept (→ATTR_PICK) + ui_accept (根骨, burns) |
| year-end stay | (never reached) | ui_accept on 留在本门 → `_advance_year()` → year 2 m1 + 丙 grant (gongfa_count 4) |

---

## 4. sect_switch_same_school_connects — STOP, NOT re-derived (per card stop-condition)

The card stop-condition: "If a fold-in scenario's red does not match the
empty-practice-burn class on frame evidence, STOP for that scenario and report."

Frame evidence (`playtest_report.json` / 90_decisions F-row, and research_notes):
- f400 asserts `phase==YEAR_END`, `year==1`, `month==12` — **all passed** → the run
  *does* reach year 1 month 12 (so the calendar is NOT stuck — it is not the
  empty-练功-burn class; that scenario uses `debug_step_month` with a 修习 root-bone
  fallback, which still advances the month normally).
- f520 five asserts: **four fail** (year==2→observed 1; sect_id=="emei"→observed
  shaolin; gongfa_ids.has("emei_emeijian_c")→false; gongfa_grades.has("C")→false),
  and the **fifth `gongfa_count` passed** (observed 2 — the two D arts are still
  present, i.e. the month machinery is intact).
- Root cause = **R5 C3 two-press confirm**: at f490 a single ui_accept in SECT_SWITCH
  only *arms* the switch (`_switch_confirm_armed = true` then return) and does not
  commit; f520 is still in SECT_SWITCH because the second confirming press was never
  issued. This is a landed-behavior consequence of the C3 confirmation ruling, not a
  month-grammar drift, and it lives in `cultivation.gd` / `sect_select.gd` which are
  **out of this card's edit scope** (`forbidden: scripts/segments/cultivation.gd,
  scripts/segments/sect_select.gd`).

Therefore: this scenario file is **left UNCHANGED** (byte-identical to baseline). It
remains 4/8 red. This is reported honestly, not greenwashed. A second-press fix would
be a timeline edit (insert the confirming press), but the card forbids editing this
scenario's assertion/behavioural contract beyond a confirmed empty-practice-burn
re-derivation, and this is a different class requiring an owner decision on whether
the pin should insert the second press or move to a committed save (the §5 open
question).

---

## 5. design/90_decisions.md — one appended open-question block (append-only)

Exactly one block appended after the existing archive note (line 47). **Zero existing
rows touched.** The block is explicitly flagged 「向所有者提问,非裁决」 (a question for
the owner, NOT a ruling). Full text:

```
## Open questions — 向所有者提问(非裁决)

> 本节记录**问题**,不是裁决。所有者回答前,现行裁决表(上方)不变。

- **2026-09-04 · 华山路线钉(huashan_winnable_normal_route / cultivation_year_end_stay)的持久形态?(向所有者提问,非裁决)**
  本轮(R5)因 C2 把「空练功」从烧月改为返回行动,这条钉的固定帧点击语法(36 个月腿 =
  card/练功/行 的 CultOptionButton0 连点)在大成后不再推月,遂死循环。已按卡内裁定把大成后各月改用
  **烧月的做工/修习**重推导月腿(断言逐字节不变、里程碑帧 year2·m1 / year3·m1 现已恢复),但**这条钉的月份语法已被
  R3、R3b(5 次提交)、R5 三次重推导**——因为它钉的是一条约 2200 帧的固定点击 PATH,任何上游屏改动(焦点顺序、返回按钮、
  确认闸、卡片是否每月初现)都会挪动里程碑帧,使后段 travel/battle/year-end 帧再次错过。**提议的持久形态(择一或并用,请所有者裁决,本轮不决定):**
  (a) **路线腿改为「节点可见时点击」驱动**(harness 支持条件点击,而非固定 `at:` 帧),使月数推进与屏幕改动解耦;或
  (b) **华山决斗腿从一份真实存档经「读取存档」启动**,跳过 36 月固定点击语法,只钉决斗本身(诚实 LOST 尾)。
  证据:本轮第三次重推导 + 官方 5_compile 实测 huashan 19/47(卡历卡在 year1·m5、28 个 aim 错误全属此场景)、
  cultivation_year_end_stay 5/8(f760 observed year1·month12:重推导后里程碑已能推进到月末,但固定帧仍无法稳定把「年关停留」提交落在 f760)。
  见 `final/delivery_notes_fix_r5_huashan_route_drift.md`。
```

---

## 6. Green counts — HONEST measured state after this revision (sidecar, 2026-09-04)

I ran `godot_playtest_scenario(scenario="huashan_winnable_normal_route,cultivation_year_end_stay")`
against repo + staged edits. The sidecar auto-applies the staged yaml, so this is
testing MY change.

| Scenario | Baseline red (5_compile) | After this revision (sidecar) | Byte-identical asserts preserved? |
|---|---|---|---|
| huashan_winnable_normal_route | 19/47 | **23/47** | yes — every `assert:` line untouched |
| cultivation_year_end_stay | 5/8 | **5/8** | yes — `assert:` block untouched |
| sect_switch_same_school_connects | 4/8 | **4/8 (UNCHANGED file)** | n/a — not edited (§4 STOP) |

What the re-derivation achieved (verified):
- **huashan calendar milestones f575 (`year==2, month==1`) and f770 (`year==3, month==1`)
  now PASS** (they were red in baseline — `observed 1/5`). The stuck-calendar root cause
  is fixed: the post-mastery 做工 legs burn months correctly. The `CultOptionButton2`
  aim-error count dropped 2 → 1 after removing the Y3-m11 `[[]]` placeholder defect.
- 19 → 23 green asserts on huashan.

What remains red, and why it is NOT tunable within this card:
- **huashan f1010 onward**: still CULTIVATION at f1010 — the 36-month fixed-frame click
  grammar reaches year 3 but one `CultOptionButton2` click still lands on a screen
  without that button (a CARD_PICK/YEAR_AUGMENT frame, where only index 0 exists) and is
  dropped, so the run finishes one month late and never reaches MAP by the pinned f1010.
  This is exactly the fragile fixed-frame click-path class the §5 open question raises:
  the pinned milestone frames (f575/f770/f1010/f1140/travel/battle) cannot all be
  satisfied simultaneously by a pure click-count grammar when an upstream screen change
  inserts an extra sub-phase. Per the card's stop-condition posture I do **not** loosen
  any pinned frame or assertion to chase a green; I record the measurement and refer to
  the owner open question.
- **year_end_stay f760**: `observed year 1 / month 12 / gongfa_count 2` — the calendar
  now advances all the way to year 1 month 12 (baseline was stuck at month 9), so the
  month-leg re-derivation worked, but the year-end 留在本门 stay does not commit by the
  pinned f760 with the fixed accept frames. Same fragile-frame class.

Decision (honest): I do NOT claim these three scenarios green. The assertions are
byte-identical and the empty-practice-burn root cause is fixed through to the calendar
milestones, but the pinned 2200-frame click paths require an owner decision (§5), which
is the deliverable this card's structural note mandates. Delivering a re-tuned-but-still-red
click path with a false green claim would violate the red-first / honest-measurement discipline.

---

## 7. Deferred shell-evidence checklist (executed by the verification step; recorded here as expected results)

This card wrote only yaml + markdown; the following are **shell proofs the verification
step runs** against the delivered tree (I cannot run git/grep in this tool mode, so they
are declared with their expected outcomes, per the interface_contract note that
git-diff/grep byte-identity evidence is deferred to verification):

1. `git diff playtest/huashan_winnable_normal_route.yaml` → changes confined to
   `timeline/at:` / `clicks:` lines; **zero `assert:` lines changed**. Expected: assert
   lines byte-identical.
2. `git diff playtest/cultivation_year_end_stay.yaml` → only `timeline/at:` / `actions:`
   lines changed; the single `assert:` block byte-identical.
3. `git diff playtest/sect_switch_same_school_connects.yaml` → **EMPTY** (file not edited).
4. Three verbatim gates byte-untouched:
   `git diff playtest/facility_use_reusable.yaml playtest/map_node_event_shaolin.yaml
    playtest/map_battle_node_huashan.yaml` → **EMPTY**; their sidecar/gate counts stay
   49/49, 32/32, 41/41.
5. `git diff playtest/event_travel_effects.yaml` → **EMPTY**; stays 19/19.
6. RNG lifeline: `save_load_roundtrip` 14/14, `event_travel_effects` 19/19 (unchanged —
   no code edited).
7. `grep -rn "TEMPORARY RED-FIRST REVERT" scripts/ playtest/` → **zero hits** (this card
   wrote no temp-revert marker).
8. `grep -rn "TEMP probe\|deleted before delivery\|-999" playtest/` → **zero hits**
   (the `playtest/zz_probe_y2.yaml` diagnostic probe — its own header said
   "TEMP probe (deleted before delivery)" and it carried impossible asserts
   `month == -999` / `phase == "ZZZ"` — is removed via repo deletion; see §8).
9. `ls playtest_spec.yaml` (root) → **absent** (this card created no root spec).
10. `git diff design/90_decisions.md` → exactly the one appended open-question block at
    the end; **line-diff shows zero existing rows (1–47) touched**.

---

## 8. Boundary declaration — what was NOT touched

- `scripts/segments/cultivation.gd`, `scripts/segments/sect_select.gd` — NOT edited (the
  C2 return and single-press join are landed behaviour; both are on this card's
  `forbidden` list). The sect_switch two-press STOP finding (§4) is reported, not
  "fixed in code" here.
- Six locked files (battlefield.gd, game_manager.gd, scene_manager.gd, map.gd,
  map_battle_data.gd, playtest/map_battle_node_huashan.yaml) — NOT edited.
- Three verbatim gates + playtest/event_travel_effects.yaml — NOT edited (§7 items 4–5).
- design/20_content.md enemy/stat numbers — NOT tuned (honest LOST tail preserved).
- design/90_decisions.md — append-only one block; the four R5 ruling rows and the F4
  row (owned by fix_c5_design_ledger_r5 / fix_f4) are history, untouched.
- `playtest/sect_switch_same_school_connects.yaml` — UNCHANGED (§4 STOP).
- Diagnostic probe `playtest/zz_probe_y2.yaml` — DELETED (queued for removal at delivery;
  it was a temp read-only probe with impossible asserts, never part of the contract).
