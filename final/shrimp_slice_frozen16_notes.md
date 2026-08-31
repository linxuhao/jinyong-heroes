# Shrimp Prose Slice — Frozen-16 (12 Class-A rows)

**Date:** 2026-08-31
**Step:** shrimp_prose_slice_frozen16 (implementer)
**Scope:** rewrite prose fields (`title` / `text` / `option_a.label` / `option_b.label`) of the 12 frozen-16 Class-A journey-event rows so every written person is a shrimp; sync the three test mirrors, the `_test_fresh_instances` :387 literal, and the `i18n.gd` EN dictionary in lockstep. ids / effects / option structure / row order / 36-row count are untouched (`ROW_EFFECTS` zero-diff).

## Per-row old → new inventory

### bandits
- title: `山道遇劫匪` → `山道遇劫`
- text: `行至山道，一伙劫匪拦住去路。\n为首之人手提钢刀，索要买路财。` → `行至山道，一伙拦路的虾截住去路。\n为首一只长钳提着钢刀，索要买路财。`
- labels: unchanged (`破财消灾` / `出手退敌`)
- EN: `"山道遇劫匪": "Bandits on the Mountain Road"` → `"山道遇劫": "Ambush on the Mountain Road"`; text EN replaced in place with a shrimp pack + long-claw saber line.

### merchant
- title: `行商路过` → `车马过路`
- text: `一位行商赶着马车路过，\n车上满载刀剑兵刃，正愁销路。` → `一只虾赶着马车路过，\n钳里挽着缰绳，满载刀剑兵刃正愁销路。`
- labels: unchanged (`买下长剑` / `婉拒`)
- EN: `"行商路过": "A Passing Merchant"` → `"车马过路": "A Cart on the Road"`; text EN replaced (shrimp driving the cart, claws on the reins).

### ruins — Class-B, byte-identical (untouched).

### beggar
- title: `老丐乞食` → `巷口乞食`
- text: `巷口一名老丐伸手乞食，\n目光却在你身上暗暗打量。` → `巷口一只老虾伸钳乞食，\n触须低垂，复眼却在你身上暗暗打量。`
- labels: unchanged (`施舍` / `切磋武学`)
- EN: `"老丐乞食": "An Old Beggar"` → `"巷口乞食": "Begging at the Alley Mouth"`; text EN replaced (old shrimp, claw out, drooping antennae, compound eyes).

### tomb_bed / wounded_eagle / peach_maze — Class-B, byte-identical (untouched).

### snake_bile (text only)
- text: `白驼山弟子叫卖蛇胆，\n称其大补真元，价钱不菲。` → `白驼山来的虾客叫卖蛇胆，\n药袋挂在触须上，称大补真元，价钱不菲。`
- title `蛇胆奇效` and both labels unchanged.
- EN: text EN replaced (White Camel Mountain shrimp, pouch on an antenna).

### dragon_scrap (label_b only)
- label_b: `卖与书贾` → `卖与书铺`
- title `降龙残谱`, text, label_a `强记于心` byte-identical.
- EN: `"卖与书贾": "Sell it to a bookseller"` → `"卖与书铺": "Sell it to a bookshop"`.

### flood_ferry (text only)
- text: `河水暴涨，渡口只余一舟，\n艄公索价甚高，爱搭不理。` → `河水暴涨，渡口只余一舟，\n一只虾撑舟而立，索价甚高，爱搭不理。`
- BOTH labels byte-identical (`付钱渡河` / `泅水而过` — the protected land-world river-crossing feat is untouched).
- EN: text EN replaced (shrimp poling the boat); `泅水而过` EN `"Swim across"` unchanged.

### escort_job (text only)
- text: `镖头缺人手，见你身手，\n便邀你押一趟去南边的镖。` → `镖局里一只虾头领缺个帮工，见你身手，\n便邀你押一趟去南边的镖。`
- title `镖行招募` and labels unchanged (`接下镖单` / `婉拒独行`).
- EN: text EN replaced (escort agency's shrimp chief); `身手` idiom retained in EN.

### dali_market (text only)
- text: `市集上皮甲快靴俱全，\n掌柜的拍着胸脯称分量十足。` → `市集上皮甲快靴俱全，\n铺里的虾拍着甲壳称分量十足。`
- title `大理市集` and labels unchanged.
- EN: text EN replaced (shopkeeper shrimp pounds its carapace).

### night_rain (text only)
- text: `夜雨滂沱，破庙漏得厉害，\n老僧独坐，就着灯火补屋檐。` → `夜雨滂沱，破庙漏得厉害，\n一只老虾独坐，就着灯火补屋檐。`
- title `破庙夜雨` and labels unchanged.
- EN: text EN replaced (old shrimp mending eaves by lamplight).

### gambling_den (text only)
- text: `镇上赌坊彻夜喧闹，\n有人一夜输光了全部盘缠。` → `镇上赌坊彻夜喧闹，\n一只虾一夜输光了全部盘缠。`
- title `赌坊喧嚣` and labels unchanged.
- EN: text EN replaced (a shrimp gambled away its travel purse).

### quanzhen_scripture (text only)
- text: `全真宫外老道伏案抄经，\n见你驻足，递来一卷道德经。` → `全真宫外一只老虾伏案抄经，\n见你驻足，伸钳递来一卷道德经。`
- title `全真抄经` and labels unchanged; `随他抄经` kept (pronoun rule — antecedent is the described shrimp).
- EN: text EN replaced (old shrimp copies scripture, extends a claw with the scroll).

### lost_purse
- text: `路旁褡裢里散着银两，\n四下无人，只有风声掠过草叶。` → `路旁褡裢里散着银两，\n四下不见虾影，只有风声掠过草叶。`
- label_a: `送还失主` → `归还失物`
- title `遗落的褡裢` and label_b `收起走人` unchanged.
- EN: text EN replaced (no shrimp in sight); `"送还失主": "Find the owner"` → `"归还失物": "Return the lost goods"`.

## Sync record

### tests/test_event_data.gd
- `ROW_TITLES`: bandits `山道遇劫`, merchant `车马过路`, beggar `巷口乞食` (3 values).
- `ROW_TEXTS`: bandits / merchant / beggar / snake_bile / flood_ferry / escort_job / dali_market / night_rain / gambling_den / quanzhen_scripture / lost_purse (11 values), byte-for-byte including the `\n` escapes.
- `ROW_LABELS`: dragon_scrap `["强记于心", "卖与书铺"]`, lost_purse `["归还失物", "收起走人"]` (2 values).
- `ROW_EFFECTS`: **zero diff** (never edited).
- `_test_fresh_instances` :387 literal: `"山道遇劫匪"` → `"山道遇劫"` (same commit as the bandits row). `"破财消灾"` (:383) unchanged.
- `_test_no_repeat_full_journey` (seed 20260831): untouched — ids/effects/row order/36-row count unchanged.

### scripts/autoload/i18n.gd (EN dictionary, travel-events block)
All replaced **in place** (key AND value); no duplicate keys appended. Changed entries:
- bandits title + text
- merchant title + text
- beggar title + text
- snake_bile text
- dragon_scrap label_b
- flood_ferry text
- escort_job text
- dali_market text
- night_rain text
- gambling_den text
- quanzhen_scripture text
- lost_purse text + label_a

Every EN value renders a shrimp body (claws / antennae / carapace / compound eyes / tail) while keeping the wuxia nouns in English (mountain road, steel saber, cart, inn objects, escort agency, market, ferry boat, gambling den, scripture, silver). The EN membership gate (`_test_i18n_entries`) stays green because all four prose fields of every row remain keys of `EN`.

## Guard state (recorded, not fixed here)

`pytest tests/test_event_prose_shrimp.py` is **expected to stay RED** by construction: the 16 appended-20 Class-A rows still carry person tokens. The implementer cannot run pytest (pipeline gate owns execution); the remaining red rows/tokens are read directly from the current corpus:

| row | person tokens remaining (HUMAN_TOKENS) |
|---|---|
| riverside_duel | 剑客 |
| poisoned_well | 药翁 |
| tiger_pass | 头目 |
| lantern_festival | 人声 |
| pawnshop | 刀主 |
| storyteller | 说书人 |
| chess_stall | 无人 |
| smithy | 老铁匠 |
| cliff_herbs | 招人 |
| night_inn | 掌柜, 揉眼 |
| snow_pass | 向导 |
| drunken_fist | 醉汉, 手舞足蹈 |
| river_god | 巫师, 村民 |
| plague_village | 郎中 |
| young_disciple | 少年 |
| fallen_rider | 客商, 揉着腰, 寻人, 搭手 |

That is **16 affected rows** and **22 (row, token) hits** as read from the corpus. None of these 16 rows were touched this task. The guard's `test_no_human_tokens` fails on these; `test_no_underwater_tokens` / `test_no_species_tokens` / `test_protected_literals_present` are green over the current file. The guard turns green only when the appended-20 slice lands (next task). The protected literals (`"title": "崖上采药"`, `"重金购芝"`, `"泅水而过"`, `"破财消灾"`) are all still present in `event_data.gd`.

## Invariants verified (by reading, before/after)
- `scripts/data/event_data.gd` still has exactly 36 rows in unchanged order (bandits → … → fallen_rider).
- ids, effects, option structure, and the `\n` two-line body shape unchanged; `ROW_EFFECTS` zero-diff.
- Class-B neighbours (ruins, tomb_bed, wounded_eagle, peach_maze) byte-identical in data + mirrors + EN.
- Titles ≤ 6 CJK chars; labels ≤ 6 CJK chars; body lines ≤ 20 CJK chars.
