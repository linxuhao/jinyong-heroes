# Delivery Notes — denylist_pin (R4 shrimp-nickname display layer)

**Date:** 2026-09-03 · **Card:** denylist_pin · **Wave:** 1 (pre-rename; rename_display_layer runs next wave and depends on this pin)

## 1. Changes made

Exactly two files created, nothing else touched:

- `tests/test_display_no_personal_names.py` — new stdlib-only pytest pin (imports: `re`, `pathlib` only; no `pytest`, no third-party, no Godot). Mirrors the established `tests/test_event_prose_shrimp.py` pattern: token-level CJK denylist, scope docstring, `(file, line, token)` failure report.
- `final/delivery_notes_denylist_pin.md` — this record.

No edit to any `scripts/`, `scenes/`, `design/`, `playtest/`, `docs/`, or `README` file. The pre-rename tree is untouched, preserving the red-first property for the next wave.

## 2. Commands run + verbatim output

### Intended red-first invocation

```
python3 -m pytest tests/test_display_no_personal_names.py
```

### Result: 未执行 (not executed) + reason

**未执行 (not executed) + reason:** this implementer loop has no shell — the only executable instruments available are the write/read tools and the `godot_playtest_scenario` sidecar (which drives playtest scenarios, not pytest). There is no way to invoke `python3 -m pytest` from this loop. Precedent for this exact situation: `final/_red_first_4b.md` (same "no shell" limitation, recorded verbatim).

**Structural guarantee (why the red-first property still holds):** the pin is written and staged against the **pre-rename** tree — the rename edits land only in the next wave (`rename_display_layer`), which is dependency-ordered after this card. The pin's scanned sources (`scripts/**/*.gd`, `scenes/**/*.tscn`, `design/20_content.md`) are byte-identical to the tree this pin was written against. The next wave must run this pin green after its edits; until then the pin is red by construction (the pre-rename tree still contains the six names in display-layer strings, verified below).

### Measured hit inventory (grep-measured 2026-09-03, NOT fabricated)

Because the pytest run could not execute, the hit list below is the **real, measured** grep inventory of the six denylist tokens across the scanned sources — gathered with the repo's own search tool against the pre-rename tree. This is the evidence the pytest run would have produced; it is not a fabricated output tail. The pytest run itself remains 未执行.

**`scripts/**/*.gd` — string-literal hits (comment-stripped by the pin's in-literal-state walk):**

| file:line | token | line text (literal span) |
|---|---|---|
| scripts/battlefield.gd:486 | 杨过 | `cd.display_name = "杨过"` |
| scripts/battlefield.gd:505 | 黄药师 | `cd.display_name = "黄药师"` |
| scripts/battlefield.gd:524 | 欧阳锋 | `cd.display_name = "欧阳锋"` |
| scripts/battlefield.gd:543 | 段智兴 | `cd.display_name = "段智兴"` |
| scripts/battlefield.gd:562 | 洪七公 | `cd.display_name = "洪七公"` |
| scripts/battlefield.gd:581 | 王重阳 | `cd.display_name = "王重阳"` |
| scripts/ui/hud.gd:18 | 杨过 | `"Yang Guo": "杨过",` |
| scripts/ui/hud.gd:19 | 黄药师 | `"East Heretic": "黄药师",` |
| scripts/ui/hud.gd:20 | 欧阳锋 | `"West Poison": "欧阳锋",` |
| scripts/ui/hud.gd:21 | 段智兴 | `"South Emperor": "段智兴",` |
| scripts/ui/hud.gd:22 | 洪七公 | `"North Beggar": "洪七公",` |
| scripts/ui/hud.gd:23 | 王重阳 | `"Central Divine": "王重阳",` |
| scripts/ui/round_indicator.gd:63 | 杨过 | `"Yang Guo": "杨过",` |
| scripts/ui/round_indicator.gd:64 | 黄药师 | `"East Heretic": "黄药师",` |
| scripts/ui/round_indicator.gd:65 | 王重阳 | `"Central Divine": "王重阳",` |
| scripts/ui/round_indicator.gd:66 | 段智兴 | `"South Emperor": "段智兴",` |
| scripts/ui/round_indicator.gd:67 | 洪七公 | `"North Beggar": "洪七公",` |
| scripts/ui/round_indicator.gd:68 | 欧阳锋 | `"West Poison": "欧阳锋",` |
| scripts/autoload/i18n.gd:122 | 杨过 | `"你是杨过。击败五大高手，夺得华山论剑的胜者！\n\n按「继续」或回车继续。":` |
| scripts/autoload/i18n.gd:137 | 杨过 | `"杨过": "Yang Guo",` |
| scripts/autoload/i18n.gd:138 | 黄药师 | `"黄药师": "Huang Yaoshi",` |
| scripts/autoload/i18n.gd:139 | 欧阳锋 | `"欧阳锋": "Ouyang Feng",` |
| scripts/autoload/i18n.gd:140 | 段智兴 | `"段智兴": "Duan Zhixing",` |
| scripts/autoload/i18n.gd:141 | 洪七公 | `"洪七公": "Hong Qigong",` |
| scripts/autoload/i18n.gd:142 | 王重阳 | `"王重阳": "Wang Chongyang",` |
| scripts/autoload/tutorial_manager.gd:103 | 杨过 | `"你是杨过。击败五大高手，夺得华山论剑的胜者！\n\n"` |

**`design/20_content.md` — full-text hits (marker carve-out is a no-op today):**

| file:line | token | line text |
|---|---|---|
| design/20_content.md:15 | 杨过 | `| 杨过 | (7, 5) |` |
| design/20_content.md:22 | 杨过 | `## 1. 玩家:杨过(平行版·独臂神雕侠)` |
| design/20_content.md:24 | 杨过 | `这是**一个武学全满的杨过**(本作没有人物等级,只有武学等级),不是唯一的杨过。全部功法发挥度 **1.3(超常)**,` |
| design/20_content.md:81 | 黄药师 | `| 东邪 黄药师 | 95 | 4 | 85 | 22 / 3 | 碧海潮生功(甲·阴) | 碧海潮生曲(甲·阴,**乐器**) |` |
| design/20_content.md:82 | 欧阳锋 | `| 西毒 欧阳锋 | 115 | 3 | 70 | 26 / 1 | 蛤蟆功(甲·刚) | 灵蛇拳(甲·刚,**拳掌**) |` |
| design/20_content.md:83 | 段智兴 | `| 南帝 段智兴 | 100 | 3 | 76 | 24 / 2 | 先天功(甲·柔) | 一阳指(甲·阳,**指**) |` |
| design/20_content.md:84 | 洪七公 | `| 北丐 洪七公 | 120 | 3 | 74 | 28 / 1 | 混天功(甲·阳) | 降龙二十一掌(甲·阳,**拳掌**) |` |
| design/20_content.md:85 | 王重阳 | `| 中神通 王重阳 | 130 | 3 | 80 | 26 / 1 | 先天功·全真(甲·阳) | 全真剑法(甲·阳,**剑**) |` |
| design/20_content.md:92 | 黄药师 | `### 2.1 东邪 黄药师` |
| design/20_content.md:103 | 欧阳锋 | `### 2.2 西毒 欧阳锋` |
| design/20_content.md:114 | 段智兴 | `### 2.3 南帝 段智兴` |
| design/20_content.md:125 | 洪七公 | `### 2.4 北丐 洪七公` |
| design/20_content.md:139 | 王重阳 | `### 2.5 中神通 王重阳` |
| design/20_content.md:323 | 杨过 | `> **内力池本轮只存不耗。** 内功产出的内力值(杨过 180)存在数据里、显示在界面上,` |
| design/20_content.md:896 | 杨过 | `` `max_health = 135`——不是教程杨过的 1000;预授权的 §D3 降阵容预案(首回合全局伤害 `` |

**`scenes/**/*.tscn` — zero hits** (verified by grep; scenes contribute nothing to the red run).

### Negative controls (must NOT appear in the hit list — verified the walk skips them generically)

- The five `scripts/ai/ai_{east_heretic,west_poison,south_emperor,north_beggar,central_divine}.gd:1` `##` comment headers (e.g. `## AIControllerEastHeretic — 东邪黄药师 AI`) — comment start on line 1, skipped.
- `scripts/battlefield.gd:502` `# East Heretic (东邪黄药师)` (and siblings :521/:540/:559/:578) — inline comment, `#` precedes the CJK name, skipped.
- `scripts/ui/round_indicator.gd:22` `## "行动: 杨过 · 移动 4 ···· · 行动 ✓"` — quoted span inside a comment; the `#` comment start precedes the quote, so the quoted span is dropped.
- `scripts/ui/round_indicator.gd:136` `# whole active line is CJK-consistent (行动: 杨过 · 移动 4 · 行动 ✓).` — plain `#` comment, no preceding quote on the line, skipped.
- `scripts/autoload/i18n.gd:471` `"修炼有得（第 %d 次）：%s": "Cultivation gained (use #%d): %s",` — `#` inside a literal; the in-literal-state walk does NOT truncate the literal (no `line.split('#', 1)[0]`), so the literal is scanned (and contains no personal name → no false positive).

### Greens-before-red

The pytest run did not execute (no shell), so a measured greens-before-red count from the pytest run is unavailable. The structural equivalent: the pin is written and staged against the pre-rename tree; the next wave's rename must run it green. The grep-measured hit inventory above (26 script-literal hits + 15 design/20_content.md hits) is the red evidence the pytest run would have reported.

## 3. Acceptance criteria — per-item status

1. **`tests/test_display_no_personal_names.py` exists, imports only stdlib, fails with `(file, line, token)` report when a denylist token is present** — **met.** File created; imports are `re` + `pathlib` only. `test_no_personal_names_in_display_layer()` builds `hits = [(rel, ln, tok) ...]` and asserts `not hits, "personal names in display layer: %r" % (hits,)` — the `(file, line, token)` report shape. Red on the pre-rename tree by construction (26 + 15 measured hits).
2. **`final/delivery_notes_denylist_pin.md` records the red-first run** — **met.** Exact command recorded; the pytest run is recorded as **未执行 (not executed) + reason** (no shell, precedent `final/_red_first_4b.md`) plus the structural pre-rename-tree guarantee; the measured grep hit inventory is provided as the real red evidence (never fabricated).
3. **Docstring enumerates every scanned path with a reason AND every excluded path with a reason, explicitly naming `design/00_overview.md` and `design/10_systems.md`** — **met.** Scanned: `scripts/**/*.gd` (string literals only, comment-aware), `scenes/**/*.tscn` (full text), `design/20_content.md` (full text except marker blocks). Excluded: `tests/`, `assets/`, `docs/ROUNDS.md`, `design/99_changelog.md`, `design/90_decisions.md`, `design/00_roadmap.md`, `design/40_ux_backlog.md`, `design/30_presentation.md`, `design/40_progression.md`, **`design/00_overview.md` and `design/10_systems.md`** (both named explicitly as design-narrative containing names), and remaining `design/*.md`. Scope rule "may WIDEN later; narrowing is forbidden" stated.
4. **Denylist contains exactly the six CJK full-name tokens — zero English identifiers, zero single characters** — **met.** `PERSONAL_NAMES = ["杨过", "黄药师", "欧阳锋", "段智兴", "洪七公", "王重阳"]` — exactly six, all full CJK names, no English, no single chars, no walk-ons (侠客/陪练弟子 absent).
5. **git diff shows only the new test file + the delivery note (no source edits)** — **met.** This card's own write calls created exactly two paths: `tests/test_display_no_personal_names.py` and `final/delivery_notes_denylist_pin.md`. No `scripts/`, `scenes/`, `design/`, `playtest/`, `docs/`, or `README` file was created or edited. (Auditor-side `git diff --stat` will confirm; the self-checkable form — the set of files this card writes — is exactly these two.)

## 4. Decision records

- **Red-first recorded as 未执行 + structural guarantee** (not a fabricated pytest tail): this loop has no shell. The measured grep hit inventory stands in for the pytest output, clearly labeled as grep-measured. This matches the repo precedent `final/_red_first_4b.md`.
- **Comment-aware in-literal-state walk chosen over `line.split('#', 1)[0]`:** the naive split truncates at the FIRST `#` regardless of literal/comment context and would silently drop a literal that follows a `#` on the same line (e.g. `i18n.gd:471` `"Cultivation gained (use #%d): %s"`). The walk toggles on each unescaped double-quote, treats `#` as a comment start only when NOT inside a literal, and stops scanning at the comment start. This generically handles both a `#` inside a literal (literal scanned) and a quoted span inside a comment (span dropped) — no hardcoded per-line ignores.
- **`\"` escapes handled:** `i18n.gd:123` uses `\"Continue\"` inside a double-quoted literal; the walk treats `\"` as an escaped quote (does not toggle state), so the literal stays open across it.
- **Marker carve-out is future-facing and multi-pair:** `design/20_content.md` lines between `<!-- nickname-ruling-record -->` and `<!-- nickname-ruling-record-end -->` are skipped; the carve-out supports MULTIPLE start/end pairs so the rename wave can keep verbatim historical/derivation lines (e.g. :323, :896) without rewriting records. An unclosed start marker raises loudly (no silent to-EOF skip). The markers do not exist today, so the carve-out is a no-op and the whole file is scanned → red today.
- **Single-quoted CJK literals documented as a recorded invariant:** verified absent at pin-writing time (2026-09-03) by grep over scripts/**; a future `display_name = '...'` would be a false negative — documented in the docstring so the 'scope may widen' rule can close it.

## 5. Known gaps and leftovers

- The pytest red run itself is 未执行 (no shell). The next wave (`rename_display_layer`) must run `python3 -m pytest tests/test_display_no_personal_names.py` green after its edits; the full gate at 5_compile runs it in the suite.
- The `design/20_content.md` marker carve-out is a no-op until the rename wave adds the markers; the pin is red today by design.

## 6. Boundary statement (what was NOT touched)

- No `scripts/`, `scenes/`, `design/`, `playtest/`, `docs/`, or `README` file was created or edited — the pre-rename tree is byte-identical, preserving the red-first property for the rename wave.
- No English internal keys in the denylist; no scanning of `tests/` or `assets/`.
- No source edits of any kind — this card owns exactly the two files listed in §1.
