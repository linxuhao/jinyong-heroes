# Technical Architecture Design — jinyong-shrimpcopy2 (Shrimp Wuxia Event Prose Rewrite)

**Step 2 / Architect — 2026-08-31**
**Base codebase:** `/home/linxuhao/.AItelier/projects/jinyong-assets` (previous round `jinyong-event-pool-36`, 95/95 scripts compiling, 78 playtest scenarios all PASS, all suites green).
**Nature of this round:** a surgical, prose-only data-layer edit inside an existing, heavily machine-pinned Godot 4 project. No new runtime dependencies, no new GDScript files, no scene/engine/route decisions, no numeric changes. Exactly one new file (a stdlib-only pytest guard) plus documentation.

---

## 1. Overview

Rewrite the prose (`title` / `text` / `option_a.label` / `option_b.label`) of the 36-row journey-event pool in `scripts/data/event_data.gd` so that **every written person — named or passing — is a shrimp**, shown through claws (钳/螯), antennae (须), carapace (甲壳/头胸甲), and curled tail segments (尾节) — while the wuxia world itself (inns, escort agencies, money shops, bookshops, gambling dens, mountain paths, ferries, tombs, carriages, silver, scripture-copying, steel blades) stays **verbatim**. The judging criterion (owner's words): after reading a row, the reader sees *a group of shrimp walking the wuxia jianghu* — not an undersea world, and not a crowd of humans.

Everything else is sync and guard-rail work: the three test mirror tables, the EN dictionary, one hardcoded test literal pair, README's title mentions, and (by construction, unchanged) the two playtest #78 literal pins. All remaining human prose elsewhere in the codebase is **swept and recorded, not changed**. Design-archive updates are executed by the **5_design step after the gates**, not by implementation cards.

### 1.1 The five frozen invariants (a red here means the edit is wrong — never "fix the mirror")

1. **ids** — byte-identical, row order unchanged (protects `_test_no_repeat_full_journey`'s seed-20260831 determinism).
2. **effects** — byte-identical; `ROW_EFFECTS` (`tests/test_event_data.gd` :11-:156) must NOT change. No numeric rebalancing, no type/value/target edits, no mirror edit to accommodate anything.
3. **option structure** — `{label, effects}` ×2 per row, unchanged; `battle_id` stub stays `null`.
4. **row count** — exactly 36 rows (`_test_no_repeat_full_journey` and the `>= 36` floor stay green untouched).
5. **the wuxia world** — no underwaterization (banned phrasing in §4.5), no seafood props, scenes/objects/professions/place names/silver/martial-arts names verbatim; the six decided species (皮皮虾/龙虾/樱花虾/罗氏沼虾/玻璃虾/枪虾) are **never written into event prose** — unnamed passersby get body-feature description only, no species table.

### 1.2 Tone ruling carried forward (冷面执行, 2026-08-28)

The prose keeps today's register: sober, classical-flavored 2-line wuxia vignettes. Shrimp anatomy is woven in deadpan — **no puns, no comedy, no cuteness, no emoji**. What changes is *who does the deed and what body does it*; nothing else about the voice changes.

---

## 2. Verified anchors (re-checked 2026-08-31 — use as-is, do not re-investigate)

| Anchor | Location | Role this round |
|---|---|---|
| `EventData.TABLE` (36 rows) | `scripts/data/event_data.gd` :26-:243 | **the only gameplay file edited** (prose fields only); builders `_build`/`_build_option` :247-:281 untouched |
| `ROW_EFFECTS` mirror | `tests/test_event_data.gd` :11-:156 | byte-identical proof that effects never drifted — **never edited** |
| `ROW_TITLES` / `ROW_TEXTS` / `ROW_LABELS` mirrors | `tests/test_event_data.gd` :158-:171 / :174-:211 / :214-:251 | byte-for-byte sync targets |
| `run()` wiring | `tests/test_event_data.gd` :254-:269 | 9 gates incl. texts (:363), fresh-instances (:377), no-repeat journey (:399), labels (:454), EN membership (:468) |
| `_test_fresh_instances` hardcoded literals | `tests/test_event_data.gd` :383 (`"破财消灾"`, stays) / :387 (`"山道遇劫匪"`, **must follow the new bandits title**) | sanctioned sync, documented |
| `_test_no_repeat_full_journey` | `tests/test_event_data.gd` :399-:450 | must stay green untouched (seed 20260831) |
| `_test_i18n_entries` EN membership gate | `tests/test_event_data.gd` :468-:479 | the **real** i18n guard for event prose (`test_i18n_coverage.py` cannot see it — prose enters `tr()` as a variable) |
| EN dictionary, travel-event block | `scripts/autoload/i18n.gd` :269-:413 | in-place key+value replacement for every changed field |
| #78 playtest scenario | `playtest/event_pool_new_event_resolved.yaml` — :55 `event_id == "cliff_herbs"`, :57 `event_title == "崖上采药"`, :58 `event_body != ""`, :62 `focused_option_text == "重金购芝"`, :65-:71 resolve ladder | **expected zero diff** (see §7.5) |
| README title mentions | `README.md` :23, :33-:35, :584 | documentation sync, documented |
| UX-17 (this round's mandate) | `design/40_ux_backlog.md` :42 (OPEN row), :86 (record) | closed by 5_design with gate evidence |
| Freeze record to lift | `design/90_decisions.md` §jinyong-event-pool-36 (a) :603-:608, (e) :627-:631 | lift recorded by 5_design, old records kept verbatim |
| Changelog append point | `design/99_changelog.md` after :135 | exactly ONE appended row, zero cell edits to :133-:135 |
| Stale-quote risk | `design/20_content.md` §4 (:189/:206/:214/:248/:251/:257), §8.2 (night_rain quote), §8.2b (:469 merchant quote, quanzhen quote), §4 gate-evidence block | refreshed by 5_design only (§12) |
| Sweep seeds (person words outside events) | `scripts/data/card_data.gd` :33-:35 (`行商分成` card names), `tests/test_card_data.gd` (mirror), `scripts/autoload/i18n.gd` non-event entries (:424 `各派掌门`, :426 `豪杰相迎`) | record-only inventory (§11) |
| Raw-zh publish path (why #78 pins match raw zh) | `scripts/segments/cultivation.gd` `_sync_surface` publishes `event_title = d.title` / `event_body = d.text` raw | no code change needed |

Grep-verified 2026-08-31: **no playtest yaml other than #78 pins any event prose literal** (searched all changed-title/label candidates across the repo; the only playtest hits are #78's two pins, both preserved by construction). `.aitelier/knowledge.md`, `final/*`, and the previous round's `step2_design.md` also contain event literals — all are pipeline metadata / historical records and are **never edited**.

---

## 3. Architecture — one source of truth, four synchronized shadows

```
                    scripts/data/event_data.gd  (TABLE — source of truth)
                     prose fields only: title / text / option_a.label / option_b.label
                                   │  (per-row atomic diff, one row per edit)
        ┌──────────────┬───────────┴────────────┬───────────────────────┐
        ▼              ▼                        ▼                       ▼
 tests/            scripts/autoload/        playtest/                 tests/
 test_event_data.gd  i18n.gd EN dict         event_pool_new_event_    test_event_prose_shrimp.py
 ROW_TITLES(:158)    :269-:413               resolved.yaml            (NEW stdlib guard)
 ROW_TEXTS(:174)     in-place key+value      :57/:62 pins             human/underwater/species
 ROW_LABELS(:214)    replacement             byte-unchanged           token denylists +
 ROW_EFFECTS(:11)    (≈34 entries)           BY CONSTRUCTION          protected-literal pins
 byte-mirror,        (EN membership gate     (guard enforces)         (red over pre-edit corpus,
 effects untouched   :468-:479 must green)                            green after rewrite)
        │              │                        │                       │
        └──────────────┴───────────┬────────────┴───────────────────────┘
                                   ▼
        Verification ladder (all must be green):
        GDScript unit suite (28-file registry, unchanged)
          → pytest (stdlib guards; +1 file)
          → README/doc literal audit (grep classification, §7.6)
          → 5_compile / 5_test / 5_vision official gates (authoritative evidence)
                                   ▼
        5_design: design-archive updates (§12) — 20_content §4 + §8.2/§8.2b quotes,
        90_decisions freeze-lift, 40_ux_backlog UX-17 → CLOSED + UX-19 (OPEN) opened,
        99_changelog exactly one appended row
```

**Component responsibilities are strictly separated:**
- **Implementation cards** touch: `scripts/data/event_data.gd`, `tests/test_event_data.gd` (three prose mirrors + one hardcoded literal), `scripts/autoload/i18n.gd` (event-block EN entries), new `tests/test_event_prose_shrimp.py`, `README.md` (title mentions), `final/delivery_notes_shrimpcopy2.md`. **Nothing else.**
- **5_design** touches: `design/20_content.md`, `design/90_decisions.md`, `design/40_ux_backlog.md`, `design/99_changelog.md` — after the official gates, using the implementation's delivery notes as raw material.
- **No card** touches: any `effects` literal, any `.tscn`, `playtest/*.yaml` (zero diff expected), `_common.yaml`, the GDScript unit registry, `cultivation.gd`, `EventLogic`, any other data module's prose.

---

## 4. Rewrite specification (the implementer executes these rules verbatim)

### 4.1 The single rule: re-attribution

Every agent that performs a person-coded action is explicitly a shrimp, described with body features; the wuxia object and the action stay. The brief's own example is the model: 「一伙劫匪手提钢刀」 → *the blade is held by a shrimp* — 钢刀 stays 钢刀, 提 becomes a claw verb. Fix the **doer**, not just the noun: 「手提钢刀」「赶着马车」「随他抄经」 stop implying human shape because the one doing them now visibly has 钳/须/甲壳/尾节.

### 4.2 Minimal-diff class rule (decided here so nobody re-litigates it mid-implementation)

- **Class A (28 rows) — MUST change:** the row's prose contains a person-role noun, a person-presence word (有人/无人/人声/人手), or a human-body action word (手提/伸手/拍着胸脯/揉着腰/搭手/手舞足蹈/招人/寻人). Exact per-row inventory in §5.
- **Class B (8 rows) — byte-identical, zero diff:** the row's prose contains none of the above: `ruins` 古墓残碑, `tomb_bed` 古墓寒玉, `wounded_eagle` 神雕负伤 (巨雕 is wildlife), `peach_maze` 桃花迷阵, `ancient_bell` 荒寺晚钟, `wedding_train` 山道花轿, `sword_mound` 荒冢埋剑, `wild_goose_letter` 雁足传书. These rows write no person and no human-body action; the owner's criterion ("every *written* person is a shrimp") is already satisfied. Gratuitous rewrites of Class B would expand diff surface for zero acceptance value. The guard (§6) still protects them — no banned token may *enter* them either.

### 4.3 Shrimp-body lexicon (required vocabulary; at least one anchor per rewritten agent)

钳 · 螯 · 须 / 触须 · 甲壳 · 头胸甲 · 尾节 / 蜷起的尾节 · 尾扇 · 步足 · 复眼 · 横行.
Generic 虾 is the setting's core word and is always allowed (一只虾 / 几只虾 / 虾客 / 众虾). What is forbidden is only the six decided **species names** (§4.6).

### 4.4 Craft rules

1. **Human-body-part words are replaced by shrimp anatomy:** 手提 → 钳里提着 / 长钳提着; 伸手乞食 → 伸钳乞食 (or 捧着破碗的螯); 拍着胸脯 → 拍着甲壳; 揉着腰 → 捶着甲壳/尾节; 揉眼 → 用螯揉着复眼; 搭手 → 援钳 / 伸出长钳; 手舞足蹈 → 挥螯踏节 / 螯足乱划; 缺人手 → 缺虾手 → rephrase 缺个帮工的虾.
2. **Person-role nouns are replaced by shrimp descriptions** (preferred), e.g. 劫匪 → 拦路的虾; 艄公 → 撑舟的虾; 老僧 → 一只年老的虾 (庙里独坐的那只老虾); 老铁匠 → 铁匠铺里的老虾; 说书人 → 醒木一拍的老虾. Keeping a role word is acceptable **only** when explicitly shrimp-marked (虾客) — the bare human noun may never survive (guard-enforced, §6).
3. **Collectives are shrimp-marked:** 满堂喝彩 → 满堂虾客喝彩; 有人一夜输光 → 几只虾一夜输光; 四下无人 → 四下不见虾影; 十年无人解出 → 十年无虾解出; 人声鼎沸 → 虾声鼎沸 (or 灯影攒动).
4. **Pronouns may stay** when their antecedent is the now-explicitly-shrimp agent: quanzhen_scripture 「随他抄经」 stays — 他 is the described shrimp (and its EN "Copy with him" stays).
5. **Wildlife stays animal:** 巨雕 (wounded_eagle), 猴子 (lantern_festival), 大雁 (wild_goose_letter), 蛇/蛇胆 (snake_bile), 虎 (tiger_pass), 马 (fallen_rider 坠马 — horses exist; a shrimp rider falling from one is a wuxia image). Never shrimped, never seafood'd.
6. **河伯 stays a name** (river_god): a named deity is a person, so the *scene's* agents (巫师, 村民) are rewritten as shrimp, and 河伯's wedding remains a shrimp affair — but 河伯 itself is a proper name, never species-tagged, never one of the six.
7. **Places and objects verbatim:** 客栈 · 镖局/镖行 · 钱庄 · 书铺/书摊 · 赌坊 · 山道 · 渡口 · 古墓 · 马车 · 银两/盘缠/银赏 · 抄经/道德经 · 钢刀/长剑/兵刃 · 皮甲/快靴 · 灵芝/蛇胆/药箱/药柜 · 灯摊/谜面 · 花轿 · 铁匠铺 · 当铺/断票 · 茶馆/茶碗 · 棋盘/残局 · 酒肆/温酒 · 鼓号 · 褡裢 · 帛书 · 村舍/荒村/疫村/镇上 (村/镇 as place morphemes stay; only 村民 the person goes) · 白驼山/全真宫/桃花阵/降龙 (faction & martial names).
8. **No underwaterization:** scenes never move underwater, no seafood props, and the phrasings in §4.5 never appear.
9. **New-verse shape:** keep the current 2-line body with the `\n` escape exactly where it is today; each line ≈ ≤ 20 CJK chars (current lines run 14–20). Titles ≤ 6 CJK chars, labels ≤ 6 (current max is 5) — this keeps the vision gate's Q6 (no truncation) green and the composite render key (`【%s】\n\n%s\n\n…`) intact.

### 4.5 Banned phrasing (underwaterization) — and the 泅水而过 tie-breaker (decided)

Banned in event prose: 「游过去」「潜入」「水流」「海底」「水底」「下潜」「潜游」「洄游」「洋流」「珊瑚」「海藻」「鳃」. Rivers, floods, rain, snow and crossings stay land-world: 河水暴涨, 夜雨滂沱, 风雪封了隘口 are scenery, not seabed.

**Tie-breaker (adopted per Step-1 review suggestion, so it is never re-argued during implementation):** flood_ferry's option-B label **「泅水而过」 stays byte-identical**. Swimming across a swollen river is a land-world wuxia feat performed by a shrimp traveler; the owner's ban is on rewriting the jianghu *into* a seabed world, not on a person-crossing a river. The guard pins this literal (§6 protected literals) so a future round cannot "fix" it into an underwater phrasing either.

### 4.6 Species are never named for passersby

皮皮虾 / 螳螂虾 / 龙虾 / 小龙虾 / 樱花虾 / 罗氏沼虾 / 玻璃虾 / 枪虾 / 濑尿虾 / 对虾 / 基围虾 / 青虾 / 明虾 — none may appear in event prose (guard-enforced). Passersby get body features only; no new species table.

### 4.7 EN values are rewritten in the same stroke

The public build is read in English: every replaced EN value must also render a shrimp body ("claws", "antennae", "carapace", "curled tail segments") while preserving wuxia nouns in English (inn, escort agency, money shop, bookshop, gambling den, mountain path, ferry, tomb, carriage, silver, scripture, steel blade). Example register:
- 「山道遇劫匪」 "Bandits on the Mountain Road" → 「山道遇劫」 "Ambush on the Mountain Road".
- bandits body → e.g. "On a mountain road a pack of shrimp cuts off your way.\nTheir leader scuttles forward, a steel saber gripped in one long claw, demanding a toll."

---

## 5. Per-row rewrite surface (all 36 rows; "tokens" = what the guard must not find afterwards)

Legend: **A** = change (28 rows), **B** = byte-identical (8 rows). Suggested titles/labels are **suggestions** — the implementer finalizes within §4's rules; the guard and length limits are the contract.

| # | id | cls | person-shape tokens to remove | directive (objects that MUST stay verbatim) |
|---|---|---|---|---|
| 1 | `bandits` | A | title 劫匪; text 劫匪, 为首之人/之人, 手提 | ambushers are shrimp, saber gripped in a claw; 钢刀/买路财 stay. Suggested title 「山道遇劫」. Labels 破财消灾 / 出手退敌 stay. Sync: mirrors ×2 + `_test_fresh_instances` :387 |
| 2 | `merchant` | A | title 行商; text 行商 | the cart-driver is a shrimp (reins in claw/步足); 马车/刀剑兵刃/销路 stay. Suggested title 「车马过路」. Labels stay. (20_content §8.2b quote refreshed by 5_design) |
| 3 | `ruins` | B | — | byte-identical |
| 4 | `beggar` | A | title 老丐; text 老丐, 伸手 | an old shrimp with worn antennae begs, claw out, compound eyes sizing you up; 巷口 stays. Suggested title 「巷口乞食」. Labels 施舍/切磋武学 stay |
| 5 | `tomb_bed` | B | — | byte-identical |
| 6 | `wounded_eagle` | B | — (巨雕 wildlife) | byte-identical |
| 7 | `peach_maze` | B | — | byte-identical (海岛 is a land word — never red) |
| 8 | `snake_bile` | A | text 弟子 | the hawker is a White Camel Mountain shrimp, pouch on its antennae; 白驼山/蛇胆/真元 stay. Labels stay |
| 9 | `dragon_scrap` | A (label only) | label_b 书贾 | label_b → 「卖与书铺」(书铺 is a sanctioned wuxia noun). text & title byte-identical |
| 10 | `flood_ferry` | A | text 艄公 | the boatman is a shrimp poling the boat, indifferent; 河水/渡口/舟 stay. Labels **both stay** — 「泅水而过」 is the protected land-world feat (§4.5) |
| 11 | `escort_job` | A | text 镖头, 人手 | the escort agency's shrimp chief sees your 身手 (idiom stays); 镖/南边 stay. Labels stay |
| 12 | `dali_market` | A | text 掌柜, 拍着胸脯 | the shopkeeper shrimp pounds its own carapace; 市集/皮甲/快靴 stay. Labels stay |
| 13 | `night_rain` | A | text 老僧 | an old shrimp sits alone mending the eaves by lamplight; 破庙/夜雨/灯火/屋檐 stay. Labels stay. (20_content §8.2 quote refreshed by 5_design) |
| 14 | `gambling_den` | A | text 有人 | 几只虾 lost a whole travel purse; 赌坊/盘缠 stay. Labels stay |
| 15 | `quanzhen_scripture` | A | text 老道 | an old shrimp bends over the desk copying; 全真宫/道德经 stay. Label_a 随他抄经 **stays** (§4.4-4). (20_content §8.2b quote refreshed by 5_design) |
| 16 | `lost_purse` | A | text 无人; label_a 失主 | 四下不见虾影; label_a → 「归还失物」. label_b 收起走人 stays; 褡裢/银两 stay |
| 17 | `riverside_duel` | A | text 剑客 | two shrimp schools at opposite ends of the bank; 河滩/执剑裁断 stay. Labels stay |
| 18 | `ancient_bell` | B | — | byte-identical |
| 19 | `poisoned_well` | A | text 药翁 | an old shrimp arrives, medicine case on its back; 荒村/井水/药箱 stay. Labels stay |
| 20 | `tiger_pass` | A | text 商队头目 | the caravan's shrimp chief hawks the talismans; 虎啸/危崖/过路符 stay (虎 wildlife). Labels stay |
| 21 | `lantern_festival` | A | text 人声 | crowds are shrimp (虾声鼎沸 / 满街虾客); 灯摊/谜面 stay, 猴子 wildlife stays. Labels stay |
| 22 | `pawnshop` | A | text 刀主 | the blade's owner is a down-and-out shrimp; 当铺/柜台/断票 stay. Labels stay |
| 23 | `storyteller` | A | text 说书人 (+ collective 满堂) | an old shrimp raps the gavel; 满堂虾客喝彩; 茶馆/旧年剑侠 (tale-subject genre word, kept)/茶碗 stay. Labels stay |
| 24 | `chess_stall` | A | text 无人 | 十年无虾解出; 街角/棋盘/残局 stay. Labels stay |
| 25 | `smithy` | A | text 老铁匠 | the smithy's old shrimp smith; 铁匠铺 (place)/炉火/回炉重铸 stay. Labels stay |
| 26 | `cliff_herbs` | A (text only) | text 采药人, 招人 | the herb-gatherer is a shrimp recruiting fellow climbers; 崖/灵芝 stay. **Title 「崖上采药」 and label_b 「重金购芝」 stay byte-identical** (#78 pins, §7.5); label_a 帮攀崖顶 stays |
| 27 | `wedding_train` | B | — | byte-identical |
| 28 | `sword_mound` | B | — | byte-identical |
| 29 | `night_inn` | A | text 掌柜, 揉眼 | the inn's shrimp keeper rubs its compound eyes with a claw over the ledger; 客栈/账本/温酒 stay. Labels stay |
| 30 | `wild_goose_letter` | B | — (大雁 wildlife) | byte-identical |
| 31 | `snow_pass` | A | text 向导 | the guide crouching by the fire is a shrimp; 风雪/隘口/火 stay. Labels stay |
| 32 | `drunken_fist` | A | title 醉汉; text 醉汉, 手舞足蹈 | a drunken shrimp waves its claws outside the tavern, fist-logic intact; 酒肆/拳理 stay. Suggested title 「酒肆拳影」. Labels stay |
| 33 | `river_god` | A | text 巫师, 村民 | the shrimp ritualist demands a price, the village shrimp look troubled; 河伯 (name stays)/鼓号/村头 stay. Labels stay |
| 34 | `plague_village` | A | text 郎中 | the village's healer is an old shrimp sighing over the cabinet; 疫村/药柜 stay. Labels stay |
| 35 | `young_disciple` | A | text 少年 | a young shrimp paces outside the door; 门外/指点 stay. Labels stay |
| 36 | `fallen_rider` | A | title 客商; text 客商, 揉着腰, 搭手(寻人搭手) | a traveling shrimp thrown from its horse, goods scattered, pounding its own carapace, looking for a claw to help; 马/货物 stay. Suggested title 「途中坠马」. Labels 帮拣银赏/捡靴自用 stay |

**Change tally:** titles 5, texts 27, labels 2 → **34 changed prose fields** across 28 rows; 8 rows byte-identical; ≈34 EN entries replaced in place; 2 test-file sync points (three mirrors + one `_test_fresh_instances` literal); README ~3 spots; #78 zero diff.

---

## 6. The guard: `tests/test_event_prose_shrimp.py` (NEW, stdlib-only pytest)

Modeled on the repo's `tests/test_shrimp_roster.py` philosophy: **the judgement stays human (prose quality), the reminder is automatic (no person noun, no underwater phrasing, no species name may enter event prose).** Scope: `scripts/data/event_data.gd` **only** — the mirrors are byte-pinned to it by the GDScript suite, EN values are English, and every other file is the sweep's scope (§11), not the guard's.

```python
"""Shrimp-prose guard for the 36 journey events (jinyong-shrimpcopy2).
Denylists are token-level CJK substrings built from the PRE-edit corpus —
never character-level bans (手 appears in legitimate 出手/身手 idioms)."""
from pathlib import Path

SRC = Path(__file__).resolve().parents[1] / "scripts" / "data" / "event_data.gd"

HUMAN_TOKENS = [
    # person-role nouns (pre-edit corpus inventory)
    "劫匪", "行商", "老丐", "掌柜", "郎中", "村民", "少年", "醉汉", "客商",
    "老僧", "老道", "药翁", "书贾", "失主", "刀主", "向导", "说书人", "剑客",
    "弟子", "艄公", "镖头", "头目", "巫师", "老铁匠",
    # person-presence / human-body phrases
    "之人", "有人", "无人", "人声", "人手", "招人", "寻人",
    "手提", "伸手", "手舞足蹈", "搭手", "揉着腰", "揉眼", "拍着胸脯",
]
UNDERWATER_TOKENS = [
    "游过去", "潜入", "水流", "海底", "水底", "下潜", "潜游",
    "洄游", "洋流", "珊瑚", "海藻", "鳃",
    # NOTE: 泅水而过 (flood_ferry) is a land-world river-crossing feat — deliberately NOT banned.
]
SPECIES_TOKENS = [
    "皮皮虾", "螳螂虾", "龙虾", "小龙虾", "樱花虾", "罗氏沼虾", "玻璃虾",
    "枪虾", "濑尿虾", "对虾", "基围虾", "青虾", "明虾",
]
PROTECTED = [
    '"title": "崖上采药"',  # playtest #78 f200 pin
    '"重金购芝"',           # playtest #78 f210 pin
    '"泅水而过"',           # kept land-world feat (§4.5)
    '"破财消灾"',           # _test_fresh_instances :383 (unchanged, pinned cheap)
]
```

Four test functions: `test_no_human_tokens`, `test_no_underwater_tokens`, `test_no_species_tokens` (each failure message names the offending token **and the row id** — split the source on `"id": "` and attribute by offset), and `test_protected_literals_present` (fails *before* the pipeline gate if a future edit drifts a #78 pin or the kept feat). ~70 lines total; no dependencies beyond `pathlib`.

**Landing order is deliberate:** the guard is committed **first**, while the corpus still contains the person words — its red is the round's **measured red-first evidence** (record the failing token count and affected rows in the delivery notes). It turns green when the last Class A row lands. (Red-first measurement discipline for *new playtest pins* does not apply here — there are no new pins; this guard's red is measured by construction.)

---

## 7. Sync contracts

### 7.1 Test mirrors (`tests/test_event_data.gd`)
`ROW_TITLES` :158-:171 (5 values), `ROW_TEXTS` :174-:211 (27 values), `ROW_LABELS` :214-:251 (2 values) updated **byte-for-byte** with the new strings, including the `\n` escapes exactly as written in `event_data.gd` (all three files must carry identical runtime strings). `ROW_EFFECTS` :11-:156 **never edited** — if `_test_option_effects` reds after a prose edit, an effects literal was corrupted: revert the edit, do not touch the mirror. Same-commit discipline: **one row = one diff** touching its data cell, its three mirror cells, and its EN entries, so any red is attributable to exactly one row.

### 7.2 EN dictionary (`scripts/autoload/i18n.gd` :269-:413)
For every changed field, **replace the existing `"<zh>": "<en>",` line in place** (key AND value) — never append a second entry for the same row (duplicate keys in a GDScript dictionary literal are a latent bug). ≈34 lines. The EN membership gate (`_test_i18n_entries` :468-:479) must stay green; `test_i18n_coverage.py` is blind to event prose (variable-path `tr()`) — the gate, not the pytest, is the guard (SOTA-confirmed).

### 7.3 `_test_fresh_instances` hardcoded literals (:377-:388)
:383 `"破财消灾"` — unchanged. :387 `"山道遇劫匪"` — becomes the new bandits title **in the same commit as the bandits row**. This is sanctioned mirror-sync (the literal pins the *freshness property*; its value follows the data it pins), and it must be listed in the delivery notes. It is not a playtest assertion and not an assertion-weakening.

### 7.4 README.md (documentation sync, documented)
:23 (narrative mention 山道遇劫匪), :33-:35 (twenty-rows title list — 醉汉传拳 / 坠马客商 change), :584 (行商路过). Sync changed titles only; list every edit in the delivery notes. README is documentation, not the playtest contract; a stale title would misdocument the build.

### 7.5 Playtest #78 — expected ZERO diff, documented either way
The two prose pins (:57 `event_title == "崖上采药"`, :62 `focused_option_text == "重金购芝"`) pin literals containing **no person word**; this design freezes both strings byte-identical (`cliff_herbs` title + option_b label; enforced by the guard's protected-literal test). `event_body != ""` (:58) is shape-only and survives the text rewrite. The :65-:71 resolve ladder rides untouched effects. The delivery notes must still state, line by line, for **both** pin lines: "checked — unchanged — and why" (the brief requires documenting each changed pin line; the honest answer here is *none changed*, with the construction argument). If — contrary to this design — any pin had to change, the measured red-first protocol (temporary-rollback method, byte-exact restore, four measured values) applies; **predicted values are never recorded as measurements**. No other playtest yaml may be touched: grep shows no frozen scenario pins any changed literal (§2).

### 7.6 Grep classification protocol (run BEFORE the first prose edit)
Grep every zh literal that is about to change across the whole repo; classify each hit:
(a) `tests/test_event_data.gd` mirrors → sync (sanctioned, §7.1); (b) `scripts/autoload/i18n.gd` EN → sync (sanctioned, §7.2); (c) `playtest/*.yaml` → ONLY #78's two pins are sanctioned, and by design neither changes — any other playtest hit is a **STOP**: preserve that literal byte-identical and record the conflict; (d) `design/*.md` → **not edited by implementation** — handed to 5_design (§12); (e) `README.md` → sync + document (§7.4); (f) `.aitelier/knowledge.md`, `final/*`, previous `step2_design.md` → **never edited** (pipeline metadata / historical records). Known sites from the 2026-08-31 scout: `design/20_content.md` (:189/:206/:214/:248/:251/:257 §4 shape lines, §8.2/§8.2b quote blocks, §4 gate-evidence block), `design/40_ux_backlog.md` :42, `design/90_decisions.md` :636, `design/99_changelog.md` :133-:135, `final/delivery_notes.md` :186 — all deferred to 5_design or left as historical record, except README.

---

## 8. Execution order & rollback (irreversibility constraint satisfied)

Every phase is a plain-text edit on a git-tracked tree; the rollback path is `git checkout -- <file>` per file or `git reset` to the recorded baseline hash. Per-row atomic diffs keep partial rollback meaningful, and the mirrors + EN gate + guard make any half-applied state **loud (red), never silent**. There is no delete-then-write step and no data loss window. The one forbidden "fix" is editing `ROW_EFFECTS` or weakening any mirror/gate to make a red disappear — a red always means the prose edit is wrong.

- **Phase 0 — baseline.** Record `git rev-parse HEAD` in the delivery notes; run the §7.6 classification grep; run the full pytest suite + GDScript unit suite once to record the green starting state.
- **Phase 1 — guard lands RED.** Commit `tests/test_event_prose_shrimp.py`; measure and record its red over the pre-edit corpus (failing token count + affected rows). Do not touch prose yet.
- **Phase 2 — Class A frozen-16 slice (12 rows: bandits, merchant, beggar, snake_bile, dragon_scrap, flood_ferry, escort_job, dali_market, night_rain, gambling_den, quanzhen_scripture, lost_purse).** Per-row single diffs; run the unit suite after the slice.
- **Phase 3 — Class A appended-20 slice (16 rows: riverside_duel, poisoned_well, tiger_pass, lantern_festival, pawnshop, storyteller, chess_stall, smithy, cliff_herbs, night_inn, snow_pass, drunken_fist, river_god, plague_village, young_disciple, fallen_rider).** Same discipline; run unit suite + full pytest (guard now green).
- **Phase 4 — #78 verification.** Guard protected-literal test + (recommended) one sidecar self-run of `event_pool_new_event_resolved.yaml`; record counts in the delivery notes.
- **Phase 5 — README sync + delivery notes.** `final/delivery_notes_shrimpcopy2.md`: (a) per-changed-line inventory (old → new for all 34 fields + `_test_fresh_instances` + README); (b) the #78 pin check statement (§7.5); (c) the sweep inventory (§11); (d) self-run evidence. Official gate evidence comes only from the pipeline's `compile_report.json` / `playtest_summary.md` / `test_report.json` / `vision_report.json` — never from predictions or repo files.
- **Phase 6 — 5_design.** Design-archive updates (§12) after the gates.

---

## 9. Proposed task decomposition (PM may re-slice; the interfaces are §§4-7)

| Task | Input (fixed interface) | Output | Definition of done |
|---|---|---|---|
| T1 (impl) | §6 token lists (frozen), §8 Phase 0-1 | guard file + baseline hashes + measured red evidence | guard red on pre-edit corpus; suites otherwise green |
| T2 (impl) | §5 rows 1-16 directives, §4 rules, §7 sync contracts | 12 frozen-16 Class A rows rewritten + mirrors + EN (+ :387) | unit suite green on the slice; zero effects diff |
| T3 (impl) | §5 rows 17-36 directives, §7.5 | 16 appended Class A rows rewritten + mirrors + EN; #78 check/self-run | all-36 guard green; unit + pytest green; pin statement recorded |
| T4 (impl) | §7.4, §11 | README sync + `final/delivery_notes_shrimpcopy2.md` (changed-line inventory + sweep inventory) | every changed line documented; sweep has file:line rows |
| T5 (5_design) | §12, T4's delivery notes, official gate artifacts | design/ updates; UX-17 CLOSED; UX-19 OPEN; one changelog row | gates passed:true first; archives consistent; changelog append-only respected |

**Per-row checklist (every Class A row):** prose fields only · no HUMAN/UNDERWATER/SPECIES token · wuxia nouns verbatim · ≥1 body-feature anchor per rewritten agent · title ≤6 / labels ≤6 CJK chars · body keeps the 2-line `\n` shape · mirrors synced byte-for-byte · EN key replaced in place · `ROW_EFFECTS` diff empty · Class B neighbours untouched.

---

## 10. Playtest contract statement

No scenario is added, removed, or edited; `playtest/_common.yaml` is untouched (`event_title` / `event_body` / `focused_option_text` / `debug_seed_events_seen` already whitelisted). The only playtest edits this round could ever sanction are #78's two literal pins — by design neither changes (§7.5), so there are **no new pins and no new red-first measurements owed**. All 78 scenarios stay green *by construction* (prose is data; `EventLogic`, `draw_unseen_id`, effects, option structure, and RNG streams are untouched — `event_travel_effects` 19/19, `save_load_roundtrip` 14/14 and the whole regression net are structurally immune) and are verified by the pipeline gates; `spine_to_ending` 42/42 must remain untouched-green as always. The addon's playtest-spec duties (observable surface + scenario skeleton incl. one to-endgame scenario) are already satisfied by the existing 78-scenario contract; this round declares **no contract change**.

---

## 11. Record-only sweep: human prose outside the 36 events

**Scope (player-visible string literals only; ids/comments/code excluded):** `scripts/data/facility_data.gd`, `map_data.gd`, `tutorial_fillers.gd`, `encounter_data.gd`, `card_data.gd`, `trait_data.gd`, `gongfa_data.gd`, `scripts/autoload/i18n.gd` (entries **outside** the `# --- Travel events ---` block), `scenes/*.tscn` (`text=` / label strings), plus their prose-pinning test mirrors where they exist.

**Method:** broad recall-first grep over a single-char/short CJK class — `(人|僧|道|翁|匠|丐|匪|商|客|师|郎|主|民|徒|兄|姐|妹|侠|豪|杰|掌门|官|兵|贼|盗)` — then human-classify each hit: a person inside a player-visible literal → record; an id, a comment, or a place/idiom morpheme (客栈, 道德经, 主角 UI 标签) → skip. Precision is human work here; the sweep must not miss.

**Known seed hits (2026-08-31 scout):** `scripts/data/card_data.gd` :33-:35 — card display names 「行商分成」 ×3 (economy cards); `tests/test_card_data.gd` — the matching card-prose mirror; `scripts/autoload/i18n.gd` :424 (ending 「各派掌门纷纷登门请教」 — 掌门), :426 (「皆有豪杰相迎」 — 豪杰).

**Output format (one row per hit):** `file:line | quoted literal | person words found` — into `final/delivery_notes_shrimpcopy2.md` §sweep. **This round changes none of them.** 5_design transcribes the inventory into the new OPEN backlog item **UX-19 「事件外的人形文案清单」** in `design/40_ux_backlog.md` (queue table, after UX-18), so later rounds can fix the rest one slice at a time with attributable reds.

---

## 12. Design-archive changes (executed ONLY by 5_design, after the gates pass)

Implementation cards never edit `design/`. This section is the sanctioned change-list for 5_design (the "设计变更" declaration required by the pipeline):

1. **`design/20_content.md` §4** — record the prose direction: all written persons in the 36 events are shrimp (body-feature lexicon, no species names), wuxia world verbatim, Class A/B minimal-diff record (28 changed / 8 byte-identical), pointer to the freeze-lift in `90_decisions.md`, and the round's gate-evidence line appended per the archive's evidence discipline (official artifact numbers only). **Also refresh the stale verbatim quotes**: §8.2 (night_rain 「老僧独坐…」 → new prose) and §8.2b (merchant 「一位行商赶着马车路过…」, quanzhen_scripture 「全真宫外老道伏案抄经…」 → new prose) — these quote data and must not go stale.
2. **`design/90_decisions.md`** — NEW dated section (2026-08-31, jinyong-shrimpcopy2) recording the **freeze-lift**: why it was frozen (pool-expansion round `jinyong-event-pool-36` had to prove append-only with zero touching of existing rows; machine-pinned by the mirrors, ruling (a) :603-:608); why the owner lifted it (2026-08-31 ruling: **all characters are shrimp — passersby included**; prose consistency is mandatory; UX-17 resolved); **lift scope = prose only** (id / effects / option structure / 36-row count / row order remain frozen); old records kept verbatim. Plus the event-layer landing summary (28 rows, lexicon, 「泅水而过」 kept, species never named, guard file).
3. **`design/40_ux_backlog.md`** — UX-17 row :42 → **CLOSED(jinyong-shrimpcopy2)** with this round's evidence (official `playtest_summary.md` 78/78, `test_report.json`, vision Q6, guard green) — written **after** the gate run; implementation cards must **not** self-close it. NEW row **UX-19 (OPEN)**: 「事件外的人形文案清单」 with the §11 file:line inventory; note "record-only this round; one slice at a time later". A dated record line in the 记录 section per the archive's conventions.
4. **`design/99_changelog.md`** — append **exactly ONE row** (date 2026-08-31) summarizing the prose rewrite + syncs + guard + closures. **Zero edits to any existing row's cells** — :133-:135 carry last round's own corrigendum chain; the earlier accidental cell corruption (restored by the driver) must not be repeated.

No `design/00_roadmap.md` / `design/README.md` changes are required (no completeness item moves); if 5_design finds a stale claim, correct minimally with a dated note.

---

## 13. Tech stack & linter manifest

- **Godot 4 headless CLI** — `godot --headless --path . -s res://tests/unit_test_runner.gd`; the 28-file GDScript unit registry is unchanged (no new `.gd` files; the new guard is Python, so the compile count stays 95).
- **Python 3 + pytest, stdlib-only** — the repo's established static-guard layer; the new file follows `tests/test_shrimp_roster.py`'s precedent (no new dependencies, Godot-free).
- **`godot_playtest_scenario` sidecar** — optional self-run of `event_pool_new_event_resolved.yaml` in Phase 4.
- **git** — baseline hash + per-file checkout as the rollback path (§8).
- **linter_manifest.json** — unchanged mapping, re-emitted: `.py: ruff`, `.md/.yaml/.yml/.json/.tscn: basic`; `.gd` deliberately excluded (owned by the `gdscript_check` gate, not the manifest).

---

## 14. Extensibility

The guard + mirrors make every future backlog slice (UX-19) a repeat of this round's per-row discipline: sweep → record → one slice → sync mirrors/EN → gates. Adding event rows later automatically inherits the guard (new rows are scanned too). The token lists are append-only data in one test file — extending the denylist when new person prose enters other data modules is a one-line change per token, and the protected-literal pins keep #78 and 「泅水而过」 safe from well-meaning future "fixes".

---

## 15. Risk register

| Risk | Mitigation |
|---|---|
| Underwaterization (the owner's most-feared failure) | §4.5 banned-token guard + protected 「泅水而过」 + delivery-notes quotes reviewed in 5_review |
| Effects drift while editing inline dicts | per-row minimal diffs; `ROW_EFFECTS` red = revert the edit, never the mirror |
| Mirror desync | same-commit per-row discipline; mirrors red by design on a miss |
| EN gate blind spot (pytest can't see event prose) | the GDScript membership gate is the guard; in-place key replacement, no duplicate keys |
| Stale design quotes (§8.2/§8.2b) | explicitly assigned to 5_design (§12.1) |
| 99_changelog cell corruption (last round's incident) | append-only, exactly one row, zero cell edits (§12.4) |
| Species leakage into passersby | SPECIES_TOKENS guard (§6) |
| #78 pin drift | guard protected-literal test fails before the pipeline gate does (§6) |
| Title/label growth breaking vision Q6 | §4.4-9 length limits + the vision gate itself |
| Prose quality (the actual hard part) | human judgement stays with implementer/reviewer; the guard is a floor, not a ceiling (`test_shrimp_roster` philosophy) |
| Frozen-scenario conflict | grep classification protocol (§7.6); today's evidence: no frozen yaml pins any changed literal |

---

## 16. Success criteria mapping

| Brief criterion | Carried by |
|---|---|
| Every written person in the 36 events is a shrimp; world verbatim, no underwaterization | §4 spec + §5 table + guard (§6) |
| ids / effects / option structure / 36-row count byte-identical | five frozen invariants (§1.1); unchanged `ROW_EFFECTS` is the machine proof |
| Mirrors + EN synced; `_test_event_data.gd` fully green (EN gate, no-repeat journey) | §7.1-7.3; verification ladder (§3) |
| #78 pins synced and passing (15/15); 78 scenarios zero regression | §7.5 + §10; official gates |
| Zero compile errors, hard gate `passed: true`, zero runtime errors, pytest + GDScript suites green | pipeline gates (authoritative artifacts only) |
| Sweep recorded as new OPEN item with file:line | §11 + §12.3 (UX-19) |
| 20_content §4 / 90_decisions freeze-lift / 40_ux_backlog UX-17 CLOSED + UX-19 OPEN / 99_changelog one row | §12 (5_design, after gates) |
| Open-and-play delivery | no scene/engine/route/resource decisions; prose-only data edit on an already-green project |
