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
| 2026-09-03 | 外号裁定(江湖不称名,只称号,所有者裁定) | 屏上只出现带虾字的外号:杨过→独臂大虾、黄药师→东邪虾、欧阳锋→西毒虾、段智兴→南帝虾、洪七公→北丐虾、王重阳→中神通虾;路人按身份起带虾外号(侠客→侠客虾、陪练弟子→陪练虾);只改 display_name/_DISPLAY_ALIASES/_ORDER_TOKENS/教程文案/i18n(EN 译名本轮自拟 One-Armed Prawn / East Heretic Shrimp 等,非所有者裁定),character_name/节点名/turn_order 内部键不动;两条钉显示名字面量的既有闸门让位原地更新,三条 verbatim 闸门零改动 | `20_content.md` 附:R4 外号裁定记录;`tests/test_display_no_personal_names.py`;`playtest_summary.md: round_one_snapshot_and_turn_order 14/14、ui_geometry_readability 38/38`(2026-09-03 官方 95/95 全 PASS) |
| 2026-09-03 | Card 0 敌方回合墙钟 | 只许缩短等待与并行化(帧计数轮询 → 0.05 s SceneTreeTimer),不改 AI 决策与数值;完整敌方回合 ≤ 10 s、单人 ≤ 2 s、镜头平移不把上排敌人切进顶栏;web 墙钟轮内未实测(诚实分支:console 打印 + FROM HEAD 管线;红证据 = 2026-09-02 web 报告 20–40 s/人) | `30_presentation.md` Card 0 节;`playtest_summary.md: enemy_turn_wall_clock 5/5、camera_transform_follows_unit 13/13`;`final/delivery_notes_card0_enemy_turn_l1.md` |
| 2026-09-03 | design/ 预算偏差(记录) | brief 字面 `du -cb design/*.md ≤ 180 KB` 在「99_changelog.md 只增不删(164,501 B)+ 三文件内容冻结」约束下算术不可满足;重钉为除 99_changelog.md 外 design/*.md ≤ 340,000 B(实测 301,874 B),per-file 目标(≤ 25 KB / ≤ 20 KB)不变 | `tests/test_design_ledger_budget.py` docstring;`final/delivery_notes.md` §10.1 |
| 2026-09-04 | 点之前知道后果,从数据渲染(R5) | 每个盲选屏的后果说明**由数据模块在焦点/悬停时即时合成**(`CardData` 效果字段 / `EventData` 选项成本收益 / `ProgressionGongfaData` 三年授艺 / `ProgressionMath.work_income` / `MapData` 节点槽 / 捏人步进成本),经 `tr()` 出屏;不做手写字面量、不做 tooltip(触屏不可达);捏人属性/设施/技能条已合格不动 | `playtest/consequence_*` 八钉;`playtest_summary.md: consequence_card_pick_focus 11/11、map_travel_node_type_hint 9/9` 等;`scripts/segments/map_travel_hints.gd`(map.gd 零改动) |
| 2026-09-04 | 未提交的选择屏可返回,已提交的不回滚(R5) | ATTR/GONGFA/CARD/YEAR_END/SECT_SWITCH 五相位有可见「返回」按钮 + `ui_cancel`,零相位/月份/银两差分;已提交动作(月份推进/银两扣除)一律不回滚;不可逆提交(拜入门派、年末改投、通往结局的行程、战斗回主菜单)一律两按确认(首按零写入零 RNG);EVENT 阶段**无离开键**(见下行重申) | `back_button_*_zero_delta` 五钉;`sect_join/year_end_switch/travel_to_ending_needs_confirm`;`event_phase_no_exit_reaffirmed`;`battle_pause_menu_continue_zero_delta` |
| 2026-09-04 | EVENT 无离开键(重申,非推翻) | 重申 2026-08-31 EVENT 否决离开键的裁定(事件已抽取、RNG 已消耗;婉拒即出口):R5 的 `ui_cancel` 在 EVENT 相位显式早退,零差分;该裁决由新钉 `event_phase_no_exit_reaffirmed` 承载,原文见 archive `decisions_2026-08.md` | `playtest/event_phase_no_exit_reaffirmed`;archive: decisions_2026-08.md §EVENT |
| 2026-09-04 | 软锁 = 无路可走,不是「月份不走」(取代 2026-09-01 jinyong-loop R2 854-866 纪元) | R2 把「软锁」定义成月份不动、用「烧月」换绿,owner 2026-09-02 试玩裁定推翻:无可练功法时**返回行动重选、月份零差分**才是正确出口——软锁的定义是「玩家没有任何路可走」,空列表按钮是**返回**(标签 `返回行动`,不是 `度过本月`);旧裁决被本条以内容取代(archive 原文不动),三颗钉重推导为返回+零差分(`softlock_empty_practice_returns` 换名、另两条同文件重推),烧月断言零保留;M2' 腿 A do-nothing 不再经该按钮(见 40_progression.md §9 R5 注记) | `playtest/softlock_empty_practice_returns` 16/16、`clicks_only_gongfa_empty_exit` 19/19、`gongfa_pick_empty_keyboard_return` 16/16(2026-09-04 官方);`40_progression.md` §3 月度循环节 R5 注记 |
| 2026-09-04 | 拜师单按(R5 fix round) | 初始拜门在**每条输入路径**都是**单按**(点击与键盘 `ui_accept` 一致——无 per-input-path 分支;playtest-harness-injects-input 一类解法禁止),因为三条逐字闸门(`facility_use_reusable` 49/49、`map_node_event_shaolin` 32/32、`map_battle_node_huashan` 41/41,字节一致)为**游戏**钉住单按拜师,不是为某一条输入路径;让单按安全的是**点之前知道后果**(C1:拜师屏后果区在焦点/悬停时渲染加入给什么/花什么)与**返回路径**(C3:未提交时可见返回按钮、零状态差分);**年末改投保留两按确认**(无闸门钉它,且它是带代价的真实改投)。证据指针:三闸门计数 + 重推导的 sect-select 钉 `sect_join_needs_confirm` 8/8(硬闸门 passed: True)+ `final/delivery_notes_fix_f4_sect_join_single_press.md` | `playtest/facility_use_reusable` 49/49、`map_node_event_shaolin` 32/32、`map_battle_node_huashan` 41/41(字节一致,来源 `final/delivery_notes_fix_f4_sect_join_single_press.md` sidecar 复跑);`playtest/sect_join_needs_confirm` 8/8;`final/delivery_notes_fix_f4_sect_join_single_press.md` |

<!-- 本节以下的旧长文已由 R4 ledger slimming (2026-09-03) 逐字归档至
     design/archive/decisions_2026-08.md;现行裁决表见本文件顶部,一行一条。 -->

