# Decisions

> 本文件是「现行裁决表」:每条裁决一行(日期 / 范围 / 现行规则 / 证据指针)。
> 被替代或已落地的长篇推导**逐字**搬入 `design/archive/decisions_2026-08.md`;
> 每条被搬走的裁决在此保留一行索引指针。R4 Card N+2(2026-09-03)ledger slimming。

| 日期 | 范围 | 现行规则 | 证据指针 |
|---|---|---|---|
| 2026-08-22 起 | Out of scope 否决清单 | 实时战斗 / 单挑擂台 / 标量熟练度 / 相克 / 好感度 / 同伴养成 / 人物等级 等一律否决(理由逐字归档) | archive: decisions_2026-08.md §Out of scope |
| 2026-08-23 起 | Open questions 待决清单 | 已决定但未设计的养成数值 / 首批事件 / 江湖图 / 结局分级 待各层落定;普攻消耗 0 为保底动作,定价须先立决定 | archive: decisions_2026-08.md §Open questions |
| 2026-08-28 | 武虾世界观 | 游戏里出现的每一个角色都是一只虾(现有六只及此后新增);仅形象与称号是虾,文案一字不动 | `99_changelog.md`;`test_shrimp_roster.py` |
| 2026-08-28 | 战斗命中 5 步优先级 | 左键依次解算:脚格敌→in-reach 敌立绘矩形→可达空格移动→out-of-reach 选中→自己脚格;空格不因身后立绘高而点不到 | `30_presentation.md`;`final/delivery_notes.md` |
| 2026-08-28 | menu.tscn 全屏 STOP 根因 | 全屏 Control 宿主须 `mouse_filter=2`(IGNORE);契约默认 scene 与游戏 boot scene 分歧已入 `_common.yaml` | archive: decisions_2026-08.md §P0 根因 |
| 2026-08-28 | 地图提示一屏一条 | 保留页脚 `HintLabel`,删面板尾行;不许「两处都留但内容一致」算统一 | `playtest/map_hint_single.yaml` |
| 2026-08-28 | 棋盘不受视口约束 | 棋盘=内容尺寸(GRID×TILE),视口=显示尺寸;相机拥有可见性,「整盘看不全」是常态非缺陷;对位 pin 断立绘站自家格 | `camera_follower.gd`;`portrait_grid_alignment.yaml` |
| 2026-08-29 | 点击锚解锚 *_ClickTarget | 点击锚指向单位自身 Node2D 名(如 `Central_Divine`),不挂 `*_ClickTarget`;闸门只断游戏级属性 | archive: decisions_2026-08.md §点击锚 |
| 2026-08-29 | 门派设施定义 | facility 从不接入到达分派,只由 `use_facility`(F)主动进入;复用上限每 profile 月 2 次;event/facility 两条通道互不读写 `events_seen` | archive: decisions_2026-08.md §门派设施;`facility_use_reusable.yaml` |
| 2026-08-29 | 解析错误拉倒整轮验证 | 新增 `tests/*.gd` 后交卡前先独立解析检查;红转绿记录是一次性证据,常驻性质由负向断言承载 | archive: decisions_2026-08.md §解析错误 |
| 2026-08-29 | 主线六段触屏可达 | 六段(transition/sect_select/cultivation/map/ending + overlay)补可见可点控件;`clicks_only_storyline` 证明不碰键盘能走到结局;FACILITY 委托三按钮 delegation-only | `clicks_only_storyline.yaml`;`map_facility_buttons_click.yaml` |
| 2026-08-30 | 单面 + 全状态可点出口 | 按钮是选项唯一呈现(删逐字重复选项行,保留描述与操作摘要);每个需选择相位必有可点出口;选中高亮=`modulate` 亮/暗 | `30_presentation.md` 指针可达性 (f)/(g);`test_touch_option_surface_gate.gd` |
| 2026-08-30 | 角色面板七裁定 | 面板纯展示 overlay、任意相位可开、关闭=按钮+点外、click-only、(e)只读保证、降级不发明、自足 instanced 场景 | archive: decisions_2026-08.md §jinyong-roster |
| 2026-08-31 | 武虾立绘落地 | 四虾种由所有者裁定(东邪 樱花虾/南帝 罗氏沼虾/中神通 玻璃虾/杨过 枪虾);画风换向头卡通身写实;换图重测几何零红 | archive: decisions_2026-08.md §武虾立绘落地 |
| 2026-08-31 | 角色面板只读保证被推翻 | 取代 08-30 (e):面板经 equip/unequip_slot 只写 `equipped` 三槽;其余自由动作不变量保留;装备差分 `equipment_in_battle_diff` 47/47 | archive: decisions_2026-08.md §jinyong-equipment-battle |
| 2026-08-31 | 事件池扩至 36 | 池=恰好 36、append-only、冻结 16 条逐字不动;不重复由 `_test_no_repeat_full_journey` 实测;新文案物种中性 | `test_event_data.gd`;`event_pool_new_event_resolved.yaml` |
| 2026-08-31 | 事件散文全员虾化 | 冻结 16 条仅散文半边解冻;36 条散文人形词换虾体行文;id/effects/选项结构/36 行数/行序仍冻结(`ROW_EFFECTS` 镜像未改即证明) | `test_event_prose_shrimp.py`;`20_content.md` §4 |
| 2026-09-01 | 华山建人来源解耦 | `map_battle_id`=建人来源(非空⇒profile 建人+按 id 解阵容);`battle_return_state`只剩返回目标;对手=五绝数据行 | `map_battle_node_huashan.yaml` 41/41;`final/delivery_notes_huashan.md` |
| 2026-09-01 | 水墨主题调色与焦点 | 深墨底+纸色字 light-on-dark(取代宣纸浅面板);压字修复结构性不透明底板;焦点 stylebox+字色换装(cultivation/sect_select);残余 map/creation 保留 | `32_theme.md`;`theme_focus_marker_cultivation.yaml` |
| 2026-09-01 | 月度循环四短路修复 | 软锁出口转属性分配并推月份(零白送);设施复用每 profile 月 2 次;事件结算键=(节点,事件)对;购买 validate-then-apply 全有或全无;零平衡数字移动 | `final/delivery_notes_loop*.md`;`ui_occlusion_watch.gd` |
| 2026-09-02 | 等级词表单一来源 | `PRACTICE_TO_MASTER` 键集(拉丁 D/C/B/A)是等级词表唯一来源;`GRADE_POINTS` 键集须相等(D1 C2 B3 A4);测试禁手写等级字符串 | `test_progression_math.gd` |
| 2026-09-02 | M2/M3 真实档实测 | M2/M3 必须真实档(完整 boot)验证;空档只承载「度过本月×36」唯一合法零收益路线;做工曲线为 C7 杠杆 | `40_progression.md` §7/§9;`final/delivery_notes_fix_c*.md` |
| 2026-09-02 | 华山数据解锁裁决 | 授予:`map_battle_data` POSITIONS/PLAYER_SPAWN + 五先攻字面量 + `battle_setup` mp 折现(move/伤害/血);禁降血/攻/减单位数/改 AI | `final/unlock_record_r3b_huashan.md` |
| 2026-09-02 | 结局阈值 C3 双杠杆 | 构成杠杆(免费卡银两不计 deeds)+ 阈值重定(旧 90/60/0→150/120/0)同属一次测量;三档随构成自然分化 | `40_progression.md` §M2';`final/delivery_notes_fix_c3_ending_tiers.md` |
| 2026-09-02 | R3c WIN 裁决 | WIN 尾为许可红(不冒充 WIN);红 WIN 断言不可接受,诚实 LOST 钉可接受;诚实分支须同改动重推导 ending gate pins | archive: decisions_2026-08.md §R3c WIN |
| 2026-09-03 | C5 诚实-LOST 收口 | WIN 由所有者重划出 R3b;诚实 LOST 钉是 R3b 的 C5 交付物;WIN 携 36/48 基线移入 world-breadth 轮;五绝数据保持锁定 | `playtest_summary.md: huashan_winnable_normal_route 47/47`;`final/delivery_notes_r3c_restore_huashan_scenario.md` |
| 2026-09-02 | 华山带裁决(C4) | `P_fresh_max`=仅靠创建分配可达最高 readiness_power(60);`even=P_fresh_max+1=61`;真实路线落 even 之下**不降 even**,成长曲线缺陷交下一轮 | `40_progression.md` §M3''';`final/delivery_notes_r3c_readiness_bands.md` |

<!-- 本节以下的旧长文已由 R4 ledger slimming (2026-09-03) 逐字归档至
     design/archive/decisions_2026-08.md;现行裁决表见本文件顶部,一行一条。 -->

