# Decisions

## Out of scope

被考虑过并**否决**的想法,连同否决理由。这一节的作用是阻止后续 run
把已经砍掉的东西加回来。

| 想法 | 否决理由 |
|---|---|
| 实时战斗(real-time-with-pause) | 格子、移动力、范围形状全是回合制的词汇;实时跑它等于没有决策空间。2026-08-22 改为回合制。 |
| 五场循序单挑(华山论剑式擂台) | 数值上更好平衡,但本作是同人 / 乱入 / 大乱斗,同场混战才是题旨。改为同场 + 大幅增强杨过。 |
| 武学熟练度(标量) | 标量要调曲线、无法断言。改用**前置依赖 + 发挥度查表**,前置齐没齐是可判定的事实。 |
| 属性相克(阴克阳等) | 是独立于发挥度的一层复杂度。当前只做同属性前置加成;等回合制战斗跑顺再议。 |
| 3/3 全同属性才有奖励(原提案) | 内容底线会炸(4 属性 × 4 级 × 10 门类)。改为按同属性门数递增 ×1.1/×1.2/×1.3,第一门就有正反馈。 |
| 爪法 / 腿法 / 鞭法单列门类 | 爪、腿并入拳掌;鞭暂不设。门类已有 10 类,再拆只增加内容底线,不增加决策。 |
| 太吾式连续发挥度(相性 / 境界 / 熟练共同决定) | 不透明,玩家靠猜,也写不了断言。简化为查表。 |
| 穿越用一场必败战表现 | `00_overview.md` 要求教程「赢得漂亮——它是被夺走的那个东西」;紧接一场必败等于把刚给的东西当场作废两次。改为文本过场。 |
| 好感度系统 | 需要一整套角色关系与衰减,而本作角色是「同名平行变体」,谁对谁的好感本身就没有连续性。2026-08-23 砍。 |
| 门派势力关系 | 要求门派之间有可演化的状态;当前门派只是开局分支,没有状态可演化。 |
| 大地图用格子移动 / 自由移动 | 格子是战斗的词汇,放到江湖图上会让玩家以为能打;自由移动要碰撞与寻路,买不到相应的玩法。改为节点移动。 |
| 同伴可养成(有自己的属性成长与功法阶梯) | 第 4 段的复杂度直接翻三倍——三份属性、三条阶梯、三套装备——而第 4 段本身还没落地。同伴要么是内容,要么是另一个养成游戏,不能两头都要。定为**内容**:可招募,不能捏、不能练、不吃机缘。 |
| 杀破狼只有「不能带同伴」+ 大额返点,不自带任何数值 | 补不回**行动经济**:1 个单位对 3 个单位是三倍行动差,而行动差压倒数值,多给点数没用。改为机制打底 + 随在场敌人数缩放的数值补偿,返点从 12 降到 6。 |
| 非主修内功完全不生效 | 内功自成一类且家家都教,换过门派的人会攒下好几门;只算主修那一门的话,广度路线攒的内功全是废纸,那不是「把外功摊薄」而是白练。改为两层:属性加成学了就有,内力与特征主修才发挥。 |
| 机缘三张牌纯随机(不保证类别) | 迟早发出「三张都用不上」的一手,那时玩家不是在选择,是在认命。改为三个类别各一张——选的是方向,随机的是该方向上具体哪一张。 |
| 不带种子的随机 | playtest 跑两次抽到不同的牌,断言时绿时红,而「偶尔红一次」是最难查的失败模式。种子开档时生成、写进存档,所有抽牌与掷骰走同一序列。 |
| 给神功卡单独设平衡规则 | 不需要:前置级联已经处理了——白送的甲级功法前置不齐,发挥度 0.6~0.7,得到的是一件用不好的神兵。一条新内容,零条新规则。 |
| 先天特质给数值加成(伤害 +10%、先攻 +8 之类) | 那只是把属性换个地方写,玩家做的还是同一道算术题,捏人退化成分配分数。特质改为一律给**机制**——改变你能做什么,不是你的数字多大。 |
| 缺陷数量设上限(最多 2 个) | 这条只在缺陷是数字时才需要。缺陷一旦是机制,堆缺陷本身就有代价(不能用绝招、残血失控、没有内功、学不了轻功),不需要外加一条规则去管它。 |
| 换门派零代价(纯收集起手功法) | 没有代价的话最优解永远是每年都换,把三家起手功法收集齐——那不是取舍是收集。 |
| 换门派把该门类打回丁级重来 | 与 `10_systems.md` §3「级联按**门类**计算」直接打架:A 门派的丁级剑法与 B 门派的丙级剑法本来就该接得上。代价改挂在时间上——三年只有三级,推得动一条外功阶梯;换门类等于两条都推不完。 |
| 人物等级 / 经验条 | 会和武学等级抢同一个位置——玩家看到两条进度条就要问「该练哪条」,而本作的答案只有一条。且等级一旦存在,数值设计会围着它转(每级 +X 气血),`40_progression.md` §6 的属性派生公式立刻变成两套并行的东西。 |
| 养成一周分多时段(侠客风云传式三时段) | 本阶段先让 48 次决策跑通;时段细分随时能加,且加了不推翻任何结构。不是否决,是延后。 |
| 捏人界面「键盘光标 + 鼠标按钮」两套 UI 并存 | 上一轮把「键盘降级为快捷方式」实现成键盘 `▶` 光标列表与鼠标按钮组并列——那正是用户报的「双 UI」本身。主交互只能有一套:按钮是唯一可见表面,键盘退化为纯快捷方式(不占用方向键语义)。 |
| 捏人屏「整组居中」用 CenterContainer 包裹或固定宽内容列(~280 px) | 前者新增节点,撞 13 条被 playtest 钉死的节点路径;后者列内墨迹仍然偏右,「居中」断言只好量**列框**而非墨迹--上一轮刚杀掉的「容器矩形 ≠ 墨迹」谎言换一层复活。行级 `SHRINK_CENTER`(`size_flags_horizontal=4`)让墨迹与框重合,零新节点零改名。2026-08-25 否决。 |
| 血条换节点类型(`TextureProgressBar` 九宫格贴图 / 手写 `_draw()` 自绘) | 前者要重画美术(本轮明令禁止);两者都换掉 `ProgressBar` + `EmptyCap` + `StyleBoxFlat` 的既定结构,playtest 几何断言与 `tests/test_health_bar.gd` 全挂在它上面。尺寸+对比三件套(条高 12 / 空尾 10 / 光环 6)已让视觉闸门 Q5 在 960×704 原生帧全过,证明不需要换类型。2026-08-25 否决。 |
| 用悬停 / 鼠标查询(`gui_get_hovered_control` 等)做立绘可见性判定 | 悬停只证明**鼠标可达**,不证明像素真的画上了帧;纯可见性测试也不该依赖鼠标。改为绘制序比较(树序 + `z_index` / `show_behind_parent` / `CanvasLayer`),且只看矩形相交的 Control。2026-08-25 否决。 |
| 探针没跑成就按「猜测的失败层」直接修 UX-01(比如直接改 `clamp_sprite_offset`) | 违反「先查明再修,不许猜」:探针一个实测值都没落下(builder HTTP 500 ×9,随后是本轮自身的 `Canvas` 编译错),此时任何修复都是在修一个没人观察过的缺陷。修集保持为空,判读等修后闸门——结果六单位 10/10 全可见,「缺陷」本来就不存在。2026-08-25 记录。 |
| 移动提示放顶栏状态行 / 悬停 tooltip | 顶栏是受保护几何(TopStrip 及其表面断言不许动);tooltip 依赖鼠标,又表达不了「随状态失效的承诺」。提示必须坐在动作发生的地方(移动落点,玩家脚下),且文案在锁定移动的**同一个转移**里换掉——留着一条已经不成立的承诺,就是捏人屏「右键确认」那次的错误换一层复活。2026-08-25 否决。 |
| 在仓库里改写视觉闸门 Q5 的问题文本(把「空尾」条件限定为 HP<max) | 闸门问题文本活在 godot-builder 侧车 `/vision` 配置里,**不在本仓库**——在仓库里改一句闸门从没问过的问题,只会让两边漂得更远。诚实的处理是把仓库记录的 Q5 **描述**对齐到真实闸门状态:闸门未裁决(4/47 全满血、零受伤帧),分类保持 PENDING,`ready_for_deploy` 保持 false;「19/28」与「主端点已修复」均无盘上依据,一律删除。2026-08-26 记录(`align_vision_gate_wording_v2`)。 |
| 在 `final/verify_report.json` 里维护交付裁定(all_goals_met / ready_for_deploy / verified_subtasks 等) | 管线的 `repo_apply` 明确忽略 `final/*`,这份文件永远不会被任何一次运行刷新,而它携带的是 jinyong-events 那一轮(t_impl 卡)的旧裁定——视觉闸门 IncompleteRead 只裁了 4/47 个场景、terminal_victory 5/6、47 个场景——之后一直以「当前交付裁定」的面目留在仓库里,误导了 jinyong-hud 的待办收尾复查。改为指针墓碑(pointer note):不携带任何裁定字段,只声明「不代表当前交付」;唯一权威的闸门证据是流水线步骤产物,从不是 `final/` 下的仓库文件。2026-08-27 否决。 |

## Open questions

已**决定要做**但**尚未设计**的部分。写在这里是为了让后续 run 既知道它们存在,
又不会擅自开工。

> 2026-08-23:原先列在这里的 11 个问题**全部已定**,答案写在
> `40_progression.md`(第 2~6 段的内容、属性派生公式、存档格式、技能栏容量、
> 乐器门类规则)。它们不再是待决问题,而是**已决定、未实现**——所以搬到了
> 那一层,不是留在这里。

| 段落 / 议题 | 待决问题 | 谁来定 |
|---|---|---|
| 第 4 段 · 养成 | 属性成长的具体查表数值(每次修习 +1~3 的分布) | 架构 |
| 第 5 段 · 活动与战斗 | 首批事件的数量与内容 | 用户 + 架构 |
| 第 6 段 · 大地图 | 江湖图有哪些节点、主线串哪几个 | 用户 + 架构 |
| 全局 · 结局 | 结局按什么分级、分几档、各档的文案 | 用户 |

2026-08-27 `jinyong-spend-qi fix`:普攻消耗 0,是玩家的保底动作;内力归零时玩家仍能普攻。给普攻定价属于重大规则改动,后续轮次不得顺手为之,要改先在此立决定。

2026-08-28 `jinyong-map-events`:**事件解算逻辑从 `scripts/segments/cultivation.gd` 迁入共享纯静态模块 `scripts/data/event_logic.gd`(`class_name EventLogic`)**。被迁移的三个核心:

- `_draw_event() -> String`(游历抽事件)
- `_apply_event_option(opt_index: int) -> void` 中的 5 类效果循环(`for eff in opt.effects: match ...`)
- `_add_practice(amount: int) -> void`(先未精通的功法 + 杀破狼 `TraitEffects.pojun_practice` 钩子)

对应三个静态函数:`EventLogic.draw_unseen_id(profile: PlayerProfile, rng: RandomNumberGenerator) -> String`、`EventLogic.apply_option_effects(profile: PlayerProfile, opt: EventData.EventOption) -> void`、`EventLogic.add_practice(profile: PlayerProfile, amount: int) -> void`。

**逐字不变的约束**:每抽**恰好一次** `rng.randi_range(0, pool.size() - 1)`(RNG 操作序不变 → 种子流不变 → 既有断言不漂移);效果仍限 5 类 `silver / attr / item / practice / none`。

**所有权切分契约**:cultivation 保留 `_sync_surface()`、`flags["events_seen"]` 已见标记、phase / `event_id` 管理;EventLogic 只拥有纯抽 / 纯应用 / 纯加修习核心,不持有实例状态、无场景引用。

动因(doc-first 纪录:"如果解算逻辑需要挪位置或共享,先改设计档案说明理由,再动代码"):大地图节点内容轮(map 段)要复用既有解算路径而非另起一套并行系统;共享实例耦合代码而不回归 cultivation 既有钉住的测试,唯一办法是**一次性把纯核心搬进共享模块**,故先记档再动代码。

2026-08-29 `jinyong-nodes(主线事件)`:**主线节点事件全部走确定性字面 `event_id` 绑定,不走池抽取;昆仑保持 `declared`;`playtest/` yaml 编辑例外仅两文件;单一重基线。**

- **确定性字面 event_id 绑定(不用池抽取)**:主线五节点接事件一律用 `MapData.active_event_id(id)` 的字面绑定,不调 `EventLogic.draw_unseen_id`。理由:`draw_unseen_id` 会读写 `profile.flags["events_seen"]`,把「养成游历无重复袋子」与「大地图节点事件」两条通道耦合——而 `design/20_content.md §8.2` 明写两条通道相互独立、互不读写 `flags["events_seen"]`;且抽池会让本轮重排的两条固定帧时间线(spine、shaolin)变成 RNG 依赖,按键预算不再确定。绑定写错读作惰性(`def(event_id) == null` 即返回 `""`),不崩。
- **4/5 live + 昆仑终点保证**:无名谷/洛阳/武当/襄阳转 `active`(绑定 `tomb_bed`/`merchant`/`quanzhen_scripture`/`dragon_scrap`,逐字取自 `event_data.gd`,零新文案);**昆仑 `event` 槽保持 `declared` / `""`**——`_travel()` 对终点节点先路由到 ENDING(`ended = true`)、运行在 `_maybe_start_entry_event()` 之前,昆仑绑事件是结构性死路,结局本身就是终点的内容;既有机器钉 `active_event_id("kunlun") == ""` 因此保持绿、保持不动(这是本轮终点规则的可读形式)。
- **yaml 编辑例外仅两文件**:解除「既有 yaml 不许改」的限制**只**给 `playtest/spine_to_ending.yaml` 与 `playtest/map_node_event_shaolin.yaml`(两条经 grep 核实会走地图、因而被主线 live 事件改变按键预算的场景),其余 53 条既有场景一律不动。条件:先在 `design/` 写理由(本卡)再动 yaml、断言只加不减不放宽、改的是帧/按键预算而非每条场景所证明的性质;两条改完仍全绿且 `spine_to_ending` 仍是「六段连着、走得到结局」的证明。
- **单一重基线**:少林场景 `MapScreen.events_resolved_count == 1` → `== 2`(洛阳去程先解一次事件)。它是本轮唯一一处既有断言的字面改动,辩护 = 仍为**精确相等**(绝不用 `>=`),并在洛阳去程解算后**新增** `== 1` 阶梯钉,使配对 `{==1 于洛阳, ==2 于少林}` 比原单个 `== 1` 钉得更紧(纯加性精神)。此例外由 `tests/test_playtest_contract_smoke.py` 的 superset 钉作为唯一记录项机器化。
- **提示统一(顺带补上一轮不完整)**:地图页底部 `HintLabel.text` 由残缺的「左右选择 · 回车启程」改为与面板逐字节相同的「左右/上下选择相邻去处，回车启程」(全角逗号照抄),`HintLabel: visible, text` 已在白名单,无需改 surface。
- **常驻文本排查落产出物**:上轮「排查同段相位切换后未让位的常驻文本」这条要求没落到任何产出物;本轮补上并记入 `final/delivery_notes.md`——MAP 段仅 `BodyLabel`/`HintLabel` 两处常驻 Label,均在 EVENT→TRAVEL 后让位,结论「查过,只此一处」。

一次一杠杆:本轮只做主线节点事件接入,不调数值、不改战斗、不动养成的月循环、不新增美术资产、不写新事件文案(超出 16 行池的一律记缺口)。

## 武虾:本作的一切角色都是虾(2026-08-28,项目所有者裁定)

**规则:游戏中出现的每一个角色都是一只虾——现有的六个,以及此后新增的任何一个。**
这不是一次美术替换,是**世界观约束**。任何一轮若要加入一个非虾的角色,必须先改这一条,
而不是先画那张图。

### 为什么

- **美术门槛塌了一个数量级。** 一只画得糙的虾**仍然是一只虾**;一个画得糙的郭靖是一张烂图。
  虾的剪影自带辨识度,靠体色与道具即可区分角色。对一个 agent 驱动的流水线,
  「很难做坏」比「可以做好」值钱得多。
- **它穿过语言墙。** 本作 UI 全中文,这对非中文读者是硬壁垒。视觉笑话不需要翻译——
  「Kung Fu Shrimp」不经解释即可读懂,而 412 条中文字符串做不到这一点。
- **它清掉 IP 暴露面。** 现有资源里有 `yang_guo.png`。五绝是**称号**(东邪/西毒/南帝/北丐/中神通),
  换成虾之后称号原样可用,而人名不必出现在一个公开部署的构建里。

### 冷面原则(同等重要,且更容易被下一轮做反)

**只有角色形象与称号是虾;文案一个字不动。** 事件、功法、招式、地名维持严肃武侠散文。
一只虾一本正经地说「今夜雨大,城中人心浮动」,比一百个谐音梗有效——**反差是笑点,
谐音的重复不是**。这条同时是成本判断:全面搞笑要重写 183 条内容字符串(事件/功法/卡牌/特质),
那是另一个项目;冷面只动美术与称号。

### 现有名册的映射(称号即是虾,无需改名)

| 现资源 | 归属 | 备注 |
|---|---|---|
| `west_poison.png` 西毒 | 皮皮虾(雀尾螳螂虾) | 其螯击速度约 23 m/s,单位体重出拳最狠的动物——西毒配它是**本色**,不是硬凑 |
| `north_beggar.png` 北丐 | 龙虾 | 降龙十八掌由一只龙虾使出 |
| `east_heretic.png` 东邪 / `south_emperor.png` 南帝 / `central_divine.png` 中神通 | 待定虾种 | 称号原样保留 |
| `yang_guo.png` | 待定虾种 + 改称号 | 唯一带人名的资源,借此机会去名化 |

### 时机(硬约束)

**不得在立绘几何轮次进行中替换。** interaction-defects 轮正在校准 96x128 立绘的名牌位置、
地面标记、墨迹矩形与命中判定;此时换图等于在别人量尺寸时换零件。替换排在 defect B
落地、命中矩形钉死之后,新资源直接套进已验证的几何契约。

### 守卫

「记得所有角色都是虾」是一条**没有守卫就必然漂移**的规则,与双语文案同类。
`assets/characters/roster.json` 声明每个立绘对应的虾种;
`tests/test_shrimp_roster.py`(pytest,受 `5_test` 闸门执行)使 `assets/characters/*.png`
与该名册**互为充要**:多一张没登记的图,或名册里有一条没有图,都红。
它不能判断一张图画的是不是虾——**它强制的是「新增角色时必须在名册里写下这是哪种虾」**,
把一条要靠记性的规则变成一道会拦人的门。

## 战斗命中的 5 步优先级规则(2026-08-28,interaction-defects)

左键点击按以下顺序解算(全文见 `30_presentation.md`):1) 脚格有敌人 → 攻击;
2) **in-reach** 敌人的画出立绘矩形(`portrait_ink_rect`,每帧按钳制后实际墨迹)
包含点击点 → 攻击最近者;3) 移动高亮中的可达空格 → 移动;4) out-of-reach 敌人
矩形 → 选中(不静默移动);5) 自己脚格无操作,否则移动。

**被否的 grid→rect→move 规则**(先点中格子找单位 → 再按立绘矩形 → 都没有才移动)
实测三场景全红:`click_move_undo_right` **10→6**、`click_move_commit_lock` **9→1**、
`move_target_affordance` **18→11**(`click_move_to_tile` 10→10 只是侥幸:第二次点击
x=544 恰在矩形右缘外)。原因:顶行王重阳被 `BOARD_TOP_MARGIN_Y=92` 钳制的立绘画在
y∈[92,220]、x∈[432,528],盖住 (7,2) 与 (7,3) 两格,三个场景从 (7,5) 上移的点击
(480,160) 落在他身体里,被解析成「攻击王重阳」(超射程,静默失败)而不是移动。
**结论:空格子不能仅仅因为背后站着一个高的就点不到。** 第 2 步因此只限 in-reach
敌人;验收网为七条既有场景,保持全绿,不为新规则放水。

## P0 根因:menu.tscn 的 SegmentHost 全屏 STOP(2026-08-28,interaction-defects)

玩家报「左键移动完全失灵」而 headless playtest 57/57 全绿。真实 X11 窗口 + xdotool
实测定位:`scenes/menu.tscn` 的 `SegmentHost`(铺满全屏的 Control)漏写
`mouse_filter = 2`,Godot 默认 STOP,整局压在棋盘上方,吞掉所有不落在 Button 上的
按键。修复落地 `42637b7`(前后实测:`raw=3 handled=0 EATER SegmentHost(filter=0)`
→ `raw=3 handled=1 EATERS none`),玩家在 web + 桌面双端确认恢复。

**57 绿的套件为什么看不见它(两个 dodge 原因):**
1. 契约的默认 `scene:` 是 `res://scenes/main.tscn`,而游戏 `run/main_scene` 是
   `res://scenes/menu.tscn`——每条场景都在给修好的孪生场景打分;
2. `clicks:` 走 `Input.parse_input_event()` 注入,**永不进入 GUI 阶段**——STOP 控件
   吃事件的那个阶段根本没被执行到。

已落的两道 pytest 守卫(`test_every_full_rect_host_is_click_through`、
`test_the_contract_boot_scene_is_recorded_against_the_games_own`)钉住这一类;
`_common.yaml` 头注释记录 boot-scene 分歧。双层覆盖网(Layer 1 差分观测量、
Layer 2 窗口化 X11 闸门)使同类缺陷下一次在服务器上变红。诚实边界:web 浏览器桥接
服务器够不着,manual-only;skipped 的闸门运行记 OPEN 覆盖缺口,永不为绿。

## 地图提示一屏一条(2026-08-28,interaction-defects)

上一轮(jinyong-nodes)把页脚 `HintLabel` 与 `map.gd::_render()` TRAVEL 面板尾行
统一成逐字节相同的同一句,结果同一屏把「左右/上下选择相邻去处，回车启程」印了两遍
——「统一」合成了「重复」。本轮裁定:**保留页脚 `HintLabel`,删面板尾行**(面板留
「当前:%s」)。理由:页脚是地图的持久操作提示、已被 `map_hint_single.yaml` 钉住、
EVENT 隐藏逻辑(`_apply_hint_visibility`)挂在它上面,删面板行的爆炸半径最小;
「一屏一条,一条提示」——不许用「两处都留着但内容一致」算统一。上一轮统一方案的
本条勘误按规矩以新行记录,不改旧行。

## 棋盘不再受视口约束(2026-08-28,项目所有者裁定)

**棋盘尺寸不再受视口约束。** 此前「棋盘 == 视口」(15×11×64 = 960×704)是一条
偶然等式,不是定律,却让「移动相机」看起来不可能,逼出了 `clamp_sprite_offset` 这个
把立绘挪离自家格的补丁。本轮拆开:视口是显示尺寸,棋盘是内容尺寸
(`GRID_*×TILE_SIZE`);**大场景需要大地图**,内容轮不必再设计到 15×11
(见 `00_roadmap.md`)。相机的无空白范围、跟随行为全部从 `GridManager` 符号派生
(`scripts/camera_follower.gd`),`GRID_HEIGHT` 11→20 只改代入数、零行相机逻辑改动。

**「整盘看不全」是正常取景,不是缺陷。** 相机把行动单位框进 HUD 顶栏与招式栏之间
的未遮挡带时,棋盘南端会暂时落在招式栏后——这是相机拥有可见性之后的常态,不再是
一张要修的缺陷图。小地图 / 屏外单位边缘指示记为 UX-09(本轮不做)。

**UX-01b 前一次的 CLOSED 是钳位买来的,本轮把它拆掉。** UX-01b 曾因引入
`clamp_sprite_offset`(顶边距 `BOARD_TOP_MARGIN_Y=92`)而 CLOSED;那一次关闭靠的是
把立绘推出自家格来骗过 `portrait_covered_frac < 0.25`。本轮删除钳位、由相机拥有
可见性,并新增对位 pin(`playtest/portrait_grid_alignment.yaml`)让「立绘站在自己
格子上」成为可断言事实——这才算真正修好(证据路径:`scripts/camera_follower.gd`、
`playtest/portrait_grid_alignment.yaml`、改写后的 `playtest/portrait_visibility.yaml`)。

**「今天数值相同」不是等价的理由。** 一个替代方案只在它本该处理的条件**尚未发生**
时才成立,那它就不是替代方案——正如旧 `health_bar.gd` 用 `get_final_transform()`
做世界→屏幕,在缩放 1、相机不动时数值上与 canvas 变换恰好相同,于是一句
「numerically identical today」被当成保留的理由;一旦相机移动(即它要处理的那种
情况出现),它立刻失效。等价要写在条件成立时也成立的证明上,不是写在「现在还没
发生」上。

## 点击锚不再挂在 *_ClickTarget 上(2026-08-29,record_clicktarget_anchor_decision)

**`*_ClickTarget` 不再是 playtest 的点击锚点;点击锚指向单位自身的 Node2D 名字**
(如 `Central_Divine`、`Player`),偏移由场景自己表达(例如 `Central_Divine +0,0`
= 脚格),锚点解锚走相机感知的 `get_global_transform_with_canvas().origin`。

### 根因:一个节点不可能同时是两样东西

一个节点不可能既是「可按名解析、且真的点得着」的锚,又是「永远不该收到点击」的
Control——两个要求**互斥**,且本轮**两边各红过一次**:

- `mouse_filter = 0`(STOP):`Central_Divine.debug_click_target_fires == 1`,
  立绘挡住单位格子、吃掉本该走 `_input` 中继的按下——控制元件把「该走玩家路径的
  点击」拦在了 GUI 阶段;
- `mouse_filter = 2`(IGNORE):锚点打不着,harness 直接在 aim 阶段
  `push_error` → `aim: node has mouse_filter=IGNORE (cannot be hit): Central_Divine_ClickTarget`
  → 硬闸门红(`click_targeting_fixed` / `click_move_commit_lock` /
  `move_target_affordance` / `input_click_differential` 四条同时挂)。

「既是可点锚、又不可点」在同一次交付里互相打架,说明问题不在 `mouse_filter` 取哪个
值,而在**让一个 Control 去当点击锚**这件事本身。

### 向后原则(通用规矩)

控件的 `mouse_filter` 是**引擎实现细节**,场景**不许**把它钉成断言对象;playtest
点击必须走真实玩家走的那条路——点单位本体。这与 `design/30_presentation.md` 已记的
「**闸门断言游戏级属性,不断言引擎级属性**」是同一条规矩——本轮那次红正是这条规矩
在点击锚上的**第二次现身**(第一次是 2026-08-25 的「容器矩形 ≠ 墨迹」教训)。

### 被本条取代的旧文(点名,不改写)

早先「`ClickTarget` 节点保留,因为它是 harness 按名解析的点击锚」的裁定(现
`design/30_presentation.md` L723-731)由本条作废其后半句:节点仍在(仍是
`debug_click_target_fires` 路由计数器的载体),但它**不再是锚点**——场景一律改用
单位自己的 Node2D 名字,`_input` 中继才是敌人点击路径。

### 实测证据路径(下一轮不必重查)

- `final/delivery_notes_fix_clicktarget_ignore.md`:STOP 侧 `debug_click_target_fires`
  计数 == 1 的实测;以及被撤回的「同一屏幕点会被单位 `_input` 中继接住,所以点
  IGNORE 控件也能绿」的自我辩护。
- `final/delivery_notes_fix_commit_lock_rebase.md`(第 30-49 行):IGNORE 下 aim
  硬失败的原话;同一物理点改用 Node2D 锚 `Central_Divine +0,0`(== 脚格 ==
  ClickTarget 矩形中心)后 **7/7 干净通过、硬闸门 True**。
- `playtest/_common.yaml` L59-60:两种锚点契约(Control 取 `get_global_rect()`
  中心、Node2D 取 `get_global_transform_with_canvas().origin`)与 L68(IGNORE 早已被
  列为「事件收不到」的原因)。

### 自我批评(必须写,否则同样的错会再犯)

上一条交付备注曾用「同一屏幕点会被单位 `_input` 中继接住,所以点 IGNORE 控件也能
绿」为自己辩护——那假设的是**重建后的**闸门镜像;装着的 harness 直接在 aim 阶段
`push_error`。结论:**「行为在另一种 harness 下会正确」不是保留一条红锚点的理由**;
锚点必须对当下装着的 harness 就成立,否则拿什么当实测证据。

## 门派设施:定义、不变量与复用上限(2026-08-29,`jinyong-facility` 轮)

本条记 `jinyong-facility` 轮五项裁定。设施的定义与数据行见 `20_content.md` §10;
本轮把地图第三类进入内容(facility)落地于少林 / 武当,并把「它凭什么不是第二个
event」这一性质变成永久可观测的事实。

### (a) event / facility 优先级:到达永不入设施,只由显式键进入

**裁定:facility 从不接入到达分派(`_maybe_start_entry_event()` /
`_maybe_start_entry_battle()`);它只在 TRAVEL 相位由玩家按 `use_facility` 键(F)
主动进入 `FACILITY` 相位。** 这是 event(到达即触发的被动内容)与 facility(主动选择、
可重复使用的主动内容)的定义性区别——若做不出这个区别,facility 就只是第二个 event。

**由永久负向断言钉住,不只记档**:`playtest/facility_use_reusable.yaml` 的到达半场
断 `phase == "EVENT" and phase != "FACILITY"`、`facility_id == ""`、
`facility_use_count == 0`(event 解算回 TRAVEL 后再断一次 `facility_use_count == 0`,
防解算夹带使用)。这确保任何未来轮次把 facility 悄悄接进到达分派都会**当场变红**——
「定义一样东西的性质若没有观测点」是本项目的复发性失败形状,本条就是它的观测点。
同一事实的第二层保护是 `tests/test_playtest_contract_smoke.py` 的防删钉(要求场景
文件文本里 `phase != "FACILITY"` 与 `facility_use_count == 0` 两行都在)——因为一个
静默可删的常驻断言,和从没写过的观测点是同一种失败。

### (b) 少林场景 gap 断言重基线例外(机器记录,仅 f560 收紧)

**裁定:facility 槽转 `active` 令 `declared_gap_types()` 这个诚实可观测量必须移动,
经 superset fixture 授权重基线;但只动真正变了的那一条。**
`playtest/map_node_event_shaolin.yaml`:
- **仅 f560**(在少林、`events_resolved_count == 2`)收紧为
  `entry_declared_gap_types.has("battle") and not entry_declared_gap_types.has("facility")`
  ——少林 facility 已 live,不再是缺口。
- **f460**(在洛阳、`events_resolved_count == 1`)保持
  `has("battle") and has("facility")`——洛阳 facility 槽**仍 `declared`**,在此处去掉
  `facility` 会是**假断言**(前一次尝试过度重基线了它,本轮如实回退,是加强诚实、非放宽)。
`tests/fixtures/playtest_assert_superset.json` 以收紧后的 f560 表达式为其单条冻结基线
行(f560 满足之;f460 的正向形式是允许的超集),honesty 钉(每条 gap 行含 "battle" 与
"facility" 两 token)在两行上都成立。

### (c) §433 文案位置守卫:已采纳(实测核实)

**裁定:把「设施 / 事件文案只能住在其数据模块、绝不 inline 于 `map_data.gd` /
`map.gd`」这条原为纯文档的规矩,升级为会拦人的静态守卫。**
`tests/test_facility_copy_location.py`(纯标准库 pytest,照 `test_i18n_coverage.py` 形状):
扫 `map_data.gd` / `map.gd` 中 ≥4 CJK 的双引号字面量,命中不在 allowlist 者即红;allowlist
含设施 chrome(`"\n\n门派设施：%s（F 使用）"`、`"回车使用 · 上下离开"`、`"银两不足"`)
与既有合法字面量(旅行动词、节点 display_name 等)。prose-scoped 而非「零 CJK」——
更严的变体需要同一份 allowlist,额外严格买不到东西。动机与 `test_i18n_coverage.py`
一致:一段 inline 的江湖轶事渲染中文毫无问题,没有任何自动检查看得见它。

### (d) 红转绿记录是一次性证据,常驻性质由负向断言承载

**裁定:新场景 flip 前实测的红值(34/47:到达半场绿、选择半场红——`phase` 读
`TRAVEL`、`facility_id` 读 `""`、`facility_use_count` 读 `0`,逐条见
`final/delivery_notes_facility.md`)是一次性证据——它证明这条钉子确实能红、不是永远
绿的装饰;但它转绿即消失,此后保护不了任何东西。** 把「到达即触发 vs 主动进入」这一
性质带向未来的,是 (a) 的常驻负向断言 + 防删钉,不是一次性的红。写在此处,以防后续读者
误把红签名当成持久守卫。

### (e) facility 复用上限 = 第 5 阶段待决数值(本轮仅以既有银两为限)

**裁定:本轮复用上限只由既有银两决定(每次付费、付得起就能再用),零新资源 / 新
货币 / 新经济。复用的真正上界——once-per-visit / once-per-period / pure-silver-limit
三取一——是第 5 阶段数值精调的待决项,本轮不下结论。** 记在此处,是因为若只留当前
银两门槛这一实现事实,下一轮极易把它读成已定的复用上限;把未决的东西显式记为 PENDING,
正是 `90_decisions.md`「已决定但未实现 / 未决定」这一层的用途。「先记下」优于沉默。

## 主线六段触屏可达(touch-reach, 2026-08-29)

「手机上过不了教程」的根因此前已核实:教程结算 overlay 是**代码现搭**(`game_manager.gd:194/199`
调 `_show_end_game_overlay`,CanvasLayer + ColorRect + Panel + Label,零 Button),五个段场景
(transition / sect_select / cultivation / map / ending)是 `Backdrop + Label` 零按钮 ——
视角上「触屏能玩的范围正好到教程打完为止」。本轮给全部六段补可见、可点的控件,并立一条
`clicks:`-only 场景把「不碰键盘能不能走到结局」变成游戏级闸门。五款裁定逐条如下。

(a) **clicks-only 脊柱里 `debug_win_tutorial` 是唯一非点击动作。** `playtest/clicks_only_storyline.yaml`
全程只走 `clicks:`;除 `debug_win_tutorial` 外不允许任何 `ui_accept` / `move_*` / `skill_*` 等键盘
动作。`debug_win_tutorial` 是**未绑定的 DEBUG 动作**(在 `_process` 里消费,不是键盘输入),是
`spine_to_ending` 在 f20 用的同一个结局种子。理由:全击打战斗**放不进帧上限**(一次 39 伤命中
序列就要约 1750 帧);战斗屏的可点性由四张既有点击场景(`battle_end_turn_attack_buttons` /
`click_targeting_fixed` / `undo_button_retreat` / `click_portrait_body_targets_enemy`)加场景内
一次真实 `AttackButton` 点击证明;拆成两条场景则做不到「overlay → … → ending 一条龙可点」。
该种子记入场景头 + 交付报告 + 本文件(三处)。

(b) **选项按钮 = 设焦点 + `_on_accept()` 委托,零分叉点击逻辑。** cultivation / map 的动态选项
列表(卡片 / 行动 / 功法 / 属性 / 事件 / 节点旅行)是文本行(▶ 标记),没有逐选项节点可点;
本轮新增 `CultOptionButton{i}` / `TravelButton{i}` / `EventOptionButton{0,1}`,点击 = 把阶段的
焦点变量设到该下标(键盘方向键本来就读它),再调**同一个** `_on_accept()`。键盘分支(bytes)不动,
这使「加,不是换」由构造成为真。

(c) **文案对齐范围 = overlay 仅此一处。** `game_manager.gd:194/199` 的调用点字面量与
`i18n.gd:101/102` 的键值一起换,把「按回车继续」/「按回车重试」对齐为描述真实可点操作的
「点击「继续」进入江湖」/「点击「重试」再战」(两处同改,漏一处查表静默落回中文)。**其余**
键盘味提示(结局重开 / 过场 / 拜师 / 地图启程 / 事件定夺 / 设施 F 提示 / 教程开场见
`i18n.gd:350/354/359/364/369/378/380/122` 等)一律**不修**,记作 UX-12 测量欠账。

(d) **FACILITY 委托按钮 —— 进入/使用/离开,delegation-only + 双结果协议。** 地图屏新增三个
Button,只委托到既有设施的具名 handler:`FacilityEnterButton` 镜像 F 键(`use_facility`)分支
**自己的门卫**(`phase == "TRAVEL"` 且 `MapData.active_facility_id(current_node_id) != ""`)
再调 `_enter_facility()` —— 点击只开 F 键能开的门;`FacilityUseButton` → `_use_facility()`;
`FacilityLeaveButton` → `_leave_facility()`(**必需,非可选**:没有它,点进 FACILITY 的触屏玩家
会被困在相位里 —— 方向键是今天唯一的出口,那会原样复现本轮要消除的死路)。**双结果协议**:
若实现中加这三个按钮需要改变设施逻辑(进入/离开/复用语义、F 键绑定与门、`map_data.gd` /
`facility_data.gd` / `20_content.md` §8.1/§10 / `playtest/facility_use_reusable.yaml` 任一),
**停手**,把「委托做不到」的原因写进报告与本文件,回退到「无设施按钮」(设施面板回记 UX-12
为已测量欠账)。两种结论都接受;沉默不接受。

**结果(2026-08-30 官方闸门实测收口):落到第一种结论** —— 委托做成、设施逻辑零改动:
`playtest/facility_use_reusable.yaml` 逐字节未动且官方全量闸门实测 **49/49** 全绿,配套
`map_facility_buttons_click` **38/38** 全绿(硬闸门 `passed: true`、71/71 场景全 PASS、编译
**88/88** 零错误,见 `99_changelog.md` record_official_gate_run_green)。「无设施按钮」回退
未触发;设施面板不再记「面板缺可点控件」欠账,UX-12 只余文案行号。

(e) **点击锚挂控件/单位本体,重申 `*_ClickTarget` 禁令。** 沿用本条上方 2026-08-29「点击锚不再
挂在 *_ClickTarget 上」的裁定;本轮所有新锚点(overlay / 五段场景按钮、旅行 / 事件 / 设施按钮)
都是 Button 本体,绝不挂 `*_ClickTarget`。

## 解析错误拉倒整轮验证(record_parse_lesson_and_reconcile, 2026-08-29)

**规矩:新增任何 `tests/*.gd` 测试文件后,交卡前先跑一次独立解析检查。** Godot 的解析检查是**项目级**的——任何一个测试 `.gd` 里的笔误 ⇒ 编译红 ⇒ play-test 被跳过 ⇒ 0 场景 / 0 帧 ⇒ 行为/可读性闸门集体失明。本轮 `5_compile` 的 `playtest_summary.md` 即该形状(`Parse failed — play-test skipped`、`spec_used: false`、`frames: 0`,而硬闸门 `passed: true`,因为硬闸门只报 crash / scene-load / 非法键 / 输入未收到,**不报「零帧」**——「闸门绿」与「闸门根本没跑」在报告里长得一样)。这条独立解析检查比任何断言都便宜,却能在「编译红 → 闸门盲」之前拦住。

**配套勘误**(与 `design/99_changelog.md` 同步):touch-reach 行「先红(f180)→ 转绿」是**结构预测而非实测**——`red_first_evidence_reproduction` 步无 shell/网络,调不动外部 harness;实测须来自一次解析干净的运行,复现配方(临时回退法)见 `final/delivery_notes_touch_reach_red_first.md`。在此之前档案只保留「预测 + 复现配方」,不写实测数字。

**实测补充(2026-08-29,record_measured_red_first_and_reconcile):** 上两条所等的「实测数字」现已由一次
解析干净的运行抵达 — 勘误所设的条件「在此之前档案只保留『预测 + 复现配方』,不写实测数字」**已满足**。
轮 `red_first_evidence_measured` 用**临时回退法**复现(touch-reach 上方裁定 (a)–(e) 一律不动;在
`scripts/autoload/game_manager.gd::_show_end_game_overlay` 注释掉两个 Button 构造块、re-show 分支的
`existing_continue` / `existing_retry` 重同步块、两处 `_refresh_end_overlay_pressed_connected()` 调用点,
保留函数定义与键盘分支,每处标 `# TEMPORARY RED-FIRST REVERT — DO NOT COMMIT`),用
`godot_playtest_scenario(scenario="clicks_only_storyline")`(**直连同一外部边车**
`aitelier/tools/godot_playtest/impl.py`)实测:failing frame **265** / first failing assert
**`ContinueButton.visible`**(f265,expr `visible == true`,error `node not found: ContinueButton`)/ exact
error **`aim: node not found: ContinueButton (spec: ContinueButton)`** / green asserts before red **8**;
逐字节还原后复跑 **47/47** 全绿。此前记档的 `f180` / 5 是**结构预测**(原时间线),由帧时序重投影修(全部
`at:` 帧重基线到屏就绪时序、教程开场腿 Next 点击数 3→7、加 `scene: res://scenes/menu.tscn`)后实测为
**265**,同一屏同一首断断言。该红**不以 5_compile 闸门为来源** — 本轮闸门运行仍解析失败 / 0 帧,实测
来自对同一外部边车的直连每场景调用。档案自此持有实测数字,不再以预测充数。

**官方闸门收口(2026-08-30):** 上文所指那次解析失败的 `5_compile` 运行之后,本轮的**官方
全量闸门重跑解析干净**:编译 **88/88** 零错误、`spec_used: true`、**71/71** 场景全 PASS
(`clicks_only_storyline` 47/47、`spine_to_ending` 42/42、`map_facility_buttons_click` 38/38、
`facility_use_reusable` 49/49),零 runtime error。本节立的规矩(新增 `tests/*.gd` 后先独立
解析检查)不因此作废——它防的正是那次盲跑;本行只把「本轮最终闸门证据」与「盲跑教训」
分界,防止下一轮把二者混读。

## 单面 + 全状态可点出口(touch-single-surface, 2026-08-30)

本轮把上一轮 `touch-reach` 的「每一屏有一个可点控件」升级为两条更强的规矩:**按钮是选项的
唯一呈现**(单面),以及**每个需要玩家选择的状态都必须有可点出口**(不限于「每一屏」)。
五款裁定逐条如下,均记入 `30_presentation.md` 指针可达性节 (f)/(g)。

(a) **键盘提示文案保留。** 「上下选择，回车执行」等一行操作摘要**不是**与按钮逐字重复的
选项行,是**一行操作说明**;删掉它桌面玩家就不知道还能用键盘。其残留文案欠账(命名只讲
键盘、屏上已有控件但没说可点)由 UX-12 已测量记档,本轮不修。单面规矩只删「和按钮
逐字重复的选项行」,描述性文字与操作摘要都保留。

(b) **过场「继续 ▶」保留。** `transition.gd:65` 的 `▶` 是**按钮自身文本里的一个字形**
(「继续 ▶」),单面、零重复,与 `BodyLabel` 平行文字列表不是一回事;它还是冻结文案
(`i18n.gd`),无断言依赖其移除。按 SOTA §1.1 记为单面,不删。

(c) **GONGFA_PICK 空列表出口委托同一条 `_on_accept` 链,零分叉相位逻辑。** 空未大成列表时
`_rebuild_options_box` 追加单个「返回行动」按钮(`cultivation.gd:576`),其 `pressed` 与其它
选项**同一条** `_on_option_pressed → _on_accept` 路径,`_on_accept` 的既有空分支
(`:235-238`)执行 `phase = "ACTION_PICK"`。没有为按钮另写一段转场逻辑;键盘分支逐字节不变,
按钮是键盘空分支的**触屏孪生**。

(d) **地图 TRAVEL 节点名一览保留为描述性总览,焦点标记移除。** 节点列表列举了不相邻节点,
是「地图长什么样」的**总览**(描述性),不是选项列表,保留;从列表里删掉 `▶` 光标与
`（可前往）` 焦点标记,焦点现在只活在**高亮的 `TravelButton{i}`** 上(`map.gd:483`)。
当前节点行改用 `  %s（当前所在）\n`(说它「正站在这个节点上」,与列表下「当前：%s」同一语域),
缩进保留使节点名与普通行列对齐。

(e) **选中高亮 = `modulate` 亮/暗。** 焦点行 `Color(1,1,1,1)`、其余 `Color(0.72,0.72,0.72,1)`,
`creation.gd` 先例,逐段复制到 cultivation / map / sect_select 的按钮。`theme_type_variation`
/ `ButtonGroup` / Godot GUI focus(`grab_focus` / `focus_neighbor_*`)按 SOTA §2.2/§2.3/§2.4
**否决**:本仓实测 GUI focus 会吞 `ui_up/ui_down`(`battle_focus_arrow_keys`),动态按帧重建的
选项池无稳定邻序,主题文件只含字体、无按钮 stylebox 可复用;`modulate` 零新资产、零主题改动、
零焦点系统风险,且不碰全仓 `focus_mode = FOCUS_NONE` 约定。

(f) **覆盖闸门排除规则 + 遍历范围。** 性质:「机器自身到达的每个玩家选择相位,除非 **EXEMPT
(没有任何输入能改变它)**,其可点控件构造必须产出 ≥ 1 个可见、已接线控件,且正文无 `▶`」。
相位不是字面量清单,**遍历 phase 机器**发现(`match phase:` 分派臂即邻接表,`< 250` 趟守卫,
一次一个消耗每月行动的相位,与手动游玩到达方式一致);排除规则「EXEMPT iff 无输入可改它的
状态」写进闸门本身,今天三个被遍历机器(travel/event/facility、cultivation 八相位、
sect_select)无纯展示相位,排除表为空但规则常驻。遍历范围限三段**按帧/按状态重建选项池**的段
(cultivation / map / sect_select);battle(按钮池稳定 + 终局 overlay)、creation(单面)、
menu / settings / tutorial / ending(稳定按钮池)在遍历机器之外,由各自既有 playtest 场景覆盖。

(g) **文案位置守卫是「被维护」不是「被绕」。** `tests/test_facility_copy_location.py`(§433
文案守卫)在早期草稿里被当成冻结而**绕过**:复合键保持逐字节不变、往被删的选项槽喂 `""`
(玩家屏上渲染出 4/2 个连续空行),文案字词挑到刚好压在 ≥4-CJK 阈值下。轮主明确解冻该守卫做
两类维护,本轮走**其文档化的下一步**:`tr()` 调用点检测(把 map.gd 里的 `tr("...")` 键识别为
合法文案位置,检出对白名单是 **ADDITIVE**——非 tr 的 ≥4-CJK 字面量照旧红);`ALLOWED` 九条
chrome 全被检出覆盖后清空(若有非 `tr()` 首参者留在白名单并在交付说明点名);`ENDING_TIERS`
块跳过与 `"display_name":` 字段跳过两处符号排除**逐字节不动**;数据模块文案去重测试
`test_no_prose_duplicated_from_data_modules` **不**因此豁免(含 `tr()` 键,防数据句绕进
map.gd);反平凡下限按实测重基线(带日期注释,绝不 < 3);文案按「它告诉玩家什么」选用
(「当前所在」),**绝不是**按 CJK 字数挑词。理由:逐键白名单维护正是制造「在玩家屏幕上留洞」
诱因的机制;检出从结构上移走这个诱因——map.gd 里的文案必须是且只能是 `tr()` 键 + i18n 条目,
否则守卫红它。

2026-08-30 `touch-single-surface`(5_design 证据步骤,如实记 open 项):新钉子 `clicks_only_gongfa_empty_exit` 的**修红实测四值**(失败帧 / 首个失败断言 / 确切错误串 / 红前绿数)在本轮收尾时**仍为结构预测**(f140 / `CultOptionButton0.visible` / 红前 8 绿),实测须按 2026-08-29 `record_measured_red_first_and_reconcile` 同款临时回退法(`TEMPORARY RED-FIRST REVERT` 标记的空出口分支注释块,直连边车 `godot_playtest_scenario`,跑红后逐字节还原)产生一次。**绿半边已实测**:本轮官方全量闸门 `clicks_only_gongfa_empty_exit` **16/16** / `gongfa_pick_empty_keyboard_return` **13/13**(`playtest_summary.md`),修后行为由闸门实测成立;欠的只是「修前红那一跑」的四个实测数字。预测不得当实测引用;实测值产生后回填场景头与 `final/delivery_notes_touch_single_surface.md`。

**修红实测收口(2026-08-30,5_design 证据步骤;上行 open 项关闭):** 上行所等的「修前红那一跑」
四个实测数字**已抵达**——按上行所记的同一临时回退法(`scripts/segments/cultivation.gd` 空出口
分支注释块标 `# TEMPORARY RED-FIRST REVERT — DO NOT COMMIT`,直连边车
`godot_playtest_scenario` 跑红后逐字节还原,`scripts/` 零回退标记残留)实测:失败帧 **f140** /
首个失败断言 **`CultOptionButton0.visible: visible == true`** / 确切错误
**`aim: node not found: CultOptionButton0 (spec: CultOptionButton0)`** / 红前绿 **9** 条
(f80 6 + f110 2 + f140 的 `phase == "GONGFA_PICK"` 断言——该断言在回退下也过,因为空列表相位
本身可到达,缺的只是按钮)。与结构预测(f140 / 红前 8 绿)相比**同帧、同首断,唯绿数 8→9**
(预测没算上 f140 那条回退下仍过的相位断言);预测值按档案纪律逐字保留在场景头 RED-FIRST
EVIDENCE 块并标注被本实测取代,实测值落 `final/delivery_notes_touch_single_surface.md`
(Part A §4/§5 + Part B §4/§5)。还原后的树上两条新场景复跑全绿:
`clicks_only_gongfa_empty_exit` **16/16**、`gongfa_pick_empty_keyboard_return` **13/13**
(硬闸门 `passed: true`)——上行「绿半边已实测」与本行「红半边已实测」合起来,该钉子
「先红后绿」的档案记录链完整。本文件自此无因本轮新增的待决问题。

## jinyong-roster — 角色面板七裁定 (2026-08-30)

- **(a) 面板是纯展示 overlay,不是 phase。** 无 `match phase:` 分支、无新状态串,不开存档。
  单一操作面**空集真**满足(面板内部零内可选控件)+ **主动**满足(`cursor_markers_visible == false`
  发布并被新场景断言;dim 层 STOP = 打开期间唯一操作面,`▶` 无处出现)。
- **(b) 养成 / 大地图任意相位——含 map EVENT/FACILITY 模态与 cultivation 选择相位——都可打开,
  宿主 `_unhandled_input` 以 `is_open` 为闸第一行进 return。** 选 (ii)(不隐藏入口)而非 (i)(模态期
  藏入口):「我是谁 / 背上有什么」是与相位无关的信息,而玩家最可能想确认的恰是**刚落定某个事件
  选项之前**(花这笔银两?取这把剑?)。代价是两个「面板打开期间模态键语法惰性、关闭即刻恢复」的
  主张必须被**钉**而不是靠散文:由 `playtest/roster_panel_item_nail.yaml` 的中段(f35–f60)实现——
  面板打开在未解算的 merchant 模态之上,断言 `phase == "EVENT"` / `event_id == "merchant"` /
  `events_resolved_count == 0` 未动,关闭后**同一个** `EventOptionButton0` click 正常解算
  (`events_resolved_count == 1`、`silver: changed`)。`spine_to_ending` 永不打开面板 → 时序天然未动。
- **(c) 关闭 = 关闭按钮 和 点面板外区域。** 关闭按钮被真实 click 钉住(纯 tap-outside 层无法被
  harness 有意义地命中测试);dim 层的 STOP filter 让面板成为打开期间的唯一操作面。
- **(d) 本轮不加新键盘动作。** 开 / 关纯 click-only,无 `project.godot` input-map 变更、无新动作
  token、零语法冲突面;键盘快捷层留待后续,**可见可点控件是唯一机制**(无键盘、无按钮 = 不合格)。
- **(e) 只读硬保证。** `open()/close()` 从不 `SaveManager.autosave()`(反例:`map.gd::_resolve_node_event`
  会存档——那是事件路径,不是面板)、不写 profile/flags、不消耗月份/行动、不改 phase。
  `save_load_roundtrip` 保持绿;`spine_to_ending` 逐字节未动。
- **(f) 降级,绝不发明。** 物品名走冻结的 `CardData.display_name_of`,功法走
  `ProgressionGongfaData.display_name_of`,特质走 `TraitData.get_def()`,门派走 `SECTS`;
  每个 resolver miss 惰性降级为原始 id 或诚实「（无）」行。无新数据字段、无新系统、无装备语义——
  面板只**显示** `PlayerProfile` 已存的一切。
- **(g) 自足 instanced 场景。** 一个 `roster_panel.tscn` 承载入口 + 面板overlay,宿主只加
  一个节点 + 一行 `_unhandled_input` 闸;按钮位置实现者可调(画布内、不压既有命中区)——`clicks:`
  真命中测试即证明。

## 武虾立绘落地:四个虾种裁定 + 画风换向(2026-08-31,项目所有者裁定)

**四个「待定虾种」由所有者逐条裁定,名册 `assets/characters/roster.json` 照录,守护测试
`tests/test_shrimp_roster.py` 不改且绿。** 2026-08-28「武虾:本作的一切角色都是虾」条目里
挂着的四行待定,自此闭合:

| 角色 | 虾种(逐字) | 对应理由(逐字) |
|---|---|---|
| 东邪 `east_heretic` | 樱花虾(正樱虾) | 深海群游、绯红半透,聚散如落英,对桃花岛 |
| 南帝 `south_emperor` | 罗氏沼虾 | 南方淡水巨虾,一对细长蓝螯,对大理段皇爷 |
| 中神通 `central_divine` | 玻璃虾 | 通体透明、内里一览无余,对先天功 |
| 杨过 `yang_guo` | 枪虾 | 一只螯极大而另一侧空缺(独臂);且与虾虎鱼结伴共生(神雕) |

(西毒 皮皮虾 / 北丐 龙虾 两行此前已写好,原样未动;六行 `art_status` 由 `pending` 翻为
`completed`。)**杨过的称号与去名化 note 原样保留**——去名化是独立一轮的事,已记
`40_ux_backlog.md` UX-15(OPEN);本轮不改名(改名会打断编译期资源引用,与「证明几何
没坏」搅在一起就分不清红是谁造成的)。

**画风换向裁定:角色从「人形水墨武侠人物」改为「非人形的真虾体 + 头卡通身写实」。**
试验收敛记录:纯写实 → 吓人;纯 Q 版 → 平;「介于两者之间」→ 糊;结论是分层 register
必须**写进同一句**——头全卡通(圆化头胸甲、大而有高光的眼、讨喜绝不吓人)+ 身体半写实
(叠压甲片、清晰体节、棘刺脊线、方向光与柔和阴影、硬壳光泽)。风格句唯一来源 =
`assets/seed_manifest.json` 的 `style_block`,与 `30_presentation.md`「画风」节逐字同步
(本轮已核 byte-identical);完整配方(虾种表、污染词、年龄/性别表达、不对称正面化、
构图→后处理、remove_bg + 边框泛洪补洞)逐字归档于 `final/delivery_notes_wuxia.md` §1。

**立绘几何重实测(2026-08-31;换图不换几何——钉子必须重新量,不能沿用旧绿):**
`portrait_grid_alignment` **30/30**(24 条墨迹线在 f40 静态腿与 f820 走位腿全部
`ink_world_dx/dy = 0.0`)、六单位八层可见性 `portrait_visible=true / portrait_fail_layer="" /
portrait_covered_frac=0.0`、`camera_transform_follows_unit` **9/9**、`spine_to_ending`
**42/42 零 runtime error**;逐 PNG alpha 包围盒 `bottom_gap=0` 全部(墨迹触及底行,
纹理矩形盲区在本套图上不存在)、水平中心偏差 0 / −0.5(奇数宽半像素,记为发现非缺陷)、
`east_heretic top=3` 记为偏差不修。零红钉、零阈值放宽、零 yaml/脚本/PNG 改动;
纹理矩形盲区(`portrait_ink_rect` 是纹理矩形派生、全绿不证明墨迹落脚)记入
`30_presentation.md` 盲区记录,可选 alpha-bbox 落脚钉提议给所有者、本轮不落。
观测值:`final/delivery_notes_wuxia.md` §3。**过渡文件 `WUXIA_ART_HANDOFF.md` 的内容
已逐字归档进 `final/delivery_notes_wuxia.md` §1(归档先于删除、回滚路径见同文件 §7);
根文件删除被管线「必需产物」守卫拒绝(5 次尝试,实录该文件 §7)——删除待有删除权限的
步骤/配置执行,归档完整性已核验(§一–§六齐备、风格句与 `style_block` byte-identical)。**

## jinyong-equipment-battle — 角色面板只读保证被有意推翻(2026-08-31;取代 2026-08-30 jinyong-roster 裁定 (e))

- **被取代:2026-08-30 jinyong-roster 裁定 (e)「只读硬保证」**(`open()/close()` 从不
  autosave、不写 profile/flags、不耗月份/行动、不改 phase)。旧条原文逐字保留于上文,
  由本条明文取代——一条被静默删除的保证,和从来没有过那条保证,是两回事;
  `scripts/ui/roster_panel.gd` 头注释已改写为新事实并指回本条。
- **为什么 (e) 当时是对的:** 那一轮的全部任务就是证明面板零副作用——open/close/refresh
  纯只读,只读保证是那个证明的最锋利形式,month/phase/计数不变量的闸门靠它钉住。
  若当时就带写路径,「面板不产生副作用」将无从证明。
- **现在改了什么:** 装备需要一个写路径,而角色页是本轮指定的触控操作面。面板现在恰好
  写**一个** profile 面:物品行「装上 / 卸下」按钮池经 `SaveManager.profile.equip() /
  unequip_slot()` 只写 `equipped` 三槽,随后 `refresh()`。这是本轮全仓唯一的新 profile
  写入点。
- **(e) 不冲突的部分原样保留:** 仍然不调 autosave / save_game(装备沿用养成段存 / 读
  模型,改 profile 不落盘)、不消耗月份 / 行动、不改 phase、不写任何其他 profile 字段
  ——`roster_panel_cultivation_open_close.yaml` 16/16 与 `roster_equip_free_action`
  36/36 把这条自由动作不变量钉在真实运行里。
- **单一操作面(touch-single-surface 规则)不变:** 新控件全部是按钮(`focus_mode = 0`
  ——按钮持有 Godot 内建焦点会在 `_unhandled_input` 之前吞掉 ui_up/ui_down),
  没有并行的键盘光标 `▶` 列表,`cursor_markers_visible == false` 保持。
- **相邻两条的 scope 更正:** 2026-08-30 (a)「面板是纯展示 overlay」与 (f)「无装备语义」
  除物品行装备按钮外仍然为真——按钮池是本轮新增的唯一例外,(f) 的「无装备语义」自此
  由本条接替:装备语义存在,且只经这一个写入口。旧记录原文不删。
- **Open question(实测欠账,如实记:修复已落、闸门证据未拿到):** 本轮官方闸门
  (`playtest_summary.md`,2026-08-31)实测 `equipment_in_battle_diff` **16/32** 红
  (6 条 runtime error:`aim: node not found: RosterOpenButton / EquipButton0 /
  RosterCloseButton`;断言首红 f630 `GameManager.current_state == "MAP"` 实测
  `BATTLE`)——场景把面板装 / 卸点击排在 `debug_win_tutorial` 返回 MAP 之前,BATTLE 态下
  map 段及其 RosterPanel 不在树上;硬闸门因此 `passed: false`。**修法已定:重排该场景
  帧布局(先返回 MAP 再开面板),零断言放松、零阈值放宽,留给下一轮**;记
  `40_ux_backlog.md` UX-16(OPEN)。功能层证据已绿:`roster_equip_free_action` 36/36
  (面板自由动作腿)+ `tests/test_battle_setup_equipment.gd`(空槽等价 / 方向 / 可逆);
  装备进真实遭遇战的 `changed` 差分官方闸门证据待重排后重测。两条新钉子的修红实测四值
  (临时回退直连边车法)仍欠一次实测——`final/delivery_notes_equipment.md` 里为结构
  预测,按档案纪律不得当实测引用。
- **Open question 收口(2026-08-31 post-fix 官方闸门,5_design 证据步骤补写):** 上问已答
  ——根因不是帧布局而是路由:MAP(华山)战斗复用教程战场(`battle_return_state !=
  "CULTIVATION"` 分支),从不调 `build_character(SaveManager.profile)`,任何帧重排都到
  不了差分;修法 = 场景重写为真实养成遭遇战路径(`debug_enter_encounter` →
  `battlefield.gd:651` → `derive_stats` → `EquipmentData.sum_bonuses`;物品经白名单
  `debug_grant_equip` → `EventLogic.apply_option_effects`;每腿断
  `CombatManager.tutorial_battle == false`)。本轮官方闸门 `playtest_summary.md` 复测
  `equipment_in_battle_diff` **47/47**、硬闸门 `passed: true`、零 runtime error——装备进
  真实遭遇战的 `changed` 差分证据到手,`40_ux_backlog.md` UX-16 据此
  CLOSED(jinyong-equipment-battle)。修红实测四值同批抵达(临时回退法直连边车,逐字节
  还原,`scripts/` 零回退标记):失败帧 **f560** / 首断
  **`Player.gear_attack_bonus: gear_attack_bonus > 0`** / 确切错误
  **`FAIL f560 Player.gear_attack_bonus: gear_attack_bonus > 0 (observed=0)`** / 红前绿
  **46**(`roster_equip_free_action` f110 四值同批,见
  `final/delivery_notes_equipment.md`)——上句「结构预测不得当实测引用」由此实测取代。
  pytest 与 GDScript 单元套件的 post-fix 复跑报告(5_test 产物)不在本步上下文,不冒充实测。

## jinyong-event-pool-36 — 事件池扩至 36 条与两道不重复闸门(2026-08-31)

本条记 `jinyong-event-pool-36` 轮五项裁定。数据行见 `20_content.md` §4;本轮把游历
事件池从 16 条扩到 **36 条**,配两道证明「一次完整旅程不重复」的可执行闸门,
全部动因是路线图完整度第 3 条(16 条撑不过 36 个月,第 17 个月起必重复)❌→✅。

**(a) 池 = 恰好 36、append-only、冻结 16 条逐字不动。** `EventData.TABLE` 只追加 20 行
到 36 行;既有 16 行的 id / title / text / 选项 / 效果**逐字冻结**,游戏机制(五种效果
类型、抽取逻辑、`events_seen` 语义、`battle_id` stub、大地图节点事件通道)一律不动。
「冻结 16 条未变」由 `tests/test_event_data.gd` 的镜像(标题 / 效果 / 正文 / 选项标签
逐条 pin)机器化,任何一行被改都会当场变红。36 = 旅程长度(3 年 × 12 月),是「不重复」
的精确最小值;清空分支原样保留,留作第 37 抽的安全网。

**(b) 不重复闸门 = `_test_no_repeat_full_journey`,在 `tests/test_event_data.gd`,
跑真实 `EventLogic.draw_unseen_id`。** 闸门构造一颗带显式种子的 `RandomNumberGenerator`、
一个干净 profile,循环调真实抽函数 36 次,每次按 `cultivation.gd` 同形的 append-if-absent
标记 seen,断言 seen **单调阶梯 0→36、无中途清空**(任何一次重置都会让阶梯回落而红),
36 个 id 全互异。这是「一次完整旅程不重复」的**实测**依据,不是推理。

**(c) 调试注入纪律:all-but-one seeder 经同一标记分支写入,绝不裸覆盖 flags。**
屏上证明用的调试动作 `debug_seed_events_seen` 把除 showcase id 外的全部事件 id
append-if-absent 进 `profile.flags["events_seen"]`——与 `cultivation.gd` 标记分支同形、
同 `debug_grant_silver`「走正常管线」的纪律,从不直接覆写 `flags` 数组,游戏代码零
fixture 数据。

**(d) playtest id 钉对未来追加按构造免疫。** 屏上场景
`event_pool_new_event_resolved` 断言 `event_id == "cliff_herbs"` 而非写死 35 个 id 的
夹具:seeder 永远只留下 showcase 一个不可见 id,无论未来池子扩多大,该钉子都指向同一
条新事件——追加不改此钉。

**(e) 文体政策:新文案保持物种中性,世界观不一致记为 UX-17(OPEN,待所有者裁定)。**
既有 16 条文案写的是劫匪 / 行商 / 老丐这类**不指明物种**的人物,与 2026-08-28「本作
一切角色都是虾」的裁定并存——本轮**新 20 条照既有写法,不虾化、也不宣称两边一致**,
把「事件文案与全员是虾的世界观不一致」如实记入 `40_ux_backlog.md` **UX-17(OPEN)**,
待所有者裁定(虾化 or 明示豁免)。关闭需各自动作 + 闸门证据,不因本轮转绿而自行关闭。

**(f) 闸门实测回填与一条新欠账(2026-08-31,5_design 证据步骤):屏上「渲染」腿 13/15,记 UX-18。**
本轮官方闸门:编译 **95/95** 零错误;playtest **78 场景**硬闸门 `passed: true`、`spec_used: true`、
零 runtime error、**77 PASS / 1 红**——唯一红是本轮新场景 `event_pool_new_event_resolved`
**13/15**:f200 两断言红(`CultivationScreen.event_title == "崖上采药"` 实测**空串**、
`CultivationScreen.event_body != ""` 实测**空串**),同帧及其后断言全绿(`event_id == "cliff_herbs"`
抽中、f140/f200 `events_seen_count == 35`、f210 `focused_option_text` 选中、f230
`events_seen_count == 36` 结算阶梯 + 相位/月份回 CARD_PICK)——「抽到 / 选中 / 结算 / 无清空」
屏上实测成立,唯「渲染」腿缺。红落在本轮**新增的两个观测面**(`cultivation.gd` `_sync_surface`
发布 `event_title` / `event_body`)的时序/接线,不在玩法:既有渲染走 `tr()` 标签路径,冻结 16 条的
`event_travel_effects` **19/19** 仍绿,视觉闸门 Q6 78 好 / 0 坏。修法留给下一轮:核对发布点时序 →
修 → 复测该场景至 **15/15**,零断言放松、零阈值放宽、零冻结场景改动;缺陷如实记
`40_ux_backlog.md` **UX-18(OPEN)**。单元闸门 `_test_no_repeat_full_journey` 的官方 PASS 以
5_test 产物(`test_report.json`)为准——该产物不在本步上下文,不冒充实测;完整度第 3 条 ✅ 维持
(不重复性质由单元闸门 + 屏上 seen 阶梯承载,红的两条断言钉的是新增观测面而非该性质)。
另记验证报告点出的 cosmetic 项:`event_data.gd` 头注释仍写「first batch of 4 / 16 event rows」,
零闸门影响,下一轮顺手改。既有 77 场景零回归全 PASS(`spine_to_ending` 42/42、
`event_travel_effects` 19/19、`equipment_in_battle_diff` 47/47 等全部在列)。

**(g) 渲染观测面缺陷修复收口 + cosmetic 项已清(post-fix,2026-08-31,5_design 证据步骤)。** 上行 (f) 所记
13/15 红(f200 `event_title` / `event_body` 实测空串)已修复并由本轮 `5_compile` 官方复跑实测转绿:发布点修复 =
ACTION_PICK case 3 抽取后立即 `_sync_surface()`(原实现抽完直接 `_render()`,新增观测面晚一拍发布,f200
读到空串);发布保持**原始中文**字面量(与 playtest 中文钉子一致,`tr()` 仍在渲染路径),未知 id 带防御性
`push_warning`;单元钉 `_test_event_title_body_surface`(`tests/test_cultivation.gd`)守住发布 / 清空对;
`event_data.gd` 头注释同步改为 36 行((f) 末所记 cosmetic 项清账)。实测:**78/78 场景全 PASS**、
`event_pool_new_event_resolved` **15/15**、零 runtime error,编译 **95/95** 零错误,视觉闸门 passed
(Q6 78 好 / 0 坏)——`40_ux_backlog.md` **UX-18 → CLOSED(jinyong-event-pool-36)**,证据 =
`playtest_summary.md: event_pool_new_event_resolved 15/15`。零断言放松、零阈值放宽、零冻结场景改动。
单元闸门 `_test_no_repeat_full_journey` 与 pytest 守卫的官方 PASS 仍以 5_test 产物(`test_report.json`)
为准——该产物不在本步上下文,不冒充实测。

