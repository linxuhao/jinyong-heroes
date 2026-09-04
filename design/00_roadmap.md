# 00 · 开发路线图

> **循环与排序规则**(一轮怎么跑、两件事同等紧急时先做哪个)见 01_process.md;本档只定阶段顺序。
> 本档案定的是**做事的顺序**,不是做什么。「做什么」在 10_systems / 20_content / 30_presentation。
> 立此档的直接原因:2026-08-24 有三轮流水线在教程战的数值上反复打转,
> 而当时游戏连「这一局能不能打赢」都还没定下来。**顺序错了,再多轮次也是白跑。**

## 顺序

```
1. 游戏逻辑      —— 用最简单的美术(灰盒/色块),把规则跑通
2. 游戏交互      —— 玩家看得懂、点得动、知道下一步按什么
3. 游戏内容      —— 事件、地图节点、结局、招式表填实
4. 美术内容      —— 定妆、贴图、动效
5. 数值精调      —— 放到最后
```

**当前位置(2026-09-04 校准):R5 navigation-and-consequence 已落地并经修复轮 + post-fix 官方复跑收口——C1 后果由数据渲染(遮挡证据:pre-fix 官方主网 62/62;post-fix 官方 `occlusion_no_button_over_text` 22/22 + map 腿 9/9)、C2 软锁返回零差分(三钉 16/16·19/19·16/16)、C3 五相位可返回 + 确认、C4 战斗/结局只读角色面板(两钉 27/27)、战斗反馈钉绿;F1/F4 修复后三条逐字闸门回字节一致绿(49/49·32/32·41/41,官方实测)。** 下一项 = **外号**(编号队列第 2 项,见下;R6「江湖有人」随后)。第 2 阶段(交互)与第 3 阶段(内容)是**并行**的,
不是顺序推进——上面那张表没说清这一点,记在这里。

- **第 1 阶段(逻辑)** 完成:六段骨架接通(教程→养成→遭遇→江湖→结局),结局可达。
- **第 2 阶段(交互)** 主体已交付,但 2026-08-27 发现它有一个**致命漏洞**:`menu.tscn` 的
  全屏 `SegmentHost` 漏写 `mouse_filter`,吞掉棋盘上**每一次**鼠标点击。左键移动对所有玩家
  都是死的(网页版与桌面版皆然),而 57 个 play-test 场景**全绿**。已修。
  教训不是"漏了一行",是**契约看不见玩家走的那条路**:契约启动 `main.tscn`、游戏启动
  `menu.tscn`,而 `clicks:` 用 `Input.parse_input_event` 注入,永远到不了 GUI 阶段。
  两道守卫已落在 `tests/test_playtest_contract_smoke.py`。
  **仍未完成(2026-08-29 更正:此四条已全部落地,见完整度表第 4 条与其「第 4 条核对」)**:
  立绘比它所站的格子高整整一格(照着立绘点打不到人)、名牌压在小腿上、
  天生特质要点击才显示介绍、手机上没有可达的「退回」控件(触摸没有右键)。
- **第 3 阶段(内容)** 已开工:招式消耗填实、地图节点进入内容、主线五节点事件已绑定
  (4/5 有确定性事件;昆仑是终点,有意留空)。**2026-08-28:battle 类型已落地**——新增
  **华山**节点(挂少林旁支,主线不动),到达即开战,胜负皆回地图。战棋此前**只能从教程
  进入一次**,自此「行走→交战→再行走」成为闭环。`start_encounter()` 那条为养成段预留
  却从无调用点的接缝,证明了架构早已为此留口:回程一行未写,因为 `request_continue/
  request_retry` 本就按 `battle_return_state` 回段。**剩余缺口(2026-08-29 更新)**:
  **facility** 本轮已在少林 / 武当实装(见 `20_content.md` §10),余五节点仍 `declared`;
  剩余内容活是逐个填实 battle / facility 已声明槽位;事件池已扩至 36 条(2026-08-31
  `jinyong-event-pool-36`,第 3 条转 ✅,见 `20_content.md` §4);华山的行为路径
  (到达→开战→回图)已由 `jinyong-huashan`(2026-09-01)钉死——`map_battle_node_huashan`
  重写为「能打」闸门并实测 **41/41**(到达→开战→回合推进→真实行动→胜负回图全链,
  见 `20_content.md` §11)。
- **大地图已可行**(2026-08-28):可见性归跟随相机后,棋盘不再受视口约束——后续内容轮
  不必设计到 15×11,可以上更大的地图(见 `90_decisions.md` 2026-08-28 条)。
- **第 4 阶段(美术)**:六名角色已有 96×128 立绘,战场已有山水背景——**「美术仍是色块」
  这句已不成立**。垂直切片(教程战)尚未立项。
  **本阶段已改向「武虾」**(2026-08-28 裁定,见 `90_decisions.md`):**本作的一切角色都是虾**,
  现有六个与此后新增的任何一个皆然——这是世界观约束,不是一次美术替换。**冷面执行**:
  只有形象与称号是虾,事件/功法/招式的文案维持严肃武侠散文(全面搞笑要重写 183 条内容
  字符串,那是另一个项目)。名册 `assets/characters/roster.json` + 守卫
  `tests/test_shrimp_roster.py` 已就位,使「新增角色必须写明是哪种虾」成为一道会拦人的门。
  **时机是硬约束:替换必须等 defect B 的立绘几何(名牌、地面标记、墨迹矩形、命中判定)
  落地钉死之后**,否则等于在别人量尺寸时换零件。
  **替换已执行(2026-08-31,武虾轮)**:六张立绘换为非人形真虾体,恰在本条时机约束之后
  ——几何钉于 2026-08-28/29 落地,本轮换图后逐条重实测全绿(`portrait_grid_alignment`
  **30/30**、`camera_transform_follows_unit` **9/9**、六单位八层可见性全过、
  `spine_to_ending` **42/42** 零 runtime error;证据 `final/delivery_notes_wuxia.md` §3,
  裁定见 `90_decisions.md` 2026-08-31 条)。武虾形象自此屏上可见,上表第 5 条转 ✅。
  **UI 主题已落地(2026-09-01,jinyong-theme 轮;数字凭本轮官方闸门产物填)**:
  `assets/themes/global_theme.tres` 由 7 行占位扩为完整水墨主题(Button 四态不透明墨底 +
  朱红焦点环 + 五字色、不透明墨底 Panel、Label 14 / RichTextLabel 纸色、
  `TitleLabel` 26 / `HintLabel` 12 分级)——第 4 阶段的「界面有人设计过」自此有实装;
  压字三处修复(角色面板 dim 0.85 + 主题不透明底板、教程浮层 dim 0.88、战场提示加投影)
  与焦点标记(`ThemeManager.option_style`,取代 modulate 亮度差)同轮落地。
  实测:编译 **98/98** 零错误;playtest 硬闸门过、零 runtime error、**78/79 PASS**
  (五条保护闸门全绿;唯一红 `creation_layout_readability` **21/22**,主题字号增长引入、
  记 `40_ux_backlog.md` UX-31);视觉闸门 **passed**(79 场景 316 帧,Q6 78 好 / 1 坏,
  坏答在非主题的战斗帧)。详见 `32_theme.md` 与 `90_decisions.md` 2026-09-01 条。
  **post-fix 收口(2026-09-01,5_design 补记)**:上述回归已由 D6 预写的回退路修复——
  `creation.tscn` 恰 14 处逐节点 `theme_override_font_sizes/font_size = 12`(13
  TraitToggles + TraitDescLabel;零几何/文本/节点/主题改动,分级未全局缩),同帧对照
  f90 `creation_box_fits` False→True(先红 21/22 后绿 22/22,`delivery_notes_theme.md`
  §7);官方复跑 playtest **79/79 场景全 PASS**、硬闸门过、零 runtime error(五条保护
  闸门全绿、`theme_focus_marker_cultivation` 14/14),编译 **98/98** 零错误;视觉闸门
  官方产物仍是 pre-fix 那次(passed,Q6 78 好 / 1 坏),post-fix Q6 复检未执行(端点
  不可达,如实记录)。`40_ux_backlog.md` **UX-31 → CLOSED(jinyong-theme)**。
- **第 5 阶段(数值)** 未开始,按原则留在最后。

## 地平线(2026-08-28 裁定)

**这是一个一两个月的长线项目,目的是 build in public,判据是「完整」,不是「能演示」。**
此前本档案默认的终点是一个能证明核心循环的垂直切片;那个默认作废。记在这里,是因为
它改的不是优先级,而是**什么算做完**——而「什么算做完」不写下来,「越完整越好」就没有终点。

改了三件事:

1. **第 5 阶段(数值精调)从「一直推后」变成射程之内。** 一两个月足够走到打磨期。
   上面「数值只做粗调」的规矩在骨架未稳之前仍然成立,但它不再是本项目的永久状态。
2. **垂直切片是中途站,不是终点。** 切片证明可行之后要铺开:facility、事件池、结局、
   招式表都在范围内,不再是「以后再说」。
3. **build in public 给了一条本来不存在的约束:进度必须看得见。**
   测试基建、契约守卫、几何钉子——这些是对的工作,但它们对观众是空白的一天。
   这**不改**优先级(该修的底子照修),改的是交付节奏:**每一轮至少产出一件肉眼可见的变化**,
   哪怕它小到只是一个能点的按钮。看不见的一周和没做过的一周,在 build in public 里是同一件事。

**「完整」的判据(逐条勾掉,不达标不算完):**

| # | 条目 | 状态(2026-08-28) |
|---|---|---|
| 1 | 六段骨架可从头玩到结局 | ✅ 已达 |
| 2 | 地图三类节点全部实装 | event ✅ / battle ✅(华山——2026-09-01 `jinyong-huashan` 轮实装为**可打的战斗**并由本轮官方闸门实测承载:`map_battle_node_huashan` **41/41**,本轮 playtest **78/78 全 PASS**、硬闸门 `passed: true`、零 runtime error,编译 **98/98** 零错误;`huashan_duel` 绑定被真消费、对手阵容由它决定,逐行断言变更表 `final/delivery_notes_huashan.md` §2,实装记录 `20_content.md` §11)/ facility ✅(少林 / 武当)——其余六节点 battle 槽仍 `declared`、其余五节点 facility 槽仍 `declared`(见 `20_content.md` §8.1) |
| 3 | 事件池够撑一次完整旅程不重复 | ✅ 36 条(2026-08-31 `jinyong-event-pool-36` 扩池完成)——两道不重复闸门 `_test_no_repeat_full_journey`(单元,跑真实 `draw_unseen_id` 36 抽)与 `event_pool_new_event_resolved`(playtest,屏上结算一条新事件)承载该性质。**闸门实测已补记(2026-08-31 本轮 5_compile / 5_vision)**:编译 **95/95** 零错误;playtest **78 场景**硬闸门 `passed: true`、零 runtime error、**77 PASS / 1 红**——唯一红是本轮新场景 `event_pool_new_event_resolved` **13/15**:屏上抽中(`event_id == "cliff_herbs"`) / 选中(f210 `focused_option_text`) / 结算(f230 `events_seen_count == 36`,seen 阶梯 f140 35 → f230 36 无清空)全绿,红的是本轮**新增两个渲染观测面**(f200 `event_title` / `event_body` 实测空串)→ 如实记 `40_ux_backlog.md` **UX-18(OPEN)**,红不属「不重复」性质本身,本条 ✅ 维持;视觉闸门 passed(78 场景 312 帧,Q6 78 好 / 0 坏);单元闸门 `_test_no_repeat_full_journey` 的官方 PASS 待 5_test 产物(`test_report.json`,不在本步上下文,不预测)。**post-fix 收口(2026-08-31,5_design 补记)**:渲染观测面缺陷已修(`cultivation.gd` ACTION_PICK case 3 抽取后立即 `_sync_surface()` 发布,`90_decisions.md` (g)),本轮 `5_compile` 官方复跑实测 playtest **78/78 场景全 PASS**——`event_pool_new_event_resolved` **15/15**(f200 两观测面转绿,「抽到 / 渲染 / 选中 / 结算」四腿屏上全成立)、既有 77 场景零回归、零 runtime error;编译 **95/95** 零错误;视觉闸门 passed(78 场景 312 帧,Q6 78 好 / 0 坏);`40_ux_backlog.md` **UX-18 → CLOSED(jinyong-event-pool-36)**(详见 `20_content.md` §4) |
| 4 | 玩家点得动:立绘几何四条缺口 | ✅ 已达 —— 四条(立绘高一格 / 名牌压腿 / 特质要点击才显示 / 手机无退回控件)已在既往轮次落地,本条此前标 ❌ 是**过期**记载(见下「第 4 条核对」) |
| 5 | 全部角色为「武虾」形象 | ✅ 已达(2026-08-31,武虾轮)——六张立绘换为非人形真虾体(头卡通 + 身半写实),四个「待定虾种」按所有者裁定填入、六行 `art_status` → `completed`,守卫 `tests/test_shrimp_roster.py` 不改且绿;换图后立绘几何逐条重实测零红:`portrait_grid_alignment` **30/30**(24 条墨迹线 dx/dy 全 0.0,f40+f820)、六单位八层可见性全过、`camera_transform_follows_unit` **9/9**、`spine_to_ending` **42/42**;证据 `final/delivery_notes_wuxia.md` §3 + 本轮闸门产物,裁定见 `90_decisions.md` 2026-08-31 条 |
| 6 | 英文可玩(build in public 的观众不都读中文) | ✅ 已达并已上锁 —— 见下 |
| 7 | 招式表与功法填实 | 🔄 消耗已填,表未满 |
| 8 | 数值精调 | ⏸ 第 5 阶段,结构定死之后 |

**第 6 条的核对(2026-08-28 实测):** 英文表不在 `project.godot` 的 `translations=` 里,
而是 `I18n` autoload 在 `_enter_tree` 用 `TranslationServer.add_translation` **运行时注册**的
(`scripts/autoload/i18n.gd`,`EN` 字典常量)。只查静态那一条路会得出「英文不存在」的错误结论。
逐条比对之后:177 个 `tr("<中文>")` 调用点全部有词条,场景里唯一缺的是当天新加的撤销按钮 `退回`,
已补。缺口能在词表写好的**几小时之内**出现,是因为**没有任何东西看得见它**——查表落空只是原样
渲染中文,对所有自动检查而言,未翻译的标签和已翻译的长得一模一样,唯一的信号是英语玩家看到中文。
故立 `tests/test_i18n_coverage.py`(纯标准库,三条:场景 `text=`、`tr()` 调用点、`.text =` 直赋),
抽掉词条会红。

第 4 条此前是第 2 阶段的欠账,但四条缺口已在既往轮次全部落地,本条不再压着第 3、5、7 条。

**第 4 条核对(2026-08-29 按实测更新,此前标 ❌ 系过期):** 四条交互缺口的落点——
立绘高一格 / 名牌压腿由 `camera-owns-visibility`(2026-08-28)与 `jinyong-camera`
re-loop(2026-08-29)钉死(证据场景 `portrait_grid_alignment` /
`camera_transform_follows_unit`);特质要点击才显示由 `interaction-defects`
(2026-08-28)的悬停预览(`trait_hover_preview`)解决;手机无可达退回控件由
`scenes/ui/hud.tscn` 的 `退回` 按钮 + `playtest/undo_button_retreat.yaml`(18/18)
解决。前三条的裁定见 `90_decisions.md` 2026-08-28「棋盘不再受视口约束」与
2026-08-29「点击锚不再挂在 *_ClickTarget 上」两条。

**下一步的顺序判断:** 第 2 阶段的四条交互缺口已全部落地,不再压着内容扩充;地图第
三类进入内容(facility)本轮已在少林 / 武当实装(第 2 条转 ✅,见 `20_content.md`
§10)。第 3 阶段余下的内容缺口是**逐个填实已声明的槽位**——battle 槽除华山外仍
`declared`、其余五节点 facility 槽仍 `declared`(2026-09-01 更正:华山 battle 的
行为路径**已**由本轮场景钉死——`map_battle_node_huashan.yaml` 重写为「能打」闸门并
实测 **41/41**,到达→开战→回合推进→真实行动→胜负回图全链实测,见
`20_content.md` §11,该缺口关闭)。事件池已扩至 **36 条**,
第 3 条转 ✅(两道闸门 `_test_no_repeat_full_journey` / `event_pool_new_event_resolved`,
见 `20_content.md` §4),不再属开放缺口。这些是「槽位还在,内容
没填满」的常规内容活,不再有「某类节点内容根本不存在」的结构性空白。

## 第 2 阶段(交互)更新:触屏主线缺口已关闭(2026-08-29, touch-reach)

**「主线六段在触屏上断在教程结算屏」这一缺口已由本轮关闭。** 上一轮结束时把主线断触屏的
根因核实为两类:**code-built 教程结算 overlay**(`game_manager.gd::_show_end_game_overlay`,
CanvasLayer + ColorRect + Panel + Label,零 Button,文案还是「按回车继续」)和**五个仅
`Backdrop + Label` 的段场景**(transition / sect_select / cultivation / map / ending,零
Button)。本轮给全部六段加上可见、可点的控件,向既有 handler 委托(overlay `ContinueButton` /
`RetryButton`;五段场景 `NextButton` / `SectButton0..4` / `CultOptionButton{i}` /
`TravelButton{i}` / `EventOptionButton0/1` / `FacilityEnterButton` / `FacilityUseButton` /
`FacilityLeaveButton` / `RestartButton`),`focus_mode = FOCUS_NONE`、键盘分支逐字节不动,
`spine_to_ending.yaml`(键盘路径证明)未动保持全绿。新增 `clicks:`-only 场景
`clicks_only_storyline`(零键盘动作、先红后绿)把「不碰键盘能否从主菜单走到结局」变成一道
游戏级闸门。

**Phase 2 剩余只含两条测量欠账(不设闸门):** UX-11(主线可点控件在 960×704 下的真实触控
目标尺寸,measure-only,禁止 `size >= 48` 引擎级形态断言)与 UX-12(残留仅讲键盘操作、
屏上已有控件但文案没说可点的提示行号)。两条都按 `40_ux_backlog.md` 规则保持 OPEN。

**官方全量闸门实测(2026-08-30,本轮 `5_compile` 产物)**:71/71 场景全 PASS(硬闸门
`passed: true`、`spec_used: true`、零 runtime error)——`clicks_only_storyline` **47/47**
(零键盘动作)、`map_facility_buttons_click` **38/38**、键盘路径证明 `spine_to_ending`
**42/42**(未动仍全绿)、`facility_use_reusable` **49/49**、`tutorial_win_routes_to_transition`
**8/8**、`tutorial_loss_restarts_tutorial` **5/5**;编译 **88/88** 零错误;视觉闸门本轮**非盲**
(`localqwen/qwen3` 应答,284 帧,`passed: true`,六问全部 `failed: false`)。本轮早先那次
解析失败运行(见 `99_changelog.md` record_parse_lesson_and_reconcile)由此行收口:官方全量
运行解析干净、全部断言真实执行。两条测量欠账**不因闸门转绿而关闭**——关闭需各自动作
(UX-11 待一次专门测量运行转录 rect 值;UX-12 待后续文案对齐轮)。

**「先红后绿」的红由实测确认,不再只是结构预测(2026-08-29,record_measured_red_first_and_reconcile):**
上文 `clicks_only_storyline` 的「先红」已由一次解析干净的实测运行坐实 — 轮 `red_first_evidence_measured`
用**临时回退法**(在 `scripts/autoload/game_manager.gd::_show_end_game_overlay` 注释掉 `continue_btn` /
`retry_btn` 构造块、re-show 分支 `existing_continue` / `existing_retry` 重同步块、两处
`_refresh_end_overlay_pressed_connected()` 调用点,保留函数定义与 `_unhandled_input`,每处标
`# TEMPORARY RED-FIRST REVERT — DO NOT COMMIT`),跑 `godot_playtest_scenario(scenario="clicks_only_storyline")`
(**直连同一外部边车** `aitelier/tools/godot_playtest/impl.py`,非 5_compile 闸门)实测四值:failing frame
**265** / first failing assert **`ContinueButton.visible`**(f265,expr `visible == true`,error
`node not found: ContinueButton`)/ exact error **`aim: node not found: ContinueButton (spec: ContinueButton)`**
/ green asserts before red **8**;逐字节还原后复跑 **47/47** 全绿。早先记档的「f180 / 5 / 预测错误串」是
**结构预测**(原时间线推导),由帧时序重投影修(全部 `at:` 帧重基线到屏就绪时序、教程开场腿 Next 点击数
3→7、加 `scene: res://scenes/menu.tscn`)后实测为 **265** — 同一屏(教程结算)、同一首断断言,不得读作
两次互相矛盾的测量。

## 这个顺序和业界做法的差异(2026-08-24 查证)

大方向是一致的,但有两处业界不是这么做的,记下来免得以后当成教条:

**一、美术不是完全推到最后,中间有个「垂直切片」。**
主流做法是:灰盒原型证明核心循环 → **做一个小范围的垂直切片,那一小块的美术/音效/UI 做到接近成品**
→ 再铺开量产。理由是「与其一大片都像原型,不如一小块像成品」——它同时验证了美观和可行性,
也是给自己(和投资人)看的证据。

对本项目的取舍:**保持「简单美术」作为默认,但在骨架稳定后挑一个场景做成切片**
(建议是教程战,因为它是所有人的第一印象)。切片之外的部分继续用色块。

**二、「数值最后调」指的是精调,不是「一直不测」。**
业界的说法是「balancing is tuning, not designing」——数值精调发生在结构定下来之后,
多数落在打磨期;**但试玩要从很早就持续做**,越早试越早发现「某个组合强得离谱」或「某个升级永远不值得拿」。

对本项目的取舍:**数值不精调,但每一轮都要能打完一局。**
「打不赢」这种量级的问题不是数值精调,是**逻辑还没成立**——它属于第 1 阶段,不能推到第 5 阶段。
2026-08-24 的教训正是把这两者混为一谈:因为「数值最后调」,就容忍了一个通不了关的教程战,
然后花三轮去搜索打法。**判据:能不能打完 ≠ 打得爽不爽。前者是逻辑,后者才是数值。**

## 因此,本阶段的规矩

- 数值只做**粗调**,够用即止,一次改一个数,改完实测一局。
  例:2026-08-24 杨过气血 500 → 1000,理由是教程战通不了关,不是为了手感。
- 不为了让某条断言变绿去调数值;反过来也一样,**不为了保住数值让一场打不赢的仗留着**。
- 美术资产不产出,除非是切片范围内的。
- 每一轮结束时,`spine_to_ending` 必须仍然全绿——那条场景就是「六段还连着」的证明。

## 数值还在动的时候,测试怎么写(2026-08-24 立)

既然数值要一直动到第 5 阶段,**测试就必须能在数值动的时候活下来**。规矩三条:

1. **血量断言一律对 `max_health` 表达**,不写绝对值。
   `health == 500` 表面在说「满血」,实际同时钉住了 `max_health` 是 500;
   气血一改,一条跟气血毫无关系的逻辑场景就红了。
2. **需要前提的场景一律注入,不许等它自然发生。**
   「敌人五回合内把杨过磨到半血」是一个**平衡结果**,拿它去给
   「半血解锁绝招」这条**逻辑**造前提,等于把逻辑测试押在数值上。
   已备的注入接口:`debug_damage_player`(压到 40% 血)、`debug_poison_player`、
   `debug_kill_player`(经 `debug_lose_tutorial`)、`debug_wipe_enemies`。
   注入一律走正常管线(`apply_damage` / `apply_dot`),不直接改字段——
   否则测到的是脚手架,不是游戏。
3. **测机制,不要测机制的副作用。**
   DoT 场景原本断言 `health == 326` 来证明毒生效了,但那个数字里同时含着
   采样帧之前的每一次敌人攻击和神雕之力的回血——它测的东西比它以为的多。
   改成数 `debug_dot_ticks_applied` 之后,断言反而**更准**(6/6 → 9/9)。

**例外:数字本身就是契约的,不解耦,只重新推导。**
`fahui_du_multiplies_damage`(发挥度乘法)和 `terminal_victory_8_12_rounds_hp_15_40`
(难度窗口)属于此类。把它们也「解耦」等于把被测对象删掉。
这两条允许因平衡改动而变红——那正是它们的用途。

## R3b 后续队列(2026-09-02)

R3b(数值真的绑上)已落地(c1–c7 代码/数据/场景全交付,C5 升级条款行使:
华山 duel 实测不可赢,等待所有者解锁 `map_battle_data.gd`)。
**官方三闸门实测已抵达(2026-09-02,5_design 收口)**:编译 **107/107** 零错误;
视觉闸门 passed 非盲(93 场景 372 帧,Q6 93 好 / 0 坏);playtest 硬闸门
**`passed: false`**(85 条 runtime error)——**84/93 场景零断言失败、9 红**:
`cultivation_changes_combat` 27/30、`action_yield_differential` 27/38、
`huashan_readiness_warning` 20/21、`huashan_winnable_normal_route` 28/39(C5
许可红)、`ending_divergent_playstyles` 19/27、`ending_last_month_choice` 16/30、
`work_beats_idling` 11/21、`practice_target_receipt` 29/40、
`ending_tiers_differentiate` 13/22;RNG 生命线绿(`save_load_roundtrip` 14/14、
`event_travel_effects` 19/19)、三条逐字保护闸门全绿(49/49 / 32/32 / 41/41)、
`spine_to_ending` 42/42。九条红逐条入档 `40_ux_backlog.md`(UX-37/38/39 + C5
许可红),**下一轮先做队列第 0 项(R3b 场景收口)再开新卡**。后续队列如下:

```
0. ✅ R3b 场景收口        —— 官方 9 红的修复已落:五条时间线/boot 时序重基线 +
                             表达式书写修正(UX-37)、readiness 带裁决(UX-38)、
                             既有网两条红收口(UX-39);post-fix 官方复跑(2026-09-02)
                             八红转绿(30/30 · 44/44 · 16/16 · 33/33 · 38/38 ·
                             26/26 · 43/43 · 27/27),C5 WON 尾维持许可红(36/48,
                             不伪造胜利);复跑唯一新红 UX-40 另行排队。
                             iteration-4(2026-09-03):trait 钉按「数字即契约」
                             重推导为差分钉(UX-40)、C5 尾按所有者重划裁决重锚为
                             诚实-LOST 钉(WIN 携 36/48 基线移出 R3b);
                             post-iteration-4 官方 93 场景复跑(2026-09-03)
                             **93/93 全 PASS**(硬闸门 passed、零 runtime error):
                             trait 22/22、huashan 47/47,零红
1. ✅ R5 navigation-and-consequence(2026-09-04 落地)—— 点之前知道后果(每盲选屏后果由数据渲染)、
   未提交选择屏可返回(五相位返回按钮 + ui_cancel,零差分)、不可逆提交两按确认(拜师/年末改投/结局行程/战斗回主菜单)、
   软锁裁决反转(无可练功法 → 返回行动重选、月份零差分;取代 jinyong-loop R2 烧月出口)、
   战斗与结局屏的角色总览面板(read-only RosterPanel 实例,battlefield.gd 零改动)、
   战斗命中飘字 + 顶栏日志(谁对谁/伤害/剩多少);证据 = 本轮遮挡证据(pre-fix 官方主网 62/62;post-fix 官方复跑由
   `occlusion_no_button_over_text` 22/22 + map 腿 9/9 承载——主网与 `ending_last_month_choice` 已随 pre-R5 路线钉按 owner 2026-09-04 裁决退役,
   见 99_changelog 2026-09-04 行)、C2 三钉与 C4 两钉官方绿(`playtest_summary.md: softlock_empty_practice_returns 16/16` 等);
   F1(cultivation.gd:1108 两参 get 崩溃)/F4(两按拜师 × 三逐字闸门单按 boot 停留 SECT_SELECTION)修复后官方复跑
   **已落盘收口**(2026-09-04 post-fix 终局官方 118 场景:0 runtime error、0/118 断言失败——R5 全部新钉绿、三逐字闸门 49/49·32/32·41/41 与 RNG 生命线
   14/14·19/19 官方实测;两条 pre-R5 固定帧路线钉按 owner 2026-09-04 裁决退役、同族 `cultivation_year_end_stay`/`sect_switch_same_school_connects` 原位重锚 8/8,裁决见 `90_decisions.md`「固定帧路线钉退役」行)
   —— **队列自第 2 项(外号)继续**
2. 外号(nicknames)       —— 替 ProgressionHero / Sparring Partner 裸 id
   (显示层已由 R4 改名侠客虾/陪练虾,R5 `enemy_hit_float_and_log_visible` 钉住屏上显示名;残余 = 内部键,与 UX-15 去名化同轮处理)
3. 回执/结算              —— 结局回顾与结算页(UX-30)
4. 教程与目标             —— 教程页加「本关目标」提示
5. 创建屏剩余点数         —— 捏人屏未用完点数显示(R5 已把加/减点成本常显,本条余「未用完点数」提示)
6. 地图有图              —— 大地图加背景图(terrain 已有占位)
7. 非战斗美术             —— 六段非战斗屏的美术填充
```

**官方复跑收口(2026-09-02,5_design 补记)**:队列第 0 项完成——修复轮
(fix_scenario_boot_rebaseline / fix_gate_i18n_ending_copy / r3c 带裁决与华山场景
恢复)之后,post-fix 官方 93 场景复跑实测:playtest 硬闸门 **`passed: true`**、
零 runtime error,run #1 九红中八条转绿(`cultivation_changes_combat` 30/30、
`action_yield_differential` 44/44、`huashan_readiness_warning` 16/16、
`ending_divergent_playstyles` 33/33、`ending_last_month_choice` 38/38、
`work_beats_idling` 26/26、`practice_target_receipt` 43/43、
`ending_tiers_differentiate` 27/27);编译 **107/107** 零错误、视觉闸门 passed
非盲(93 场景 372 帧,Q6 93 好 / 0 坏)。C5 `huashan_winnable_normal_route`
**36/48**:WON 尾维持许可红(f2100 观测 LOST,按 R3c WIN 裁决不冒充实测 WIN)。
复跑唯一**新**红:`trait_combat_effects_and_twelve_slots` **21/22**(f885
`moves_left == 0` 实测 3;run #1 全绿之列、本轮首红,记 `40_ux_backlog.md`
UX-40,诊断线索指向 C5 解锁杠杆 ③ 的 derive_stats move_range,根因未定)——
**队列自第 1 项(外号)继续**,UX-40 随下一轮一并处理。

**iteration-4 + 官方复跑收口(2026-09-03,5_design 补记)**:iteration-4 落地
(trait 钉重推导为差分钉 `moves_left == turn_start_moves_left - 2`、C5 尾按
所有者 2026-09-03 重划裁决重锚为诚实-LOST 钉 `current_state == "LOST"` /
`health < max_health` / `RetryButton.visible`,README 手册化 1727 → 72 行)
之后,post-iteration-4 树的官方 93 场景复跑实测(本步 `5_compile` / `5_vision`
产物):playtest 硬闸门 `passed: true`、零 runtime error、**93/93 场景全 PASS**
——`trait_combat_effects_and_twelve_slots` **22/22**、
`huashan_winnable_normal_route` **47/47**、`huashan_readiness_warning` 16/16、
`ending_tiers_differentiate` 27/27、`work_beats_idling` 26/26、
`practice_target_receipt` 43/43;编译 **107/107** 零错误;视觉闸门 passed
非盲(93 场景 372 帧,Q6 93 好 / 0 坏)。`40_ux_backlog.md`
**UX-40 → CLOSED(R3b numbers-bind)**。C5 的 WIN 移入 world-breadth 轮
(携 36/48 基线);遗留两项 record-only(`playtest/huashan_readiness_warning.yaml:125`
旧带算术注释、`battle_setup.gd:47` 注释 `floor(mp/3)` vs 代码 `:64`
`floor(mp/2)`)留给下一轮 code-touching 步。**队列自第 1 项(外号)继续**。

### Backlog(R3b 试玩发现,record-only,**本轮不做**;2026-09-02 已收进 `40_ux_backlog.md` UX-33..36 队列行,本表为发现时的原始快照)

| id | 界面 | 看见什么 | 备注 |
|---|---|---|---|
| UX-33 | 主菜单 / 大地图 | 无焦点标记(键盘导航时无高亮) | UX-11/UX-12 残余;需专门测量运行 |
| UX-34 | 底部技能栏 | 第二行被 704px 视口切掉 | 需技能栏布局重排(非本轮 scope) |
| UX-35 | 底部技能栏 | 槽位数字压住技能名 | 排版微调,与 UX-34 同批修 |
| UX-36 | 养成 / 角色面板 | `ProgressionHero` / `Sparring Partner` 原样上屏(英文裸 id) | 由队列第 1 项(外号)解决 |

### Owner 试玩反馈(2026-09-02 线上试玩)—— 2026-09-03 记录,logged **NOT implemented**

本轮(R4)只记录、不实现。R5 覆盖第 1/2/3 条与第 4 条的入口;R6 覆盖第 4 条的功法量、第 5、6 条。六条原文逐字照录:

1. 选项不给介绍:点按钮之前只看到名字,不知道效果(参照 Europa Universalis:每个按钮写明点了之后的后果)。
2. 没有可练功法时原本可返回重选,现在变成「度过本月」烧掉一个月 —— 裁决:应能返回,不该 skip。
3. 很多页面没有返回上一页(如修习,进去就不能反悔)。
4. 功法太少;装备/人物/功法栏看不到(入口不可达或无标识)。
5. 没有其他战斗、没有其他 NPC;养成期与大地图期都应有战斗。
6. 养成期一个月一次行动太少。

R5「点之前知道后果 + 每屏可返回」(1/2/3/4 的入口)已落地(2026-09-04,见编号队列第 1 项)→ 下一项 **外号**(R4 遗留,编号队列第 2 项)→ R6「江湖有人」(4 的功法量、5、6)。

## 参考

- Tim Cain 的九阶段划分(test room → beautiful corner → alpha → beta → ship)
- Vertical slice 的定义与判据(GIANTY / Tono / Rami Ismail)
- 「Balancing is tuning, not designing」(游戏经济平衡实践)
- 「Balancing only comes together once you start playing your own game, constantly」
