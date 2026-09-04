# 40_ux_backlog.md — 用玩家的眼睛看,而不是用闸门的六个问题看

视觉闸门问的是**写死的六问**(格子线 / 技能按钮有别 / 按钮跨帧变化 / 回合状态可见 /
血条可辨认 / 文字无截断),而且前五问只对战斗场景生效。这份队列装的是**六问问不到的东西**:
可供性、信息缺失、玩家看不懂下一步该干什么。

来源:对真实渲染帧提一个开放问题——
「按主要用鼠标玩、键盘辅助的电脑玩家视角,这个界面有什么需要改的」。
产出格式固定为 `FINDING | 区域 | 看见什么 | 玩家因此做不到什么`,禁止写放之四海皆准的建议。

## 规矩

1. **这份队列永不参与任何闸门的 `passed`。**开放式评审答不出「什么状态会让它红」,
   当闸门要么永远不红(等于没有),要么按品味判红(等于随机拦人)。
2. **关闭必须是一个动作,不能是推断。**一条 finding 从新一轮的产出里消失**不等于**它被修好了
   ——可能只是这轮没拍到那个界面。只有在修它的那次提交里显式改成 `CLOSED(轮次名)` 才算关。
3. **不许自动开卡。**模型提得比我们修得快;它的产出是**下一轮种子的候选池**,由人筛。
4. **淘汰条件:连续三轮没有任何一条被 `CLOSED`,就删掉这个机制**,而不是留着当装饰。

## 队列

| id | 状态 | 界面 | 看见什么 | 玩家因此做不到什么 |
|---|---|---|---|---|
| UX-09 | **OPEN** | 战斗棋盘 | 相机拥有可见性后「整盘看不全」是常态:棋盘南端在相机北极时会落在招式栏后,屏外单位没有指示 | 不知道棋盘另一端还有谁、敌人是不是走出了屏幕;需要小地图 / 屏外单位边缘指示。本轮记不实现,优先级因「整盘看不全成常态」而升高 |
| UX-10 | **OPEN** | 战斗棋盘 | 立绘 96px 宽 vs 64px 格,未钳位也**横向外溢相邻格子**;地面标记 TileMarkers 存在的唯一残留理由即此 | 棋盘不再受视口约束后,立绘:格子尺寸比 96/64 是一个**可调的内容决策**(改 `PORTRAIT_TEX_Y` / 纹理宽 / `TILE_SIZE` 的哪一项,取决于内容想表达什么);本轮记不实现,仅记录其为可调项 |
| UX-11 | **OPEN** — 测量仅记,不设闸门(禁止任何 `size >= 48` 引擎级尺寸断言) | 主线各屏 | 960×704 设计分辨率下,实测各主线可点控件的 `get_global_rect().size`:**overlay** `ContinueButton` / `RetryButton`、`NextButton`(过场)、`SectButton0..4`(拜师)、`CultOptionButton{i}`(养成)、`TravelButton{i}` / `EventOptionButton0/1` / `FacilityEnterButton` / `FacilityUseButton` / `FacilityLeaveButton`(大地图)、`RestartButton`(结局),以及已可点的 creation / HUD / menu / tutorial-overlay 按钮。点名最小的几个(预期:捏人 `AttrPlus{i}` / `TraitToggle{i}` 与新加选项按钮)。平台参考仅作记录:Material 48 dp / HIG 44 pt / WCAG 2.5.8 24 px。**不含任何尺寸阈值断言** | 触屏目标太小点不准——本轮只测量、不设闸门,留待后续轮按记录定夺 |
| UX-12 | **OPEN** — 本轮只测不修(文案对齐范围 = overlay 仅此一处,见 `90_decisions.md` 2026-08-29 touch-reach 条 (c)) | 主线各屏键盘提示文案 | 残留只讲键盘操作、屏上**已有控件**但文案没说可点的提示,行号 2026-08-30 由 5_design 读树复核(touch-single-surface 轮缩短 map 复合键、i18n 条目增删使行号位移,位移明细见本文件 2026-08-30 记录行):`scripts/autoload/i18n.gd` :349(结局重开复合键「【结局 · %s】\n\n%s\n\n按回车重新开始」,ending.gd:58 调用点;独立键仍在 :350)、:354(过场「按回车继续」)、:359(拜师「上下选择 · 回车拜入」)、:364(地图「左右/上下选择相邻去处，回车启程」)、:368(事件复合键「【%s】\n\n%s\n\n上下选择，回车定夺」,本轮由 4 槽缩短为 2 槽)、:377(设施「回车使用 · 上下离开」,原 :378)、:379(设施「\n\n门派设施：%s（F 使用）」,原 :380)、:410(养成功法「\n上下选择，回车苦练」,本轮起空列表分支也显示)、:122/:123(教程开场「按「继续」或回车继续」);场景文件字面量 `transition.tscn` :50、`sect_select.tscn` :49、`cultivation.tscn` :47、`ending.tscn` :48、`map.tscn` :49;`scripts/segments/sect_select.gd` :78(正文尾「上下选择，回车拜入」,原 :75);`scripts/segments/cultivation.gd` :822-:853(各相位键盘提示调用点) | 提示仍在讲键盘,手机玩家不知道可以点;行号已按 2026-08-30 盘上代码刷新,状态仍 OPEN(本轮只测不修) |
| UX-14 | **OPEN** — 2026-09-04 更新:R5 已把总览面板(人物/装备/功法)入口接到战斗(`hud.tscn`)与结局(`ending.tscn`,只读实例 + 战斗/结局两屏开合零差分钉绿),「看不见」欠账清掉;本行只余「战前配装」——§9 承诺的选择仍不存在 | 角色页/战前 | `design/40_progression.md §9` promises 战前选装 (player loadout selection) while `scripts/data/battle_setup.gd` auto-equips the top-2 external arts by grade (3 with 左右互搏) — the promised player choice does not exist; panel visibility itself now exists on all main screens (R5) | 战前选择仍不存在;auto-equip 是既成行为,差距记档待后续独立一轮 |
| UX-15 | **OPEN** — 独立一轮(资源改名会打断编译期引用,不得与几何证明轮混做) | 角色资源命名 | `yang_guo.png` 是全仓唯一带人名的资源(名册 note 原文:「唯一带人名的资源,替换时一并改称号,人名不进公开构建」);去名化须一次做完:PNG/资源改名 + 三处引用(`scenes/player.tscn`、`assets/characters/roster.json`、`assets/seed_manifest.json`) + 称号去名化(「杨过 / 独臂神雕侠」→ 非人名称号) | 公开构建里出现人名「杨过」;五位宗师都是称号、主角至今没有非人名称号——改名 + 三处引用 + 称号必须同轮落地并重跑编译 + 全量闸门 |
| UX-19 | **OPEN** — record-only 清单(2026-08-31 起;本轮只记不改,后续一轮一片,每片同改其测试镜像与 i18n 条目) | 36 条游历事件之外的玩家可见人形散文 | 2026-08-31 全仓清查(grep 类 `(人|僧|道|翁|匠|丐|匪|商|客|师|郎|主|民|徒|兄|姐|妹|侠|豪|杰|掌门|官|兵|贼|盗)`,逐条人工分类;全单与 skip 理由见 `final/human_prose_sweep_notes.md`)——运行时字面量:`scripts/data/card_data.gd` :33/:34/:35 「行商分成」×3(经济卡显示名)、`scripts/data/facility_data.gd` :31 「…是少林弟子练骨之地」(弟子)、`scripts/data/map_data.gd` :69 「一代宗师」 / :70 「各派掌门纷纷登门请教」(掌门) / :72 「江湖中人…皆有豪杰相迎」(中人/豪杰,结局文案)、`scripts/data/trait_data.gd` :25/:27/:30 (敌人/师门/单人——存疑:战斗敌人就是六只虾,是否入列待裁定)、玩家角色标签 `scripts/autoload/i18n.gd` :143 「侠客」 + 清单外补记 `scripts/data/battle_setup.gd` :63 `display_name = "侠客"`(2026-09-03 R4 外号轮:此处与 i18n.gd :143 已改「侠客虾」,本清单其余人形泛词条目未动,状态不变);i18n 镜像:i18n.gd :126/:128/:130 (教程「敌人」) / :217/:221/:227 (特质镜像) / :241 (行商分成) / :423/:424/:426 (结局镜像) / :455 (设施镜像);测试镜像:`tests/test_card_data.gd` :50 (行商分成);检查过且干净:tutorial_fillers / encounter_data / gongfa_data,场景 tscn 仅 `scenes/segments/sect_select.tscn` :88 「丐帮」(门派专名,SKIP) | 玩家在事件之外仍读得到不指明物种的人形词(行商/弟子/掌门/豪杰/侠客…);逐片修复须同改镜像 + i18n + 闸门复跑,一次一片才能归因 |
| UX-20 | **OPEN** — record-only(2026-08-31 实测发现,`jinyong-huashan` 轮入列,本轮不修) | 养成 · 月度循环 | 月度循环无反馈、数值几乎不动:全程选「成长」四维仅 10→14;全程选「钱」36 个月四维纹丝不动 | 三年养成的感知收益近零,选什么都看不出差别——数值量级是第 5 阶段的事,反馈缺失(选完没有任何回显)另行排期 |
| UX-21 | **OPEN** — 2026-09-01 更新(cultivation / sect_select 两处已修并经本轮官方闸门实测;残余未修,故不关) | 按钮焦点高亮(touch-single-surface 的 modulate 亮暗) | 焦点高亮低于可感知阈值:选中行仅亮 2–3%,肉眼几乎分不出选中与未选中。**已修两处**:`cultivation.gd:641` 与 `sect_select.gd` 换 `ThemeManager.option_style(focused)` stylebox(朱红 3px 左条 + 边框)+ 字色换装,新差分场景 `theme_focus_marker_cultivation` 本轮官方闸门实测 **14/14**(先红后绿:f110 `focus_marker_active == true` observed=false、红前绿 7) | **残余**:`scripts/segments/map.gd`(jinyong-huashan 轮锁定文件,本轮零改动)与 `scripts/segments/creation.gd`(AttrRow 是裸 Control,机制不同)仍用 modulate 亮度差,焦点不可感知;残余关闭需各自动作 + 闸门证据,待排期 |
| UX-23 | **OPEN** — record-only(同上) | 大地图 | 大地图是竖排列表,无地理:节点间相邻关系与方位全靠文字,没有空间感 | 「行走江湖」的空间幻想落空;重排成有地理感的呈现属呈现层大活,待立项 |
| UX-24 | **OPEN** — record-only(同上) | 事件 / 选项结算 | 选择静默结算,无回执:选完选项没有任何「你得到了什么」的反馈 | 银两 / 属性变动发生但不可见,玩家无法建立「选择→结果」的因果;结果回显待排期 |
| UX-25 | **OPEN** — record-only(同上) | 养成 · 月度牌堆 | 每月牌堆四次跑逐字相同:同一个月里反复出现的卡组内容毫无变化 | 牌堆内容过少或抽样过窄,重复感破坏探索;扩池/抽样是内容活,待排期 |
| UX-26 | **OPEN** — record-only(同上) | 世界观一致性(虾) | 虾只出现在战斗屏:六只武虾立绘只在战场可见,养成 / 地图 / 事件界面没有任何虾的视觉存在 | 「一切角色都是虾」的裁定在战斗外不可感知;角色在非战斗界面的出现方式待设计 |
| UX-27 | **OPEN** — record-only(同上) | 捏人 | 创建角色无姓名、无立绘:捏出来的自己既没有名字输入也没有形象 | 玩家对「我是谁」零投入感;命名输入与主角立绘牵涉 UX-15(去名化)的裁定,须同轮考虑 |
| UX-28 | **OPEN** — record-only(同上) | 养成 · 存档 | 存盘 / 读档 / 删档混在「本月行动」选项里,与练功 / 做工同级同列 | 元操作(存读档)与月度行动(消耗月份)同列,误触即耗一个月;信息架构重排待立项 |
| UX-29 | **OPEN** — record-only(同上) | 养成 · 练功 | 练功是空屏:进入练功后没有可看的内容,只有退出 | 练功作为核心动作缺少反馈面;与 UX-20(月度循环无反馈)同根,修时须一起 |
| UX-30 | **OPEN** — record-only(同上) | 结局 | 结局不做总结:到昆仑直接出结局文字,三年里攒了什么、经历了什么一概不提 | 结局是整个 loop 的 payoff 时刻,却没有一行回顾;总结页属内容活,待立项 |
| UX-33 | **OPEN** — record-only(R3b 试玩发现;2026-09-02 自 `00_roadmap.md` R3b backlog 表收进本队列,本轮不做) | 主菜单 / 大地图 | 键盘导航时无焦点标记:菜单与地图列表没有可见高亮 | 键盘玩家看不出当前选中哪一项;需专门测量运行与样式裁定(UX-11/UX-12 残余) |
| UX-34 | **OPEN** — record-only(同上) | 底部技能栏 | 第二行技能被 704px 视口下缘切掉 | 8 格技能栏在最小视口下后半不可见不可点;需技能栏布局重排(与 UX-35 同批) |
| UX-35 | **OPEN** — record-only(同上) | 底部技能栏 | 槽位数字压住技能名 | 读不出格子对应哪一招;排版微调,与 UX-34 同批修 |
| UX-36 | CLOSED(R5) | (全文已逐字移入 `design/archive/ux_backlog_closed.md`) | | |
| UX-37 | CLOSED(R3b) | (全文已逐字移入 `design/archive/ux_backlog_closed.md`) | | |
| UX-38 | CLOSED(R3b) | (全文已逐字移入 `design/archive/ux_backlog_closed.md`) | | |
| UX-39 | CLOSED(R3b) | (全文已逐字移入 `design/archive/ux_backlog_closed.md`) | | |
| UX-41 | **CLOSED(R5 fix round)** | 养成 · EVENT 后果渲染 | `cultivation.gd:1108` 对 `EventData.EventOption`(RefCounted)两参 `get("effects", [])` → 真实档 EVENT 后果渲染崩溃(`save_load_roundtrip` 10/14、`consequence_event_option_visible` 7/9、`event_phase_no_exit_reaffirmed` 7/8 唯一红同源);**post-fix sidecar 实测已落**(来源 `final/delivery_notes_fix_f1_event_option_effects_read.md`):`save_load_roundtrip` **14/14**、`consequence_event_option_visible` **9/9**、`event_phase_no_exit_reaffirmed` **8/8**、`event_travel_effects` **19/19** | F1 修复(读类型化 `opt.effects`)落地后 C1 在该屏恢复,驱动不再崩溃;全文见归档 |
| — | CLOSED 项全文见 design/archive/ux_backlog_closed.md | | | |

## 记录

> 逐轮关闭 / 新开记录与盲判人工读帧散文已逐字归档至 `design/archive/ux_backlog_closed.md`（R4 Card N+2, 2026-09-03）。本文件只保留 OPEN 项。

- 2026-09-03 `R4 外号轮` 记录行已逐字移入 `design/archive/ux_backlog_closed.md`(R5 收尾,per-file 预算钉越界;原文以归档为准)。
- 2026-09-04 `R5 navigation-and-consequence`(post-gate 记录,5_design;证据 = 本步上下文本轮 `5_compile` / `5_vision` / verify 产物):**本轮关闭 1 条、新开 1 条、入档 1 条,其余 OPEN 状态不变**。① **UX-36 → CLOSED(R5)**——R5 战斗屏命中反馈使 `enemy_hit_float_and_log_visible` **9/9** PASS 成为侠客虾/陪练虾的首条屏上场景钉(命中行钉 R4 显示名、零内部 id);战前选装残余归 UX-14。② **新开 UX-41(OPEN,官方闸门红入档)**——`cultivation.gd` `_event_effects_text` 对 `EventData.EventOption` 用两参 `get`(:1108),真实档 EVENT 后果渲染崩溃(`save_load_roundtrip` **10/14**、`consequence_event_option_visible` 7/9、`event_phase_no_exit_reaffirmed` 7/8 的唯一红同源;修法一行,sweep 修订 1 已实测可绿),归 owning C1 卡修。③ **入档官方红共同根因 F4(两按拜师)**——三条逐字保护闸门单按 boot 停在 SECT_SELECTION(`facility_use_reusable` **0/49**、`map_node_event_shaolin` **1/32**、`map_battle_node_huashan` **5/41**),RNG 生命线连带(`event_travel_effects` **1/19**、`action_yield_differential` **24/44**):不记 UX 新卡,按 verify_report issues F4 追踪,修法 = `sect_select.gd` 只在交互路径武装;三闸门逐字节未动。④ 逐条裁定:UX-14 更新(总览入口已清欠,余战前配装);UX-37/38/39 既有 CLOSED 不受影响;UX-11/12/15/19/20/23..30/33..35 无指向动作。诚实边界:本轮 playtest 硬闸门 `passed: false`(344 runtime error,主体 = F1 × F4),62/62 遮挡网与 C2/C4 钉绿如实引用,全量收口待 F1/F4 修复后官方复跑。
- 2026-09-04 `R5 fix round`(post-fix 记录,5_design;证据 = 各 fix 卡交付说明 sidecar 复跑):**UX-41 → CLOSED(R5 fix round)**——F1 修复(`cultivation.gd:1108` 两参 `get` → 读类型化 `opt.effects`)落地后 post-fix sidecar 复跑 `save_load_roundtrip` **14/14**、`consequence_event_option_visible` **9/9**、`event_phase_no_exit_reaffirmed` **8/8**、`event_travel_effects` **19/19**(来源 `final/delivery_notes_fix_f1_event_option_effects_read.md` sidecar 复跑)。**F4 实际落地的裁决**:初始拜师在**每条输入路径**恢复**单按**——三条逐字闸门回字节一致绿(`facility_use_reusable` **49/49**、`map_node_event_shaolin` **32/32**、`map_battle_node_huashan` **41/41**),重推导钉 `sect_join_needs_confirm` **8/8**、`consequence_sect_select_focus` **10/10**、`action_yield_differential` **44/44**、`practice_target_receipt` **43/43**、`clicks_only_storyline` **47/47**(来源 `final/delivery_notes_fix_f4_sect_join_single_press.md` sidecar 复跑);拜师屏后果预览(C1)与返回路径(C3)保留。**残余 fix 收口**:`back_button_year_end_zero_delta` **10/10**(`final/delivery_notes_fix_r5_year_end_silver_baseline.md` sidecar)、`creation_layout_readability` **23/23**(`final/delivery_notes_fix_r5_creation_layout_regression.md` sidecar)、`enemy_turn_wall_clock` **14/14**(`final/delivery_notes_fix_r5_enemy_turn_split_bound.md` sidecar)、`consequence_work_income_inline` **10/10**(`final/delivery_notes_fix_stale_pin_constants.md` sidecar)。UX-14 保持 **OPEN**(战前配装仍不存在)。


