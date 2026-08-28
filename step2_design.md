# 技术架构设计 — 相机拥有可见性:删掉钳位与它逼出来的补偿

> Step 2 (Architect) · 2026-08-28 · 上游:Step 1 SOTA(`step1_sota.md`)+ 项目档案 `design/`。
> 本文档是**实现者的硬契约**:组件、接口、文件路径、删除清单、实施顺序、像素推导。
> PM 据此拆任务。路径一律相对仓库根(`./`)。

## 概述

把"立绘完整可见"从**精灵级**属性改成**相机级**属性。加一个跟随 Camera2D,由它拥有可见性;删掉 `GridManager.clamp_sprite_offset` 及其逼出来的整套补偿;补上从来不存在的那条对位断言(立绘站在自己格子上);删掉制造了这一切的闸门与三处背书 pin。

**一句话判据(写进 design)**:可见性由相机拥有,精灵只负责站在自己的格子上,二者不得互相代偿;闸门断言游戏级属性,不断言引擎级属性——一条闸门若只能靠改动引擎本该自己算的(offset/position/size/z-order)来满足,要删的是闸门。

**今天为什么行不通**:棋盘 15×11×64 = 960×704 = 视口。这个等式(不是定律)让"移动相机"看起来不可能,钳位就是为它打的补丁。本轮把它拆开:棋盘是内容尺寸,不再受视口约束;可见性归相机。

## 架构图(数据流)

```
CombatManager._active_unit  ──(getter)──▶  CameraFollower._follow_target
        │                                            │
        ▼                                            ▼
  active_unit_name (surface)              target.position (feet, world)
                                                   │
GridManager.board_rect() ◀──── 常量源 ────┐        │
        │   GRID_*/TILE_SIZE/GRID_ORIGIN  │        │
        ▼                                  │        ▼
  cam_x_lo/hi, cam_y_lo/hi ◀── no-blank ─┤   clampf(target, lo, hi)
        │   公式(见 §相机数学)            │        │
        ▼                                  │        ▼
  HUD: TopStrip/SkillBar ── cover ────────┘   Camera.position = cam
        │   (T=92 / B=648, viewport-px)            │
        ▼                                         ▼
  hud_band_top/bottom, active_unit_screen_y   世界→屏幕(Coord.world_to_screen)
        │                                              │
        ▼                                              ▼
  playtest surface:  Camera.{camera_position, camera_y_lo/hi, hud_band_top/bottom,
                              active_unit_screen_y, follow_target_id, follow_target_is_active}
        │
        ▼
  portrait_visibility.yaml(改写)断言:active_unit_screen_y ∈ [hud_band_top,hud_band_bottom]
                                       且 camera_y ∈ [camera_y_lo, camera_y_hi]
                                       且 follow_target_is_active == true
```

**点击反向流(屏幕→世界,相机一动就必须配对)**:
```
InputEventMouseButton.position(viewport-px)
        │  harness 用 get_global_transform_with_canvas().origin 解锚(相机感知,既有契约)
        ▼
注入屏幕点 ──▶ player.gd 点击入口
        │  Coord.screen_to_world(pos, get_viewport())   ← 本轮新增(替换 identity 假设)
        ▼
handle_world_click(world_pos) ──▶ 五步解析器(世界空间 portrait_ink_rect)
```

health_bar.gd 跟随已用 `get_final_transform()`(相机感知,既有);TileMarkers/背景/网格是世界空间 Node2D,随相机移动(免费)。

## 组件列表

### C1 · CameraFollower(跟随相机)— `scripts/camera_follower.gd`(新)
- **职责**:跟随当前行动单位(玩家回合=玩家;敌方回合=正在行动的敌人),把相机中心钳到无空白范围,对齐到 HUD 顶栏与招式栏之间的未遮挡带;发布游戏级可观测量。
- **挂载**:附加到 `scenes/main.tscn` 与 `scenes/menu.tscn` 的既有 `Camera` 节点(节点名不变,名字引用保持有效)。`enabled=true, current=true, zoom=1`。
- **激活门**:仅在 `GameManager.get_state() == GameManager.STATE_BATTLE` 且 `CombatManager` 有活跃单位时跟随;否则保持位置在棋盘中心(非战斗段是 CanvasLayer,相机位置对其无影响)。
- **每帧逻辑**(`_process`):
  1. `target = CombatManager.get_active_unit()`;若 null → 持平,返回。
  2. 读棋盘矩形:`board = GridManager.board_rect()`(见 C3);`V = get_viewport_rect().size`。
  3. 读 HUD 遮挡:`T = _top_strip.get_global_rect().end.y`(TopStrip 底=92);`B = _skill_bar.get_global_rect().position.y`(SkillBar 容器顶=648)。两者均在非跟随 CanvasLayer → 视口逻辑 px,正是带要表达的空间。
  4. 算范围(无空白公式,见 §相机数学):`cover_y_before = T`;`cover_y_after = V.y - B`;`cover_x_* = 0`。
     - `cam_y_lo = board.position.y + V.y/2 - cover_y_before` = 0+352−92 = **260**
     - `cam_y_hi = board.end.y - V.y/2 + cover_y_after` = 704−352+56 = **408**
     - `cam_x_lo = board.position.x + V.x/2 - 0` = **480**;`cam_x_hi = board.end.x - V.x/2 + 0` = **480**(单点)
  5. 退化分支:`if cam_lo > cam_hi: cam = board_center`(棋盘 < 视口时钉中心;今天不触发)。
  6. `cam = Vector2(clampf(target.x, cam_x_lo, cam_x_hi) if cam_x_lo<=cam_x_hi else board_center.x, 同理 y)`。设 `position = cam`。
  7. **平滑关闭**:`position_smoothing_enabled = false`(确定性;帧钉断言不与缓动赛跑)。
- **传送/回合切换**:`reset_smoothing()` + `force_update_scroll()` 在(战斗开始进入 STATE_BATTLE)+ (每次 `CombatManager.turn_started` / `phase_changed` 目标跳变)时调用,**先于任何帧钉断言**——战斗开始那次是与第 0 帧赛跑的那个。
- **HUD 节点解析**:懒加载缓存 `_top_strip`/`_skill_bar`(从 Camera 节点 `../HUDLayer/HUD/TopStrip`、`../HUDLayer/HUD/SkillBar`,defensive `get_node_or_null`;main/menu 双子结构一致)。HUD 几何静态,可缓存;每帧重读也安全。
- **发布(surface 块 `Camera:`)**:`camera_position: Vector2`、`camera_x_lo/hi`、`camera_y_lo/hi`、`hud_band_top`、`hud_band_bottom`、`active_unit_screen_y`(= `Coord.world_to_screen(target.position, get_viewport()).y`)、`follow_target_id: String`(活跃单位名)、`follow_target_is_active: bool`(在脚本内 `follow_target_id == CombatManager.active_unit_name`)。

### C2 · Coord(世界↔屏幕单一转换)— `scripts/coord.gd`(新)
- **职责**:唯一拥有世界↔屏幕映射,避免三处各抄一份(player 点击、health_bar 跟随、follower 发布 active_unit_screen_y)。
- **接口**(纯静态,取 viewport):
  - `static func world_to_screen(world: Vector2, vp: Viewport) -> Vector2:` → `vp.get_final_transform() * world`
  - `static func screen_to_world(screen: Vector2, vp: Viewport) -> Vector2:` → `vp.get_final_transform().affine_inverse() * screen`
- **依据**:`get_final_transform()` 复合 stretch + 相机;既有 in-tree 模式见 `health_bar.gd` L561。今天(identity 相机、原生尺寸)数值上 screen==world;相机一动后这是唯一正确路径。
- **消费方改动**:player.gd 点击入口改走 `Coord.screen_to_world`;health_bar.gd 可选改走 `Coord.world_to_screen`(已正确,不强制以降风险);follower 用 `Coord.world_to_screen`。

### C3 · GridManager(常量源 + 删除 + board_rect 访问器)— `scripts/autoload/grid_manager.gd`(改)
- **新增访问器**:`static func board_rect() -> Rect2:` 返回 `Rect2(Vector2.ZERO, Vector2(GRID_WIDTH*TILE_SIZE, GRID_HEIGHT*TILE_SIZE))`(棋盘艺术品矩形 `[0,W*T]×[0,H*T]`)。follower、backdrop fit、断言一律走它,**不再各自乘常量**。
- **删除**(原子,见 §删除清单):`clamp_sprite_offset`(L171)、`BOARD_TOP_MARGIN_Y`(L26)、`MIN_LEGAL_ROW`(L44-45)及其在 `is_walkable` 的执行(L156-163)。删后 `is_walkable` 只剩边界环(行/列 0 与 `GRID_*−1`,L150-155),合法行 `1..GRID_HEIGHT-2`,纯常量导出。
- **保留**:`TILE_SIZE/GRID_WIDTH/GRID_HEIGHT/GRID_ORIGIN/PORTRAIT_TEX_Y`、occupancy、A*、`grid_to_world` 全不动。

### C4 · CombatManager(暴露活跃单位)— `scripts/autoload/combat_manager.gd`(改)
- **新增**:`func get_active_unit() -> Node:` 返回私有 `_active_unit`(L203)。follower 读它取跟随目标(玩家回合=玩家,敌方回合=正在行动的敌人,含移动中——读 `unit.position` 每帧即跟踪)。
- **不动**:回合引擎、伤害管线、信号。`active_unit_name`/`phase` 已在 surface,follower 的 `follow_target_is_active` 在脚本内比对它。

### C5 · 角色脚本(ink_world 对位 + 删钳位 + 点击映射)— `scripts/characters/player.gd` / `enemy.gd`(改,二者平行)
- **新增对位可观测量**(第一交付物,从已发布 `portrait_ink_rect` 派生,**不第二次自算矩形**):
  - `var ink_world_dx: float = 0.0` = `portrait_ink_rect.get_center().x - position.x`(墨迹水平中心 − 单位世界 x)
  - `var ink_world_dy: float = 0.0` = `portrait_ink_rect.end.y - position.y`(墨迹底边 − 单位世界 y)
  - 两者为 0 = 立绘站在自己格子上。在 `_process` 末尾(算完 `portrait_ink_rect` 后)写入。
- **删除**:`_refresh_sprite_clamp()`(player L1212 / enemy L435)及其在 `_process` 顶部的调用(player L419 / enemy L269)。删后精灵 offset 永远是脚锚点 `Vector2(0, -tex_size.y/2.0)`(已在 `_apply_*_visuals` 设好:player L1203 / enemy L426),不再每帧算钳位。`sprite_top` 退化为常量派生 `position.y - tex_size.y`(仍发布,health_bar 仍读)。
- **`portrait_ink_rect` 注释更新**:去掉"world == screen under identity canvas transform / clamped offset"措辞,改为"未钳位脚锚点:ink = [feet.x − tex.w/2, feet.y − tex.h] .. [feet.x + tex.w/2, feet.y]"。
- **点击入口屏幕→世界**:player.gd 调 `handle_world_click(world_pos)` 的入口(~L779-781,注释称"today event.position==world, affine inverse keeps path correct if a camera is added")必须改为 `handle_world_click(Coord.screen_to_world(event.position, get_viewport()))`。enemy.gd 若有同类 `event.position`/`get_canvas_transform()` 点击入口,一并走 `Coord.screen_to_world`(实现者 grep `event.position` / `get_canvas_transform` 核全)。`handle_world_click` 签名不变(已解耦)。

### C6 · 五步立绘命中解析器(裁决:保留)— `player.gd::resolve_click_step`(改输入,不动逻辑)
- **裁决**:保留。钳位无关理由——立绘 96×128 的墨迹从脚格向上/外延伸超出 64 格,点**可见身体**(非脚格)应命中该敌。判据问句"立绘站在格子上时它解决什么":解决"点身体而非点脚格"。
- **唯一改动**:入口世界坐标经 C5 的 `Coord.screen_to_world` 后传入;解析器内部世界空间 `portrait_ink_rect.has_point(world_pos)`(L1062)逻辑不变。**out-of-reach 身体永不把可达空格变得点不到**的硬约束不变。

### C7 · 名牌/血条跟随(裁决:保留,几何冻结)— `scripts/ui/health_bar.gd`(只改注释/无几何)
- **裁决**:保留。钳位无关理由——可读控件悬于头顶、避开 `0..T` 顶栏带;翻转路径锚到墨迹底边+4 = 单位自己脚+4(诚实的"站这里")。
- **改动**:仅删 L569-574"Measured top-row landing (STRIP_BOTTOM + 2 = 94 clamp retained)… documented top-row landing"注释段;跟随逻辑已相机感知(L561 `get_final_transform()`),`STRIP_BOTTOM=92.0`(L49)与全部内部几何常数**冻结不动**(brief 硬约束)。
- **断言**:health_bar_above_portrait.yaml 按**未钳位几何**重新推导(见 §playtest 契约改动)。

### C8 · TileMarkers 地面标记(裁决:保留,重写理由)— `scripts/ui/tile_markers.gd`(改 docstring)
- **裁决**:保留。钳位无关理由——立绘 96px 宽 vs 64px 格,未钳位也水平外溢邻格;地面椭圆标记该单位**占据哪一格**("可点的脚在这里"),与垂直对位无关。
- **改动**:重写 L18-28 docstring,删"the art hangs elsewhere / ellipse on the robe"(钳位措辞),只留水平外溢理由。节点(battlefield.tscn L34)、脚本、surface(`tile_marker_count`/`tile_marker_visible`)、相关断言**保留**。
- **备选(不取)**:原子删除(节点+脚本+surface 白名单+断言)会动 append-only surface 块,风险高于收益;brief 接受"若保留则脚底重合",对位 pin 已证。

### C9 · Battlefield 背景对齐(G5:读 GridManager)— `scripts/battlefield.gd`(改)
- **改动**:删镜像常量 L28-30 的**几何用途**(注释可保留为"mirror for convenience"但**不用于几何**)。`_fit_backdrop_to_board`(L203-216)的 `board := Vector2(GRID_WIDTH*TILE_SIZE, GRID_HEIGHT*TILE_SIZE)` 改读 `GridManager.board_rect().size`;`_setup_tilemap` 的循环范围改读 `GridManager.GRID_WIDTH/HEIGHT`。`board_aligned` 语义保持"背景矩形 == 棋盘矩形(常量派生)",无美术缩放、无 scheme(c) 本轮(代价见下)。
- **背景不动**:背景矩形仍 = 棋盘矩形;相机在无空白范围内移动时,移出棋盘的近侧世界恰好落在 HUD 遮挡带下(推导见 §相机数学),故**不扩背景**。32px 北行立绘头顶被顶栏遮(已知接受代价,见 §代价)。

### C10 · 立绘可见性探针(语义重述,保留)— `scripts/ui/visibility_probe.gd`(不改码)
- 保留类。`off_viewport`/`covered` 一旦相机移动即**取景事实,非精灵缺陷**。本轮其**断言角色**(portrait_visibility.yaml)改写为相机级;探针本身可留作他途。此重述写进 design/30_presentation.md(见 §设计变更)。

## 删除清单(原子,验证零残留)

| 目标 | 位置 | 动作 |
|---|---|---|
| `clamp_sprite_offset` | grid_manager.gd L171 | 删函数 |
| `BOARD_TOP_MARGIN_Y` | grid_manager.gd L26 | 删常量(删后无其它用途:STRIP_BOTTOM 是 health_bar 独立常量) |
| `MIN_LEGAL_ROW` | grid_manager.gd L44-45 | 删常量 |
| rows-0-2 不可进入规则 | grid_manager.gd is_walkable L156-163 | 删分支,留边界环 L150-155 |
| `_refresh_sprite_clamp` | player.gd L1212 / enemy.gd L435 | 删函数 + 删 `_process` 顶部调用 |
| 钳位注释 | player.gd L143-153 / enemy.gd L92-114 | 改措辞(未钳位脚锚点) |
| 出生点钳位补偿 | battlefield.gd L785-799 positions 注释 + 字典 | 恢复为 (7,1)/(3,2)/(11,2)(见下) |

**出生点恢复(设计变更,见 §设计变更)**:battlefield.gd `_instantiate_enemies` positions 字典改回 `East Heretic (3,2)` / `West Poison (11,2)` / `Central Divine (7,1)`;Player (7,5)/South Emperor (3,8)/North Beggar (11,8) 不动。删 L785-792 的 MIN_LEGAL_ROW 推导注释。

**验证**:`grep -rn "clamp_sprite_offset\|BOARD_TOP_MARGIN_Y\|MIN_LEGAL_ROW\|_refresh_sprite_clamp"` 全仓零命中(含 .gd/.tscn/.yaml/.md;design 历史记录里出现旧名是允许的——那是叙事,不是代码)。

## 不动的保留项(与本轮无关、已实测正确,严防误改)

- **`scenes/enemy.tscn` 的 `ClickTarget` `mouse_filter = 2`(IGNORE)**:实测 `debug_click_target_fires == 1` 证明"Node2D 祖先下的 Control 收不到 gui_input"在本树为假、它是个会吃按下的 STOP 控件;节点保留(playtest 按名字解析它作点击锚点),只 mouse_filter 已是 2。本轮**不碰**。
- **`scripts/ui/move_hint_label.gd` 的 `dock_failed: bool`**:把"本就该隐藏"与"六个停靠位全被占、被迫压掉"拆成两种可观测状态。本轮**不碰**。
两项均非本轮可见性归属工作,出现在此仅为**禁止回归**的显式声明。

## playtest 契约改动(`playtest/_common.yaml` surface + 场景)

### surface 白名单(**append-only,只加不删**;`tests/test_playtest_contract_smoke.py` 守卫)
- `Player` / `East_Heretic` / `West_Poison` / `South_Emperor` / `North_Beggar` / `Central_Divine`:各加 `ink_world_dx`、`ink_world_dy`。(注:West/South/North 现无 `sprite_top`;health_bar_above_portrait 重推导后若仍引用 `sprite_top`,补白名单;否则断言改用 `ink_world_dy` 表达。)
- 新增块 `Camera:`:`camera_position`、`camera_x_lo`、`camera_x_hi`、`camera_y_lo`、`camera_y_hi`、`hud_band_top`、`hud_band_bottom`、`active_unit_screen_y`、`follow_target_id`、`follow_target_is_active`。
- 不删既有 `portrait_visible`/`portrait_fail_layer`/`portrait_covered_frac`/`sprite_top`/`portrait_ink_rect`(append-only)。

### 场景(可改既有断言/帧,见 jinyong-nodes 先例;场景数 append-only)
- **NEW `playtest/portrait_grid_alignment.yaml`(第一交付物)**:
  - boot 到战斗 f40,断言 Player + 五敌 `abs(ink_world_dx) <= 1.0 and abs(ink_world_dy) <= 1.0`。
  - **走位腿**:把玩家走到最北合法格(行 1,如 (6,1) 或 (8,1),行 0 是边界环不可入),到达帧重新断言同样两条。click 序列由实现者照 `click_move_to_tile` 多步走法风格 author。
  - **必须能红**:Phase 1(钳位仍在、出生点已恢复行 1-2)时,Central_Divine (7,1) dy=124、East/West (·,2) dy=60 → 红;走位腿玩家到 (6,1) dy=124 → 红。Phase 2 删钳位后全绿。若缺陷存在时也绿,无价值。
- **改写 `playtest/portrait_visibility.yaml` → 相机级**:
  - 删精灵级 `portrait_visible`/`sprite_top>=0`/`portrait_covered_frac<0.25` 作**闸门**的断言(保留 `portrait_tex_size>0` 作纹理存在 sanity)。
  - 改为:`Camera.follow_target_is_active == true`、`Camera.active_unit_screen_y >= Camera.hud_band_top and <= Camera.hud_band_bottom`、`Camera.camera_y >= Camera.camera_y_lo and <= Camera.camera_y_hi`。全部在 `Camera:` 单 surface 块内(断言只见一个块)。
  - 理由写进 design/30_presentation.md(见 §设计变更):"每张立绘完整可见"是相机/布局属性,不是精灵属性;相机负责把活跃单位框进未遮挡带;非活跃单位部分出屏是正常取景。
- **重推导 `playtest/health_bar_above_portrait.yaml`**:删 description 与注释里"documented top-row landing (not a defect)"/"top-band-clamped by BOARD_TOP_MARGIN_Y"整段;按未钳位几何重推:行 1 单位 `sprite_top = feet - 128`(负值),翻转锚到 `portrait_ink_rect.end.y + 4 = feet + 4`(坐本单位自己格)。`TileMarkers.tile_marker_count == 6`/`tile_marker_visible` 保留。具体数由实现者从常量推导(见 §像素推导),不放宽阈值。
- **重推导 `playtest/click_portrait_body_targets_enemy.yaml`**:Central_Divine click 从 `+0,+60` 改回身体中心偏移 **`+0,-64`**(`-PORTRAIT_TEX_Y/2`);删所有"clamped by BOARD_TOP_MARGIN_Y / sprite_top 92 / ink [92,220]"注释,改写为未钳位 `ink = [feet-128, feet]`,中心 `feet - 64`。负控 `North_Beggar +0,-64`(已是身体中心,行 8 未钳位)保持。
- **重基线 `tests/test_click_priority.gd`**:`out_of_reach` 夹具从钳位矩形 `Rect2(Vector2(432,92),Vector2(96,128))`(L60,行 1 钳位 ink y∈[92,220])改为未钳位 `Rect2(Vector2(432,-32),Vector2(96,128))`(ink y∈[-32,96],feet=96)。`in_reach`(L63,(7,4) ink y∈[160,288],feet=288)已是未钳位,保持。重选 click 点(原 y=140/220/120)使五步真值表仍被遍历——按未钳位矩形重新挑点,不放宽。
- **冻结验收网四条**(`click_move_undo_right`/`click_move_commit_lock`/`move_target_affordance`/`click_move_to_tile`)**场景文本不动**:其 click 多落在玩家中盘(cam=center,screen==world)自然安全;落在钳位位置(如 click_move_to_tile 末次 own-tile click at (8,2),cam_y=260)依赖**harness 已相机感知**(get_global_transform_with_canvas)+ **player.gd screen→world**(C5)——二者到位则四条绿。若变红,**上报红与原因,不削弱**。

### harness 适配契约(外部 `aitelier/tools/godot_playtest/impl.py`,不在本仓)
`_common.yaml` L59-60 已述:harness 对 Node2D 锚取 `get_global_transform_with_canvas().origin`(相机感知)。**故 harness 侧预期零改动**。**但须验证**:若 impl.py 实际假定 identity(用节点世界坐标当屏幕坐标注入),则相机一动 click 全偏——实现者须确认 harness 走 `get_global_transform_with_canvas`;若否,修它(报告为红+原因,不削弱场景)。冻结四条 + 重推 click_portrait_body 的身体 click 均依赖此契约。

## 实施顺序(架构钉死,PM 据此拆)

**判据:pin 必须先红后绿;相机/点击配对必须先于/同时于删钳位。**

- **Task A(Phase 1,pin 落地→红)**:C5 加 `ink_world_dx/dy`;NEW `portrait_grid_alignment.yaml`(静态+走位腿);恢复出生点 (7,1)/(3,2)/(11,2);删 MIN_LEGAL_ROW(行 0-2 重新合法,走位腿可达行 1)。**钳位仍在**。→ pin 红(Central dy=124、East/West dy=60、走位腿玩家到行1 dy=124)。其余场景:钳位在 → 仍绿。
- **Task B(相机预置,可与 A 并行)**:C1 CameraFollower + C2 Coord + C4 `get_active_unit()` + C5 点击入口 screen→world + C9 backdrop 读 GridManager + surface 白名单加项。**钳位仍在** → 相机随活跃单位移动,ink 仍被钳在屏内,portrait_visibility(仍精灵级)绿,pin 仍红;click 经 screen→world 正确。
- **Task C(删钳位 + 闸门/背书重写,依赖 A+B)**:删 clamp_sprite_offset/_refresh_sprite_clamp/BOARD_TOP_MARGIN_Y;改写 portrait_visibility.yaml → 相机级;重推 health_bar_above_portrait.yaml + 删 health_bar.gd L569-574 注释;重推 click_portrait_body_targets_enemy.yaml(+60→-64);重基线 test_click_priority.gd。→ pin 全绿(静态+走位腿);相机级闸门绿;背书清除;冻结四 + spine + GDScript 单元套件绿。

> A、B 可并行;C 依赖二者。中间态的瞬态红(如 Task C 内部删钳位后、闸门改写前)是实施中,非交付检查点;交付检查点是 C 完成后全绿。

## 相机数学(全常量派生,验收:GRID_HEIGHT 11→20 零行相机逻辑改动)

**无空白范围(每轴)**:`cam_lo = board_lo + V/2 − cover_before`;`cam_hi = board_hi − V/2 + cover_after`。退化:`cam_lo > cam_hi` → 钉 `board_center`。今天代入(仅作校核,不入码):
- y:`cover_before = T = 92`(TopStrip 底,`hud.tscn` offset_bottom=92.0);`cover_after = V.y − B = 704−648 = 56`(SkillBar 顶,`hud.tscn` anchor_top=1.0/offset_top=-56 → 704-56=648)。→ `cam_y ∈ [0+352−92, 704−352+56] = [260, 408]`,长 `148 = 704 − 556`(棋盘高 − 未遮挡带高)。
- x:`cover_* = 0`(无全高侧栏)→ `cam_x ∈ [480, 480]`(单点)。**这是代入结果,不是硬编码**;`GRID_HEIGHT` 改 20 只改代入数,代码零改。
- 等价 Godot 表述:相机可视窗 `[cam−V/2, cam+V/2]` 限制在 `[board_lo−cover_before, board_hi+cover_after]` = x `[0,960]`、y `[-92, 760]`——即"limits = 棋盘矩形,每侧按该侧 HUD 遮挡放宽"。本轮用**显式 position clamp + 退化分支**(不用 limit_* 的反转语义,免棋盘<视口时未定义)。

**单位在带内(证明)**:相机非钳位(中盘)时单位在 `V/2∈[92,648]`(带内,`92<352<648`);钳位时被拉向带、永不拉出(范围由遮挡边导出)。故相机级闸门断言**带范围** `active_unit_screen_y∈[92,648]`,不断言精确点。代入合法行(行 1..9,feet_y=32+64r∈[96,608]):行1-3→cam_y 钉 260→屏 y=y+92∈[188,316];行4-6→352;行7-9→cam_y=408→屏 y=y−56∈[424,552];全在 [92,648]。

## 像素推导(实测/常量,非采信 brief 参考值)

- **T=92**:`scenes/ui/hud.tscn` TopStrip `offset_bottom = 92.0`。
- **B=648**:SkillBar `anchors_preset=7`(底锚),`anchor_top=1.0`,`offset_top=-56.0` → `704-56=648`。
- **未遮挡带**:y∈[92,648],高 556。
- **ink_world_dy(Central_Divine (7,1),钳位在)**:feet_y=96;clamp 把 origin.y(=feet−64=32)钳到 `BOARD_TOP_MARGIN_Y+half.y=156`;offset.y=156−96=60;`sprite_top=96+60−64=92`;ink end.y=92+128=220;dy=220−96=**124**。删钳位后 offset=(0,−64);`sprite_top=96−128=−32`;ink end.y=−32+128=96;dy=96−96=**0**。
- **ink_world_dy(East/West (·,2),钳位在)**:feet_y=160;origin.y=96 钳到 156;offset.y=156−160=−4;`sprite_top=160−4−64=92`;ink end.y=220;dy=220−160=**60**。删钳位后 dy=**0**。
- **身体中心偏移**=`−PORTRAIT_TEX_Y/2 = −128/2 = −64`(墨迹中心相对脚)。故 click_portrait_body Central_Divine `+0,+60`(钳位补偿)→ `+0,-64`(身体中心)。
- **未钳位 ink 矩形(行 r,feet=(x,y))**:`Rect2(Vector2(x-48, y-128), Vector2(96,128))`。行1 (7,1) feet (480,96) → `Rect2((432,-32),(96,128))`(test_click_priority 夹具新值)。
- **dx 恒 0**:未钳位 ink center.x = feet.x(offset.x=0,纹理居中)→ dx=0。钳位只动 y,故 dx 恒 0;pin 的 dx 分量恒绿,真值在 dy。

## 代价(已知接受,写进 design/90_decisions.md + 40_ux_backlog.md)

- **整盘看不全**:相机在无空白范围内移动时,棋盘南端(行 9-10)在北极 cam_y=260 时落到底部招式栏后——正常取景,非缺陷。
- **32px 北行立绘头顶被顶栏遮**:行1 单位未钳位 ink world y∈[feet−128, feet]=[-32,96];北极 cam_y=260 时屏 y∈[60,188],顶部 ~32px 落在 [0,92] 顶栏后。相机级闸门断"活跃单位在带内/立绘站在格上"(ink_world_dy≈0),不断"整张立绘完整可见"。本轮不实现 scheme(c)扩背景(代价小、可推导,但 brief 接受代价)。
- **小地图/边缘指示**:本轮不做,记 `design/40_ux_backlog.md` 新条目(见 §设计变更)。

## 设计变更(本 run 改档案;`5_design` 据此外科式更新)

> 与档案冲突=本次就是要改档案。以下逐条给文件+锚+内容,供 5_design 落地,亦供 PM 派"更新 design"任务。

1. **`design/30_presentation.md` → `## 分辨率与拉伸`**:把链"基准视口 960×704(=15×11×64=棋盘=背景=相机视野)"改写成分立事实:视口是显示尺寸;棋盘是内容尺寸(`GRID_*×TILE_SIZE`,不再受视口约束);背景覆盖棋盘;**可见性归相机**,取景上限来自相机而非视口。
2. **`design/30_presentation.md` → `### 角色立绘可见性断言`**:相机一动后 `off_viewport`/`covered` 是取景事实非精灵缺陷;二者**不再裁定立绘对位**;`portrait_visibility.yaml` 被相机级闸门取代(附改写理由)。记两条原则(见下条 7)。
3. **`design/30_presentation.md`(同节)**:记 **(a)** 可见性由相机拥有,精灵只站在自己格子上,二者不得互相代偿;**(b)** 闸门断言游戏级属性不断言引擎级属性——只能靠改 offset/position/size/z-order 满足的闸门该删。
4. **`design/20_content.md §0 战场表**:删"行 0/1/2 不可进入(MIN_LEGAL_ROW==3)";中神通 (7,1)/东邪 (3,2)/西毒 (11,2) 恢复;`30_presentation.md` 定位章若有 `MIN_LEGAL_ROW==3` 同步删。
5. **`design/90_decisions.md`(新条 2026-08-28)**:棋盘尺寸不再受视口约束(大场景需大地图);"整盘看不全"是正常取景非缺陷;旧 CLOSED(UX-01b 靠引入钳位)本轮拆除。
6. **`design/00_roadmap.md`(一行)**:大地图现已可行,后续内容轮不必设计到 15×11。
7. **`design/40_ux_backlog.md`**:UX-01b **显式关闭**——前次 CLOSED 靠引入钳位换来的绿,本轮拆钳位换真修,附证据路径(`scripts/camera_follower.gd`、`playtest/portrait_grid_alignment.yaml`、改写后的 `playtest/portrait_visibility.yaml`);**两条新条**(本轮记不实现):小地图/屏外单位边缘指示(整盘看不全成常态后升优先级);立绘尺寸:格尺寸比(96/64 外溢,TileMarkers 唯一残留理由)成可调内容决策(棋盘解绑后)。
8. **`design/99_changelog.md`**:本轮一行(2026-08-28,相机拥有可见性/删钳位)。

## 风险与回滚

- **不可逆度低**:删除的是函数/常量/规则,可由 git 回滚。无 DB/批量数据。
- **配对风险(最高)**:删钳位前若 player.gd screen→world 或 harness 相机感知任一缺失,click 在 cam≠center 位置全偏→冻结四红。**缓解**:Task B 先落 screen→world + 验证 harness;Task C 删钳位前四条已绿于移动相机。变红则上报原因不削弱。
- **中间态红**:Task A 后 pin 故意红(预期);Task C 内部瞬态红(闸门改写前)——非交付检查点。
- **出生点恢复连断**:恢复 (7,1)/(3,2)/(11,2) + 删 MIN_LEGAL_ROW 须同 Task A(否则 (7,1) 不可达/走位腿不可走)。click_portrait_body 的身体 click 在 Task A(钳位在)用 +60 仍绿,Task C 改 -64。
- **回滚路径**:git revert Task C → 回到 Task B 状态(pin 红,相机在动,钳位在);再 revert A → 回到原始钳位态。

## 技术栈 / 工具

- **Godot 4.4 内建**:Camera2D(position/limits/reset_smoothing/force_update_scroll)、`Viewport.get_final_transform()`/`get_canvas_transform()`、CanvasLayer `follow_viewport_enabled=false`(HUD/Tutorial 已是非跟随)。零第三方依赖。
- **既有 playtest harness + 边车 `/script`**:跑 `res://tests/unit_test_runner.gd`(test_health_bar.gd / 重基线 test_click_priority.gd 不回归);`/playtest` 跑 57 场景;`/compile` 跑整仓解析。
- **既有 surface 守卫**:`tests/test_playtest_contract_smoke.py`(append-only)、`tests/test_i18n_coverage.py`(中文文案,本轮相机工作不引入新字符串→保持绿)。

## 扩展性

- **大地图**:`GRID_HEIGHT` 11→20 零行相机逻辑改(只改代入数)——相机/限/跟随全从 `GridManager` 符号派生。
- **棋盘<视口**:退化分支钉中心,不甩到角落。
- **scheme(c) 扩背景**:若作者日后不接受 32px 头顶遮挡,在 `_fit_backdrop_to_board` 加一个导出的上溢 margin 常量(= PORTRAIT_TEX_Y − GRID_ORIGIN.y − TILE_SIZE = 128−32−64 = 32),`board_aligned` 重述为"背景矩形 == 棋盘矩形 ⊕ 配置上溢"。本轮不做(代价接受)。
- **小地图/边缘指示**:backlog 已记,后续轮实现。

## linter_manifest

本轮新增 `.gd`(camera_follower.gd / coord.gd)与改 `.gd`/`.tscn`/`.yaml`/`.md`/`.py`。`.gd` **不进 manifest**(由 `gdscript_check` 闸门逐文件 `--check-only` 解析,宿主控制);manifest 只覆盖文本文件:`.py=ruff`、`.md/.json/.yaml=basic`(与现状一致,见 `linter_manifest.json`)。
