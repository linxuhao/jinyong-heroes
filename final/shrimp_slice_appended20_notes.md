# Slice Notes — shrimp_prose_slice_appended20

**Date:** 2026-08-31
**Task:** jinyong-shrimpcopy2 — 16 appended-20 Class-A journey-event rows rewritten to shrimp prose; mirrors + EN dictionary synced; playtest #78 literal pins verified byte-identical.

## Scope
- `scripts/data/event_data.gd` `const TABLE` — 16 rows only (`riverside_duel`, `poisoned_well`, `tiger_pass`, `lantern_festival`, `pawnshop`, `storyteller`, `chess_stall`, `smithy`, `cliff_herbs`, `night_inn`, `snow_pass`, `drunken_fist`, `river_god`, `plague_village`, `young_disciple`, `fallen_rider`). Only `title`/`text` prose fields edited; `id`, `effects`, option structure, row order all byte-identical.
- `tests/test_event_data.gd` — `ROW_TITLES` (2 values) and `ROW_TEXTS` (16 values) mirrored byte-for-byte. `ROW_LABELS` this slice: **zero diff**. `ROW_EFFECTS` :11-:156: **never touched**.
- `scripts/autoload/i18n.gd` — 18 EN entries replaced **in place** (key AND value), no duplicate keys.
- Class-B neighbours `ancient_bell`, `wedding_train`, `sword_mound`, `wild_goose_letter`: **byte-identical**.

## Per-row old → new inventory (this slice)

| id | field | old | new |
|---|---|---|---|
| riverside_duel | text | 河滩上两派剑客各立一端，\n口舌已僵，都请你执剑裁断。 | 河滩上两派虾客各立一端，\n口舌已僵，都请你执剑裁断。 |
| poisoned_well | text | 荒村井水一夜发苦，\n药翁提药箱来，开口要价。 | 荒村井水一夜发苦，\n一只老虾背着药箱来，开口要价。 |
| tiger_pass | text | 崖下虎啸阵阵，\n商队头目兜售过路符。 | 崖下虎啸阵阵，\n商队的虾首领挥螯兜售过路符。 |
| lantern_festival | text | 上元灯会人声鼎沸，\n灯摊谜面未解，猴子却已逃了。 | 上元灯会虾声鼎沸，\n灯摊谜面未解，猴子却已逃了。 |
| pawnshop | text | 当铺柜台压着一柄断票旧刀，\n刀主落魄，已无力赎当。 | 当铺柜台压着一柄断票旧刀，\n原是落魄的虾客当的，已无力赎当。 |
| storyteller | text | 茶馆说书人正讲一段旧年剑侠，\n满堂喝彩，茶碗都忘了喝。 | 茶馆里一只老虾醒木一拍，\n讲起旧年剑侠，满堂虾客忘了茶碗。 |
| chess_stall | text | 街角棋盘摆着一局残局，\n据说十年无人解出。 | 街角棋盘摆着一局残局，\n据说十年无虾解出。 |
| smithy | text | 铁匠铺炉火正旺，\n老铁匠说你的旧剑可以回炉重铸。 | 铁匠铺炉火正旺，\n铺里的老虾说你的旧剑可以回炉重铸。 |
| cliff_herbs | text | 崖上采药人正招人攀崖，\n崖顶灵芝长势极好，亦可买去。 | 崖上一只采药的虾正招同伴攀崖，\n崖顶灵芝长势极好，亦可买去。 |
| night_inn | text | 客栈掌柜伏在账本前揉眼，\n见你驻足，邀你帮算账或温酒暖身。 | 客栈里一只虾伏在账本前，\n用螯揉着复眼，见你驻足邀你帮算账或温酒。 |
| snow_pass | text | 风雪封了隘口，\n向导蹲在火边，开口报了价。 | 风雪封了隘口，\n一只虾蹲在火边，触须挂着雪，开口报了价。 |
| drunken_fist | title | 醉汉传拳 | 酒肆拳影 |
| drunken_fist | text | 醉汉在酒肆口手舞足蹈，\n看似胡闹，拳理却暗合章法。 | 一只醉虾在酒肆口挥舞双螯，\n看似胡闹，拳理却暗合章法。 |
| river_god | text | 河伯娶亲的鼓号从村头响起，\n巫师索价，村民面有难色，求你定夺。 | 河伯娶亲的鼓号从村头响起，\n一只虾巫祝索价，众虾面有难色，求你定夺。 |
| plague_village | text | 疫村炊烟稀薄，\n村中郎中望着药柜叹气，缺药无力。 | 疫村炊烟稀薄，\n一只老虾守着药柜叹气，缺药无力。 |
| young_disciple | text | 一名少年在门外徘徊良久，\n终于鼓足勇气，开口求你指点。 | 一只年轻的虾在门外徘徊良久，\n终于鼓足勇气，开口求你指点。 |
| fallen_rider | title | 坠马客商 | 途中坠马 |
| fallen_rider | text | 客商坠马，货物散落一地，\n他揉着腰，四下张望寻人搭手。 | 一只行路的虾坠马，货物散落一地，\n它捶着甲壳，四下张望盼谁伸长钳来帮。 |

**Changed fields:** 2 titles + 16 texts = 18 fields across 16 rows. All labels unchanged. `ROW_LABELS` this slice: zero diff.

## i18n.gd EN dictionary (18 entries replaced in place)
Every changed zh key above has a matching replaced EN entry describing shrimp anatomy (claws / antennae / carapace / compound eyes / curled tail) while keeping the English wuxia nouns (riverbank, medicine case, caravan, tavern, pawnshop counter, smithy fire, inn ledger, sword, horse). No duplicate keys added; the two old title keys (醉汉传拳 / 坠马客商) were **replaced** by the new keys (酒肆拳影 / 途中坠马), not appended. The EN membership gate (`_test_i18n_entries` in `tests/test_event_data.gd`) checks every row's four prose fields are EN keys — all satisfied.

## Playtest #78 literal-pin statement (line by line)

`playtest/event_pool_new_event_resolved.yaml`:
- **:57** `event_title == "崖上采药"` — **checked — unchanged — and why:** the pinned string contains no person word. Per the design, `cliff_herbs`' title is frozen byte-identical (only its `text` changed). The data still contains `"title": "崖上采药"` and the guard's `test_protected_literals_present` enforces it. Zero diff to the yaml.
- **:62** `focused_option_text == "重金购芝"` — **checked — unchanged — and why:** the pinned string contains no person word and the design froze `cliff_herbs`' option_b label byte-identical. The data still contains `"label": "重金购芝"` and the guard enforces it. Zero diff to the yaml.
- No other playtest yaml was touched; `grep -rn "崖上采药"` / `grep -rn "重金购芝"` over `playtest/` hit only `event_pool_new_event_resolved.yaml` :57/:62, both byte-matching the rewritten data.

## Guard red → green evidence
`tests/test_event_prose_shrimp.py` was **RED** over this slice's pre-edit corpus (per-row token hits recorded in `final/shrimp_guard_red_first_notes.md` :72-:87: 剑客 / 药翁 / 头目 / 人声 / 刀主 / 说书人 / 无人 / 老铁匠 / 招人 / 掌柜+揉眼 / 向导 / 醉汉+手舞足蹈 / 巫师+村民 / 郎中 / 少年 / 客商+寻人+揉着腰+搭手). After this slice all four guard tests (`test_no_human_tokens`, `test_no_underwater_tokens`, `test_no_species_tokens`, `test_protected_literals_present`) are **GREEN** across the whole 36-row TABLE. Banned underwater and species tokens: none introduced. 泅水而过 / 崖上采药 / 重金购芝 / 破财消灾 remain protected and present.

## Invariants confirmed
- `ROW_EFFECTS` (`tests/test_event_data.gd` :11-:156): **zero diff** — effects never drifted.
- TABLE has exactly 36 rows in unchanged order; ids/effects/option structure byte-identical.
- Class-B neighbours (ancient_bell, wedding_train, sword_mound, wild_goose_letter) and all frozen-16 rows: untouched this slice.
- Remaining repo references to the two changed titles are in `README.md` (owned by delivery_docs_and_readme), `design/20_content.md` (5_design), and historical notes — none pinned by tests or playtest.
- Self-run: the #78 scenario pins contain no changed literal, so no sidecar re-run is required by contract; the pipeline gates (5_compile / 5_test / 5_vision) remain the authoritative evidence.
