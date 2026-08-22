# Presentation

## 分辨率与拉伸

基准视口 **960 × 704**(= 15×11 格 × 64 px = 棋盘 = 背景图 = 相机视野)。
`project.godot [display]`:`window/stretch/mode = "canvas_items"`、
`window/stretch/aspect = "keep"`、`resizable = true`。窗口缩放时棋盘等比填满,
外侧由引擎黑边补齐。

## 画风

**一句统一风格句,只描述画风,绝不点名任何游戏对象**——把物件清单写进风格句,
生图模型会把每样东西画进每一张图。每个资源的主体只写在它自己那一条 prompt 里。

当前风格句(水墨武侠向):
> ink-wash wuxia painting, muted earth tones, soft paper texture, side view, flat lighting

## 字体(硬要求)

**界面字体必须包含中文字形。** 本作的人物名、功法名、教程文案大量使用中文;
引擎默认字体没有 CJK 字形,会渲染成豆腐块。字体文件随仓库提供,
不依赖系统字体。

## 音频

音效:选择 / 移动 / 命中 / 受伤 / 胜利。背景乐一条。

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
