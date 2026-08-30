# Presentation

## 分辨率与拉伸

分开说四件事,别再写成一条链:

- **视口是显示尺寸**:基准视口 **960 × 704**。`project.godot [display]`:
  `window/stretch/mode = "canvas_items"`、`window/stretch/aspect = "keep"`、
  `resizable = true`。窗口缩放时棋盘等比填满,外侧由引擎黑边补齐。
- **棋盘是内容尺寸**:`GRID_WIDTH × GRID_HEIGHT × TILE_SIZE = 15×11×64 =
  960 × 704`,由 `GridManager` 常量(`GRID_*/TILE_SIZE/GRID_ORIGIN`)与
  `board_rect()` 派生。**棋盘不再受视口约束**——它现在可以比视口大,
  也可以比视口小(见 `90_decisions.md` 2026-08-28 条)。
- **背景覆盖棋盘**:`SummitBackdrop` 按 `GridManager.board_rect().size` 铺满
  棋盘矩形(见 `battlefield.gd::_fit_backdrop_to_board`,读 `GridManager`,
  不再用镜像常量)。
- **可见性归相机**:取景上限来自**跟随 Camera2D**(`scripts/camera_follower.gd`),
  不来自视口。棋盘装不进视口时由相机负责把行动单位框进 HUD 顶栏与招式栏之间
  的未遮挡带——「整盘看不全」是正常取景,不是缺陷。

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
| 顶栏 (TopStrip) | 全宽 0..92 px,半透明深色底(`mouse_filter=2`,画在所有顶部件之后),回合数 / 行动条 / 出手顺序 / 技能提示 / 内力全收在带内,两两不叠压 |
| 技能栏 | 底部居中,视口内 |
| 暂停按钮 | 右上角(坐在顶栏上) |
| 结束回合 / 出招 / 技能说明 | 顶栏下方右侧 |
| 血条 + 名字 | 悬浮于角色上方,名字在血条**之上**(有半透明底),不叠压;血条随单位经**含相机的** canvas 变换(`Coord.world_to_screen`,见 `## 坐标变换`)投射到屏幕;顶栏遮挡带 `0..T` 由相机取景负责避开 |
| 教程面板 | 屏幕居中,**不透明底色** |
| 捏人屏 | 三阶段(捏人 / 特质 / 确认)内容整组在 **x=480 轴上居中**;每行 shrink-center(AttrLabel 最小宽贴文字;AttrRow0..4 / AttrNavRow / TraitNavRow / TraitToggle0..12 `size_flags_horizontal=4`);描述文字居中(AttrDescLabel / TraitDescLabel `horizontal_alignment=1`)。**属性页信息层**:AttrDescLabel 静止即全列五属性效果(名称前缀,逐字复用 `creation.gd::_ATTR_DESCS`);其正下方 `HpValueLabel` 显示当前气血(`气血 = 根骨 × 5` 的活值,仅 ATTRS 可见)。**确认页**:`ConfirmBox` 内 `ConfirmSummaryLabel` 列五项最终值(每行「名 值」),位于两个按钮之上,仅 CONFIRM 可见 |
| 移动提示 (MoveHintLabel) | 跟随玩家所在格,在脚下 +44 px 处,中文状态跟随文案(左键点格移动 · 右键退回 / 右键退回起点 · 出手即确认 / 已出手 · 移动已确认),`mouse_filter = 2`(不拦截点击)。状态机 idle / undo_ready / committed / hidden 是既有引擎字段的纯函数;文案必须在锁定移动的**同一个转移**里换掉,不许留一条已经不成立的承诺。`move_target_affordance.yaml` 把 idle / undo_ready / committed(含退回后回 idle)三态文案钉住 |

**技能按钮必须显示该招式的发挥度**(失常 / 正常 / 超常 + 乘数)——见
`10_systems.md` §6。

**层级要求**:教程面板显示时,技能栏与其它 HUD 元件**不得叠在它上面**。

**顶栏与捏人屏(2026-08-25 落地)。** 战斗顶部的五样信息(回合数 / 行动条 /
出手顺序 / 技能提示 / 内力)收进一条全宽半透明底顶栏,两两不叠压;
`ActionHintLabel` 从底部中央移入顶栏(只移位置,节点名与路径不变)。捏人屏
(捏人 / 特质 / 确认三阶段)统一成**一套竖向骨架**:44 px 等高属性行、
数值右对齐贴住本行的 `-`/`+` 簇、`PointsLabel` 贴块上方、确认按钮固定宽居中,
三阶段同一条节奏。

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

### 角色立绘可见性断言（2026-08-25, jinyong-affordance 轮次）

`visible == true` 是必要条件,不是充分条件。立绘的「在渲染帧上可见」=
六层检查,见 `scripts/ui/visibility_probe.gd` 的 `VisibilityProbe` 类:

1. `hidden_in_tree` — `visible` 标志链
2. `null_texture` — 纹理资源存在且非空
3. `blank_texture` — 纹理资源里没有任何 alpha > 0 的像素(资产级扫描,fail-open 失败开放;NEW — jinyong-events 轮次新增)
4. `zero_rect` — 几何区域面积 > 0
5. `off_viewport` — 与视口相交
6. `clipped` — 不被祖先 `clip_contents` 裁剪
7. `occluded` — 不被后绘制的 Control 完全包住
8. `covered` — 被后绘制的不透明 Control 部分遮挡 ≥ 25%(且 ≥ 64 px²;NEW — jinyong-events 轮次新增)

阈值常量:`COVERED_AREA_FRAC = 0.25`、`COVERED_MIN_PX = 64.0`。`covered` 层只在
被后绘制的不透明 Control 部分遮挡墨迹区 **≥ 25%(且 ≥ 64 px² 绝对下限,压过抗锯齿
噪声)** 时才红,取的是**最坏单个**后绘制不透明宿主的遮挡比例(**max-single-coverer
语义**——重叠的覆盖者从不求和,简单、确定、单调)。公开辅助函数
`VisibilityProbe.covered_fraction()` 返回该比例(0.0 = 无合格覆盖者),探针与
`portrait_covered_frac < 0.25` 守卫读同一个数。

八层全部通过,立绘才算「看得见」。`playtest/portrait_visibility.yaml`
断言了全部六个单位的 `portrait_visible == true`。

> **可见性归相机(2026-08-28, camera-owns-visibility)。** 相机移动后,
> `VisibilityProbe` 的 `off_viewport` 与 `covered` 两层语义改变:它们是
> **取景事实,不是精灵缺陷**——一个立绘出视口或被顶栏盖住,现在是相机把
> 行动单位框进未遮挡带时的正常取景,不再说明精灵摆错了位置。这两层**不再
> 裁定立绘对位**。裁定立绘对位的是新 pin `playtest/portrait_grid_alignment.yaml`
> (`abs(ink_world_dx) <= 1.0`、`abs(ink_world_dy) <= 1.0`,立绘站在自己的格子上,
> 含玩家走到最北一格后的走位腿)。`playtest/portrait_visibility.yaml` 已改写为
> **相机级闸门**——断言「当前行动单位处在未被遮挡的可见区内、相机钳在无空白
> 范围内、跟随目标是活跃单位」(全部经 `Camera:` surface 块发布),不再断言
> 精灵级属性。改写理由:可见性是相机/布局拥有的属性,不是精灵的;一条只能靠
> 改动引擎本该自己算的 `offset/position/size/z-order` 来满足的闸门,该删的是
> 闸门(见本节的通用规矩)。探针类仍可作他用,但其断言角色在本闸门中已被取代。
>
> **两条原则(2026-08-28)。** (a) **可见性由相机拥有,精灵只负责站在自己的
> 格子上,二者不得互相代偿**——为此删掉 `GridManager.clamp_sprite_offset` 与
> 它逼出来的补偿机器(见 `## 定位章 — 相机拥有可见性`)。(b) **闸门断言游戏级
> 属性,不断言引擎级属性**:一条闸门只能靠改动引擎本该自己算的东西
> (`offset/position/size/z-order`)来满足,那要删的是闸门,不是调精灵。
>
> **形态闸门必须自我解释(2026-08-29, facility-result-pin)。** 凡是白名单式、
> 逐字式、枚举式的断言,落笔前先问一句:「一次合法的改动会不会让它变红?」会,
> 就要么改成按性质/按符号表达,要么在失败信息里写明正确的修法。一道不能自我
> 解释的形态闸门,下一轮不会去修它,只会绕开它——那时它挡住的是重构,不是
> 缺陷。记因:上一轮 `tests/test_facility_copy_location.py` 把 `ENDING_TIERS`
> 的结局文案写进白名单,既赦了它本要拦的既存违规,又保证改一个字就红——同一
> 根因。本轮三条逐字防删钉(`phase != "FACILITY"`、`facility_use_count == 0`、
> `facility_result_text: changed`)的失败信息据此都带逃生说明:「若你在改名或重写
> 这条断言,请在**同一次改动**里更新本钉以匹配等价新断言——不要为变绿而保留
> 一行死旧的场景文本,也不要绕过合法改名」。

> **判据由六层扩到八层(2026-08-25, jinyong-events)。** 本轮在 `null_texture` 之后
> 插入 `blank_texture`(资产级 alpha 扫描,失败开放——`get_image()` 拿不到就当通过),
> 在 `occluded` 之后插入 `covered`(部分遮挡 ≥ 25% / ≥ 64 px²)。旧 `occluded` 只认
> 完全包住,漏掉了被顶栏部分遮挡的王重阳立绘;`covered` 层修上后,
> `portrait_visibility.yaml` 22/22 全绿。

**为什么要六层(2026-08-25,jinyong-affordance)。** UX-01 报告「王重阳与杨过立绘不在画面上」,
而 `visible` / `sprite_top` 等既有断言一直是绿的——`visible == true` 看不见裁剪、看不见
零尺寸、看不见出屏、看不见被后绘制的 Control 盖住,也看不见纹理为空。六层谓词把
「在渲染帧上可见」变成可判定的事实,红的时候报的是**哪一层**(`portrait_fail_layer`),
不只是「否」。

**实测结果(2026-08-25 闸门)。** 六个单位全部六层通过——「两个单位不可见」是人工读帧误判
(`portrait_visibility.yaml` 10/10,六单位 `portrait_visible == true`、`portrait_fail_layer == ""`)。
探针本身(godot-builder HTTP 500 ×9,后是本轮自身的 `Canvas` 编译错)从未落下修前实测值;
按「先查明再修、不许猜」规则修集为空,判读的实测依据是修后闸门运行,不是探针读数。

## 坐标变换(2026-08-28,camera-owns-visibility)

相机一移动,世界↔屏幕映射就不再是恒等。唯一正确的映射是
`Viewport.get_canvas_transform()`——**Camera2D 就写在这里**,它是「世界→视口」。
它的入口只有 `Coord.world_to_screen(world, vp)` 与
`Coord.screen_to_world(screen, vp)`(`scripts/coord.gd`,分别 =
`vp.get_canvas_transform() * world` 与 `vp.get_canvas_transform().affine_inverse() * screen`),
`player.gd` / `enemy.gd` 的点击入口、`health_bar.gd` 的跟随、follower 发布的
`active_unit_screen_y` 全部走它。

`Viewport.get_final_transform()` 是「视口→窗口像素」——**只有 stretch,没有相机**,
**不得用于世界↔屏幕**。旧 `health_bar.gd::follow_character` 曾用
`get_final_transform()` 做世界→屏幕,那是错的(相机一动,血条/名牌就停在原地
不跟人走);本轮改为 `Coord.world_to_screen`,并删掉它那段「final transform 合成
含相机的 canvas transform」的自我辩护注释——`get_final_transform()` 根本不含相机,
那句注释是替缺陷辩护的散文。

点击路径 `player.gd` / `enemy.gd` 的
`get_canvas_transform().affine_inverse() * event.position` **本来就对**(含相机),
`playtest/_common.yaml` 把这一形状记为实测契约;本轮只修了 `health_bar.gd`。
harness 侧读 Node2D 点击锚用 `get_global_transform_with_canvas().origin`(相机感知),
故无需改动。

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
| 移动(主) | 左键点空格;点敌格 = 攻击,点自己格 = 无操作 | (鼠标) |
| 退回本回合移动 | 右键(出手 / 结束回合后拒绝) | (鼠标) |
| 移动(快捷) | WASD / 方向键 | move_up / move_down / move_left / move_right |
| 选择招式 | 1 ~ 8 | skill_1 … skill_8 |
| 确认 / 出手 | J | confirm |
| 结束回合 | Space | end_turn |
| 推进教程 | Enter | tutorial_next |
| 暂停 | Escape | pause_game |

> **回合制改造要点**:Space 从"暂停"改绑为"结束回合",暂停单独归 Escape。
> 旧版 Space 同时绑了 `pause_game` 与 `ui_accept`,是已知缺陷。

### 大地图(map 段)(2026-08-29 补记;`use_facility` 为 jinyong-facility 轮新增)

地图段是**键盘驱动**(无鼠标点击目标),事件与设施面板共用 `ui_accept`:

| 动作 | 键 | Godot action |
|---|---|---|
| 选择相邻节点 | 方向键(左右 / 上下) | move_left / move_right / move_up / move_down |
| 启程去相邻节点 | Enter | ui_accept |
| **进入门派设施** | **F** | `use_facility`(仅 facility 槽 `active` 的节点——现少林 / 武当;到达**永不**自动进入) |
| 设施面板:使用一次 | Enter | ui_accept |
| 设施面板:离开 | ↓ / ← | move_down / move_left |
| 事件面板:选择 / 定夺 | 上下 / Enter | move_up / move_down / ui_accept |
| 注入银两(调试) | —(debug-only) | `debug_grant_silver`(经 `EventLogic.apply_option_effects` 正常管线,不直改字段) |

### 战斗命中的 5 步优先级规则(2026-08-28,interaction-defects)

左键点击世界点 `P` 在 `player.gd::handle_world_click` 内按以下顺序解算:

1. `T = GridManager.world_to_grid(P)`,存活敌人占据 `T`(脚格)→ 攻击该敌人;
2. 画出的立绘矩形(`portrait_ink_rect`,未钳位墨迹 = `[feet.x−48, feet.y−128] .. [feet.x+48, feet.y]`,
   `PORTRAIT_TEX_Y`=128、纹理宽 96、offset 恒为脚锚 `(0,−tex.y/2)`)
   包含 `P` **且该敌人在攻击射程内**(in-reach)→ 攻击最近的那个(按 `grid_pos` 距离
   决胜)——本步闭合「贴身敌人打不到」的缺口;
3. `T` 是移动范围高亮中的可达空格 → 走过去(高亮仲裁:玩家看得见谁赢);
4. 立绘矩形包含 `P` 但敌人 **out-of-reach** → 选中(不静默移动);
5. `T` == 自己脚格 → 无操作;否则移动过去。

硬约束:**out-of-reach 敌人的立绘矩形永远不能把一个可达空格变得点不到**——
被否的 grid→rect→move 规则(先格子、再立绘矩形、最后点击移动)正是死在这上面
(顶行王重阳被钳制的立绘盖住 (7,2)/(7,3),三个上移场景被解析成攻击而全红,
实测 10→6 / 9→1 / 18→11,记录于 `90_decisions.md`)。重叠矩形的决胜键是按
`grid_pos` 距 P 最近;`attack_reach_covers` 为纯静态谓词,headless 单元可测。

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

> **2026-08-25 修订(原生尺寸重验)**。旧数字「细条(高 ≤ 8)/ 整体高度 ≤ 20 / cap 6 px / expand margin 4」是在**对比放大尺度**下推出的,按历史保留;在 **960×704 原生帧**上重验后修订:条高 **12**、部件 **68×24**、空尾 **10 px**(空槽面积 120 px²,×2.5)、槽体光环 **6 px**、悬浮偏移 **−32**(悬空 8 px 不变)。原因:960×704 原生帧上 48 px² 空尾 + 8 px 条仍被视觉闸门读成 solid green(Q5 17/26);playtest 信封 `total_height <= 26` 本就允许,动的只有文档数字。
>
> **运行时注记(2026-08-25 实测)。** `ProgressBar` 一进场景树,Godot 就把
> `size.y` 抬到主题最小值(约 **22 px**)。于是战斗场景探针读到的是
> 条高 ≈ 22 / 空尾面积 ≈ **220 px²**(修前 ≈ 132),而 authored 的
> **12 px / 120 px² 只在 tscn 与无头单元测试路径上成立**;两条路径都绿,
> 运行时真正变过的量是空尾宽度 6 -> 10。要改条高,只改 tscn 并同步
> `tests/test_health_bar.gd`,**不要照运行时读数回填 tscn**--那是在把
> 引擎的钳制当成设计。

**2026-08-26 Q5 status (jinyong-events fix round).** The 5_vision gate judged 4/47 scenarios
(all full-HP battle frames) before failing with IncompleteRead; the primary endpoint was
unreachable (blind:true). The 4 Q5=NO answers ("bars are fully filled / no empty portion")
are consistent with the documented 78–100% HP flattening design (health_bar.gd:38-43). Zero
injured frames were judged. The classification (real defect / full-HP-only applicability /
fallback-model limitation) remains PENDING. No code change to health_bar.gd (EMPTY_CAP_PX 14.0,
expand margin 8.0, EmptyCap rect all unchanged). The next 5_vision gate run (with the retry fix
applied on the gate side) will produce the real verdict.

> **2026-08-30 收口(touch-reach 轮官方闸门).** The follow-up 5_vision run has since
> executed **non-blind** (judge `localqwen/qwen3`, 71 scenarios / 284 frames, `passed: true`):
> Q5 answered **39 good / 0 bad** over all judged battle frames (32 not-applicable) — the
> gate-level「bars recognisable」concern did not reproduce. The finer full-HP flattening
> classification remains an eyes-on observation only (the gate flagged no injured frame;
> zero code change to health_bar.gd, EMPTY_CAP_PX 14.0 / expand margin 8.0 / EmptyCap rect
> all still unchanged).

> **2026-08-26 wording alignment (docs only, `align_vision_gate_wording_v2`).** The repo's
> recorded Q5 description (`final/verify_report.json`, `README.md`) now reports the gate state
> honestly: the gate **did not judge** (4/47 scenarios, all full-HP, zero injured) — not "Q5
> FAILED", not a "19/28" count (that figure is not independently confirmable from the on-disk
> artifact), and no claim that the primary endpoint was "repaired". The Q5 question text itself
> lives in the godot-builder `/vision` gate config (outside this repo); the recorded repo text is
> kept aligned to the gate's actual question so the two cannot drift. Per the 78–100% HP
> flattening design, the "empty portion" condition in Q5 has meaning only on non-full bars; a
> full-HP bar rendering ~78–82% filled is still recognisable as a health bar. Docs alignment only —
> no code change to `health_bar.gd`.

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

## 战斗 HUD 说人话(2026-08-26,jinyong-hud 轮)

### 技能按钮信息层(UX-03 / UX-04)

技能按钮保持 **104×48** 不变,新增两个信息 Label(只改新增节点的矩形,不改
HotkeyLabel / StateTag / CooldownLabel 等被钉住的子节点矩形):

| 节点 | 位置 | 字号 | 对齐 | 内容 |
|---|---|---|---|---|
| `CostLabel`(新增) | 顶部带 (26,2)-(62,14) | 9 | 居中 | 内力消耗:`cost == 0` → 「无消耗」;`cost > 0` → 「内力 N」。数值只取自既有 `SkillData` |
| `InfoLabel`(新增) | 右下 (56,34)-(102,46) | 8 | 右 | 上下文案切换:锁定(5–8 格,第 4 轮前)→ 锁定原因「第 4 轮解锁」;否则 → 效果摘要 `effect_summary_text` |

- **内力不足(`no_energy`)按钮状态:本轮已实现、当前内容不可达。** 调色板**已加第 6 个状态**
  「内力不足」——浅紫 `bg (0.72,0.62,0.92)`,raw BT.709 亮度 **0.6629**,与 ready (0.3874) /
  cooldown (0.0814) / phase_locked (0.5306) / hp_gated (0.2020) / waiting (0.1558) 五个状态
  亮度差均 **≥ 0.10**;标签「内力不足」区别于「锁定」。`hud.gd` 的 disabled 推导已含
  `no_energy` 项(`phase_locked or on_cooldown or hp_gated or no_energy`),state 优先级链
  `phase_locked > cooldown > hp_gated > no_energy > ready`(waiting 覆盖最后)由
  `skill_button.gd::derive_state()` 单一事实源实现。**当前内容下不可达**(每一 `SkillData.cost == 0`),
  仅由单元测试 `tests/test_skill_button_no_energy.gd` 证明——刻意不写任何伪装它在实战中触发的
  playtest 断言。当养成轮定义真实招式消耗后自然激活。**已激活(2026-08-27,jinyong-spend-qi 轮)**:
  真实招式消耗已定义(`20_content.md` §1/§7),`no_energy` 现已在实战中可达,并被新 playtest 场景
  `qi_cost_blocks_cast_no_energy` 钉住——真实内容,非伪装断言。
- **锁定原因派生自同一谓词**:只有 `CombatManager.tutorial_battle and i >= 4 and
  current_round < 4` 时 `lock_reason_text` 非空;遭遇战 / 第 4 轮起为空,绝不写死一条
  常显字符串。
- **无省略号纪律**:新增 Label `clip_text=false`、`text_overrun_behavior=0`;放不下就
  缩短摘要(效果摘要 ≤ 6 个中文字符),绝不宽进被钉住的兄弟矩形、绝不用省略号。

### 血条数值(UX-05)

`HpLabel` 作为 `Bar` 的子节点(沿用 EmptyCap 先例),锚定 Bar 全矩形 (0,0)-(64,12),
居中,`clip_text=false`、`text_overrun_behavior=0`、`mouse_filter=2`,绘制为
Bar 的最后一个子节点(盖在填充与 EmptyCap 之上)。

**血条只显示当前值,不显示 cur/max(2026-08-26, fix_hp_number_readability_v2)。**
64×12 的条上放不下 9 个字的「1000/1000」——字号 7–8 时笔画黏连,再怎么调颜色也读不清。
路由 (a):条上只渲染当前值(如「400」,最多 4 个字),字号 10、**浅色字(0.95)+
强深色描边(outline_size 4)+ 深色阴影 2**——满足「强深色描边(outline_size ≥ 3)」约束;
满值 / 受伤时数字都压在条上,靠深描边在亮绿填充与黄填充上保持可读。`max_health`
经 `hp_max` 观测量 / 悬停 / 选中说明暴露,不画在条上。`hp_text` 即 `str(current)`,
`hp_value` / `hp_max` 语义不变,`hp_text_width_ok` 对条宽 64px 实时重算——只有
渲染宽度真正装得下时才是 true。

**`health_bar.gd` / `health_bar.tscn` / `tests/test_health_bar.gd` 的几何常数一律不动**
(68×24 部件、Bar 64×12 @(2,12)、`EMPTY_CAP_PX`、expand margin、`STRIP_BOTTOM`
全部逐字节不变),本轮只改 `HpLabel` 的文字格式与样式(字体 / 描边 / 阴影),不碰冻结常数。

### 捏人信息层(2026-08-27,jinyong-clarity 轮)

**D1 · 属性描述槽改为静止即全列五属性效果。** `AttrDescLabel.text` 从「焦点属性的
说明」(`_attr_desc(ATTR_KEYS[attr_index])`)改为「五项效果,名称前缀,逐字来自
`creation.gd::_ATTR_DESCS`」(即 10_systems.md §1 + 40_progression.md §7)。原因:
UX-06 是从静止页记录的,「焦点跟随显示」会让静止页原样保留缺陷。`attr_index` 仍驱动
行焦点高亮与 +/- 目标,只改描述通道的语义。被否方案及理由:
- **行内效果 Label**:新 Label 会把 `_row_ink_union(i)` 的墨迹 x-center 推偏约半宽,
  超过 `attr_cluster_center_ok` 的 ±6px 钉;
- **行间插入 5 行效果**:AttrBox 越过 `creation_box_fits` 预算(5×44 行 + 48 描述 +
  44 导航 + 间距已占 372/480,再 +5 行×17+间距 ≈ +135px → 底 ≈614 > 584);
- **扩展行标签文字**:破坏「数值右对齐贴住本行 -/+ 簇」的钉死节奏。
(记作决定而非疏忽,供后续轮次查阅。)

**D3 · points_attrs_gap_ok 的 CONFIRM 簇重指。** 该可观察量的 CONFIRM 分支原把
「首行墨迹簇」解析为 `ConfirmButton` 的矩形;确认页新增 `ConfirmSummaryLabel` 位于
按钮上方后,改指 `ConfirmSummaryLabel.get_global_rect()`(缺失时回退旧 ConfirmButton
查找,`get_node_or_null` 哨兵)。**同名可观察量、同一批 yaml 断言行不变**——先例是
jinyong-layout-r2 的 Round-3 重做(测的量变了,变量名与 yaml 行不变)。墨迹诚实性:
VBox 内该标签矩形顶 == 首行墨迹顶,`horizontal_alignment=1` 使每行居中 ⇒ 矩形中心 ==
墨迹中心;gap 检查读的 (top y, center x) 两个合取项因此都是墨迹事实。

## 悬浮 HUD 不许吞点击:mouse_filter 审计表(2026-08-28,interaction-defects)

`scenes/ui/health_bar.tscn` 全子树逐节点实测(`Bar` 的修复此前已 A/B 实测落地):

| 节点 | mouse_filter | 备注 |
|---|---|---|
| root `HealthBar` | 2 (IGNORE) | 原有 |
| `Bar` (ProgressBar) | 2 (IGNORE) | 本轮缺陷 A 的修复 + 每帧重断言 |
| `EmptyCap` | 2 (IGNORE) | 原有显式 |
| `HpLabel` | 2 (IGNORE) | 原有显式 + 每帧重断言 |
| `NameLabel` | 2 (IGNORE) | **无显式声明,靠 Label 类默认 IGNORE**(2026-08-28 闸门后勘误:交付的 `health_bar.tscn` 没有这一行,「本轮已补显式声明」系记载错误;运行时非 STOP,子树无洞的结论不变) |

——全子树无 STOP:一个悬浮在角色身上的 HUD 控件,不许有任何一个是 STOP 的后代。
`scripts/ui/health_bar.gd` 在 `update_health` 里对 `Bar`/`HpLabel`/cap 三个每帧重断言。

**敌人 `ClickTarget`(`scenes/enemy.tscn`,`mouse_filter=2` IGNORE)的裁定(2026-08-29 闸门实测收口):**
计数器已落进 `scripts/characters/enemy.gd`(声明 + `_input` 中继里在按键守卫之前自增,度量的
正是「gui_input 到底会不会触发」),且 `input_click_differential.yaml` 的
`debug_click_target_fires == 0` 那条腿**就是这条实测**。终局裁定(本轮 `5_compile` 的
`playtest_summary.md` 实测 `input_click_differential` **13/13**,该腿转绿):**IGNORE 已落**——
gui_input 不触发、计数器恒 0,点击路径是单位 `_input` 中继;STOP 侧的反例实测(计数 == 1,
控件吃掉按下)见 `final/delivery_notes_fix_clicktarget_ignore.md`。时序勘误链:首版勘误写
「实测 0 次」时计数器尚未落地(闸门实测 12/13,该断言报 `Invalid named index`);修复轮
计数器落地但仍 STOP(12/13,实测 == 1);camera-owns-visibility 轮上报红因;本轮落
`mouse_filter=2` 并由闸门复跑收口。节点**保留**,但只作为 `debug_click_target_fires` 路由
计数器的载体,**不再是 playtest 的点击锚**——`mouse_filter=2` 下 harness 对它 aim 会硬失败,
场景一律锚单位自身 Node2D 名字(裁定见 `90_decisions.md` 2026-08-29 条;旧文「保留为
harness 点击锚、`mouse_filter` 留原值零 diff」的后半句由该条作废)。

## 名牌挂到立绘顶端 + 地面标记(2026-08-28,interaction-defects;几何修复 fix_geometry_overlap_rebaseline)

`health_bar.gd::follow_character` 的锚点从脚底 `+(-34, -32)` 改挂**立绘顶端**:
`screen_pos = Vector2(char_x - 34, sprite_top - 4.0 - size.y)`(血条底边在
`sprite_top` 上方 4px)。`STRIP_BOTTOM` 仅作血条**内部地板常数**保留(几何冻结);
立绘头顶是否落进顶栏**是相机取景问题**,不归血条/立绘负责——本轮已量得并记为
已知接受代价(见 `## 定位章 — 相机拥有可见性`)。

**名牌翻转规则(2026-08-28,`bar_anchors_below_portrait`):** 未钳位时
`sprite_top = feet − 128`(行 1 为负,`feet = 32+64 = 96` → `sprite_top = −32`),
上锚点 `sprite_top − 4 − size.y` 落在负值区、会在顶栏带 `0..T` 之下,把名牌钳回
脸上。规则**翻到立绘另一侧**:把名牌**顶边**挂在 `portrait_ink_rect.end.y + 4 =
feet + 4`(行 1 = `96 + 4 = 100`),即立绘墨迹底下方 4px、落在单位**自家格**上。
`bar_anchors_below_portrait == true` 表示翻侧;中排单位走正常上锚
(`== false`)。理由(与钳位无关):立绘墨迹从脚格向上/外延伸超出 64px 格,
可读控件悬于头顶、避开顶栏带 `0..T`,翻转落点 = 单位自己脚底 + 4,是诚实的
「站这里」。这是防御性兜底,不是本轮缺陷的修复;对位由 `portrait_grid_alignment`
负责,名牌只要不盖脸、不进顶栏即可。

**名牌自带子布局(2026-08-28 几何修复):** 部件此前报告 68×24 而子节点量出
30+22=52px 墨迹,溢出底缘且互相压 18px。现在 `_relayout_children()` 压缩主题通胀
**源**(Bar 的 `ProgressBar minimum_height` 主题常量、NameLabel 底板 StyleBoxFlat 的
上下 content margin 2.0→0.0),再**实测**子节点高度、把 Bar 严格排在 NameLabel 下方、
根高取两者实测和(12+12=24)。根高永远来自实测子节点和,子高不许写死字面量。
`tests/test_health_bar.gd` 的 `NameLabel.size.y + Bar.size.y <= total_height`(第 137 行)
转绿即此不变式。

**SkillDescLabel 让位(2026-08-28 几何修复):** 名牌抬到顶 + UndoButton 轮把
`SkillDescLabel` 下移后,右栏翻侧名牌(顶 224,NameLabel ≤ 26 高 → 底约 250)曾落进
`SkillDescLabel`(x≥608,y 216..396) → `hint_nameplate_overlap == true`。把
`SkillDescLabel.offset_top` 216→280 **且底 396→384**(现框 `offset_left −352 / offset_top
280 / offset_right −8 / offset_bottom 384`,344×104,仍全在 704 视口内),翻转名牌底
250 < 280,解除真实压盖(可读性硬要求第 6 条);`ui_geometry_readability` 的
`hint_nameplate_overlap == false` 断言**原样保留**,不是放宽。`follow_delta <= 24`
两条腿(f30/f85)同样原样保留、`ui_geometry_readability.yaml` 一行未改、无 re-baseline
——翻转(`bar_anchors_below_portrait`)已使顶行位移归 ~0,无需放阈值。

**中排/顶行落地(未钳位几何):** 中排单位(如玩家 (7,5),`feet = 352` →
`sprite_top = 352 − 128 = 224`)严格在上方(`bar_bottom < sprite_top`,gap ≥ 4px);
顶行单位(行 1,`feet = 96`)翻侧后 `bar_top = feet + 4 = 100`,落在自家格上。
`health_bar_above_portrait.yaml` 的断言已按未钳位几何重新推导
(中排 `portrait_bar_pos.y > sprite_top + 40.0`、翻侧 `bar_anchors_below_portrait`
钉),不再引用被删的钳位位移。

**地面标记 `TileMarkers`**(`scripts/ui/tile_markers.gd`,Node2D `_draw`,挂在
`scenes/battlefield.tscn` 中 `Characters` **之后**):为每个存活单位在
`grid_to_world(grid_pos)` 画低透明度扁椭圆 + 细金边,标记「他站哪格」。必须挂在
角色之后:逐单位 `_draw()` 先于子 Sprite2D,顶行立绘会把自己的脚标盖掉——实测
`TileMarkers` 对全部六个单位(含顶行)可见,且 Node2D `_draw` 无 GUI 参与,天然不吞
点击。**保留理由(与垂直对位无关):** 立绘 **96px 宽 vs 64px 格**,未钳位也**横向
外溢相邻格子**;地面椭圆标记该单位**占据哪一格**——「可点的脚在这里」,与垂直对位
(`portrait_grid_alignment`)无关。

## 定位章 — 相机拥有可见性(2026-08-28,camera-owns-visibility)

**行 0-2 重新合法。** 删掉 `clamp_sprite_offset` 后,棋盘唯一行限制是
`GridManager.is_walkable` 的**边界环**(行/列 0 与 `GRID_*−1`),可通行行
`1..GRID_HEIGHT−2`(= 今天 `1..9`),由常量导出。出生点恢复原样:
**中神通 (7,1) / 东邪 (3,2) / 西毒 (11,2)**;南帝 (3,8)、北丐 (11,8)、
玩家 (7,5) 不变。旧「某些行不可上」的规则已作废——它曾是钳位逼出来的
第二层补丁,本轮随钳位一起删除,历史见 `99_changelog.md`。

**相机数学(全符号,GRID_HEIGHT 改 20 只改代入数、零行相机逻辑改动)。**
跟随 Camera2D(`scripts/camera_follower.gd`)把中心钳到**无空白范围**:

```
cam_lo = board_lo + V/2 − cover_before      cam_hi = board_hi − V/2 + cover_after
```

每轴一个;`cover_before` = 该侧被 HUD 遮挡的深度,`cover_after` = 对侧。
退化 `cam_lo > cam_hi`(棋盘 < 视口)⇒ 钉棋盘中心。

- 今日代入(仅一次代入的校核,不入码):`V = get_viewport_rect().size` =
  (960,704);HUD 遮挡 `T = 92`(`scenes/ui/hud.tscn` TopStrip `offset_bottom = 92.0`)、
  `B = 648`(SkillBar 底锚 `offset_top = −56` → `704−56`),未遮挡带
  `y ∈ [92, 648]`、高 `B − T = 556`;左右无全高侧栏 → x 遮挡 0。
  - `cam_y ∈ [0 + 352 − 92, 704 − 352 + 56] = [260, 408]`,区间长
    `148 = 704 − 556`(棋盘高 − 带高)。
  - `cam_x ∈ [480, 480]`(单点)——这是「x 侧无遮挡」的**推导结果**,不是硬编码。
- 相机会话:玩家回合跟随玩家、敌方回合跟随正在行动的敌人(读
  `CombatManager.get_active_unit()`,每帧取 `unit.position`),跟随目标是活跃
  单位这一事实由 `Camera.follow_target_is_active` 发布。
- 世界↔屏幕一律经 `Coord`(见 `## 坐标变换`)。

**代价两条(已接受,均写进 `90_decisions.md` / `40_ux_backlog.md`):**

1. **整盘看不全。** 相机在无空白范围内移动时,棋盘南端(行 9-10)在北极
   `cam_y = 260` 时落到底部招式栏后——**正常取景,非缺陷**;小地图 / 屏外单位
   边缘指示记为 UX-09 待办,本轮不做。
2. **行 1 立绘头顶约 32 px 落在顶栏带后。** 清掉顶栏需要相机再往北
   `PORTRAIT_TEX_Y − GRID_ORIGIN.y − TILE_SIZE = 128 − 32 − 64 = 32` px,
   超出无空白下限允许的量;这是可推导的缺口,本轮不扩背景。相机级闸门断
   「活跃单位在未遮挡带内 / 立绘站在自己格上」(`portrait_grid_alignment`),
   不断「整张立绘完整可见」。

## 指针可达性 (pointer reachability, 2026-08-29, touch-reach)

主线六段从教程结算屏起就不再可点:教程结算 overlay 是**代码现搭**的
(`scripts/autoload/game_manager.gd::_show_end_game_overlay`,
`CanvasLayer + ColorRect + Panel + Label`,零 Button),而 transition / sect_select /
cultivation / map / ending 五个段场景是 `Backdrop(Panel) + Label` 一张一个按钮都没有。
手机玩家打完整部教程就卡死在「按回车继续」。本轮给六段全程补上可见、可点的控件,
向既有 handler 委托,玩法与数值一字未动。

(a) **每一屏都必须有一个可见、可点的控件,delegate 到既有 handler。** 六段 = 主菜单 →
捏人 → 教程战 → 教程结算 overlay → 过场 → 拜师 → 养成(36 个月)→ 大地图 → 事件 → 结局。
主菜单 / 捏人 / 教程战 / 教程 overlay 原本就有按钮;本轮给代码搭的 overlay
(`ContinueButton` / `RetryButton`)与五个段场景(`NextButton` / `SectButton0..4` /
`CultOptionButton{i}` / `TravelButton{i}` / `EventOptionButton0/1` /
`FacilityEnterButton` / `FacilityUseButton` / `FacilityLeaveButton` / `RestartButton`)
各加可见控件。控件一律委托到**同一个** handler——`request_continue` / `request_retry` /
`_advance` / `_pick` / `_on_accept` / `_travel` / `_resolve_node_event` /
`restart_game`、以及设施既有 `_enter_facility` / `_use_facility` / `_leave_facility`。

(b) **观测结论:`actions:` 键注入看不见这类缺陷。** playtest 的 `actions:` 走
`Input.parse_input_event` 注入,绕过 GUI 命中测试直接喂给 `_input`——所以一个**零可点
控件**的屏也能通过键驱动的契约(69/69 全绿,玩家却卡在教程结算屏,同一个根,见下)。
`clicks:` 是真命中测试:命中不到目标即 `push_error` → 硬闸门红,是看见这类缺陷的仪器。
本轮立了全程只走 `clicks:` 的 `playtest/clicks_only_storyline.yaml`,让它**先红**
(教程结算屏 `ContinueButton` 不存在)、后转绿。这与已记录的 `SegmentHost` 全屏 STOP
吞咽缺陷同一个根:**契约看不见玩家真正走的那条路**。

(c) **button-delegate 教义。** 新控件一律 `focus_mode = FOCUS_NONE`(不抢焦点、不双触发
`pressed` + `_unhandled_input`)、`pressed` 委托到既有 handler;键盘分支**逐字节不变**,
按钮是键盘快捷键叫同一个 handler 的**汇聚点**——本轮加输入方式,不是换输入方式。
`playtest/spine_to_ending.yaml`(键盘路径的证明)本轮未动并保持全绿。

(d) **点击锚挂控件/单位本体,绝不挂 `*_ClickTarget`。** 重申 `90_decisions.md` 2026-08-29
条(「点击锚不再挂在 *_ClickTarget 上」):一个节点不能既是可命中的锚、又是不该收到点击的
控件。本轮所有新锚点都是 Button / 单位本体。

(e) **官方闸门实测收口(2026-08-30)。** 本节性质由本轮官方全量闸门实测证实:71/71 场景全 PASS
(硬闸门 `passed: true`、零 runtime error),其中 `clicks_only_storyline` **47/47**(零键盘动作、
全程 `clicks:` 真命中测试——先红于教程结算屏的实测记录 f265 见 `00_roadmap.md` /
`90_decisions.md`,(b) 的观测结论由此有了正反两面的实测值)、`spine_to_ending` **42/42**
(键盘路径未动仍全绿)、`map_facility_buttons_click` **38/38**;编译 **88/88** 零错误。视觉闸门
非盲应答(`localqwen/qwen3`,`passed: true`,六问全部 `failed: false`;Q6 **71 好 / 0 坏**——
2026-08-30 证据复核勘误:盘上 `vision_report.json` 实测 `good_answers: 71 / bad_answers: 0`,
早先转录的「69 好 / 2 坏 / 两帧候选」无法从盘上产物复现,按 `align_vision_gate_wording_v2`
纪律删除,见 `40_ux_backlog.md` 记录行与 `99_changelog.md` reconcile_q6_counts_with_artifact 行)。

(f) **按钮是选项的唯一呈现(单面规矩,2026-08-30)。** 每个需要玩家选择的屏幕上,同一份
选项**只出现一次**,且它的唯一呈现是**可点按钮**——不再有一段 `▶` 光标文字行 + 一排
一模一样按钮的平行 UI。被删的只是「和按钮逐字重复的那份选项行」;描述性文字(卡面描述、
属性说明、结局正文、HP 数值、门派内外功信息、节点名一览等)不是选项列表,**不删**。
键盘仍照常用:它是作用在这份按钮表面之上的一层**快捷键**,`_unhandled_input` + 焦点变量
仍是唯一输入权威;选中状态**表达在按钮本身上**(`modulate` 亮/暗,`creation.gd`
先例)——键盘上下键移动的就是按钮高亮,不再移动正文里的 `▶` 光标。每一段暴露一个
机器可查的观测量 `cursor_markers_visible`(正文仍含 `▶` 为真)作为「重复列表已消失」的
运行时证据。四个 `▶` 重复点本轮消除:cultivation / map / sect_select(正文行删除,选中
改按钮 `modulate`),creation 本就单面(先例)。

(g) **每个需要玩家选择的状态都必须有可点出口(规矩,2026-08-30)。** 玩家能停留、且需要他
做出选择才能推进的任何状态,其可点控件构造(`_rebuild_options_box` / `_sync_click_buttons`
/ `_wire_sect_buttons` 之属)**必须产出 ≥ 1 个可见、已接线(`pressed_connected` 非空)的
控件**。唯一的例外是「没有任何输入能改变它」的纯展示 / 自动推进状态,须在闸门里写明排除
依据。本规矩由 `tests/test_touch_option_surface_gate.gd` 作为**性质断言**钉住——它以**遍历
phase 机器**(`match phase:` 分派臂即邻接表)的方式发现并检查每个到达的玩家选择相位,不是一份
phase 名字面量清单(那样加一个 phase 就会漏)。`GONGFA_PICK` 空列表死角(零按钮、键盘独占出口)
由此类推向不可能:**空未大成列表仍产出一个「返回行动」按钮**,pressed 走与其它选项**同一条**
`_on_option_pressed → _on_accept` 链(`_on_accept` 的空分支 `cultivation.gd:237-238` 执行
返回 ACTION_PICK),无任何分叉相位逻辑。唯一留存的零按钮构造是「不可解析事件定义」的防御分支
(阶段机不可达),记录于 `design/31_touch_coverage.md`。**「钉子钉的是点得出去,不是有按钮」**:
新增 `playtest/clicks_only_gongfa_empty_exit.yaml` 断的是一记 `click:` 之后 `phase` 真从
`GONGFA_PICK` 变 `ACTION_PICK`(相位差),不是「按钮存在」。

## 角色面板 (roster panel, 2026-08-30)

玩家把数据早已存进 `PlayerProfile`(五属性 / 银两 / traits / gongfa / inventory / cultivation,
`design/30_presentation.md` 上文),却有一条完全死掉的路:**12 张装备卡把 id 写进
`profile.inventory`(`scripts/data/card_data.gd` / `scripts/data/event_logic.gd` item 效果),
而全仓没有任何一处把 inventory 读出来给玩家看**。本轮新增一个**只读、可点开 / 点关**的角色页,
把这三块「玩家已经拥有却永远看不见」的信息显示出来。它是**纯展示 overlay,不是 phase**——
无 `match phase:` 分支、无新状态串、不写存档、不消耗回合 / 行动。

### 三块内容与惰性降级

- **人物** — 五属性(根骨 / 内力 / 身法 / 悟性 / 福缘)取自 `p.attrs`,银两 `p.silver`,
  先天特质 = `traits` 逐条经 `TraitData.get_def(id).display_name` 解析(缺行 → 原始 id),
  当前年月 = `p.cultivation.year/month`,`门派` = `ProgressionGongfaData.SECTS` 匹配
  (miss → 原始 id,`""` → 「无门无派」)。traits 空列表 → 「（无）」。
- **功法** — `p.gongfa` 逐条 `{id, grade, practice, mastered}`:名称经
  `ProgressionGongfaData.display_name_of(id)`(未知 id → 原始 id),品级 = grade 字母,
  练度 `练度 %d/%d`(上限 `PRACTICE_TO_MASTER.get(grade, -1)`;grade `""`/未知 → 只显示练度不显示上限),
  `mastered == true` → 大成标记。hostile 行一律 `.get()` 带默认值,绝不崩。空列表 → 「（无）」。
- **物品** — `p.inventory` 每个 id 经**冻结的** `CardData.display_name_of(id)` 解析为中文名
  (`card_data.gd:82-84`,未知 id 返回 `""`),未知 id **惰性降级为原始 id**(显示出来),
  不崩、不 `push_error`。空列表 → 「（无）」。「看见」本轮还账,「装上」欠着(见
  `design/40_ux_backlog.md` UX-13 / UX-14)。

### 入口

`RosterOpenButton`(`scenes/ui/roster_panel.tscn` 实例进 `cultivation.tscn` / `map.tscn`,
两个宿主里节点名同为 `RosterPanel`),面板打开时隐藏、关闭时恢复可见。入口在两个可存档段落
(`design/40_progression.md §8` STABLE_STATES = CULTIVATION / MAP)都够得着。

### 关闭

`RosterCloseButton` 按钮 **和** 点面板外区域(dim 层)——两者都存在,按钮是场景钉住的关闭
控件,叠加层只吸收面板外的点击。

### 单一操作面 conformity

面板内部**零内可选控件**(纯展示行 + 两个控制),`cursor_markers_visible == false`(`"▶" in body_text`)
由新场景断言;面板打开时 dim 层的 `mouse_filter = STOP` 使它成为**唯一操作面**(宿主的所有
选项按钮在 STOP 之下点不到),宿主 `_unhandled_input` 以 `is_open` 为闸第一行进 return——
面板打开时键盘语法惰性。不回归并行 `▶` UI:四个既有段落的同名观测量保持 `false`。

### 只读硬保证

打开 / 关闭**从不**调用 `SaveManager.autosave()`(反例:`map.gd::_resolve_node_event` 会存档——
那是事件路径,不是面板),不写 `profile` / flags、不消耗月份 / 行动、不改 phase。
`save_load_roundtrip` 保持绿;`spine_to_ending` 永不打开面板 → 其时序逐字节未动。

