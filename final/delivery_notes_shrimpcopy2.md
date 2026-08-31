# Delivery Notes — jinyong-shrimpcopy2 (Shrimp Wuxia Event Prose Rewrite)

**Date:** 2026-08-31
**Task:** `delivery_docs_and_readme` (terminal implementation task) — consolidates the round's evidence trail from the four task-notes files into this document and syncs README title mentions.
**Round scope (recap):** rewrite the prose (`title` / `text` / `option_a.label` / `option_b.label`) of the 36-row journey-event pool in `scripts/data/event_data.gd` so every written person is a shrimp (claws, antennae, carapace, curled tail segments) while the wuxia world stays verbatim — no underwaterization, no species names for passersby. ids / effects / option structure / row order / 36-row count are byte-identical.

> **Official gate evidence.** The authoritative gate artifacts (`compile_report.json` / `playtest_summary.md` / `test_report.json` / `vision_report.json`) are produced **only by the pipeline's later gate steps** (5_compile / 5_test / 5_vision). This task does **not** predict or pre-write any gate result; everything below is the measured/derived evidence the implementation recorded while editing.

---

## (a) Baseline git hash

`final/shrimp_guard_red_first_notes.md` recorded the baseline commands (`git rev-parse HEAD`, `pytest tests/ -v`, `godot --headless --path . -s res://tests/unit_test_runner.gd`) **verbatim but did not run them** — this step's toolset has no shell. **No baseline git hash was measured by this round's implementation tasks.** Per the repo's no-fake-measurement rule, no hash is fabricated here. The authoritative baseline (green starting state: 95/95 GDScript files compile, 78/78 playtest scenarios PASS, GDScript unit suite green, pytest guards green) and the authoritative baseline hash are captured by the pipeline's **5_test gate**.

---

## (b) Guard red-first numbers

`tests/test_event_prose_shrimp.py` (NEW, stdlib-only pytest, modeled on `test_shrimp_roster.py`) carries frozen token lists (HUMAN_TOKENS ×38, UNDERWATER_TOKENS ×12, SPECIES_TOKENS ×13, PROTECTED ×4) over `scripts/data/event_data.gd` only. It was landed **first**, before any prose edit, so its red is this round's measured-red-first evidence.

**Derived inventory (from the pre-edit 36-row corpus, structural inspection on 2026-08-31):**
- `test_no_human_tokens` — **39 failing (row_id, token) pairs across 28 rows** (full inventory in `final/shrimp_guard_red_first_notes.md` :58-:87). The 8 clean rows are the Class-B rows: ruins, tomb_bed, wounded_eagle, peach_maze, ancient_bell, wedding_train, sword_mound, wild_goose_letter.
- `test_no_underwater_tokens` — expected PASS (no underwater token in pre-edit corpus; 泅水而过 is deliberately not banned — a land-world river-crossing feat).
- `test_no_species_tokens` — expected PASS (no species name in any event row).
- `test_protected_literals_present` — expected PASS (all 4 protected literals present: 崖上采药 title, 重金购芝 label, 泅水而过 label, 破财消灾 label).

**Mid-round red count** (`final/shrimp_slice_frozen16_notes.md` :127): after the frozen-16 slice landed, the remaining appended-20 Class-A rows still carried person tokens — **16 affected rows / 22 (row, token) hits** (riverside_duel 剑客, poisoned_well 药翁, tiger_pass 头目, lantern_festival 人声, pawnshop 刀主, storyteller 说书人, chess_stall 无人, smithy 老铁匠, cliff_herbs 招人, night_inn 掌柜+揉眼, snow_pass 向导, drunken_fist 醉汉+手舞足蹈, river_god 巫师+村民, plague_village 郎中, young_disciple 少年, fallen_rider 客商+揉着腰+寻人+搭手).

After the appended-20 slice, all four guard tests are **GREEN** across the whole 36-row TABLE (no human, underwater, or species token; all protected literals present).

**These counts are labeled DERIVED/EXPECTED inventory read from the corpus.** The **measured** pytest output (actual failing-test names, exact failing (row_id, token) count, affected row ids) is captured by the pipeline's **5_test pytest gate** (`test_report.json`), not by this task — no predicted value is recorded as a measurement.

---

## (c) Complete per-changed-line inventory (old → new)

**34 changed prose fields across 28 Class-A rows** (5 titles + 27 texts + 2 labels), plus `_test_fresh_instances` :387 and the 4 README edits. 8 Class-B rows are byte-identical and not listed.

### Frozen-16 slice (12 Class-A rows) — from `final/shrimp_slice_frozen16_notes.md`

| id | field | old → new |
|---|---|---|
| bandits | title | `山道遇劫匪` → `山道遇劫` |
| bandits | text | `行至山道，一伙劫匪拦住去路。\n为首之人手提钢刀，索要买路财。` → `行至山道，一伙拦路的虾截住去路。\n为首一只长钳提着钢刀，索要买路财。` |
| merchant | title | `行商路过` → `车马过路` |
| merchant | text | `一位行商赶着马车路过，\n车上满载刀剑兵刃，正愁销路。` → `一只虾赶着马车路过，\n钳里挽着缰绳，满载刀剑兵刃正愁销路。` |
| beggar | title | `老丐乞食` → `巷口乞食` |
| beggar | text | `巷口一名老丐伸手乞食，\n目光却在你身上暗暗打量。` → `巷口一只老虾伸钳乞食，\n触须低垂，复眼却在你身上暗暗打量。` |
| snake_bile | text | `白驼山弟子叫卖蛇胆，\n称其大补真元，价钱不菲。` → `白驼山来的虾客叫卖蛇胆，\n药袋挂在触须上，称大补真元，价钱不菲。` |
| dragon_scrap | label_b | `卖与书贾` → `卖与书铺` |
| flood_ferry | text | `河水暴涨，渡口只余一舟，\n艄公索价甚高，爱搭不理。` → `河水暴涨，渡口只余一舟，\n一只虾撑舟而立，索价甚高，爱搭不理。` |
| escort_job | text | `镖头缺人手，见你身手，\n便邀你押一趟去南边的镖。` → `镖局里一只虾头领缺个帮工，见你身手，\n便邀你押一趟去南边的镖。` |
| dali_market | text | `市集上皮甲快靴俱全，\n掌柜的拍着胸脯称分量十足。` → `市集上皮甲快靴俱全，\n铺里的虾拍着甲壳称分量十足。` |
| night_rain | text | `夜雨滂沱，破庙漏得厉害，\n老僧独坐，就着灯火补屋檐。` → `夜雨滂沱，破庙漏得厉害，\n一只老虾独坐，就着灯火补屋檐。` |
| gambling_den | text | `镇上赌坊彻夜喧闹，\n有人一夜输光了全部盘缠。` → `镇上赌坊彻夜喧闹，\n一只虾一夜输光了全部盘缠。` |
| quanzhen_scripture | text | `全真宫外老道伏案抄经，\n见你驻足，递来一卷道德经。` → `全真宫外一只老虾伏案抄经，\n见你驻足，伸钳递来一卷道德经。` |
| lost_purse | text | `路旁褡裢里散着银两，\n四下无人，只有风声掠过草叶。` → `路旁褡裢里散着银两，\n四下不见虾影，只有风声掠过草叶。` |
| lost_purse | label_a | `送还失主` → `归还失物` |

Frozen-16 slice changed fields: **3 titles + 11 texts + 2 labels = 16 fields**. Unchanged labels within this slice: bandits (`破财消灾`/`出手退敌`), merchant (`买下长剑`/`婉拒`), beggar (`施舍`/`切磋武学`), flood_ferry both labels (`付钱渡河`/`泅水而过` — protected), quanzhen_scripture `随他抄经` kept (pronoun rule), lost_purse `收起走人`.

### Appended-20 slice (16 Class-A rows) — from `final/shrimp_slice_appended20_notes.md`

| id | field | old → new |
|---|---|---|
| riverside_duel | text | `河滩上两派剑客各立一端，\n口舌已僵，都请你执剑裁断。` → `河滩上两派虾客各立一端，\n口舌已僵，都请你执剑裁断。` |
| poisoned_well | text | `荒村井水一夜发苦，\n药翁提药箱来，开口要价。` → `荒村井水一夜发苦，\n一只老虾背着药箱来，开口要价。` |
| tiger_pass | text | `崖下虎啸阵阵，\n商队头目兜售过路符。` → `崖下虎啸阵阵，\n商队的虾首领挥螯兜售过路符。` |
| lantern_festival | text | `上元灯会人声鼎沸，\n灯摊谜面未解，猴子却已逃了。` → `上元灯会虾声鼎沸，\n灯摊谜面未解，猴子却已逃了。` |
| pawnshop | text | `当铺柜台压着一柄断票旧刀，\n刀主落魄，已无力赎当。` → `当铺柜台压着一柄断票旧刀，\n原是落魄的虾客当的，已无力赎当。` |
| storyteller | text | `茶馆说书人正讲一段旧年剑侠，\n满堂喝彩，茶碗都忘了喝。` → `茶馆里一只老虾醒木一拍，\n讲起旧年剑侠，满堂虾客忘了茶碗。` |
| chess_stall | text | `街角棋盘摆着一局残局，\n据说十年无人解出。` → `街角棋盘摆着一局残局，\n据说十年无虾解出。` |
| smithy | text | `铁匠铺炉火正旺，\n老铁匠说你的旧剑可以回炉重铸。` → `铁匠铺炉火正旺，\n铺里的老虾说你的旧剑可以回炉重铸。` |
| cliff_herbs | text | `崖上采药人正招人攀崖，\n崖顶灵芝长势极好，亦可买去。` → `崖上一只采药的虾正招同伴攀崖，\n崖顶灵芝长势极好，亦可买去。` |
| night_inn | text | `客栈掌柜伏在账本前揉眼，\n见你驻足，邀你帮算账或温酒暖身。` → `客栈里一只虾伏在账本前，\n用螯揉着复眼，见你驻足邀你帮算账或温酒。` |
| snow_pass | text | `风雪封了隘口，\n向导蹲在火边，开口报了价。` → `风雪封了隘口，\n一只虾蹲在火边，触须挂着雪，开口报了价。` |
| drunken_fist | title | `醉汉传拳` → `酒肆拳影` |
| drunken_fist | text | `醉汉在酒肆口手舞足蹈，\n看似胡闹，拳理却暗合章法。` → `一只醉虾在酒肆口挥舞双螯，\n看似胡闹，拳理却暗合章法。` |
| river_god | text | `河伯娶亲的鼓号从村头响起，\n巫师索价，村民面有难色，求你定夺。` → `河伯娶亲的鼓号从村头响起，\n一只虾巫祝索价，众虾面有难色，求你定夺。` |
| plague_village | text | `疫村炊烟稀薄，\n村中郎中望着药柜叹气，缺药无力。` → `疫村炊烟稀薄，\n一只老虾守着药柜叹气，缺药无力。` |
| young_disciple | text | `一名少年在门外徘徊良久，\n终于鼓足勇气，开口求你指点。` → `一只年轻的虾在门外徘徊良久，\n终于鼓足勇气，开口求你指点。` |
| fallen_rider | title | `坠马客商` → `途中坠马` |
| fallen_rider | text | `客商坠马，货物散落一地，\n他揉着腰，四下张望寻人搭手。` → `一只行路的虾坠马，货物散落一地，\n它捶着甲壳，四下张望盼谁伸长钳来帮。` |

Appended-20 slice changed fields: **2 titles + 16 texts = 18 fields**. All labels in this slice unchanged; `ROW_LABELS` zero diff for this slice.

### Other sanctioned sync points

- **`tests/test_event_data.gd` `_test_fresh_instances` :387** — `"山道遇劫匪"` → `"山道遇劫"` (same commit as the bandits row; the literal pins the freshness property and follows the data it pins). `"破财消灾"` (:383) unchanged.
- **`tests/test_event_data.gd` mirrors** — `ROW_TITLES` (5 values: 山道遇劫 / 车马过路 / 巷口乞食 / 酒肆拳影 / 途中坠马), `ROW_TEXTS` (27 values), `ROW_LABELS` (2 values: 卖与书铺 / 归还失物) synced byte-for-byte including `\n` escapes. `ROW_EFFECTS` **never edited**.
- **`scripts/autoload/i18n.gd` EN dictionary** — every changed zh field's EN entry replaced **in place** (key AND value), no duplicate keys appended; ~34 entries. Every EN value renders a shrimp body (claws / antennae / carapace / compound eyes / tail) while keeping the English wuxia nouns. The EN membership gate (`_test_i18n_entries`) stays green.
- **README.md title mentions** — the 4 edits made by this task:

| line | old → new |
|---|---|
| README.md:23 | `山道遇劫匪` → `山道遇劫` (bandits title) |
| README.md:34 | `醉汉传拳` → `酒肆拳影` (drunken_fist title) |
| README.md:35 | `坠马客商` → `途中坠马` (fallen_rider title) |
| README.md:584 | `行商路过` → `车马过路` (merchant title) |

Same-paragraph neighbours that were **not** changed: README:34 `崖上采药`, README:584-:585 `全真抄经` / `降龙残谱` (unchanged titles). All other README bytes are untouched.

---

## (d) Playtest #78 literal-pin check (line by line)

`playtest/event_pool_new_event_resolved.yaml` pins two exact Chinese literals. **Neither string contains a person word**, so by design neither changes; this round's rewrite is a **zero diff to the yaml**. Both lines are documented as required by the brief.

- **:57** `event_title == "崖上采药"` — **checked — unchanged — and why:** the pinned string contains no person word. Per the design, `cliff_herbs`' title is frozen byte-identical (only its `text` changed — 采药人/招人 → 采药的虾/招同伴). The data still contains `"title": "崖上采药"`, and the guard's `test_protected_literals_present` enforces it. Zero diff to the yaml.
- **:62** `focused_option_text == "重金购芝"` — **checked — unchanged — and why:** the pinned string contains no person word, and the design froze `cliff_herbs`' option_b label byte-identical. The data still contains `"label": "重金购芝"`, and the guard enforces it. Zero diff to the yaml.
- **:58** `event_body != ""` — shape-only (non-empty body), survives the text rewrite.
- No other playtest yaml was touched; a repo grep for 崖上采药 / 重金购芝 over `playtest/` hits only `event_pool_new_event_resolved.yaml` :57/:62, both byte-matching the rewritten data.

---

## (e) Human-prose sweep inventory (outside the 36 events) — **record-only this round, not changed**

From `final/human_prose_sweep_notes.md`. No swept file was edited this round; this inventory is the raw material for the new OPEN backlog item (UX-19) that the 5_design step opens after the gate run.

**Runtime player-visible literals** (`file:line | "literal" | person words`):
- scripts/data/card_data.gd:33 | "行商分成" (eco_trade_1 card display name) | 行商
- scripts/data/card_data.gd:34 | "行商分成" (eco_trade_2) | 行商
- scripts/data/card_data.gd:35 | "行商分成" (eco_trade_3) | 行商
- scripts/data/facility_data.gd:31 | "木人巷中十八尊木人，\n拳脚如雨，是少林弟子练骨之地。" | 弟子
- scripts/data/map_data.gd:69 | "一代宗师" (tier-3 ending title) | 师 (grandmaster)
- scripts/data/map_data.gd:70 | "武林为之震动。\n你的名号传遍江湖，各派掌门纷纷登门请教。\n此世武学之巅，自此有了你的名字。" | 掌门
- scripts/data/map_data.gd:72 | "江湖中人都认得你的名号。\n行至何处，皆有豪杰相迎。\n虽未登峰造极，亦是一方武林名宿。" | 中人, 豪杰
- scripts/data/trait_data.gd:25 | "见过敌人用过的招式,可在无师门的情况下自学该门类的低级功法" | 敌人, 师门 (uncertain — battle opponents are the six shrimp characters)
- scripts/data/trait_data.gd:27 | "战斗中可穿过敌人所在格(不能停留其上)" | 敌人 (uncertain)
- scripts/data/trait_data.gd:30 | "永远单人上阵,不能带同伴;同时领杀·破·狼三星" | 人 (uncertain — 单人 is a morpheme)

**i18n.gd EN-dictionary keys (non-travel-event lines)**: i18n.gd:126/:128/:130 (tutorial, 敌人 uncertain), :143 (侠客 "Wanderer" player role), :217/:221/:227 (trait mirrors, uncertain), :241 (行商分成 card mirror), :423 (一代宗师 mirror), :424 (掌门 mirror), :426 (中人/豪杰 mirror), :455 (弟子 facility mirror).

**Test mirrors**: tests/test_card_data.gd:50 (`display_name == "行商分成"` mirror of card_data.gd:33).

**Adjacent observations** (recorded for visibility): scripts/data/battle_setup.gd:63 (`display_name = "侠客"` player battle-card label) — runtime player-visible person label; scenes/segments/sect_select.tscn:88 (`text = "丐帮"`) — classified SKIP (sect proper name).

**Skipped** (idiom morphemes / proper names / UI chrome / comments): card_data.gd:56 机缘悟道; trait_data.gd:23 无师自通 + i18n.gd:212; trait_data.gd:24 + i18n.gd:215; progression_gongfa_data.gd:60 丐帮 + i18n.gd:516; i18n.gd:501 兵刃, :504 悟道, :557 人物 (UI chrome), :138 黄药师 (one of the six protagonists, species already decided); equipment_data.gd:20 / player_profile.gd:24 (code comments).

**Clean files**: tutorial_fillers.gd, encounter_data.gd, gongfa_data.gd (only 丐帮 sect name), progression_gongfa_data.gd (only 丐帮), battlefield.tscn / main.tscn / menu.tscn / player.tscn / enemy.tscn.

**Statement: record-only this round, not changed.** Each runtime hit has exactly one mirror site (i18n key or test assertion) except map_data endings (:69/:70/:72 → i18n :423/:424/:426) and facility_data :31 → i18n :455; card hits ×3 share one i18n key (:241) and one test assertion.

---

## (f) Self-run evidence

Per `final/shrimp_slice_appended20_notes.md` :55: the #78 scenario pins contain **no changed literal**, so by contract **no sidecar re-run was required**. No scenario counts were fabricated. The pipeline gates (5_compile / 5_test / 5_vision) remain the authoritative runtime evidence for all 78 scenarios.

---

## (g) Invariants statement

- **`ROW_EFFECTS` byte-unchanged** — both slice notes record **zero diff** to `tests/test_event_data.gd` :11-:156 (never edited). This is the machine proof that no effect's type/value/target drifted.
- **Exactly 36 rows** in unchanged order (bandits → … → fallen_rider); `_test_no_repeat_full_journey` (seed 20260831) untouched.
- **ids / effects / option structure / row order untouched** — only prose fields changed.
- **8 Class-B rows byte-identical** — ruins, tomb_bed, wounded_eagle, peach_maze, ancient_bell, wedding_train, sword_mound, wild_goose_letter (data + mirrors + EN all untouched).
- **No underwater phrasing entered** — the UNDERWATER_TOKENS guard is green over the whole 36-row TABLE; scenes stay land-world (客栈 / 镖局 / 渡口 / 山道 / 马车 / 钢刀 / 银两 / 抄经 all verbatim). 泅水而过 (flood_ferry option_b) is deliberately retained as the protected land-world river-crossing feat — not a seabed-ification.
- **No species name written for passersby** — SPECIES_TOKENS guard green; the six decided species never appear in event prose.
- **EN membership gate green** — every row's four prose fields are keys of the EN dictionary (`_test_i18n_entries`); the pytest `test_i18n_coverage.py` is blind to event prose (variable-path `tr()`), so the gate is the real guard.

---

## Scope boundaries honored by this task

- This task did **not** write `UX-17 → CLOSED` anywhere.
- This task did **not** edit `design/20_content.md` / `design/90_decisions.md` / `design/40_ux_backlog.md` / `design/99_changelog.md` — those belong to the 5_design step after the gate run.
- This task did **not** touch any `playtest/*.yaml` (zero-diff expectation confirmed: grep found no changed literal in playtest other than the two #78 pins, which are unchanged).
- Sanctioned files changed this round: `scripts/data/event_data.gd` (prose), `tests/test_event_data.gd` (three prose mirrors + `_test_fresh_instances` :387), `scripts/autoload/i18n.gd` (EN event-block), `tests/test_event_prose_shrimp.py` (NEW guard), `README.md` (4 title mentions, this task), and this delivery note. Remaining references to changed titles live only in sanctioned historical/pipeline-metadata files (`.aitelier/knowledge.md`, `final/*`, previous `step2_design.md`) and the deferred design docs (5_design's scope).
