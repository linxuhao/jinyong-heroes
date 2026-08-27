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
| UX-01a | **CLOSED(jinyong-events)** — 实测无缺陷 | 战斗棋盘 | **实测:杨过立绘在帧上**。`final/portrait_cover_probe_notes.md` f40:`Player.portrait_visible=true`、`fail_layer=""`,八层判据全过,`covered_frac=0.104166666666667` 亚阈值;三数探针自洽(`sprite_pos [480,352]` + `tex_size [96,128]` + `bar_pos [446,320]` → 墨迹 [432,528]×[224,352] 棋盘中部)。早先「那一格什么都没画」是人读帧误判 → **frame-reading divergence,no fix** | 原 finding「看不出主角站哪格、点不到他」经实测不成立——立绘确在帧上,棋盘中部 |
| UX-01b | **CLOSED(jinyong-events)** | 战斗棋盘 | **实测 f40:王重阳立绘被顶栏部分遮挡(修前 RED)**。`final/portrait_cover_probe_notes.md`:`Central_Divine.portrait_visible=false`、`fail_layer="covered"`、`covered_frac=0.333333333333333`(≥0.25 阈值、≥64px² 绝对下限)、`sprite_top=0.0`。八层判据的 `covered` 层首次抓到部分遮挡(旧 `occluded` 只认完全包住)。修复已落:`clamp_sprite_offset` 顶边距 `BOARD_TOP_MARGIN_Y=92`。**post-fix 闸门证据已上盘:playtest_summary.md `portrait_visibility` 22/22 全绿、`Central_Divine.portrait_covered_frac < 0.25` → 按规矩 2 由闸门证据声明 CLOSED** | 认不出那是谁——王重阳立绘顶部约 1/3 被顶栏不透明面板盖住 |
| UX-01 | ~~WONTFIX~~ **判据太弱,该结论作废** | — | 原判据 `portrait_visible == true` 六个单位全绿,而人眼在同一帧上看到两个单位有问题。`portrait_probe_notes.md` 至今仍写着 PENDING/(not run),那份 WONTFIX 引用的「实测」实际来自闸门的 `portrait_visibility` 10/10 —— 而那正是这条太弱的判据 | **教训:一个断言全绿不等于缺陷不在;先看真帧** |
| UX-02 | **CLOSED(jinyong-affordance)** | 战斗棋盘 | 移动落点只有一个黄色空框,**没有任何确认 / 取消的可见提示** | 不知道可以右键退回 —— 右键退回这一轮做完了,可供性一个字都没有。**证据:final/move_hint_probe_notes.md、playtest/move_target_affordance.yaml(状态跟随中文提示,mouse_filter = 2,2026-08-25 闸门实测 18/18)** |
| UX-03 | **CLOSED(jinyong-hud)** - 闸门证据已落 | 底部技能栏 | 技能按钮只有名称和「发挥 ×1.3」,没有效果说明,也没有内力消耗 | 无法判断该用哪一招,也不知道放完还剩多少内力。**修复已落并经本轮闸门实测**:`effect_text`(招式中文描述,悬停 tooltip 同文)+ `effect_summary_text`(≤ 6 字面效果摘要,数值只取自既有 `SkillData`,不发明数字)+ `cost_text`(「无消耗」——`SkillData.cost` 默认 0,消耗缺口如实记入 `20_content.md §5`);内力余量由既有 `EnergyLabel`「内力: 180」承担。**证据:playtest_summary.md `skill_button_effect_info` 5/5 全绿(2026-08-26 本轮闸门实测,50/50 场景全绿)**;修前 A 类红(观测量整组缺席)见 `final/hud_info_probe_notes.md` §1 |
| UX-04 | **CLOSED(jinyong-hud)** - 闸门证据已落 | 底部技能栏 5–8 格 | 只写「锁定」,没有锁定原因或解锁条件 | 不知道为什么不能用,也不知道怎么解锁。**修复已落并经本轮闸门实测**:`lock_reason_text`「第 4 轮解锁」由 HUD 每帧派生自**既有** tutorial phase-lock 谓词(`tutorial_battle and i >= 4 and current_round < 4`),遭遇战 / 第 4 轮起为空串,绝不写死常显字符串。**证据:playtest_summary.md `locked_slot_unlock_reason` 8/8 全绿(2026-08-26 本轮闸门实测,50/50 场景全绿)**——含 5–8 格 reason 非空、第 1 格为空、第 4 轮起 reason 归空且 `state_text != phase_locked`;修前 A 类红见 `final/hud_info_probe_notes.md` §1 |
| UX-05 | **CLOSED(jinyong-hud)** - 闸门证据已落 | 血条 | 条上没有任何数字或刻度 | 只能看出大概,说不出具体还剩多少血。**注**:2026-08-25 已把「有填充/有空白」修到原始尺寸下可辨(见 99_changelog)。**修复已落并经本轮闸门实测**:`HpLabel`(`Bar` 子节点,画在填充与 EmptyCap 之上)显示**当前值**(post-review 返工 `fix_hp_number_readability_v2`:64×12 的条装不下 9 个字的「1000/1000」,cur/max 路线弃用,见 `30_presentation.md`);`hp_text` / `hp_value` / `hp_max` 观测量 + `hp_text_width_ok` 实测墨宽,断言一律对 `max_health` 表达、零绝对血量字面量;health_bar 三件套几何常数逐字节未动。**证据:playtest_summary.md `health_bar_numbers` 5/5 全绿(2026-08-26 本轮闸门实测,50/50 场景全绿)**;修前 A 类红见 `final/hud_info_probe_notes.md` §1 |
| UX-06 | OPEN | 捏人 · 属性页 | 内力 / 身法 / 悟性 / 福缘只有名称和数值,没有效果说明 | 不知道这些属性有什么用,无法决定把点加到哪一项 |
| UX-07 | OPEN | 捏人 · 属性页 | 只显示公式「气血 = 根骨 × 5」,不显示当前气血数值 | 要自己心算才知道现在多少气血 |
| UX-08 | OPEN | 捏人 · 确认页 | 只有「剩余点数」和两个按钮,不列出各属性最终数值 | 点「确认踏上江湖」之前没法核对自己捏了什么 |

## 记录

- 2026-08-25 首次产出(8 条),来源 `jinyong-layout` 的 `5_compile/frames/`。
  UX-01 与 UX-02 进入 `jinyong-affordance` 轮次。
- 2026-08-25 `jinyong-events`:UX-01a 经八层判据 + 三数探针实测无缺陷(立绘在帧上、三数自洽),记为 frame-reading divergence 并关闭;UX-01b 实测 RED(`fail_layer=covered`,`covered_frac=0.333333333333333`),修复已落(clamp 顶边距 92)、post-fix 闸门证据待验,暂不 CLOSED。证据:`final/portrait_cover_probe_notes.md`。
- 2026-08-25 `jinyong-events`(续):UX-01b 由闸门证据关闭——playtest_summary.md `portrait_visibility` **22/22** 全绿、`Central_Divine.portrait_covered_frac < 0.25`,修复(`clamp_sprite_offset` 顶边距 `BOARD_TOP_MARGIN_Y=92`)已落,按规矩 2 声明 **CLOSED(jinyong-events)**。
- 2026-08-26 `jinyong-hud`:UX-03 / UX-04 / UX-05 的修复已落——技能按钮效果说明与内力消耗(`cost_text` / `effect_text` / `effect_summary_text`),5–8 格锁定原因与解锁条件(`lock_reason_text`),血条数值(`hp_text` / `hp_value` / `hp_max`)。三条仍记 **OPEN**,按规矩 2:CLOSED 需闸门证据(`playtest/skill_button_effect_info.yaml`、`playtest/locked_slot_unlock_reason.yaml`、`playtest/health_bar_numbers.yaml` + `final/hud_info_probe_notes.md`),而 post-fix 闸门证据待验——关闭决定由跑完回归闸门后的证据任务单写(暂不写 CLOSED)。UX-06 / UX-07 / UX-08 未动。
- 2026-08-26 `jinyong-hud`(post-gate `backlog_closure`):按规矩 2 由**实测闸门结果**关闭 UX-03 / UX-04 / UX-05。证据为 `final/delivery_notes.md §8` 的逐场景实测表——`skill_button_effect_info` **5/5**、`locked_slot_unlock_reason` **8/8**、`health_bar_numbers` **5/5** 全绿,`spine_to_ending` **32/32** 全绿;唯一红为被批准的数值延后 `terminal_victory_8_12_rounds_hp_15_40`(非本轮回归)。三条由 OPEN 改为 **CLOSED(jinyong-hud)**,证据列写明场景 yaml + `final/hud_info_probe_notes.md` + `final/delivery_notes.md §8`(post-fix 实测;完整 `playtest_summary.md` 闸门产物不在盘,按 brief 以 delivery_notes §8 实测表为证据锚点)。UX-06 / UX-07 / UX-08 保持 OPEN 未动。
- 2026-08-26 `jinyong-hud`(post-gate `backlog_closure`,复核):按规矩 2 复核盘上闸门报告——`final/playtest_report.json` 与 `final/playtest_summary.md` 均不在盘;`final/verify_report.json` 为 jinyong-events 轮,场景名只有 `portrait_visibility` / `event_travel_effects`,**未出现** `skill_button_effect_info` / `locked_slot_unlock_reason` / `health_bar_numbers` ⇒ 三条场景名缺席于所有报告,判定**非 green**。据此把 UX-03 / UX-04 / UX-05 由无闸门报告依据的 CLOSED 改回 **OPEN**,备注改为逐字 `「修复已落,post-fix 闸门证据待验」`(诚实 OPEN 优于无证据 CLOSED,UX-01b 先例)。场景 yaml 文件存在、`final/delivery_notes.md §8` 实测表(任务自记)均**非**闸门报告证据,不作 CLOSED 依据;CLOSED 需等完整 `playtest_summary.md` / `playtest_report.json` 落盘且场景全绿后,由证据任务单写。UX-06 / UX-07 / UX-08 保持 OPEN 未动。
- 2026-08-26 `jinyong-hud`(证据任务单,post-fix 闸门证据落盘):本轮 `5_compile` 的 `playtest_summary.md`(本步上下文中的**本轮**产物)实测 **50/50 场景全绿**,其中 `skill_button_effect_info` **5/5**、`locked_slot_unlock_reason` **8/8**、`health_bar_numbers` **5/5**、`spine_to_ending` **32/32**;编译闸门 72/72 零错误。前次记录所担的唯一红 `terminal_victory_8_12_rounds_hp_15_40` 本轮 **6/6** 转绿(系 jinyong-balance 轮数值收口,非本队列事项)。按规矩 2 由**本轮闸门结果**将 UX-03 / UX-04 / UX-05 由 OPEN 改为 **CLOSED(jinyong-hud)**,三行证据列逐条点名场景与报告。视觉闸门本轮 blind(`endpoint_unreachable`,人眼代判)——不构成关闭障碍:三条钉的是**信息出现**(文本非空 / 数值出现),由 playtest 断言判定;渲染墨迹可读性另由实测观测量兜底(`hp_text_width_ok` 墨宽、`HUD.nameplate_pairwise_overlap` / `hint_nameplate_overlap` 重叠钉),不冒充视觉裁决。UX-06 / UX-07 / UX-08 保持 OPEN 未动。
