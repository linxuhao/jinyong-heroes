# Presentation

## 分辨率与拉伸

基准视口 **960 × 704**(= 15×11 格 × 64 px = 棋盘 = 背景图 = 相机视野)。
`project.godot [display]`:`window/stretch/mode = "canvas_items"`、
`window/stretch/aspect = "keep"`、`resizable = true`。窗口缩放时棋盘等比填满,
外侧由引擎黑边补齐。

## 画风

**一句统一风格句,只描述画风,绝不点名任何游戏对象**——把物件清单写进风格句,
生图模型会把每样东西画进每一张图。每个资源的主体只写在它自己那一条 prompt 里。

当前风格句(水墨武侠向)——**以 `assets/seed_manifest.json` 的 `style_block` 为准**:
> Chinese wuxia ink-painting style, flat colors, clean bold outlines, dramatic lighting

> **为什么改这一句。** 档案原先写的是
> `ink-wash wuxia painting, muted earth tones, soft paper texture, side view, flat lighting`,
> 而**实际产出全部现有资产的**是上面那句(记在 `assets/seed_manifest.json`)。
> 两句在三个轴上相反:**flat lighting ↔ dramatic lighting**、
> soft paper texture ↔ clean bold outlines、muted earth tones ↔ 未提。
>
> 档案说一套、现实是另一套,而没人发现——因为没人把两边摆在一起比过。
> 既然已经出图的是后者、看着也对,就以**已发生的事实**为准改档案,
> 而不是照一句从没生效过的话去重画。新资产一律用这一句。
>
> **只有一句风格句。** 以后改风格,改 `seed_manifest.json` 的 `style_block`
> **并同步这里**;两处不一致时,下一次重画就会和现有美术对不上。

## 字体(硬要求)

**界面字体必须包含中文字形。** 本作的人物名、功法名、教程文案大量使用中文;
引擎默认字体没有 CJK 字形,会渲染成豆腐块。字体文件随仓库提供,
不依赖系统字体。

**字体已入库:`assets/fonts/NotoSansSC-Regular.otf`**(SIL OFL 1.1,
许可证同目录 `LICENSE_OFL.txt`)。挂在一个全局 `Theme` 上作为默认字体,
**不要逐个节点挂 font override**。已核验:本档案用到的 925 个汉字与符号
该字体全部覆盖,缺字数 0。

**界面文字一律中文。** 不要为了让文本放得下而改用英文缩写。
Godot 4.4 + 本仓库字体实测(字号 12):`重剑无锋` **48 px**、
`Heavy Edge` **64 px**、八招里最长的 `黯然销魂十七式` **84 px**,
而技能按钮宽 **104 px** —— 中文全部放得下,英文缩写反而更宽。
「放不下」不是改英文的理由;真放不下就缩字号或改排版,不要用省略号。

## 音频

音效:选择 / 移动 / 命中 / 受伤 / 胜利。背景乐一条。

**音量与全屏可设置,并持久化**(`user://settings.cfg`,ConfigFile):音效默认
**0 dB**、音乐默认 **−10 dB**,两路各在 **−40 ~ +6 dB** 区间内以 **±3 dB** 步进;
全屏默认关。无头环境里只应用音量(纯数据)、跳过窗口模式 API。主菜单「设置」
入口即此屏。

## UI 布局

| 元件 | 位置 |
|---|---|
| 技能栏 | 底部居中,视口内 |
| 暂停按钮 | 右上角 |
| 血条 + 名字 | 悬浮于角色上方,名字在血条**之上**,不叠压 |
| 教程面板 | 屏幕居中,**不透明底色** |

**技能按钮必须显示该招式的发挥度**(失常 / 正常 / 超常 + 乘数)——见
`10_systems.md` §6。

**层级要求**:教程面板显示时,技能栏与其它 HUD 元件**不得叠在它上面**。

## 可读性硬要求

以下每一条都**必须能从一张截图里看出来**。它们是可读性要求,不是美术要求——
状态断言回答"是不是真的",这些回答"玩家看不看得出来是真的"。两者都要过。

2026-08-22 实测:`two_phase_skill_unlock_and_hp_gate` 场景 **20/20 全绿**,断言的是
`SkillButton5..8.disabled == true/false`;而同一局的截图里**八个按钮完全相同**,
连着三个回合、换过两次行动者,一个像素都没变。断言为真,玩家看不见——
这一节就是为了堵这个缺口。

1. **棋盘格子必须可见。** 这是格子战棋,玩家要能看出自己能走到哪一格、谁和谁
   相邻。当前背景整幅山水画盖住了 15×11 的格子,格线一条都看不见。
2. **按钮必须有可见的状态。** 可用 / 禁用 / 冷却中 / 已选中,四种状态**两两之间
   外观必须不同**,并且冷却要显示还剩几回合。只在数据里 `disabled = true` 不算。
3. **当前可做什么必须可见。** 轮到谁、这个回合还能不能移动、还能不能出手、
   剩几格移动力 —— 不能只写在一行文字里,要能一眼看出。
4. **血条要认得出是血条,并且跟着角色走。** 位置锚定在其角色上(随角色移动),
   尺寸不超过一格宽,受伤时长度要变。当前的宽灰矩形连视觉模型都认不出是血条。
5. **任何文本不得被截断或被屏幕边缘切掉。** 当前 `East Her…` `West Poi…`
   `Central D…` `North Be…` `South E…` 五个名字全是截断的,技能栏第 8 个
   `Seventeen Mela…` 被右边缘切掉。放不下就换更短的名字或换排版,不要用省略号。
6. **UI 元素不得互相压盖。** 回合指示当前压在顶栏和暂停按钮上。
7. **角色不得视觉重叠。** 两个单位站得近时,精灵和名字标签都要仍然可分辨。

### 这些怎么被检验

- **几何类**(血条是否跟随、尺寸、是否在视口内、矩形是否相交)→ 写进
  `playtest/<场景>.yaml` 的断言。数字题用数字判,又准又便宜。
- **辨识度类**(格线是否可见、状态是否可区分、文本是否被截断、能否认出是血条)
  → 视觉检查。实测这类问题视觉模型答得准;而**单帧的空间关系问题它答不准**,
  所以不要用视觉去问"A 有没有压到 B"。
- 视觉检查要**跨帧提问**:"换行动者时按钮外观有没有变化"比"这个按钮看起来
  禁用了吗"可靠得多,也更能说明问题。

## 输入映射

| 动作 | 键 | Godot action |
|---|---|---|
| 移动 | WASD / 方向键 | move_up / move_down / move_left / move_right |
| 选择招式 | 1 ~ 8 | skill_1 … skill_8 |
| 确认 / 出手 | J | confirm |
| 结束回合 | Space | end_turn |
| 推进教程 | Enter | tutorial_next |
| 暂停 | Escape | pause_game |

> **回合制改造要点**:Space 从"暂停"改绑为"结束回合",暂停单独归 Escape。
> 旧版 Space 同时绑了 `pause_game` 与 `ui_accept`,是已知缺陷。

## 血条:必须做小(实测结论,不要再推一遍)

2026-08-23,视觉闸门连续三轮判 **0/11**「solid green rectangles, not bars with
empty portions」。逐项渲染验证后的结论:

1. **满血时,只有填充色的血条就是一块纯色矩形。** 底槽必须**始终**看得见。
   做法是给 background 的 StyleBox 加 `set_expand_margin_all(3.0)`,把底槽画得
   比控件矩形大一圈。
   ⚠️ **不要用 `set_content_margin_all` 去内缩填充** —— StyleBoxFlat 的
   content margin 只移动**内容**,从不缩小它绘制的矩形。前两轮的修复方案就是
   这一条,渲染出来逐像素无变化。
2. **位置不是剩下的问题,尺寸才是。** 放脚下 → 读成**站台**;抬到头顶
   (offset −104) → **盖住角色胸口**,还和顶部 HUD 撞,顶排角色更是没有
   headroom 就被视口钳住。两个位置都渲染对比过。
3. **真正的要求:把部件做小。** 现在是 110×30 的控件裹一条 64×12 的血条**外加
   一行名字**,而一个格子才 64px——不管放哪儿都要么当站台要么挡人。
   目标:细条(高 ≤ 8)、小字、整体高度 ≤ 20,放在角色**上方**且不遮挡精灵。

闸门的原话是「**above** or attached to the characters, a bar with a filled
portion and an empty portion」——三个条件缺一不可。

## 美术:整套重画(决定于 2026-08-23)

**现有美术资产数量少、质量不够,不逐条修补,到时候整套重画。**

所以下面这张表**不是待办补丁清单,是重画时的输入规格**——每一条都核实过,
写在这里是为了重画时不必重新发现一遍,也不会把同样的错再画一次。

**重画的前提是风格句只有一句**(见上节)。六张立绘、地形、背景、UI 一次
用同一句出,才谈得上一致;现在这套之所以看着散,一部分原因就是档案里那句
和实际用的那句从来不是同一句。

### 重画的流程:先定妆,再出图

**每个主体先「定妆」一次锁定外观,之后所有图都从那个已定妆的主体出。**

| 步骤 | 做什么 |
|---|---|
| 1 · 定妆 | 六个人物各 `create_character` 一次(道具用 `create_object`),**先看定妆图再往下走** |
| 2 · 出图 | 之后一律 `subject_image(subject, scene)` 出每一张——侧视站姿、其它姿势、将来的头像与事件插图 |
| 3 · 抠图 | `remove_bg` 转成真 RGBA。生图模型画不出 alpha,它会把 PS 那种灰白棋盘格当成**不透明像素**画出来 |
| 4 · 缩放 | 按 3:4 出图再缩到 96 × 128(现有立绘的尺寸) |

**为什么不能继续用「一图一种子」。** 种子保证的是**同一张图可复现**,
保证不了**同一个人在不同图里是同一个人**。现在这六张是各自独立生成的,
所以将来想给杨过加一个出招姿势,等于重掷一次骰子——脸、衣服、比例都会漂。
定妆之后,加一张图只是换一个 scene,人还是那个人。

这也决定了 `assets/seed_manifest.json` 的形状要变:
**主体(已定妆的身份)和图像(从主体派生的姿势/场景)是两层,不是一张平表。**
一个 seed 不再足以标识一个人物。

| 项 | 现状 | 该是什么 |
|---|---|---|
| **杨过的 prompt** | `a young swordsman in deep blue robes holding a heavy iron sword` | **缺"独臂"**。`20_content.md` §1 明写他是**独臂神雕侠**,而 prompt 从没提过,所以出来的立绘是双臂的 |
| **洪七公的 prompt** | `a ragged beggar in faded red robes with a wine gourd` | **缺打狗棒**。丐帮的标志性兵器(见 §2.3 门派表:丐帮 → 打狗棒法),prompt 里只有酒葫芦 |
| **背景图尺寸** | 768 × 588,运行时拉伸到 960 × 704 | **非等比拉伸**(横 1.25 × 纵 1.1973),画面会被拉扁。应按 **960 × 704 原生出图** |
| **战败音效** | 没有。`game_lost` 只调了 `stop_music()` | 战败当前是**静音**的,该有一个下沉的收尾音 |
| **背景乐循环点** | 未设 | 30 秒一圈重头播,接缝听得见 |
| **招式音效** | 31 个招式共用一个 `hit.wav` | 至少按外功门类分几种 |

**背景图还有一条硬约束:必须偏亮。** `grid_lines.gd` 画的是 35% 透明度的深色墨线,
背景一深,格线就消失——而"格子可见"是可读性硬要求第一条。

## playtest 的形状:金字塔,不是长跑

**底层是大量短场景,每条直接把状态「注入」到被测的那一点再断言;
顶层留一条薄脊柱,只断言各段接得上,不断言细节。**

现在反了。`cultivation_changes_combat` 是一条约 3000 帧的长场景:
捏人 → 选门派 → `debug_step_month ×13` → 授功 → 遭遇战 → 打 → 赢 →
`debug_step_month ×21` → 再遭遇战 → 再打,**29 条断言串在同一条时间线上**。
它拿到 13/29,而失败时你分不清是遭遇战坏了、还是快进漂了一帧。

更要命的是**耦合**:场景交换是异步的,所以上游任何一处时序变化,
都会让下游每一条绝对帧号的断言一起失效——这一轮的架构就不得不专门
花一节去「重新基线化」帧号。**一条长场景把每一步都绑在了前一步上。**

**关键的那条改动:DEBUG 接口要从「推进 N 个月」变成「把状态置成 X」。**
累积状态(`debug_step_month ×21`)每一步都可能漂;直接跳(把 Profile 设成
「剑法阶梯已满」)不会。前者是长跑,后者是 setUp。

按这个拆,`cultivation_changes_combat` 变成两条各几百帧的独立场景:
一条注入「阶梯未填」断言伤害 21,一条注入「阶梯已满」断言伤害 30。

**但不能全换成隔离场景。** 一堆隔离场景可以全绿而游戏整体走不通——
那正是本项目反复撞的墙(断言全绿、屏幕全空)。所以脊柱要留,
只是它的职责收窄成**证明接得上**,细节交给底层那些短场景。



## 闸门的接线:哪个闸门跑在哪里(不要「修」回去)

三道 Godot 闸门**全部走 `godot-builder` 边车的 HTTP 接口**,
跑管线的那个容器里**没有 godot 二进制**,将来也不会有。

| 闸门 | 跑在 | 看什么 |
|---|---|---|
| 5_compile | 边车 `/compile` | 整仓 GDScript + `.tscn` 解析 |
| (同一步) | 边车 `/playtest` | 真无头运行 + `playtest/` 契约断言 |
| 5_vision | 视觉模型 | 5_compile 拍下的帧,可读性 |
| 5_test | pytest | **Python** 测试。本仓没有 Python,故不适用 |

**`run_tests.sh` 不要再改成解析本地 `godot` 路径。** 它曾经有一段四级
`GODOT_BIN` 探测(env → 绝对路径 → `command -v` → 报错),四级全部落空,
每一轮都报 `godot binary not found`,而 5_review 每一轮都据此拦下整个 run,
PM 每一轮都派一个实现者去「修 PATH」——**去找一个根本不在这个文件系统里的
二进制**。现在它 POST 给边车。

**GDScript 单元套件从来没有跑过。** `tests/` 下 5 个 `extends SceneTree`
的入口(`unit_test_runner` + `test_save_manager` / `test_game_manager_fsm` /
`test_cultivation` / `test_encounter`)带着另外 12 个静态测试文件,
一次都没有被执行过——因为它唯一的入口是 `tests/test_godot_suite.py`,
而那条路上有**两堵墙**:pytest 的每测 60 秒上限,和 `run_tests` 工具
外层 75 秒的总墙(它跑在调度器线程上,所以必须短)。编译一次就要两分钟,
`test_godot_suite.py` **在结构上不可能通过**,它只会产出假红。

所以那个包装被删了,套件的正确归宿是 5_compile(自己的 1200 秒预算,
同一个边车)。在它接进去之前,**这一层是空的,不要把它当成绿灯**。

### 第一次真的跑起来的结果(2026-08-23,手工经边车 `/script`)

不是「大概能过、只差接线」。第一次执行就有 **5 处真失败**:

| 入口 | 结果 |
|---|---|
| `unit_test_runner.gd` | rc=1,**8 过 4 挂**:`test_gongfa_cascade` / `test_health_bar` / `test_player_profile` / `test_skill_button_states` |
| `test_game_manager_fsm.gd` | **rc=124,120 秒不退出** — 它根本不终止 |

已知的一条具体断言:`test_skill_button_states: Q4: move_pips == "·".repeat(moves_left)`。

这就是「一层从没跑过的闸门」的代价:它不是空着,是**攒了五处欠账**,
而每一轮 5_review 都在读一句「godot binary not found」,以为问题出在 PATH。
接线之前先修这五处,否则闸门一接上就是红的,而那一轮的主题会被它劫持。

### 接线完成(2026-08-24,fix_unit_test_gate_signal)

五项欠账全部修复,`run_tests.sh` **默认运行** GDScript 单元套件:

| 欠账 | 修复 |
|---|---|
| `run_tests.sh` 无 `GODOT_UNIT_SUITE` 时打印 SKIPPED 并以 0 退出 | 删除跳过分支;**空发现 / 空结果集硬失败**(no_tests_collected 永远不可能是绿灯),任一脚本失败即整体非零退出并打印该脚本输出尾部 |
| `test_gongfa_cascade` | 测试自身缺陷:同属性子用例把「刚 A + 柔 前置」当「柔 A + 柔 前置」算 1.3,而实现按设计(`10_systems.md` §4,同属性 = 与**被算功法自身**属性相同)正确给出 1.0。修测试(该子用例改用柔 A),不动实现 |
| `test_health_bar` | 场景几何漂移:`health_bar.tscn` 是 68×21,设计与测试都是 68×20。修场景(68×20、名称标签 9px、条 y=12),标签 9 + 条 8 = 17 ≤ 20 |
| `test_player_profile` | 现码与全部断言一致(防御性 from_dict 已就位),无改动 |
| `test_skill_button_states` | Q4 假玩家改为**带声明属性**的脚本化节点:`in` 运算符对 Object 只能看见声明过的属性,裸 Node 上 `set()` 的动态值对它不可见,于是渲染成「移动 0」。修测试机制,断言意图不变 |
| `test_game_manager_fsm` rc=124 | 加**脚本挂接守卫**(`get_script() == null` 时手动 `set_script`,不再在光板 Node 上硬错误跳 quit())+ **看门狗计时器**(`_run()` 即使中途炸掉,150 秒内强制退出,rc=124 不可能重现)。quit() 在所有路径可达 |

修完的实测状态:`unit_test_runner` 打印 `UNIT TESTS: 12 passed, 0 failed` 且退出 0;
`test_game_manager_fsm` / `test_save_manager` / `test_cultivation` / `test_encounter`
均在各自超时内终止且通过。

## 选了招式之后没法出招(2026-08-23,真人试玩发现)

**现象:**玩家点了技能按钮,按钮亮了,然后就卡住了——不知道怎么把这一招打出去。

**实际的操作链**(从代码和 `playtest/` 契约读出来的):

```
点技能按钮(或按 1–8)  →  selected_skill_index 设上
        ↓
走到射程内(WASD)
        ↓
按 J  或  点敌人   →  出招
```

三层都缺:

**1. 出招键是 J,而屏幕上没有任何地方写着它。**
更糟的是那个动作在 `project.godot` 里叫 `basic_attack`(physical_keycode 74)——
它同时是「普攻」和「放已选招式」的确认键。名字骗人,而且没有提示。

**2. 每一条拒绝都是静默的。** `player.gd` 里「silent no-op / silently ignore」
出现 6 次:射程不够、冷却中、血量门槛没到、招式被封、教程没放行——
**一律什么都不发生,也什么都不说**。玩家分不清「我按错了」和「游戏没反应」。

**3. 选中之后没有任何指示范围/可打目标的表现。**
哪几格能打、有没有敌人在里面,全靠猜。

**这是一个断言查不出来的缺陷。** `fahui_du_multiplies_damage` 10/10 全绿,
因为脚本知道要先 `move_up ×3` 再 `skill_1` 再 `basic_attack`。
机制是通的,**人不会玩**。视觉闸门也查不出——它问的是「看得清吗」,
不是「知道下一步按什么吗」。

**要做的(下一轮):**
- 选中招式后,HUD 显示一行提示:「按 J 出招 / 点击目标」,并在按钮上标出键位
- 每一条静默拒绝都要给一句理由(飘字或 HUD 一行):「射程不够」「冷却中 N 回合」
  「须在半血以下」「本回合无法用招」「本回合已行动」
- 选中后在网格上高亮该招式的可及范围与其中的合法目标
- 把 `basic_attack` 这个动作名改成表意的(它并不只是普攻)

## 断言里必须有比较运算符,否则它什么都没测

playtest 闸门**只在值里含有比较/逻辑运算符**(`==` `!=` `<` `>` `and` `or` …)
时才把它当 GDScript 表达式求值。不含运算符的值被当成**标量字符串**,
拿去和活节点的属性做相等比较。

于是这样写:

```yaml
RoundIndicator.active_text: 'active_text.contains("行动")'
```

实际被求值成:

```
active_text == "active_text.contains("行动")"
```

——把标签文字拿去和「`active_text.contains("行动")`」这一串**字面量**比。
**永远为假,而且不报错。**

两种坏法,后一种更阴:

| 属性类型 | 结果 |
|---|---|
| Array(如 `status_names` / `gongfa_ids` / `traits`) | 报 `Invalid operands to operator ==, Array and String`,至少看得见 |
| String(如 `active_text`) | **静默恒假**,看起来就像功能坏了 |

已发现 5 条这样写的断言,分布在 `round_one_snapshot_and_turn_order`、
`dot_resolves_at_victim_turn_start`、`sect_switch_same_school_connects`、
`trait_combat_effects_and_twelve_slots`。**其中 String 那条一直被当成
「回合指示器坏了」的证据**,而回合指示器可能一直是好的。

**写法:补一个 `== true`。**

```yaml
RoundIndicator.active_text: 'active_text.contains("行动") == true'
```

这也意味着:**一个场景的失败条数,在这些断言修好之前不能当作游戏质量的度量。**

## 那个 120 秒不退出的测试,死在哪

`tests/test_game_manager_fsm.gd` 每次都跑满 120 秒被杀(rc=124),看起来像「慢」。
不是慢,是**炸了之后没人收尸**。

GDScript 的运行时硬错误**中止当前函数,但不中止 SceneTree**。这个测试的
`quit(0 if ok else 1)` 写在 `_run()` 的末尾(第 59 行),`_run()` 在第 46 行炸掉,
`quit()` 永远到不了,进程就一直转到超时。

炸点:

```
SCRIPT ERROR: Invalid access to property or key 'state_changed' on a base object of type 'Node'.
          at: _ready (res://scripts/autoload/scene_manager.gd:68)
          at: _run  (res://tests/test_game_manager_fsm.gd:46)
```

`_gm` 是一个**光板 `Node`**,没有挂脚本。而它上面第 42 行的守卫是:

```gdscript
if _gm == null or _sm == null:
    push_error("... autoloads not found (run with -s from the repo root)")
    quit(1)
```

**守卫检查了不会失败的那件事(节点存在),漏掉了真正会失败的那件事(节点有没有脚本)。**
测试自己的文档注释写着「`-s` 模式下 project.godot 的 autoload 确实会被加载」——
节点这一半是对的,脚本那一半不对,而守卫是照着那句话写的。

`scene_manager.gd:68` 在 `_ready` 里以完全相同的方式失败,所以这不是测试的毛病,
是 `-s` 模式的性质。想在 SceneTree 测试里用 GameManager,只能自己
`GameManagerScript.new()`(文件顶上已经 `preload` 了,一直没用上)。

**两条结构性的教训:**

1. **每个 `extends SceneTree` 入口都必须保证 `quit()` 被调到。** 把断言堆在一个长函数
   末尾再 quit,等于把「退出」押在「一条都不炸」上。
2. **守卫要挡真正的失败模式。** `!= null` 挡不住「类型不对」,而这里能出错的就是类型。

## 存档的混淆函数,从来没算过它该算的东西

同一次运行的 stderr 里刷了上百行:

```
ERROR: Cannot represent 0x9E3779B97F4A7C15 as a 64-bit signed integer, since the value is too large.
   at: hex_to_int (core/string/ustring.cpp:2406)
```

出处是 `scripts/autoload/save_manager.gd:65-67`,splitmix64 的三个常数:

```gdscript
var v: int = x + 0x9E3779B97F4A7C15
v = (v ^ (v >> 30)) * 0xBF58476D1CE4E5B9
v = (v ^ (v >> 27)) * 0x94D049BB133111EB
```

这三个都 **> 2^63**,GDScript 的 int 是有符号 64 位,literal 表示不了,**每次调用都报错**。
也就是说这个混淆函数一直在用错的常数算,**它的输出从来不是 splitmix64**。

`save_load_roundtrip` 场景当时一直是 **9/13**。这大概率就是机制,而不是巧合。

> **2026-08-24 更新:该场景现在是 6/14。** 三条深度相等断言加上非空守卫后不再
> 空对空通过,于是暴露出写盘 `io_error`、读回 `bad_schema`——**存档从来没有成功
> 写进去过**。所以 splitmix64 常数溢出**未必**是同一条因果:它是「报错了但没停」,
> 而 io_error 是写盘失败。不要在没有证据时把两者归因到一起。

**写法**:超过 `0x7FFF...` 的常数在 GDScript 里要写成补码后的负数字面量,
或者拆成高低 32 位。**别指望 literal 报了错还能给你一个能用的值。**

**这条是怎么被看见的**:边车的 `/script` 路由在超时分支里写的是
`rc, out, err = 124, "", "timed out"`——**把已经产出的全部输出扔了**,
而超时恰恰是最需要看输出的时候。`subprocess.TimeoutExpired` 本身就带
`.stdout` / `.stderr`。改成捞回来之后,答案在第一次运行里就全在那儿了。

## 打不赢,是因为先死了——而且死了之后游戏不知道

`terminal_victory_8_12_rounds_hp_15_40` 长期 4/6,失败的两条是
`current_state == "WON"` 和 `health >= 75 and health <= 200`,而
`current_round >= 8 and <= 12` 是**通过**的。前几轮据此判断「节奏是对的,打不赢是伤害不够」,
并推出「单体输出打不完五个人,要聚怪 + 群攻」。

2026-08-24 手工跑了一次全时间线扫描(教程战,26 个采样点,f100 → f1100):

```
f620  round=7   hp=177
f660  round=7   hp=129
f700  round=8   hp=55
f740  round=9   hp=35
f780  round=10  hp=1
f820  round=10  hp=0   active=Central Divine  phase=ENEMY_TURN
f860  round=10  hp=0   active=Central Divine  phase=ENEMY_TURN
f900 / f940 / f980 / f1020 / f1060 / f1100  ——  八个连续采样点完全相同
```

那个「第 8–12 回合」不是打赢所需要的回合数,**是输掉所需要的回合数**。

而更要紧的是后半截:**血量归零之后,战斗没有任何状态转移。** 没有 LOST、没有结算、
没有 `end_battle`,phase 停在 `ENEMY_TURN`,当前单位一直是中神通,一直到扫描结束。

这不是「失败路径没写」:`tutorial_loss_restarts_tutorial` 现在 5/5 全绿,
而出问题的这一局**就是教程战**(同样的 7× `ui_accept` 前导)。失败路径存在、在别处跑得通,
在这里没触发。

**推测(未验证,先证再改)**:`combat_manager.gd` 的 `_begin_round` 从
`GameManager.get_player()` 加 `get_enemies_alive()` 建回合序,并剔除 `health <= 0` 的单位。
玩家血量为 0 时被剔出回合序,但敌人还活着,于是 `_turn_order_units` 不为空、
`empty_round_stalls` 不自增、那条「无人可行动」的 `push_error` 也不触发——
战斗就这样静悄悄地永远进行下去。胜利路径是 `unregister_enemy()` → `end_battle(true)`
在 `enemies_alive` 清空时触发;失败路径大概率缺少对称的那一半。

**这条压在所有战斗平衡讨论的上面。** 在它修好之前,任何「伤害够不够、要不要聚怪」的结论
都建立在一个不会结束的战斗上。

## 这一局里,毒从来没有被施加过

同一次扫描,26 个采样帧里 `Player.status_names` **一次都没有出现 `poison`**——
出现过的只有 `init_minus_20`、`no_techniques_next_turn`、`no_move_next_turn`、`[]`。
西毒从头到尾没有用过灵蛇缠身。

于是 `dot_resolves_at_victim_turn_start` 这个场景断言的「西毒中途施毒 → 玩家下回合开始跳伤」,
**它要求的两个帧根本不存在**。

代价是具体的:jinyong-winnable 那一轮的 `repin_dot_timing` 连续四次交付失败,
每次都交出加密的扫描脚手架。看起来像实现者不肯收尾,实际上它在找一个没发生过的事件,
永远收敛不了。轮次预算从 15 提到 24 也没有改变任何事。

**教训:一个场景连续多轮修不好的时候,先问它要求的状态是不是真的会出现,再问实现者为什么做不到。**
这是本档案里第三次记同一件事(前两次是 `two_phase` 要求满血时按钮 8 可用、
`each_unit_acts_once` 要求第 2 回合杨过先手)。**断言的前提出错,比断言的数值出错更难发现,
因为它每次都失败得很有道理。**

