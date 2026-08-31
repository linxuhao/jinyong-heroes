# Human Prose Sweep — outside the 36 journey events (record-only)

Date: 2026-08-31
Task: human_prose_sweep (jinyong-shrimpcopy2)
Status: **record-only** — no swept file was edited. This inventory is the raw
material for the new OPEN backlog item (UX-19) that 5_design opens after the
gate run. One slice at a time later; each fix must sync its test mirror and
i18n entry in the same change.

Grep pattern used (verbatim):
`(人|僧|道|翁|匠|丐|匪|商|客|师|郎|主|民|徒|兄|姐|妹|侠|豪|杰|掌门|官|兵|贼|盗)`

Scope scanned: `scripts/data/{card_data,map_data,facility_data,trait_data,gongfa_data,progression_gongfa_data,tutorial_fillers,encounter_data}.gd`,
`scripts/autoload/i18n.gd` OUTSIDE the `# --- Travel events ---` block
(:1-:268 and :415-:606; the travel-event block :269-:414 belongs to the prose
slices, not this task), `scenes/*.tscn` text/label strings, and prose-pinning
test mirrors (`tests/test_card_data.gd`).

Line numbers are the measured current values (re-read 2026-08-31).

## Hits — runtime player-visible literals

Format: `file:line | "quoted literal" | person words found`

- scripts/data/card_data.gd:33 | "行商分成" (id eco_trade_1, economy card display name) | 行商
- scripts/data/card_data.gd:34 | "行商分成" (id eco_trade_2) | 行商
- scripts/data/card_data.gd:35 | "行商分成" (id eco_trade_3) | 行商
- scripts/data/facility_data.gd:31 | "木人巷中十八尊木人，\n拳脚如雨，是少林弟子练骨之地。" | 弟子
- scripts/data/map_data.gd:69 | "一代宗师" (tier-3 ending title) | 师 (person title: grandmaster)
- scripts/data/map_data.gd:70 | "武林为之震动。\n你的名号传遍江湖，各派掌门纷纷登门请教。\n此世武学之巅，自此有了你的名字。" | 掌门
- scripts/data/map_data.gd:72 | "江湖中人都认得你的名号。\n行至何处，皆有豪杰相迎。\n虽未登峰造极，亦是一方武林名宿。" | 中人, 豪杰
- scripts/data/trait_data.gd:25 | "见过敌人用过的招式,可在无师门的情况下自学该门类的低级功法" (trait photographic_memory description) | 敌人, 师门 (uncertain — 敌人 = battle opponents; those are the six shrimp characters, so arguably already shrimp-safe; recorded for 5_design to rule)
- scripts/data/trait_data.gd:27 | "战斗中可穿过敌人所在格(不能停留其上)" (trait swallow_lightness description) | 敌人 (uncertain — same reasoning as above)
- scripts/data/trait_data.gd:30 | "永远单人上阵,不能带同伴;同时领杀·破·狼三星" (trait sha_po_lang description) | 人 (uncertain — 单人 = "alone"; morpheme, not a person description)

## Hits — i18n.gd EN-dictionary keys (non-travel-event lines)

Same strings mirrored for translation; each is a distinct edit site when the
backlog slice lands (key AND value must move together):

- scripts/autoload/i18n.gd:126 | "移动到敌人身边，按 J（或鼠标左键）进行普通攻击。" (tutorial) | 敌人 (uncertain — enemy units are the shrimp roster)
- scripts/autoload/i18n.gd:128 | "按 1-4 选择重剑剑法招式，再按 J 对射程内最近的敌人施展。…" (tutorial) | 敌人 (uncertain)
- scripts/autoload/i18n.gd:130 | "按空格结束回合。结束回合后，敌人会按出手顺序依次行动。" (tutorial) | 敌人 (uncertain)
- scripts/autoload/i18n.gd:143 | "侠客": "Wanderer" (player role label) | 侠客
- scripts/autoload/i18n.gd:217 | "见过敌人用过的招式,可在无师门的情况下自学该门类的低级功法" (trait mirror) | 敌人, 师门 (uncertain)
- scripts/autoload/i18n.gd:221 | "战斗中可穿过敌人所在格(不能停留其上)" (trait mirror) | 敌人 (uncertain)
- scripts/autoload/i18n.gd:227 | "永远单人上阵,不能带同伴;同时领杀·破·狼三星" (trait mirror) | 人 (uncertain)
- scripts/autoload/i18n.gd:241 | "行商分成": "Merchant's Cut" (card mirror) | 行商
- scripts/autoload/i18n.gd:423 | "一代宗师": "Grandmaster of an Era" (ending title mirror) | 师 (person title)
- scripts/autoload/i18n.gd:424 | "武林为之震动。\n你的名号传遍江湖，各派掌门纷纷登门请教。\n此世武学之巅，自此有了你的名字。" (ending mirror) | 掌门
- scripts/autoload/i18n.gd:426 | "江湖中人都认得你的名号。\n行至何处，皆有豪杰相迎。\n虽未登峰造极，亦是一方武林名宿。" (ending mirror) | 中人, 豪杰
- scripts/autoload/i18n.gd:455 | "木人巷中十八尊木人，\n拳脚如雨，是少林弟子练骨之地。" (facility mirror) | 弟子

## Hits — test mirrors (recorded separately so 5_design can deduplicate)

Mirror-hits pin runtime prose 1:1; they change only when their source changes:

- tests/test_card_data.gd:50 | `CardData.def("eco_trade_1").display_name == "行商分成"` | 行商 (mirror of card_data.gd:33)

## Adjacent observations (outside this task's declared scan list — recorded for visibility, per plan review)

- scripts/data/battle_setup.gd:63 | `cd.display_name = "侠客"` (player battle-card display name) | 侠客 — runtime player-visible person label; its file was not in the plan's scan list but the reviewer flagged it, so it is recorded here rather than silently omitted.
- scenes/segments/sect_select.tscn:88 | `text = "丐帮"` | 丐帮 — classified SKIP (sect proper name, like 白驼山/全真宫), listed here only to show the .tscn sweep found it.

## Classification: skipped (with reason)

- scripts/data/card_data.gd:56 "机缘悟道" — 道 is an idiom morpheme (enlightenment), no person.
- scripts/data/trait_data.gd:23 "无师自通" (display_name) + i18n.gd:212 — idiom "self-taught"; 师 is idiom morpheme, no person described.
- scripts/data/trait_data.gd:24 "可同时主修两门内功(常规只能一门)" + i18n.gd:215 — no person word in the visible text.
- scripts/data/progression_gongfa_data.gd:60 "丐帮" + i18n.gd:516 — sect proper name (skip per plan rule).
- scripts/autoload/i18n.gd:501 "兵刃" — weapon-category idiom, no person.
- scripts/autoload/i18n.gd:504 "悟道" — idiom morpheme.
- scripts/autoload/i18n.gd:557 "人物" — UI chrome (Character tab label), not prose describing a person.
- scripts/autoload/i18n.gd:138 "黄药师" — one of the six named protagonists' proper names; species already decided in design/90_decisions.md.
- scripts/data/equipment_data.gd:20, scripts/data/player_profile.gd:24 — code comments, not player-visible.
- scripts/data/event_data.gd (all matches) — the 36 journey events; owned by the prose slices this round, explicitly out of this task's scope.
- scripts/autoload/i18n.gd :270-:411 — travel-event EN block; owned by the prose slices.

## Files checked and found clean

- scripts/data/tutorial_fillers.gd — no person-word hits (its tutorial strings are keyed in i18n.gd, recorded above).
- scripts/data/encounter_data.gd — clean.
- scripts/data/gongfa_data.gd — clean.
- scripts/data/progression_gongfa_data.gd — only 丐帮 (sect name, skipped).
- scenes/battlefield.tscn, scenes/main.tscn, scenes/menu.tscn, scenes/player.tscn, scenes/enemy.tscn — clean.

## Notes for UX-19 transcription

- 敌人 hits (i18n :126/:128/:130, trait_data :25/:27 + mirrors) are marked
  (uncertain): the battle enemies ARE the six shrimp characters, so the word
  denotes shrimp already; 5_design should rule whether UX-19 covers them.
- 侠客 (i18n :143, battle_setup.gd :63) is the player's own role label — a
  person word the player sees constantly; likely the first slice for UX-19.
- Each runtime hit above has exactly one mirror site (i18n key or test
  assertion) except map_data endings (:69/:70/:72 → i18n :423/:424/:426) and
  facility_data :31 → i18n :455; card hits ×3 share one i18n key (:241, the
  three cards reuse the same display_name) and one test assertion.
