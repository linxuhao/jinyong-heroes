# Content — 教程战「华山之巅·五绝同场」

本文件只覆盖**第 1 段(教程战)**。第 3~6 段的可练功法阶梯尚未设计,
见 `90_decisions.md`。

## 0. 战场

15 × 11 格,每格 64 px(960 × 704)。玩家起始 (7,5) 正中,五绝分列四方与正北。
棋盘唯一的行限制是 `is_walkable` 的**边界环**(行/列 0 与 `GRID_*−1`),
可通行行 `1..GRID_HEIGHT−2`(= 1..9);可见性归跟随相机
(见 `30_presentation.md` 定位章)。

| 单位 | 起始格 |
|---|---|
| 杨过 | (7, 5) |
| 东邪 | (3, 2) |
| 西毒 | (11, 2) |
| 南帝 | (3, 8) |
| 北丐 | (11, 8) |
| 中神通 | (7, 1) |

## 1. 玩家:杨过(平行版·独臂神雕侠)

这是**一个武学全满的杨过**(本作没有人物等级,只有武学等级),不是唯一的杨过。全部功法发挥度 **1.3(超常)**,
前置视为已满(教程战不需要玩家去练)。

| 属性 | 值 | | 派生 | 值 |
|---|---|---|---|---|
| 根骨 | 92 | | 气血 | **1000** |
| 内力 | 95 | | 内力值 | 180 |
| 身法 | 88 | | 移动力 | 4 |
| 悟性 | 90 | | 先攻 | 88(全场最高,玩家先手) |
| 福缘 | 70 | | 普攻 | 30 / 射程 1 |

### 内功 · 九阴真经残卷(甲 · 阳)
**强大特征「神雕之力」** —— 每轮自己回合开始回复 **0** 气血(基础 0 × 发挥度 1.3);
受到的**近战**伤害 **−10%**。

> **为什么减免挂在「近战」上。** 五人同场,五人全打时净进伤约 60~70/回合,
> 玩家以 1000 血打满 8~12 回合,目标收尾 15%~40%(即 150~400)血量,
> 净进伤需落到约 600~850。初始把减免做高(近战 −50%、每轮回血 20×1.3=26)
> 实测收尾 78%——教程太简单,玩家赢得太健康,违背 `10_systems.md` §5.3 的
> 难度规格。本轮平衡下调生存盈余:回血归零、近战减免降到 −10%,实测收尾 349
> (≈35%),落在目标窗口正中。
> 之所以仍挂在「近战」上,是因为**远程绕过它**:门类属远程的招式(乐器/指/
> 暗器/奇门毒,见 `10_systems.md` §2.2)不吃这个减免——东邪与南帝主修的正是
> 这两类。于是这场仗的题目从「怎么不被五个人同时打死」变成「怎么在被近战贴身
> 的同时切进去处理那两个远程」。近战贴脸不太痛,远程专家才要命。

### 外功 · 玄铁剑法(甲 · 刚) — 4 招

| 招式 | 效果 | 冷却 | 内力消耗 |
|---|---|---|---|
| 重剑无锋 | 单体 **45**,击退 1 格 | 1 | 0(免费基础招) |
| 大巧不工 | 直线 3 格 **38** | 2 | 15 |
| 力斩千钧 | 十字 2 格 **34** | 3 | 20 |
| **绝招 · 四海无量** | 以自身为心半径 2 格全体 **70** | 6 | 25 |

### 外功 · 黯然销魂掌(甲 · 阴) — 4 招

| 招式 | 效果 | 冷却 | 内力消耗 |
|---|---|---|---|
| 心惊肉跳 | 单体 **38** | 1 | 10 |
| 拖泥带水 | 单体 **25**,目标下一回合移动力 −2 | 2 | 15 |
| 徘徊空谷 | 位移:跳 3 格,落点相邻全体 **20** | 3 | 20 |
| **绝招 · 黯然销魂十七式** | 相邻全体 **70**,击退 2 格 | 8 | 30 |

> **十七式的开关条件:自身气血低于 50% 才能使用。** 原著里这门掌法要心境
> 对了才使得出来;本作把"心境"机械化成一条翻盘条件。这也是回合制里很好
> 的一个动词——它奖励撑到残血。

### 教程的招式解锁节奏

8 个招式一次全给太多。教程分两段:前 3 轮只开**玄铁剑法**,
第 4 轮起开**黯然销魂掌**。

## 2. 五绝(各自武学全满,发挥度均 1.3)

| | 气血 | 移动 | 先攻 | 普攻/射程 | 主修内功 | 主修外功 |
|---|---|---|---|---|---|---|
| 东邪 黄药师 | 95 | 4 | 85 | 22 / 3 | 碧海潮生功(甲·阴) | 碧海潮生曲(甲·阴,**乐器**) |
| 西毒 欧阳锋 | 115 | 3 | 70 | 26 / 1 | 蛤蟆功(甲·刚) | 灵蛇拳(甲·刚,**拳掌**) |
| 南帝 段智兴 | 100 | 3 | 76 | 24 / 2 | 先天功(甲·柔) | 一阳指(甲·阳,**指**) |
| 北丐 洪七公 | 120 | 3 | 74 | 28 / 1 | 混天功(甲·阳) | 降龙二十一掌(甲·阳,**拳掌**) |
| 中神通 王重阳 | 130 | 3 | 80 | 26 / 1 | 先天功·全真(甲·阳) | 全真剑法(甲·阳,**剑**) |

> **「降龙二十一掌」不是笔误。** 这是本作平行世界规则的示范:同名功法在不同
> 时空有不同版本与近名变体(降龙十八掌 / 降龙二十一掌 / 降龙伏虎掌)。

五绝气血合计 **560**。

### 2.1 东邪 黄药师

**内功特征「弹指神通」** —— 被 3 格内的单位攻击后,立即反击 **10** 伤害(每轮至多 1 次)。

| 招式 | 效果 | 冷却 |
|---|---|---|
| 落英缤纷 | 射程 3,3×3 范围 **14** | 2 |
| 玉箫点穴 | 单体 **20**,目标下一回合无法使用招式 | 3 |
| 桃花迷阵 | 自身周围 2 格生成迷阵,进入者移动力 −2,持续 3 轮 | 4 |
| **绝招 · 碧海潮生** | 全场音波 **18**,并使全体敌方先攻 −20 持续 2 轮 | 6 |

### 2.2 西毒 欧阳锋

**内功特征「蛤蟆反震」** —— 被近战击中时反弹 **12** 伤害给攻击者。

| 招式 | 效果 | 冷却 |
|---|---|---|
| 灵蛇缠身 | 单体 **24** + 中毒 8/轮 × 2 轮 | 2 |
| 蛤蟆蹲 | 本轮不动,下一轮首个招式伤害 ×1.5 | 3 |
| 毒砂掌 | 十字 1 格 **18** + 中毒 6/轮 × 2 轮 | 3 |
| **绝招 · 蛤蟆功·倾巢** | 直线 4 格 **40** + 击退 2 | 5 |

### 2.3 南帝 段智兴

**内功特征「一阳续命」** —— 每轮回复 **10**;首次跌破 40% 气血时一次性回复 **60**。

| 招式 | 效果 | 冷却 |
|---|---|---|
| 一阳指 | 射程 2 单体 **30** | 2 |
| 点穴 | 射程 2 单体 **12**,目标下一回合无法移动 | 3 |
| 先天调息 | 为自己或友方回复 **35** | 4 |
| **绝招 · 六脉齐发** | 射程 3,直线 3 格 **34**,穿透 | 6 |

### 2.4 北丐 洪七公

**内功特征「丐帮铁骨」** —— 受到的一切伤害 **−15%**。

| 招式 | 效果 | 冷却 |
|---|---|---|
| 亢龙有悔 | 单体 **36**,击退 2 | 2 |
| 飞龙在天 | 位移 3 格,落点 3×3 **22** | 3 |
| 见龙在田 | 直线 3 格 **30** + 击退 1 | 4 |
| **绝招 · 降龙·潜龙勿用** | 半径 2 全体 **48** + 击退 2 | 6 |

副修外功 **打狗棒法(乙 · 阳,长兵)** — 3 招:绊、戳、封,各 **18~22** 伤害,
射程 2。(乙级 3 招,示范外功等级与招式数的对应。)

### 2.5 中神通 王重阳

**内功特征「先天罡气」** —— 首次受到致命伤时不死,气血保留 1,并清除全部负面状态。
每场战斗一次。

| 招式 | 效果 | 冷却 |
|---|---|---|
| 全真剑 | 单体 **32** | 1 |
| 七星聚会 | 十字 2 格 **26** | 3 |
| 罡气护体 | 自身获得 **50** 护盾,持续 3 轮 | 5 |
| **绝招 · 先天一炁** | 全场 **30**,并驱散敌方全部增益 | 7 |

## 3. 招式属性对照(用于发挥度)

教程战中全部单位的前置视为已满且同属性 3/3,故**发挥度一律 1.3**。
下表记录各功法的属性,供后续段落的前置计算沿用。

| 功法 | 门类 | 属性 |
|---|---|---|
| 九阴真经残卷 | 内功 | 阳 |
| 玄铁剑法 | 剑 | 刚 |
| 黯然销魂掌 | 拳掌 | 阴 |
| 碧海潮生功 | 内功 | 阴 |
| 碧海潮生曲 | 乐器 | 阴 |
| 蛤蟆功 | 内功 | 刚 |
| 灵蛇拳 | 拳掌 | 刚 |
| 先天功 | 内功 | 柔 |
| 一阳指 | 指 | 阳 |
| 混天功 | 内功 | 阳 |
| 降龙二十一掌 | 拳掌 | 阳 |
| 打狗棒法 | 长兵 | 阳 |
| 先天功·全真 | 内功 | 阳 |
| 全真剑法 | 剑 | 阳 |

## 4. 游历事件池 (16 条)

游历途中的 16 条纯数据事件,每条两条真实取舍的选项,只用到
`silver` / `attr` / `item` / `practice` / `none` 五种效果类型。权威源
`scripts/data/event_data.gd` 的 `EventData.TABLE`(本文只记取舍形状,不抄数据)。

**银钱换物 (item-with-cost)。** `merchant` 行商路过——花钱买物,一物一价;
`dali_market` 大理市集——二选一,花不同的钱买皮甲或快靴。

**物品 vs 属性 (item-vs-attr)。** `tomb_bed` 古墓寒玉——床上练内力,还是床畔捡剑。

**属性二选一 (attr-A-vs-attr-B)。** `ruins` 古墓残碑——悟性与福缘二选一;
`peach_maze` 桃花迷阵——闯阵的身法,还是观潮的悟性。

**练功 vs 金钱 (growth-vs-money)。** `dragon_scrap` 降龙残谱——强记掌谱练功,还是卖给书贾换银两。

**花钱练功/买属性 (paid-growth)。** `wounded_eagle` 神雕负伤——花银两施药换练功,
还是静观换悟性;`quanzhen_scripture` 全真抄经——免费抄经涨悟性,还是花银两求教剑理
换练功;`night_rain` 破庙夜雨——帮工换宿贴银两又涨根骨,还是檐下练剑。

**花钱买属性 vs 白拿 (paid-attr-vs-free-attr)。** `snake_bile` 蛇胆奇效——重金购蛇胆
涨根骨,还是掉头就走白拿一点福缘。

**花钱过路 vs 自力 (pay-vs-effort)。** `bandits` 山道遇劫匪——花钱消灾,还是自力周旋;
`flood_ferry` 渡口风波——付钱渡河,还是泅水而过换内力。

**银两 vs 属性 (money-vs-attr)。** `escort_job` 镖行招募——接下镖单挣银两,还是婉拒独行换悟性。

**道德·福缘 vs 银两 (moral fortune-vs-silver)。** `lost_purse` 遗落的褡裢——送还失主
涨福缘,还是收起走人得银两;`gambling_den` 赌坊喧嚣——入局三把搏一把银两,还是袖手旁观涨福缘。

**施舍 (charity)。** `beggar` 老丐乞食——施舍银两,得福缘回报。

## 5. 内力消耗缺口(2026-08-26,jinyong-hud 轮记录)

**本轮的技能按钮内力消耗显示必须用已存在的数值,不许就地发明一个数。**

`design/10_systems.md §1` 逐字写明:

> **内力池本轮只存不耗。** 内功产出的内力值(杨过 180)存在数据里、显示在界面上,
> 但招式**不消耗内力**——`20_content.md` 里没有一招标了消耗。招式的内力开销与
> 功法细则一起,等养成那一轮再定。

即:**教程战(及养成进度数据)里没有任何一招标了内力消耗**。本轮为技能按钮新增
`SkillData.cost: int = 0`(schema 字段,默认 0 =「未定义消耗」),`battlefield.gd`
的 `_skill()` 调用点一律**不改**(不填任何造出来的数字);显示层对 `cost == 0`
渲染「无消耗」。

**内容缺口(留给养成那一轮定义,不许就地补):** 下列 8 个玩家招式,当前消耗一律
**未定义(0)**:

- 玄铁剑法(甲 · 刚):重剑无锋 / 大巧不工 / 力斩千钧 / 绝招 · 四海无量
- 黯然销魂掌(甲 · 阴):心惊肉跳 / 拖泥带水 / 徘徊空谷 / 绝招 · 黯然销魂十七式

(12 格技能栏其余槽位同样「消耗未定义(0)」。)

**连带后果(如实记录):** 内力不足(`no_energy`)按钮状态**本轮已实现、但当前内容不可达**——
不是「推迟、未落地」:`skill_button.gd` 的调色板**已加第 6 个状态**「内力不足」(浅紫
`bg (0.72,0.62,0.92)`,raw BT.709 亮度 **0.6629**,与 ready / cooldown / phase_locked /
hp_gated / waiting 五个状态亮度差均 **≥ 0.10**,标签「内力不足」区别于「锁定」),`hud.gd`
的 disabled 推导已含 `no_energy` 项,并有对应单元测试 `tests/test_skill_button_no_energy.gd`
钉住亮度分离与 `cost > energy ⇒ no_energy`。它之所以在实战中**不可达**,是因为本轮**每一
个 `SkillData.cost == 0`**(`10_systems.md §1` 仍写「内力池只存不耗」)——这是预期,不是缺陷:
状态是真实的呈现机制,当养成那一轮定义了真实招式消耗后会自然激活。本轮就内力消耗落地
两件事:`SkillData.cost: int = 0`(schema 默认 0)与 `CostLabel` 渲染「无消耗」。

**内容缺口已关闭(2026-08-27,jinyong-spend-qi 轮)。** 上述 8 个玩家招式的内力
消耗已由本轮定义并写入本档 §1 招式表与 §7 消耗表(0/15/20/25/10/15/20/30);
`no_energy` 状态由此在实战中可达,并被新 playtest 场景
`qi_cost_blocks_cast_no_energy` 在真实对局中钉住。上文(2026-08-26 jinyong-hud
轮记录)原样保留为历史记录。

## 6. 属性效果文案:无内容缺口(2026-08-27,jinyong-clarity 轮记录)

五项属性的效果说明全部有既有定义,本轮**只呈现、不发明**:

- 文案源:`scripts/segments/creation.gd::_ATTR_DESCS`(逐字来自 `10_systems.md §1`
  属性表与 `40_progression.md §7` 公式表),捏人页直接复用,不新增任何字。
- 悟性 / 福缘在 `10_systems.md §1` 的战斗派生列为 `—`;其显示效果取**养成列**的
  定义(「学功法的速度」/「事件与奇遇」),与档案逐字一致,不算缺口。
- 结论:无内容缺口。若未来某属性确无既有定义,才按 §5 的纪律记缺口、不许就地发明。

镜像 §5 的纪律:内容文案必须以既有定义为准;有缺口才记,无缺口就明说「无缺口」。

## 7. 招式内力消耗(2026-08-27,jinyong-spend-qi 轮记录)

本轮把 `10_systems.md §1` 的「内力池只存不耗」改为「既存也耗」,并给 8 个玩家
招式定义真实内力消耗。**本表是唯一权威数值,代码必须逐字匹配。**

### 7.1 消耗表

| # | 招式 | 内力消耗 | 档位 |
|---|------|---------|------|
| 1 | 重剑无锋 | **0**(免费) | 基础招(见 7.3) |
| 2 | 大巧不工 | 15 | 轻 |
| 3 | 力斩千钧 | 20 | 中 |
| 4 | **绝招 · 四海无量** | 25 | 绝招 |
| 5 | 心惊肉跳 | 10 | 最轻 |
| 6 | 拖泥带水 | 15 | 轻 |
| 7 | 徘徊空谷 | 20 | 中 |
| 8 | **绝招 · 黯然销魂十七式** | 30 | 最贵绝招 |

阶梯:**轻招 10~15 < 中招 20 < 绝招 25/30**;十七式(30)是全作最贵的招式,
体现「重招贵、轻招便宜、绝招最贵」。

### 7.2 通关预算(为什么这些数安全)

`terminal_victory_8_12_rounds_hp_15_40` 的脚本施放链(按序):skill_1, skill_4,
skill_3, skill_8, skill_1, skill_3, skill_7, skill_4, skill_5, skill_1,
skill_7, skill_1。按本表累计:

| 施放 | 消耗 | 累计 | 施放前内力(上限 180) | 通过门槛? |
|------|------|------|----------------------|-----------|
| f620 skill_4 | 25 | 25 | 180 | 是 |
| f970 skill_3 | 20 | 45 | 155 | 是 |
| f1045 skill_8 | 30 | 75 | 135 | 是 |
| f1300 skill_1 | 0 | 75 | 105 | 免费 |
| f1560 skill_3 | 20 | 95 | 105 | 是 |
| f1820 skill_7 | 20 | 115 | 85 | 是 |
| f2080 skill_4 | 25 | 140 | 65 | 是 |
| f2340 skill_5 | 10 | 150 | 40 | 是 |
| f2600 skill_1 | 0 | 150 | 30 | 免费 |
| f2870 skill_7 | 20 | 170 | 30 | 是 |
| f2960 skill_1 | 0 | 170 | 10 | 免费 |

**总消耗 170 / 180,余量 10。** 每次施放都通过门槛(`energy == cost` 可放,仅
`energy < cost` 被挡),伤害/冷却/血量轨迹逐字节不变——消耗是真实约束
(乱打会空蓝),但打不破通关。

**实测确认(2026-08-27,终局闸门):** 上表是设计期推演。本轮 `5_compile` 的
playtest 闸门实测 `terminal_victory_8_12_rounds_hp_15_40` **6/6 全 PASS**
(全 54 场景零红、零 runtime error,编译 75/75 零错误)--预算成立,消耗表
无需回调;若未来数值重调把该场景打红,按回调规则**改本表消耗**,不改
气血 / 伤害 / 冷却 / 敌人。

### 7.3 重剑无锋为何免费(如实记录,不编数)

1. **既有钉**:`playtest/skill_button_effect_info.yaml` 第 42 行钉住
   `SkillButton1.cost_text == "无消耗"`,而既有 yaml 本轮不可改;唯一同时满足
   两个约束的解是重剑无锋消耗 0。
2. **内容理由**:它是玄铁剑法最朴素的招式(「重剑无锋,大巧不工」,冷却 1)。
   免费的两个真实理由:(a) **既有钉**——`playtest/skill_button_effect_info.yaml`
   第 42 行钉住 `SkillButton1.cost_text == "无消耗"`,既有 yaml 本轮不可改;
   (b) 它是这套剑法里最朴素的招式。注意:「玩家永不赤手空拳」的保底性质
   **不归重剑无锋**,而由**普攻**(消耗 0,内力归零时无条件可用,见
   `design/90_decisions.md`)保证,与重剑无锋是否免费无关。
3. 12 格技能栏其余槽位与全部敌方/进度招式保持 0(敌方能量为 0;进度招式的
   定价属后续轮次的杠杆)。

### 7.4 已记录缺口

内力池**一场战斗内不回复**——回复机制(调息、内功被动回蓝等)留待后续轮次,
本轮不发明。

## 8. 大地图节点进入内容 (2026-08-28, jinyong-map-events 轮)

`design/40_progression.md §5`(第 6 段 · 大地图)写着「点击相邻节点移动,**节点上
触发战斗、事件或门派设施**」——后半句此前没有实现:走到昆仑就看结局,进任何
节点什么都不发生。本轮把「事件」这一种做通,其余两种只留声明位。本节与
§5 的表**同一事实源**,两份文档必须一致。

### 8.1 六节点进入内容声明表(镜像 `scripts/data/map_data.gd`)

每节点声明三槽 `event` / `battle` / `facility`,槽形状
`{"status": "active"|"declared", "<type>_id": String}`:`active` = 已实现且生效,
`declared` = 仅声明槽位、本轮未实现。

| 节点 id | 名称 | event 槽 | battle 槽 | facility 槽 |
|---|---|---|---|---|
| `wuming_valley` | 无名谷 | `active` / `tomb_bed` | `declared` / `""` | `declared` / `""` |
| `luoyang` | 洛阳 | `active` / `merchant` | `declared` / `""` | `declared` / `""` |
| `wudang` | 武当 | `active` / `quanzhen_scripture` | `declared` / `""` | `active` / `wudang_meditation` |
| `xiangyang` | 襄阳 | `active` / `dragon_scrap` | `declared` / `""` | `declared` / `""` |
| `kunlun` | 昆仑 | `declared` / `""` | `declared` / `""` | `declared` / `""` |
| `shaolin` | 少林 | `active` / `night_rain` | `declared` / `""` | `active` / `shaolin_wooden_men` |

(行序 = `map_data.gd` 的 `NODES` 顺序;`wuming_valley` 的 `tomb_bed` 是 `active`
且诚实——它**只在经 return travel 到达时**触发,开机 / 读档不触发。2026-08-29
`jinyong-nodes(主线事件)` 轮把主线 event 槽从「全部 `declared`」转为「4/5 live」,
昆仑保持 `declared`(终点保证,见 §8.3 第 3 条);battle 槽六节点仍全 `declared`;
facility 槽本轮在少林 / 武当(两个门派)转 `active`,其余五节点仍 `declared`。)可观测语义:`declared_gap_types(id)` =
该节点所有 `status == "declared"` 的槽类型列表——「已声明未实现」因此是可断言
的事实,不只是文档里的一句话;`active_event_id(id)` = 仅当 event 槽
`status == "active"` 且 `EventData.def(event_id) != null` 时返回该 id,否则返回
`""`(绑定写错读作惰性,不崩)。

### 8.2 少林的绑定:`night_rain` 破庙夜雨(取自既有池,零新文案)

少林是洛阳的一条支线,此前**没有任何去的理由**。本轮给它的理由是**确定性绑定**
一行既有事件:在 `scripts/data/event_data.gd` 的 `EventData.TABLE` 16 行里,
`night_rain`(标题「破庙夜雨」)是**唯一一行老僧在庙里的场景**——

> `夜雨滂沱，破庙漏得厉害，\n老僧独坐，就着灯火补屋檐。`

(text 逐字引自 `event_data.gd`,全角标点与换行转义照源文件;它就是「去一座
寺院」在现有池子里最近的场景:到了,帮老僧补漏雨的屋檐,或就在檐下练剑。)
两个选项同样是既有数据:「帮工换宿」贴银两 −6 又涨根骨 +1,「檐下练剑」
练功 +2。本节**不新增任何文案**——「少林专属」指的是**机制专属**:只有少林的
节点进入会确定性地触发这一行;行本身仍留在共享池里,养成游历的无重复袋子照旧
可能抽到它(两条通道相互独立,互不读写 `flags["events_seen"]`)。若团队日后想
换一行,改的只是 `map_data.gd` 里 `event_id` 这个值,机制不动。

### 8.2b 主线四节点的绑定:`tomb_bed` / `merchant` / `quanzhen_scripture` / `dragon_scrap`(2026-08-29,取自既有池,零新文案)

承接 §8.2 少林的同一纪律:每个主线节点用**确定性绑定**(字面 `event_id`,不是
池抽取)挂上一行既有事件,文案逐字取自 `scripts/data/event_data.gd` 的
`EventData.TABLE`,零新文案。四条绑定按内容合理性选行,各自理由如下。

**无名谷 → `tomb_bed`(标题「古墓寒玉」)。** 无名谷是隐藏幽谷的起点节点;一行
写「荒山之中藏着一座古墓」——幽谷藏古墓,是全池与无名谷意象最近的场景。

> `荒山之中藏着一座古墓，\n石室中央横着一张寒玉床。`

(text 逐字引自 `event_data.gd`。)两个选项同样是既有数据:「卧床练气」涨内力 +2,
「床畔拾剑」得剑(`eq_sword_2`)。**触发时机**:无名谷是起点,`map.gd::_ready()`
落在 `start_node()`,而节点事件**只在经 travel 到达时**触发、开机 / 读档不触发——
故 `active` 诚实:它在**洛阳→无名谷的 return travel** 上触发,新追加场景
`map_node_event_mainline_return` 钉住「开机 `event_id == ""`」与「return 到达即开
`tomb_bed`」两面。

**洛阳 → `merchant`(标题「行商路过」)。** 洛阳是帝都级的通都大邑、三条边的枢纽;
一行写行商赶着满载刀剑的马车路过——正是交通枢纽该发生的事。

> `一位行商赶着马车路过，\n车上满载刀剑兵刃，正愁销路。`

两个选项:「买下长剑」贴银两 −20 又得长剑(`eq_sword_3`),「婉拒」无效果。
**选它的决定性技术理由**:它的 option A 是 **`silver` + `item`、没有 `attr` 效果**。
少林场景 `map_node_event_shaolin.yaml` 的时间线会**经过洛阳**才到少林,而少林那一
腿钉着 `attr_bone: changed`(差分)与 `last_effect_types == ["silver", "attr"]`
(尾块);洛阳的解析发生在少林**之前**,若洛阳绑定带 attr,就会**伪造或掩盖**少林的
`attr_bone` 差分。选一行无 attr 的绑定,使这两个既有钉保持其精确含义。

**武当 → `quanzhen_scripture`(标题「全真抄经」)。** 武当是道教门派之山;一行写
「全真宫外老道伏案抄经……递来一卷道德经」——全池唯一与道教宫观清修直接对应的场景,
武当最强贴合。

> `全真宫外老道伏案抄经，\n见你驻足，递来一卷道德经。`

两个选项:「随他抄经」涨智慧 +2,「求教剑理」贴银两 −5 又涨练功 +3。护线时间线在
武当解算 option A(智慧 +2),其 `tier >= 1 and tier <= 3` 的范围断言吸收这一增量。

**襄阳 → `dragon_scrap`(标题「降龙残谱」)。** 襄阳是《神雕侠侣》的高潮之城;一行
写书摊上一册残破掌谱、隐见「降龙」二字——侠义之城里捡到一册残谱,贴合该城气质。

> `书摊上一册残破掌谱，\n隐见「降龙」二字，纸色发黄。`

两个选项:「强记于心」涨练功 +4,「卖与书贾」得银两 +25。护线时间线解算 option A
(纯 practice +4)——**零属性耦合**,对 `attr_*` 类差分钉完全中性。

**四行共同的技术前提(为何不抽池)**:节点事件通道走 `MapData.active_event_id(id)`
的确定性绑定,没有无重复袋子;若改走 `EventLogic.draw_unseen_id`,它会读写
`profile.flags["events_seen"]`,与 §8.2 末尾所述「两条通道相互独立、互不读写
`flags["events_seen"]`」直接冲突,并让两条重排时间线变成 RNG 依赖。`EventLogic.apply_option_effects`
(节点事件走这条路)**零 RNG 调用**,故种子流逐字节不变、`event_travel_effects`
(19/19)与 `save_load_roundtrip`(14/14)按构造保持绿。

### 8.3 已声明未实现缺口(照 §5 的纪律:不许假装实现,也不许悄悄不提)

1. **battle 槽:已声明、未实现。** 6 个节点的 battle 槽全部是 `declared`、
   `battle_id` 保持空串;本轮没有任何「进节点触发战斗遭遇」的接线。
2. **facility(门派设施)槽:少林 / 武当已实现,其余五节点仍 `declared`。**
   少林绑定 `shaolin_wooden_men`(木人巷)、武当绑定 `wudang_meditation`(紫霄静修),
   两槽本轮转 `active`;其余五节点(wuming_valley / luoyang / xiangyang / kunlun /
   huashan)`facility_id` 仍空串,诚实报 `declared`。设施是玩家在节点上**主动选择、
   可重复使用**的进入内容(区别于到达即触发的 event),效果走既有系统(银两 / 属性),
   不发明新经济。
3. **主线 event 槽:本轮 4/5 live,昆仑保持 `declared`(终点保证,非上轮的护线惰性)。**
   无名谷 / 洛阳 / 武当 / 襄阳的 event 槽本轮转为 `active`(§8.1 表 / §8.2b 绑定),
   主线每一站在经 travel 到达时都触发内容。**唯昆仑仍 `declared` / `""`,理由已不是
   上轮的「护线预算不可改 yaml」,而是终点保证**:`map.gd::_travel()` 对终点节点先做
   到 ENDING 的路由(并置 `ended = true`),**先于** `_maybe_start_entry_event()`——
   在昆仑绑一行事件是**结构性死绑定**,永不触发;结局本身就是终点节点的内容。上轮
   的「主线 5 槽位惰性以保护不可修改的 spine_to_ending 时间线」这一理由,本轮由轮次
   所有者**有条件解除**:`playtest/spine_to_ending.yaml` 允许重排按键/帧预算(断言只加
   不减、先写理由再动 yaml),使主线站点的 event 可开可解、结局仍然走得到。理由与
   before/after 帧表见本节 2026-08-29 记录 (a)。battle 槽六节点仍全
   `declared`(见本条前第 1 条);facility 槽少林 / 武当已 live(见第 2 条),「打听」行动仍**未实现**(见第 6 条)。
4. **本轮不新编少林专属事件文案。** 「去的理由」用的是 §8.2 的既有池绑定。
   未来若要**新写**一段少林专属行(例如山门场景),那是**内容缺口**:
   必须先按本节风格记缺口,且新行只能写进 `event_data.gd` 的 `EventData.TABLE`
   ——绝不在 `map_data.gd` / `map.gd` 里就地编一段江湖轶事。
5. **节点事件重触发策略(记录,而非静默缺失):** 少林事件在**每次经 travel
   到达时**触发,本轮没有 per-profile 一次性标记(扩展 `PlayerProfile.flags`
   的持久化/清洗不在本轮范围)。即少林是一个**可重复访问的内容点**——这是
   有意记录的政策,不是漏做。
6. **「打听」行动:档案已声明、未实现。** `design/40_progression.md §2.2` 正面
   特质「江湖阅历」写着「大地图多一个行动:**打听**,揭示相邻节点的内容」——
   该行动本轮未实现、也在本轮范围之外;记在此处以免被读成遗忘。

**实测确认(2026-08-28,终局闸门):** 本节表格与 §8.2 绑定均为设计期
(doc-first)产物,终局实测后无需修订。本轮 `5_compile` 的 playtest 闸门
**55/55 场景全 PASS**:`map_node_event_shaolin` **18/18**(进少林即开
`night_rain`、两选项均可聚焦选中、选项效果落地、`entry_declared_gap_types`
在节点上可断言),护线 `spine_to_ending` **32/32**(主线 5 槽位惰性在真实
运行中成立,昆仑照常直达结局),`save_load_roundtrip` **14/14**(节点事件
只在 travel 到达时触发,存读档不复触发),`event_travel_effects` **19/19**
(共享 `EventLogic` 后 RNG 操作序未漂);编译 **77/77** 零错误。§8.3 六条
缺口**一条也未因实测而关闭**:实测绿证明的是「event 类型做通了、声明与
惰性行为如实」,battle / facility / 主线 event 槽仍是已声明未实现,待后续
轮次实现时才关闭。

---

## 9. `jinyong-nodes(主线事件)` 轮次记录 (2026-08-29)

本轮单一杠杆 = **主线节点事件接入**:给主线 5 节点接上事件(4 个 live 确定性绑定 +
昆仑终点非触发),把结局保持可达,统一地图页底部提示,并补上一轮没落地的常驻文本
排查记录。以下 (a)–(d) 是本轮改动的可核查记录。

**(a) 两处 yaml 重排(before/after 帧表)。** 本轮授权编辑的既有场景**仅此两文件**
(`spine_to_ending.yaml`、`map_node_event_shaolin.yaml`),其余 53 条不动(改动范围经
grep 核实:只有这两条含 `current_state == "MAP"` / 会走地图,故无第三条会因主线事件
变红)。**断言只加不减、不放宽;变的是帧/按键预算,不是每条场景所证明的性质。**

`spine_to_ending.yaml` — 地图腿(昆仑腿 0 次额外按键,洛阳/武当/襄阳各 1 次解析按键):

| 帧 | before | after |
|---|---|---|
| f400 | assert `current_state == "MAP"` … | **逐字节不变** |
| 420 | `move_right` | `move_right`(无名谷→洛阳) |
| 430 | `ui_accept` | `ui_accept`(到达洛阳,`merchant` EVENT 开) |
| 440 | `move_right` | **assert NEW**(`phase=="EVENT"`、`event_id=="merchant"`、`current_node_id=="luoyang"`) |
| 450 | `ui_accept` | `ui_accept`(解 option A → TRAVEL) |
| 460 | `move_right` | `move_right`(洛阳→武当) |
| 470 | `ui_accept` | `ui_accept`(到达武当,`quanzhen_scripture` EVENT 开) |
| 480 | `move_right` | **assert NEW**(武当) |
| 490 | `ui_accept` | `ui_accept`(解 option A → TRAVEL) |
| 500 | `move_right` | `move_right`(武当→襄阳) |
| 510 | `ui_accept` | `ui_accept`(到达襄阳,`dragon_scrap` EVENT 开) |
| 520 | **assert ENDING**(f520) | **assert NEW**(襄阳 + `events_resolved_count == 2`) |
| 530 | — | `ui_accept`(解 option A → TRAVEL) |
| 540 | — | `move_right`(襄阳→昆仑) |
| 550 | — | `ui_accept`(到达昆仑:终点路由先到 ENDING、`ended=true`,不触发事件) |
| 580 | — | **assert ENDING**(既有 6 行原样,f520→f580 只移帧不改字) |

既有 ENDING 断言行逐字节保留,仅 `at:` 由 520 移到 580(末断言 580 ≤ 2900 spine 上限、
≤ 2999 硬上限)。`description:` 里的「4 moves to 昆仑」旧述本轮改写(它若不改便成假)。
场景仍是六段连通证明:tutorial→transition→creation→sect→cultivation→map→ending。

`map_node_event_shaolin.yaml` — 洛阳去/返两站各插入 1 次解析按键,插入落在**每次聚焦
循环之前**(洛阳是三条边枢纽,EVENT 中被吞的 `move_right` 会**静默改变聚焦节点**):

| 帧 | before | after |
|---|---|---|
| f400 | assert MAP … | **逐字节不变** |
| 420 | `move_right` | `move_right`(无名谷→洛阳) |
| 430 | `ui_accept` | `ui_accept`(到达洛阳(去程),`merchant` EVENT 开) |
| 440 | `move_right` | **assert NEW**(`phase=="EVENT"`、`event_id=="merchant"`、`current_node_id=="luoyang"`、`HintLabel.visible==false`) |
| 450 | `move_right` | `ui_accept`(解 option A: silver+item,无 attr → TRAVEL) |
| 460 | `ui_accept` | **assert NEW**(`phase=="TRAVEL"`、`event_id==""`、`events_resolved_count == 1`(D2 新增阶梯钉)、少林 gap 槽 `has("battle") and has("facility")`) |
| 470 | `move_right` | `move_right`(洛阳→武当) |
| 480 | `assert` EVENT(少林,f470→此处下移) | `move_right`(武当→少林) |
| 490 | `move_right` | `ui_accept`(到达少林,`night_rain` EVENT 开) |
| 500 | `assert` event_focus… | **assert EXISTING**(原 f470 块:EVENT/night_rain/shaolin/Hint false) |
| 510 | `ui_accept` | `move_right`(event_focus→1) |
| 520 | `move_left` | **assert EXISTING**(原 f490 块:`event_focus==1`、`phase=="EVENT"`) |
| 530 | `assert` TRAVEL…(f530) | `move_left`(event_focus→0) |
| 540 | — | `ui_accept`(解 `night_rain` option A:silver −6,attr bone +1) |
| 560 | — | **assert EXISTING**(原 f530 块,一处重基线见 (b):`events_resolved_count == 2`) |
| 590 | `move_right` | `move_right`(少林→洛阳) |
| 600 | `ui_accept` | `ui_accept`(到达洛阳(返程),`merchant` **re-fire**,重复到访政策) |
| 610 | `assert` TRAVEL(洛阳,f600) | **assert NEW**(EVENT/merchant/luoyang) |
| 620 | — | `ui_accept`(再解 option A) |
| 630 | — | **assert NEW**(TRAVEL/`event_id==""`/`events_resolved_count == 3`) |
| 660 | — | **assert EXISTING**(原 f600 块:`current_node_id=="luoyang"`、TRAVEL、`event_id==""`,f600→f660 只移帧) |

`description:` 原称「主线节点保持惰性(声明槽、无事件)」——本轮改写(见 (a) 末)。
`last_effect_types == ["silver","attr"]` 与 `attr_bone: changed` 两钉在 f560 保持绿:
洛阳 option A 无 attr,且 `night_rain` 是 f560 前最后一次解算(既有邻居断言不受扰)。
末断言 660 ≤ 2999。✓

**(b) 单一重基线(本轮唯一一处既有断言的字面改动)。** 少林场景 f530 的
`MapScreen.events_resolved_count == 1` → `== 2`:洛阳在去程解析一次事件后,到少林的
`night_rain` 解算完,会话计数器已是 2。**辩护:它仍是精确相等(`==`),绝不用 `>=`,
故阶梯被钉得更紧、不是放松。** 为使改动纯加性,在洛阳去程解算后(f460)**新增**一个
`events_resolved_count == 1` 的阶梯钉,配对 `{==1 于洛阳, ==2 于少林}` 比原来单个
`== 1` 更严格地钉住「每解算一次 +1」的阶梯。这是被机器 superset 钉(见
`tests/test_playtest_contract_smoke.py`)记录的**唯一例外**;除此之外两场景的每条既有
断言行都必须在改后文件里存在(「只加不减」的机器证明)。

**(c) 地图页底部提示统一。** `scenes/segments/map.tscn` 的 `HintLabel.text` 原为
`左右选择 · 回车启程`(残缺版,只提左右),而面板 `map.gd::_render()` 打印
`左右/上下选择相邻去处，回车启程`。本轮把 `HintLabel.text` 改为与面板**逐字节相同**
(含全角逗号 `，`)的字符串,只看底部提示的玩家也能知道上下可选相邻去处。宽度安全:
统一串约 17 个 CJK 字 ≈ 272 px,落在 400 px 居中矩形内,几何不动。可断言性:
`HintLabel: visible, text` 已在 `playtest/_common.yaml` 白名单里,**无需改 surface 白名单**;
新追加的 `map_node_event_mainline_return.yaml` 在 boot 帧钉 `HintLabel.text ==
左右/上下选择相邻去处，回车启程`(「两处一文本」的 UI 文本契约)——这是**文本契约**,
不是数值断言,不违反「数值断言一律相对」的规矩。同提交内更新 `map.gd::
_apply_hint_visibility()` 引用旧提示串的两处 docstring/注释;可见性切换逻辑不动
(`phase != "EVENT"` 是按否定的白名单,天然适应任何未来相位)。

**(d) 重复到访 re-fire 政策扩展到主线 4 节点。** 上轮 §8.3 第 5 条记录的「少林事件在
每次经 travel 到达时触发、无 per-profile 一次性标记」政策,本轮原样适用于新转 `active`
的无名谷 / 洛阳 / 武当 / 襄阳——它们是**可重复访问的内容点**,option-A 效果每次到达
重新施加(洛阳返程在少林场景里 re-fire 正是此政策的体现,并被 f600–f630 钉住,而不再
是静默吃掉一次按键)。**正因效果可重复施加、且绝对值随 RNG/存档漂移,本轮新增的每条
数值断言一律差分/相对**(`attr_bone`/`attr_wisdom`/`attr_inner`: changed、`events_resolved_count`
阶梯 `==1/==2/==3`、`tier >= 1 and <= 3` 范围),绝不钉绝对游戏值。

**常驻文本排查(本轮补记,详见 `final/delivery_notes.md`):** 排查 `scenes/segments/
map.tscn` 的 MAP 段 TRAVEL↔EVENT 切换——该段恰有两个常驻 Label:`BodyLabel`(每相位
由 `_render()` 完整重绘,含 EVENT 分支)与 `HintLabel`(由 `_apply_hint_visibility()`
以 `phase != "EVENT"` 切换可见)。两处都在 EVENT→TRAVEL 后让位。**结论:查过,只此
一处**(上一轮唯一「相位切换后未让位的常驻文本」即 HintLabel 的残缺旧串,已在本轮 (c)
统一并被新场景钉住)。其它段的相位切换在本轮单一杠杆之外。

**本轮结果(诚实边界):** 5/5 主线站有内容——4 个 live 绑定 + 昆仑经论证的终点非触发;
结局仍可达(routing-first + 重排后时间线,既有 ENDING 断言逐行存活)。实测 PASS 计数
属下游 `5_compile`/`5_test` 闸门产物,本轮不预设。

**实测确认(2026-08-29,终局闸门):** 本节 (a)–(d) 与 §8.1/§8.2b/§8.3 表格均为设计期
(doc-first)推演,终局实测后无需修订。本轮 `5_compile` 的 `playtest_summary.md` 实测
**57/57 场景全 PASS**(硬闸门过、零 runtime error、断言失败 0/57):重排后的
`spine_to_ending` **42/42**(3 个事件块插入后 ENDING 块 f580 逐行存活,「六段连着 +
走得到结局」在真实运行中成立),`map_node_event_shaolin` **32/32**(唯一重基线
`events_resolved_count == 2` 与新增 `== 1` 阶梯钉成立,`attr_bone` 差分钉未受洛阳
去程/返程 merchant 事件影响),新场景 `map_node_event_mainline_east` **23/23** /
`map_node_event_mainline_return` **20/20**(四绑定逐一被钉、无名谷不在 boot 触发、
`tomb_bed` 返程触发并解算、统一提示串被钉);既有回归网零红:`save_load_roundtrip`
**14/14**(节点事件只在 travel 到达时触发,存读档不复触发)、`event_travel_effects`
**19/19**、`cultivation_month_cycle_and_deck_bookkeeping` **17/17**、
`cultivation_changes_combat` **30/30**(袋子与 RNG 流未被节点通道触碰,按构造成立);
编译 **77/77** 零错误;视觉闸门 blind(`endpoint_unreachable`,人眼代判,57 场景 228
帧,本轮零新几何/零新调色板)。§8.3 缺口未因实测而关闭:battle / facility 仍已声明
未实现,昆仑 event 槽仍为终点保证的有意 `declared`,三者待后续轮次实现时才关闭。

---

## 10. 门派设施(facility)内容类型 (2026-08-29,`jinyong-facility` 轮)

上节末句「facility 仍已声明未实现……待后续轮次实现时才关闭」预告的那一后续轮次
就是本节。本节把「门派设施」这一内容类型**定义并落地**:它填上 §8.1 六节点表里
`facility` 槽此前**六个节点全是 `declared` / `""`** 的结构性缺口——本轮把其中两个
(少林 / 武当,它们本来就是门派)从 `declared` 转 `active`,其余五节点(wuming_valley /
luoyang / xiangyang / kunlun / huashan)仍诚实保持 `declared` / `""`(见 §8.1 表与
§8.3 第 2 条,同一事实源)。「还剩什么没做」以 `MapData.declared_gap_types(id)` 为可
断言的事实源,不靠本节的文字。

### 10.1 定义性区别:event 被动触发、facility 主动进入

「门派设施」若做不出与 event 的玩家可感区别,它就只是第二个 event。区别钉死如下:

- **event = 到达即触发的被动内容。** `map.gd::_travel()` 在经 travel 到达节点时自动
  调 `_maybe_start_entry_event()`,玩家无需选择。
- **facility = 玩家主动选择进入、可重复使用的主动内容。** 它由玩家在 TRAVEL 相位按
  专门的 **`use_facility` 键**(绑 `F`)才进入 `FACILITY` 相位;在 FACILITY 里按
  `ui_accept` 使用一次、按 `move_down` / `move_left` 离开,下一次到访可再用。

### 10.2 「到达永不入设施」不变量(定义性,非冗余)

**facility 从不接入到达分派** —— 它绝不写进 `_maybe_start_entry_event()` /
`_maybe_start_entry_battle()`。这是「facility 不是第二个 event」的全部所以然,也是
`playtest/spine_to_ending.yaml`(武当一腿)按构造对它无感的理由:设施不自动触发、
不消费到达输入,护线到达帧只解算 event、继续行走。

### 10.3 两条数据行(文案唯一源 `scripts/data/facility_data.gd`)

设施文案一律进 `FacilityData.TABLE`(镜像 `EventData.TABLE`,零 inline 于
`map_data.gd` / `map.gd`,见 §10.5 守卫)。本轮两行,效果只走**既有 EventLogic 封闭
域**(silver / attr / practice / none),不发明新经济:

| facility id | 节点 | 标题 | 每次效果 |
|---|---|---|---|
| `shaolin_wooden_men` | `shaolin` 少林 | 木人巷 | 银两 −8 → 根骨 +2(`bone`) |
| `wudang_meditation` | `wudang` 武当 | 紫霄静修 | 银两 −8 → 内力 +2(`inner`) |

银两消耗即门槛(cost-gated):`profile.silver < cost` 时拒绝使用、不加计数、效果不
落地(「银两不足」)。效果经由 `EventLogic.apply_option_effects` 落到既有
`PlayerProfile` 的 `silver` / `add_attr`——设施是既有系统的**一个新入口**,不是一套
并行玩法。数值「够用即止」,非精调(第 5 阶段)。

### 10.4 可重复但有界(复用上限 = 第 5 阶段待决数值)

本轮以**既有银两**为唯一复用门槛(每次付费、付得起就能再用)——引入零新资源 / 新
货币 / 新经济。但**复用的上界尚未定死**:每访一次(once-per-visit)/ 每周期一次
(once-per-period)/ 纯银两限(pure-silver-limit)三者取哪一个是**第 5 阶段数值精调的
待决项**,已记入 `design/90_decisions.md` 裁定 (e)。**后续轮次不得把当前的银两门槛
读成已定的复用上限** —— 这是本条必须显式写 PENDING 的原因。

### 10.5 可观测性与守卫(本轮立的常驻观察点)

- **永久负向断言**(`playtest/facility_use_reusable.yaml`,第 58 个场景):到达半场
  钉 `phase == "EVENT" and phase != "FACILITY"`、`facility_id == ""`、
  `facility_use_count == 0`(且在 event 解算回 TRAVEL 后再断一次 `facility_use_count
  == 0`,防解算夹带使用)——与选择半场(主动进入 → 用一次 → 离开 → 再访再用)同处
  一景,两面是同一事实的正反面。它永久防止未来某一轮把 facility 悄悄接进到达分派。
- **防删钉**(`tests/test_playtest_contract_smoke.py
  ::test_facility_use_reusable_surface_contract`):要求该场景文件文本里
  `phase != "FACILITY"` 与 `facility_use_count == 0` 两行都在,否则红——常驻断言本身
  也可删,故再钉一层。
- **§433 文案位置守卫**(`tests/test_facility_copy_location.py`,本轮**已采纳**):prose-
  scoped 静态 pytest,扫 `map_data.gd` / `map.gd` 里 ≥4 CJK 的新 inline 文案(白名单
  含设施 chrome),使「设施文案只能住在其数据模块」从一句文档规矩变成会拦人的门。
- **红值记录**:本场景在 facility 仍 `declared`(flip 未落)时实测 **34/47**:到达半场
  全绿、选择半场全红(`phase` 读 `TRAVEL`、`facility_id` 读 `""`、`facility_use_count`
  读 `0`)。flip 后 `facility_use_reusable` 实测 **47/47** 全绿。红值逐条见
  `final/delivery_notes_facility.md`。红转绿是一次性证据(转绿即消失),承载该性质向
  前的是上条的永久负向断言(见 `design/90_decisions.md` 裁定 (d))。

