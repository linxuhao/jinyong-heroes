# 技术架构设计 — R3b「Numbers That Bind」(数值真的绑上)

> Step 2 · Architect. 输入:项目 brief(8 张卡 C1–C8)+ Step 1 SOTA 报告(全部代码锚点已由本步逐一直读复核,见 §3 各卡的「已验证锚点」)。
> 本轮**不加任何新系统、不加任何新货币**;只让 R3 已声称的数字绑定在**真实存档**上成立。
> 排序遵守 `design/01_process.md`:L2(C1、C7)→ L3(C2/C3/C4/C5,C5 依赖 C1+C4)→ L4(C6)→ 设计记录(C8)。

---

## 0. 概述

R3 落地的数值公式(结局多轴评价、华山战备、做工收益、功法修习)在**空档**(`debug_seed_save`,0 门派 0 功法)上验证过,但在真实档(创建 → 入门派 → 36 月)上因一个**等级词表分裂**而大面积失效:`GRADE_POINTS` 用 CJK 键(丁丙乙甲),而生产写入用拉丁键(D/C/B/A),导致 `mastery_points` 在任何真实档上恒为 0 → 武学结局轴为 0、华山 mastery 项为 0、修习收益曲线虚假。本轮逐卡先立**实测红**(brief 已给帧号/观测值),再落地绿,全部钉子改在真实档路径上。

**改动的文件面(全部可编辑,六文件锁零触碰)**:

| 层 | 文件 | 卡 |
|---|---|---|
| 纯数学单源 | `scripts/data/progression_math.gd` | C1、C7 |
| 事件/修习核心 | `scripts/data/event_logic.gd` | C2 |
| 养成段 | `scripts/segments/cultivation.gd` | C2、C6、C7 调用点 |
| 地图数据 | `scripts/data/map_data.gd` | C3(ENDING_TIERS)、C4(HUASHAN_BAR + 删辩护注释) |
| 结局屏 | `scripts/segments/ending.gd` | C3(历史观测量)、C7(银两观测量) |
| 单元测试 | `tests/test_progression_math.gd`、`tests/test_action_yield_curves.gd`(既有文件更新) | C1、C7 |
| playtest | `playtest/huashan_winnable_normal_route.yaml`(重写)、`playtest/huashan_readiness_warning.yaml`(重基线)、新增 3 条场景、`playtest/_common.yaml` | C2–C7 |
| 契约守卫 | `tests/test_playtest_contract_smoke.py`(ROUND_SCENARIOS 两地同步 + 新钉子门) | 全部 |
| 设计档案 | `design/40_progression.md`、`design/90_decisions.md`、`design/00_roadmap.md`、`design/99_changelog.md` | C8 |

**零触碰清单(锁)**:`scripts/battlefield.gd`、`scripts/autoload/game_manager.gd`、`scripts/autoload/scene_manager.gd`、`scripts/segments/map.gd`、`scripts/data/map_battle_data.gd`、`playtest/map_battle_node_huashan.yaml`(六文件锁);三条 verbatim 闸门(`facility_use_reusable` / `map_node_event_shaolin` / `map_battle_node_huashan`)逐字节不动;RNG 生命线 `save_load_roundtrip`、`event_travel_effects` 在改动后必须复跑绿。**本设计全部改动为纯算术/数据/观测量,零新增 RNG 操作**(逐条核对见 §8)。

---

## 1. 硬约束(每张卡都吃)

1. **先红后绿**:每张卡先跑出实测红(失败帧 / 首断 / 确切错误串 / 红前绿数),才准落修复。brief 已给的红值视为权威测量(帧在服务器 `~/.AItelier/play_frames_r3/`,不在仓内,不重推);修复轮用**临时回退法直连边车**(`# TEMPORARY RED-FIRST REVERT — DO NOT COMMIT` 标记 + `godot_playtest_scenario` 直连,跑红后逐字节还原)补齐每条新钉子的四值。
2. **钉性质不钉字面量**:差分(`changed`)、边界、比率、计算型布尔观测量;禁绝对银两/血量/Power 字面量;测试夹具的等级键**必须取自生产词表**(`PRACTICE_TO_MASTER`/`GRADE_BY_YEAR` 的键),不许手写字符串。
3. **真实档验证**:仪器与钉子走 main.tscn → 教程 → 创建 → 入门派的完整 boot;`debug_seed_save` 空档只允许出现在「度过多月 ×36」这条**唯一合法的无功法路线**上(C3 腿 A,见 §3-C3 的路线裁定)。
4. **升级条款(C5)**:C1 落地后若玩家侧杠杆仍赢不了华山且不琐碎化战斗 → **停手**,向所有者申请解锁 `scripts/data/map_battle_data.gd`。不许把「赢」重定义成「多活两回合」,不许用 debug 胜利充数。
5. **`map_data.gd:63-69` 辩护散文删除**:「fresh profile scores below 30 on all seeds」与算术不符(10/10/10 → power = 50/5 + 20 + 10/2 = 35 ≥ 30)。改为 C4 实测值,或删。

---

## 2. 架构图(数据流)

```
                    ┌── 生产等级词表(唯一来源,拉丁键 D/C/B/A)──────────────┐
                    │  scripts/data/progression_gongfa_data.gd              │
                    │   PRACTICE_TO_MASTER {"D":4,"C":6,"B":8,"A":10}       │
                    │   GRADE_BY_YEAR ["D","C","B"]  GRADE_SUFFIX/GRADE_STEP│
                    └──────────────┬────────────────────────────────────────┘
                                   │ keys 派生(唯一词表来源,C1)
                    scripts/data/progression_math.gd
                      GRADE_POINTS  ← 由 PRACTICE_TO_MASTER 的键派生,值=丁1丙2乙3甲4
                      mastery_points(profile)   ├──→ EndingLogic.evaluate → 结局武学轴 (C1)
                      work_income(months)       ├──→ cultivation 做工 (C7,驱动改为 work_months)
                      deed_score(deeds)         ├──→ 结局历练轴 (C3 阈值重测)
                      readiness_power(stats)    ────→ BattleSetup.readiness → HUASHAN_BAR (C4)
                                   │
        scripts/segments/cultivation.gd          scripts/data/event_logic.gd
          _apply_action("practice") ──┐   add_practice(profile, amount, target_id:="") (C2)
             target 传入 ↓            │      target 空才回落 _first_unmastered_id
          last_yield_text(显示名) ────┼──→ _render() 追加回执行 (C6)
          practice/attr 回执去 raw id ─┘
                                   │
      scripts/data/map_data.gd     │
        ENDING_TIERS min_score(90/60/0 → M2' 实测重定)  ←── 36 月真实档路线表 (C3)
        HUASHAN_BAR {even,strong} → M3' 实测重定 + 删辩护注释 (C4)
                                   │
      scripts/segments/ending.gd   │
        ending_tier_history / ending_title_history / first_ending_silver 观测量 (C3/C7 钉)
                                   │
      playtest/*.yaml(真实档 boot)+ tests/*.gd(无头仪器)
        新钉子:practice_target_receipt (C2+C6) · ending_tiers_differentiate (C3)
               work_beats_idling (C7) · huashan_winnable_normal_route 重写 (C5)
               huashan_readiness_warning 重基线 (C4)
```

---

## 3. 组件设计(逐卡)

### C1 (L2) — 等级词表单一来源

**已验证锚点**:`scripts/data/progression_math.gd:16`(`GRADE_POINTS := {"丁":1,"丙":2,"乙":3,"甲":4}`,CJK);生产写入端全部拉丁键 — `progression_gongfa_data.gd:22/27/30/33`(`PRACTICE_TO_MASTER`/`GRADE_BY_YEAR`/`GRADE_SUFFIX`/`GRADE_STEP`)、`cultivation.gd:456/455`(shen_gong `add_gongfa(pick,"A")`)、`:566-573`(`_grant_year_arts` 用 `GRADE_BY_YEAR`)、`:967`(debug A 授予);`event_logic.gd:95-96`(`PRACTICE_TO_MASTER.get(grade,4)`)。唯一消费 CJK 键的就是 `GRADE_POINTS` 自己 + `tests/test_progression_math.gd:19` 的 `GRADE_KEYS := ["丁","丙","乙","甲"]` 手写夹具。

**设计**:

1. `scripts/data/progression_math.gd`:`GRADE_POINTS` 改为**从 `PRACTICE_TO_MASTER` 的键派生**:
   ```gdscript
   const ProgressionGongfaData = preload("res://scripts/data/progression_gongfa_data.gd")
   ## 设计点值(10_systems §3: 丁1 丙2 乙3 甲4),键一律取生产词表。
   const _GRADE_POINT_VALUES := {"D": 1, "C": 2, "B": 3, "A": 4}
   ## SINGLE-SOURCE:键集 = PRACTICE_TO_MASTER.keys()(生产词表),从不手写。
   static var GRADE_POINTS: Dictionary = _derive_grade_points()
   static func _derive_grade_points() -> Dictionary:
       var out := {}
       for key in ProgressionGongfaData.PRACTICE_TO_MASTER.keys():
           out[key] = int(_GRADE_POINT_VALUES.get(key, 0))
       return out
   ```
   - `mastery_points` 本体不动(它读 `GRADE_POINTS.get(grade,0)`,键换拉丁后真实档立即非零)。
   - **回退路**(若 static-var 初始化在 headless 装载序上出问题,实测才会暴露):退为 `const GRADE_POINTS := {"D":1,"C":2,"B":3,"A":4}` 字面拉丁键 + 一条**键集相等**单元钉(`GRADE_POINTS.keys()` 与 `PRACTICE_TO_MASTER.keys()` 互为充要)——「共享同一套键」同样满足 C1;两条路线都由同一个单元钉守护,实现者按实测择一。
2. 全仓 `grade` 消费面扫荡(实现时逐点核对,预期零残余):`event_logic.gd:95`(拉丁 ✓)、`cultivation.gd:566/759`(拉丁 ✓)、`battle_setup.gd`/`GongfaData.GRADE_RANK`(键为拉丁,实现时直读 `scripts/data/gongfa_data.gd` 确认)。**除 `progression_math.gd` 外预期零改动** — 扫荡是防漏,不是预期改动面。
3. **单元钉重写**(`tests/test_progression_math.gd`,既有文件):
   - 删 `GRADE_KEYS` 手写 CJK 常量,改为 `var GRADE_KEYS: Array = ProgressionGongfaData.PRACTICE_TO_MASTER.keys()`(夹具从生产词表取键,卡规原文);
   - `_test_grade_points`:断言 `GRADE_POINTS` 键集与 `PRACTICE_TO_MASTER.keys()` 互为充要(C1 单源守卫)、每个键的点值与 `_GRADE_POINT_VALUES` 一致;
   - `_test_mastery_points`:用生产键构造 mastered 行(D/C/B/A),保留既有性质钉(未大成 → 0、未知键 `"ZZ"` → 0、缺 `mastered` 键 → 0);
   - `PlayerProfile.add_gongfa(id, grade)` 的 grade 实参一律取词表键。
4. **场景钉(C1 的树上证明)**:真实档练功路线跑到结局,断言 `EndingScreen` 武学轴 > 0 — 挂在 C3 新场景的腿上(见下),红先值 = 当前树上武学轴 `== 0`(brief 实测:`pt2_top_s2_frame_1020.png` 武学:0)。

### C2 (L3) — 练功加到所选功法

**已验证锚点**:`cultivation.gd:469-476`(读 `target` 却调 `_add_practice(PRACTICE_ACTION_GAIN)` 不带 target;`last_yield_text = tr("练功：%s +%d") % [target, ...]` 用裸 ASCII id);`event_logic.gd:87-97`(`add_practice(profile, amount)` → `_first_unmastered_id`);`cultivation.gd:581-582`(`_add_practice` 转发);事件效果调用点 `event_logic.gd:79`(无 target,必须保留回落)。

**接口变更**:

```gdscript
# scripts/data/event_logic.gd
static func add_practice(profile: PlayerProfile, amount: int, target_id: String = "") -> void:
    if profile.has_trait("sha_po_lang"):
        amount = TraitEffects.pojun_practice(amount)     # 变换次序不变(纯算术,零 RNG)
    var gid: String = _resolve_target(profile, target_id)
    if gid == "":
        return
    ...  # 既有累加 + PRACTICE_TO_MASTER 门槛判大成,逐字不动
## target 非空且是 profile 里**未大成**的行 → 用它;否则(空 / 未知 id / 已大成)
## 一律回落首个未大成 — 绝不静默丢弃这次练功。
static func _resolve_target(profile: PlayerProfile, target_id: String) -> String
```

- **裁定(记入 90_decisions 裁决一附注)**:target 指向已大成或未知 id 时**回落**到首个未大成而不是丢弃 — 理由:练功月份已经付出,静默丢弃等于月份蒸发;回落保持「练功必有所得」的不变量。UI 路径(`GONGFA_PICK` 只列 `_unmastered_ids()`)永远不会触发该回落,它是纯防御分支。
- `cultivation.gd:_apply_action` "practice" 分支:`_add_practice(PRACTICE_ACTION_GAIN, target)`(包装函数加透传参数);`last_practice_target` 语义升级为**实际生效的 gid**(解析后的),不再是原始输入。
- 事件效果路径 `apply_option_effects` → `add_practice(profile, value)` 不传 target → 回落,行为逐字节不变。

**回执显示名(与 C6 共用)**:`last_yield_text = tr("练功：%s +%d") % [ProgressionGongfaData.display_name_of(gid), gain]`;`display_name_of` 未知时返回 `""`,此时降级回原始 gid(诚实降级,roster_panel 先例)。

**钉(新场景 `playtest/practice_target_receipt.yaml`,承载 C2+C6)**:
- 第 1 月练功选第 1 行(默认焦点)→ 第 2 月练功**点第 2 行**(`GONGFA_PICK` 的 `CultOptionButton1`):断言 `CultivationScreen.last_practice_target: changed`(两月目标不同)、新观测量 `CultivationScreen.last_practice_other_rows_unchanged == true`(**零差分钉**:第 1 行及全部其它未大成行的 practice 计数不变,计算型观测量,不写任何绝对计数)、`CultivationScreen.last_yield_text: changed` 且 `last_yield_text` 含所选功法**显示名**(CJK 字面钉,值源自 `display_name_of`,与 `event_pool_new_event_resolved` 的中文钉同纪律)。
- 红先:修复前选第 2 行,`last_practice_target` 记的是 `"shaolin_luohan_d"` 但实际加到第 1 行(brief 实测 `pt2_top_s0_frame_0340/0425.png`:`易筋经·入门(2/4)`、`罗汉拳(0/4)`)→ 修复后树上先以临时回退(`_add_practice` 去掉透传)跑出四值。

### C3 (L3) — 结局档位分化

**已验证锚点**:`map_data.gd:81-88`(`ENDING_TIERS` min_score 90/60/0);`ending_logic.gd:27-33`(score = attrs×1.0 + mastery×2.0 + deed_score);`progression_math.gd:20-21/51-54`(deed = travel×2.0 + silver_earned×0.05);`ending.gd:76-80`(三轴渲染 + `first_ending_evaluation`);deeds 写入点 `cultivation.gd:423`(卡牌银两,真实钳位差值)/`:495`(做工)/`:617`(游历)。免费卡 `card_data.gd:30` `eco_20` value 20、count 4 → 每月卡池近乎必出 +20。

**M2' 实测流程(先测后调,红先绿后)**:

1. **仪器**:扩展 `tests/test_action_yield_curves.gd` 的月循环模拟(它已复刻真实行动数学 + 播种 RNG),新增「真实档入档前缀」:先模拟入派授艺(`_grant_year_arts` 等价:internal+external 丁级各一门,`main_external_id` 置位),再跑 36 月 — 使测量发生在**有功法、有门派**的档上,而不是 0/0 空档。
2. **路线定义(裁定,记入 90_decisions 裁决二附注)**:
   - **腿 A · 什么都不做**:`度过本月` ×36。该按钮只在「无未大成功法」时出现 — 在 0 功法空档上它从第 1 月就存在,是**唯一合法的零收益路线**;真实档(入门派)上它要求先练满全部功法,不再是「什么都不做」。故腿 A 用空档播种子 + 纯键盘(收卡 + 练功→度过多月),**并在 40_progression.md 记录该路线的可达性边界**;真实档上的 tier-1 下界由腿 A' (最低产出合法路线:36 × 修习,+1~3 属性/月)承载,两条都断言 tier < 3。
   - **腿 B · 单一路线**:36 × 练功(只推武学轴)。
   - **腿 C · 均衡/强路线**:练功 + 修习 + 做工 + 游历混合(clicks-only 月语法,`ending_divergent_playstyles` Leg A 先例)。
3. **阈值重定**:由三条腿 × ≥5 种子的实测 score 分布重定 `ENDING_TIERS` 三行 `min_score`(替换 90/60/0;行序 descending、末行 0 的不变量逐字保留)。同时按实测定**历练轴构成**:跑一组「免费卡银两计入 / 不计入 `deeds.silver_earned`」的对照 — 若免费卡银两剔除后三档分化自然成立,则把 `cultivation.gd:423` 的卡牌银两 deed 增量改为不计入(卡牌银两仍入 `profile.silver`,只动 deed 记账一行,零新系统);若剔除后仍不分化,则只动阈值。**两条杠杆按实测择一,不许都动**;结论写进 `40_progression.md` M2' 小节(替换旧表,旧表标注 "measured on empty seeded profile")。
4. **观测量**(`scripts/segments/ending.gd`,加法不动既有):`ending_tier_history: Array[int]`、`ending_title_history: Array[String]`(每次 `_ready` 追加 tier/title,与 `first_ending_evaluation` 同生命周期);`SaveManager` surface 白名单加这两个名字。

**钉(新场景 `playtest/ending_tiers_differentiate.yaml`,三腿同 run)**:
- 腿 A(空档度过多月 ×36,键盘语法)→ ENDING:断言 `EndingScreen.tier < 3`(红先:当前 143 > 90 → tier 3);
- 腿 B(真实档单一路线)→ 断言 `SaveManager.ending_tier_history[1] != SaveManager.ending_tier_history[0]`(**tier 差分,不是 text 差分** — 旧钉 `first_ending_evaluation != evaluation_text` 被三个数字差异满足的漏洞就此关死);
- 腿 C(真实档强路线)→ 断言 `ending_tier_history[2] != ending_tier_history[0]`、三标题两两互异:`ending_title_history[0] != [1] and [1] != [2] and [0] != [2]`(表达式内联三连不等);
- `ending_divergent_playstyles.yaml` 的既有差分保留(它钉「同种子异玩法 → 评价不同」,与本钉互补)。

### C4 (L3/L4) — 华山评估两头修真

**已验证锚点**:`progression_math.gd:60-64`(`readiness_power = floor(hp/5)+atk+floor(ini/2)`);`map_data.gd:70`(`HUASHAN_BAR {"even":30,"strong":40}`)与 `:63-69` 辩护散文;`battle_setup.gd:67-78`(`readiness()`,不动);`playtest/huashan_readiness_warning.yaml:67`(`readiness_text == "华山评估：战备不足"` 字面钉,f130 **当前已红** — 10/10/10 空档 power=35 ≥ 30 → 势均力敌,这就是红先值);`cultivation.gd:1074-1082`(第 3 年起正文华山水位行,同一公式源)。

**流程**:

1. **C1 先落**(mastery 项进入 `derive_stats` 的 mp 才非零,战备才随成长动)。
2. **M3' 实测**:真实档 boot(创建 → 入派)× ≥5 种子 × 三条路线(最低/平衡/强),无头仪器(`tests/test_battle_setup_readiness.gd` 扩展,输出 power/verdict 表)+ 真实华山战局验证(胜负与「活过第 2 回合」)。
3. **重定 `HUASHAN_BAR`**(`map_data.gd:70`,常量行替换):判据 —(a) 创建即新档(五围 10、0 大成)落 weak 带;(b) 平衡路线落 even 带;(c) 强路线落 strong 带且**进华山后活过第 2 回合**;(d) 评语与实际胜负相关(胜券在握的档不许第 2 回合死)。同时删 `:63-69` 辩护散文,替换为一句指向 `40_progression.md` M3' 实测表的指针(实测值住档案,代码住公式)。
4. **既有钉转绿**:`huashan_readiness_warning.yaml` 的 f130 字面行按实测重基线(若重定后空档 fresh verdict 仍为 `战备不足` 则该行逐字保留;若词表/格式变了则同步改该行与 :127 — 这是**有意的重基线**,在交付说明逐行记变更,零断言放松)。f320 的 STRING 差分钉原样保留。
5. **新钉(边界/差分,不写 HP 字面量)**:强路线进华山后,在「第 2 回合结束后」的帧断 `CombatManager.current_round >= 3 and Player.health > 0` — 「胜券在握不许第 2 回合死」由轮次边界承载。挂进重写后的 `huashan_winnable_normal_route`(见 C5)的时间线,不新增场景。

### C5 (L3) — huashan_winnable_normal_route 重写(头身相符)

**已验证锚点**:`playtest/huashan_winnable_normal_route.yaml` 现状 — `scene: menu.tscn` 但时间线 f20 用 `debug_win_tutorial`、f280 用 `debug_fast_forward`、f400 前后全是 `ui_accept`/`move_right` 键盘动作 → 与标题「clicks-only month grammar: card + work」头身不符,且 WIN 证据实为 debug 胜利。`playtest/map_battle_node_huashan.yaml`(锁定、verbatim)的 WIN 腿同样来自 f815 `debug_win_tutorial` — 它**保持逐字不动**,本轮可赢路线的唯一证据源就是重写后的本场景。

**重写规格**(该文件不在锁内):

- `scene: res://scenes/menu.tscn` 保持;**时间线全部点击语法**(`clicks:`,真实 GUI 命中,`clicks_only_storyline` / `ending_divergent_playstyles` Leg A 先例),**时间线内零 `debug_win_tutorial`、零 `debug_fast_forward`、零键盘动作**:
  1. 主菜单点「新的冒险」(`MenuStartButton` 类真实按钮锚,菜单按钮池稳定,clicks 语法可用)→ 捏人屏确认点击 → **教程战用真实点击打赢**(战斗点击先例:`battle_end_turn_attack_buttons` / `click_targeting_fixed`:技能按钮 `SkillButton{i}` + 敌方单位 Node2D 锚如 `Central_Divine +0,0` + `EndTurnButton`;禁止 `*_ClickTarget` 锚 — 2026-08-29 裁定);
  2. 教程结算/过场/拜师/养成全部按 `clicks_only_storyline` 的按钮名点击(`CultOptionButton0` 收卡 + `CultOptionButton2` 做工,年界附加 `CultOptionButton0` 留门、开年 `CultOptionButton0` 收际遇);
  3. 大地图 `TravelButton{i}` / `EventOptionButton0` 点击走到华山(路线同 `map_battle_node_huashan` 的洛阳 → 少林 → 华山,但用点击);
  4. **真打华山**:技能按钮点击 + 敌方单位锚点击 + `EndTurnButton` 点击,目标/站位脚本化;C1 落地后 mp 项抬高玩家先攻/血量/内力,胜负由真实技能循环决定;
  5. 断言:WIN 帧 `Player.health < Player.max_health`(战斗是真的,不是满血白拿);`ui_accept`(结局 overlay 的确认键 — overlay 的 ContinueButton 也可点,取点击)回地图后 `GameManager.current_state == "MAP"`、`SceneManager.current_scene == "map"`、`map_battle_id == ""`、`MapScreen.current_node_id == "huashan"`;
  6. 附加 C4 边界钉:战斗中段一帧断 `CombatManager.current_round >= 3 and Player.health > 0`(强档活过第 2 回合)。
- **帧预算**:36 个点击月(~5 帧/月 ≈ 190 帧)+ boot/捏人/教程点击战(~300 帧)+ 地图行走(~120 帧)+ 华山多回合(敌人先手、回合间隔 ~120-150 帧/回合,预估 4-8 回合 ≈ 1000-1400 帧)→ 总计 ~1800-2200,2999 上限内;点击间距按既有场景 5-20 帧/击放宽,回合等待帧按 `map_battle_node_huashan` 实测(f580 起战斗、f720 玩家回合)外推。若实测超预算:**先砍月内 click 间距,再合并断言帧**,不许删断言。
- **先红后绿**:重写后先在修复前树上跑(时间线走不到 WON → 首断即红,记录四值);C1+C4 落地后复跑转绿。
- **升级条款检查点**:若 C1 落地、C4 曲线调完,玩家侧真实技能仍赢不了(五绝 95-130 HP、95-130 先攻区间压制)→ 停手,出报告向所有者申请解锁 `scripts/data/map_battle_data.gd` 数据;不许削弱敌人、不许重定义胜利。

### C6 (L4) — 回执画上屏

**已验证锚点**:`cultivation.gd:1058-1134` `_render()` 只追加 `status_text`(`:1120-1121`);`last_yield_text` 在 surface 白名单(`_common.yaml:789`)但**零消费者**;回执用裸 id(修习:`bone`、练功:`shaolin_luohan_b`)。

**设计**:

1. `_render()` 在 `status_text` 块之后追加回执行(位置形式不限,沿用组合式 BodyLabel,零新控件层级):
   ```gdscript
   if last_yield_text != "":
       text += "\n" + last_yield_text + "\n"
   ```
2. **显示名替换**(三处生成点):
   - 练功(C2 已改):`display_name_of(gid)`(易筋经·入门 等);
   - 修习(`:487`):`tr("修习：%s +%d") % [_attr_label(action.get("target","bone")), gain]` — 复用既有 `_attr_label`(根骨/内力/身法/悟性/福缘),**零新 i18n 键**;
   - 做工(`:498`)已是中文,不动。
3. **新观测量(计算型,性质钉)**:`CultivationScreen.last_yield_readable: bool` — 回执非空时 = `not last_yield_text.contains("_") and not last_yield_text.contains(<本次裸 id>)`(练功对 `last_practice_target`、修习对原始属性键、做工恒 true);`CultivationScreen.last_practice_other_rows_unchanged: bool`(C2 零差分钉,同点计算)。
4. **i18n**:`last_yield_text` 的两条格式键已在 i18n EN 表(现网在用),EN 侧显示名由 `display_name_of`/`_attr_label` 产出(中文专名,i18n 覆盖测试不波及);新增观测量进 `_common.yaml` surface 白名单。
5. **遮挡**:`UiOcclusionWatch.violations == 0 + scan_ok == true` 挂在新场景每个触帧(回执多两行文本,BodyLabel 加高不得压任何按钮 — 既有 5 判据闸门兜底)。

**钉**:`practice_target_receipt.yaml` 中,动作前帧 `last_yield_text` 与动作后帧差分(`changed`),且 `last_yield_readable == true`(不含 `_`、不含裸 id);红先 = 修复前 `_render` 不含回执 → `last_yield_text` 有值但屏上无消费者(性质红以「回执行不存在」的临时回退实测:注释掉追加行跑红)。

### C7 (L2) — 做工拉开与免费卡

**已验证锚点**:`progression_math.gd:46-47`(`work_income = 10 + 2*maxi(mastered,0)`);`card_data.gd:30`(`eco_20` +20, count 4);`cultivation.gd:492-498`(做工调用点,deed 先读后加,顺序保持);`tests/test_action_yield_curves.gd:71/90`(仪器里的同款调用);`tests/test_card_data.gd:39`(`eco_20 x4` 钉)。

**杠杆裁定(二选一,本设计选「做工曲线拉开」,记录否决理由)**:

- **选 (ii) 做工曲线真正拉开**:`work_income` 的输入从「大成交数」改为**既有持久 deed `work_months`**,曲线改为 `10 + 3 * maxi(work_months, 0)` — 递增做工(第 k 次做工 +10+3(k−1)),36 次做工单做工收入 ≈ 360 + 3×630 = 2250,叠免费卡/事件后总银两 ≈ 4100+,对「度过多月」路线(~1900-2000)比率 ≈ **2.1× > 1.5×**,余量充足。
  - 签名改为 `work_income(months_worked: int) -> int`(参数语义变,形状不变:floor 10、严格递增、非负、负数钳 0 — 既有单元钉全部保留成立);`cultivation.gd:492` 调用点改传 `SaveManager.profile.get_deed("work_months")`,**注意 gain 必须在 `work_months += 1` 之前计算**(现序正好如此,逐字保持,零 RNG)。
  - 免费卡 `eco_20` **一个字节不动** → `tests/test_card_data.gd` 与 `eco_20` 相关镜像零改动(否决「稀释卡牌」路线的决定性理由:该杠杆必改 `card_data.gd` + 其测试镜像 + M1 表三处,且按算术只能把比率推到 ~1.3-1.46×,压不住 1.5× 钉)。
  - 与 C3 的交互:做工路线的 `deeds.silver_earned` 随之抬高 → 历练轴上升 → 强路线 tier 3 更稳;do-nothing 无做工收入,tier 1 不受威胁。M2' 测表按新曲线重测,两卡的数据在 `40_progression.md` 各自小节**互相引用**(一次测量,两处引用)。
- **钉(新场景 `playtest/work_beats_idling.yaml`,两腿同 run)**:
  - 腿 A:空档 `度过多月` ×36(收卡 + 度过多月)→ ENDING,`SaveManager.first_ending_silver` 捕获(新观测量,`ending.gd` 在首次评价时记 `SaveManager.profile.silver`);
  - 腿 B:真实档 36 × 做工(clicks 语法)→ ENDING:断言 `EndingScreen.final_silver > SaveManager.first_ending_silver * 3 / 2`(整数安全写法,**比率钉,零绝对银两**);`EndingScreen.final_silver` 为新观测量(`_ready` 时快照 `SaveManager.profile.silver`)。
  - 红先:修复前比率 ≈ 1.12(brief 实测 2248 vs ~2000)→ 比率断言红。

### C8 — 设计记录(5_design 的交付物,本架构只定内容大纲)

- `design/40_progression.md`:M2' 表(真实档三路线 × ≥5 种子,阈值推导,旧表标 "measured on empty seeded profile" 并保留)、M3' 表(≥5 种子 × 三档带,「胜券在握活过第 2 回合」实测)、做工小节替换(`work_income` 新曲线 + 比率实测,旧数标注被取代)、C1 词表单一来源小节。
- `design/90_decisions.md` 两条裁决(2026-09-02 日期):①**等级词表单一来源**(GRADE_POINTS 从 PRACTICE_TO_MASTER 派生;测试夹具禁手写等级键;附 C2 的 target 回落语义);②**M2/M3 必须真实档**(空档只承载「度过多月 ×36」腿 A 的可达性边界,附路线定义)。
- `design/00_roadmap.md`:队列改为 R3b → 外号 → 回执/结算 → 教程与目标 → 创建屏剩余点数 → 地图有图 → 非战斗美术;UX-11/UX-12 焦点标记、技能栏 704px 截断、槽位数字压名、`ProgressionHero`/`Sparring Partner` 裸上屏等试玩发现记入 backlog(UX-33+,record-only,本轮不做)。
- `design/99_changelog.md`:**append-only**,新增 2026-09-02 R3b 行(实测红值 + 卡清单),零删改旧行。

---

## 4. 接口规范汇总(实现者契约)

| 签名 / 观测量 | 变更 | 消费者 |
|---|---|---|
| `EventLogic.add_practice(profile, amount, target_id := "")` | 加第三参,默认空 | `cultivation._add_practice`(透传)、`apply_option_effects`(不传,回落) |
| `ProgressionMath.GRADE_POINTS` | 键集改为派生自 `PRACTICE_TO_MASTER`(拉丁) | `mastery_points`、单元测试 |
| `ProgressionMath.work_income(months_worked: int)` | 参数语义 mastered→work_months,斜率 2→3 | `cultivation._apply_action`、`test_action_yield_curves` |
| `MapData.ENDING_TIERS[].min_score` | M2' 实测重定(行序 descending、末行 0 不变量逐字保留) | `ending_tier_score` |
| `MapData.HUASHAN_BAR` | M3' 实测重定;`:63-69` 散文删/换指针 | `BattleSetup.readiness` |
| `CultivationScreen.last_yield_readable / last_practice_other_rows_unchanged`(bool) | 新增计算型观测量 | 新场景、`_common.yaml` surface |
| `EndingScreen.final_silver`(int)、`SaveManager.first_ending_silver`(int)、`SaveManager.ending_tier_history`(Array[int])、`SaveManager.ending_title_history`(Array[String]) | 新增观测量 | C3/C7 场景、`_common.yaml` surface |

**不变式**:上述全部为纯算术/数据/发布,零新增 RNG 操作、零新增存档字段(deeds 键集不动)、零场景节点改名;`gongfa` 行结构 `{id, grade, practice, mastered}` 不变(grade 值域拉丁,老档无损)。

---

## 5. 技术栈(沿用 Step 1 推荐,零新增)

- **帧捕获 playtest 边车**(`playtest/*.yaml` + `_common.yaml` + `godot_playtest_scenario`):所有场景钉、修红四值实测。
- **无头 GDScript 单元**(`tests/*.gd` + `tests/unit_test_runner.gd` 注册表):M2'/M3' 调参仪器、C1/C7 数学钉。
- **pytest 契约守卫**(`tests/test_playtest_contract_smoke.py` 等):新场景两地注册、新 load-bearing 钉的防删门。
- **UiOcclusionWatch / i18n 覆盖闸**:C6 新文本的遮挡与 EN 覆盖自动兜底。
- 否决 GUT / gdUnit4(Step 1 已裁定):不引入任何新依赖。

---

## 6. 测试与契约变更清单

**单元(更新 2 个既有文件,零新增文件 → `unit_test_runner.gd` 注册表不动)**:
- `tests/test_progression_math.gd`:夹具键改生产词表;新增 GRADE_POINTS↔PRACTICE_TO_MASTER 键集互充守卫;`work_income` 语义更新(floor 10 / 严格递增 / 单调 / 负数钳 0 全保留)。
- `tests/test_action_yield_curves.gd`:`work_income` 调用点改 `work_months` 驱动;M1 表加打真实档前缀授艺;`mastered-heavy > fresh` 差分钉改为 `late-work > early-work` 形状(曲线变陡的性质钉)。

**playtest(改 2、增 3;`_common.yaml` scenario_order 尾部 + `ROUND_SCENARIOS` 两地同步,相对序守卫自动核)**:
- 重写:`huashan_winnable_normal_route.yaml`(C5,零 debug 胜利)。
- 重基线:`huashan_readiness_warning.yaml`(C4,f130 字面按实测)。
- 新增:`practice_target_receipt.yaml`(C2+C6)、`ending_tiers_differentiate.yaml`(C3)、`work_beats_idling.yaml`(C7)。
- `_common.yaml`:surface 白名单加 `CultivationScreen.last_yield_readable / last_practice_other_rows_unchanged`、`EndingScreen.final_silver`、`SaveManager.first_ending_silver / ending_tier_history / ending_title_history`;actions 零新增(全部用既有动作/点击)。
- `tests/test_playtest_contract_smoke.py`:三个新名进 `ROUND_SCENARIOS` 尾部(与 `scenario_order` 同相对序);为比率钉/档位钉各加一条防删弱化门(照 `facility_use_reusable` 门形状:关键断言行必须在场且带比较符)。

**回归网(改动后必须全绿)**:`spine_to_ending` 42/42、`clicks_only_storyline` 47/47、`facility_use_reusable` 49/49、`map_node_event_shaolin` 32/32、`save_load_roundtrip` 14/14、`event_travel_effects` 19/19、`equipment_in_battle_diff` 47/47、`cultivation_changes_combat` 30/30、`softlock_empty_practice_month_advances`、`occlusion_no_button_over_text` 22/22、`ending_divergent_playstyles`、`ending_last_month_choice`、`action_yield_differential`、`fortune_reroll_budget`。

---

## 7. 设计变更(对 design/ 档案的冲击,供 5_design 执行)

1. **`40_progression.md`**:M2/M3 两表被实测表**替换**(旧表保留并标注 "measured on empty seeded profile, superseded 2026-09-02");做工小节数值替换;新增「等级词表单一来源」小节;`度过多月` 路线的可达性边界注记。
2. **`90_decisions.md`**:新增两条裁决(词表单源;M2/M3 真实档)+ C2 target 回落语义附注 + C7 杠杆选择(做工曲线,否决稀释卡)的算术理由。
3. **`00_roadmap.md` / `99_changelog.md`**:按 C8 大纲更新(队列重排;append-only 追加)。
4. **`map_data.gd:63-69`**:辩护散文删除,替换为一行指向 40_progression.md M3' 表的指针注释。
5. **不动的档案**:10/20/30/31/32 系列零改动(无数值/呈现/内容变更);`20_content.md` 的 eco_20 行不变(C7 未动卡牌)。

---

## 8. 风险登记与回滚

| 风险 | 缓解 |
|---|---|
| static-var 派生 GRADE_POINTS 的装载序 | 回退路已备(字面拉丁键 + 键集相等钉);两种实现由同一守卫测试裁决 |
| C1 波及面(grade 消费者) | §3-C1 扫荡清单逐一核对;唯一 CJK 消费者是 GRADE_POINTS 本体 |
| RNG 操作序漂移 | 全部改动零新增 RNG op;`save_load_roundtrip` / `event_travel_effects` 改后必跑 |
| C5 帧预算超 2999 | 先压点击间距,再并断言帧;仍超则减重复断言(不删钉);仍超则报告并重排 |
| C5 玩家侧仍赢不了 | **升级条款**:停手申请 `map_battle_data.gd` 解锁,不琐碎化 |
| C3 阈值/历练构成二选一犹豫 | 按 M2' 实测择一,`40_progression.md` 记录数据与抉择 |
| 观测量新增破坏既有白名单守卫 | 两地同步 + 相对序守卫自动拦;新钉子配 pytest 门 |
| 锁文件误碰 | 变更面表(§0)即为审计清单;六文件 + 三 verbatim 闸逐一比对 |

**回滚路径**:每张卡独立成 commit 粒度的改动集;数据常量(HUASHAN_BAR / ENDING_TIERS / work_income 斜率)回滚 = 还原常量行;观测量为加法字段,回滚零破坏;playtest yaml 重写前旧版本在 git 历史中(该文件非 verbatim 锁,可回退)。

---

## 9. 给 PM 的分解建议(顺序即依赖)

1. **T-C1**:GRADE_POINTS 派生 + test_progression_math 夹具重写(先行,其余卡依赖 mastery 非 0)。
2. **T-C7**:work_income 曲线 + 调用点 + 仪器更新(独立于 C2/C3,可与 C1 同批)。
3. **T-C2**:add_practice 透传 + 回执显示名 + `practice_target_receipt.yaml`(依赖 C1 的显示名数据无关,但建议 C1 后跑)。
4. **T-C3**:M2' 仪器实测 → 阈值/历练构成裁定 → `ending_tiers_differentiate.yaml` + ending.gd 观测量。
5. **T-C4**:M3' 实测 → HUASHAN_BAR + 删散文 → `huashan_readiness_warning` 重基线(依赖 C1)。
6. **T-C5**:`huashan_winnable_normal_route` 重写(依赖 C1+C4;含升级条款检查点)。
7. **T-C6**:回执渲染 + 观测量(可独立,建议与 C2 场景合并验收)。
8. **T-C8**:四份设计档案更新(收尾,带实测数字)。

每张卡交付物固定四件:代码/数据改动、单元或场景钉、修红实测四值、(C8)档案行。