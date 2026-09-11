# 《Herdr 实战手记》EP0 从单窗格到常驻作战室：Basics & Sessions

## 能力跃迁：学完能多做什么

合上笔记本，SSH 断线，第二天重连——窗格原封不动，Agent 进程**从头到尾没断过**。你附着回去看到的不是重建的现场，是一直在跑的活现场。进程没断就意味着：零额外 token；Agent 跑完了就安静停在完成态，不会自己接着干下一件事。

侧边栏一眼扫完全局：

- `◐` working——在跑，别打扰
- `×` blocked——卡审批弹窗，等你拍板
- `✓` done——跑完了，你还没看
- `○` idle——看过了，空闲待命

> **分离 vs 重启，代价天差地别**
>
> 合上笔记本 = 客户端分离（detach）。Herdr 服务端没停，Agent 进程没停，你只是断开了显示器。零代价。
>
> 机器重启或 `herdr server stop` = 服务端重启。原始进程死了。Herdr 恢复窗格布局，配合集成钩子用保存的会话 ID 重启 Agent（如 `claude --resume <id>`）。Agent 加载对话历史但**不会自动继续上次的任务**——回到提示符等你指令。

键盘侧：前缀键 `ctrl+b` 保留分屏和缩放的肌肉记忆。鼠标侧：点击切窗、拖边界、滚轮翻页，全程可用。两个不冲突。

---

## 核心矛盾：tmux 看不见 Agent 状态

tmux 够用——对单人命令行场景。常驻进程、分离/附着、多窗格分屏，全有。

问题出在多 Agent 并发。你开 3 个窗口分别让 Agent 改后端、重构前端、补测试，十分钟后：

- 窗格 A 在吐日志，是在想还是死循环？
- 窗格 B 停了，是等新输入还是卡在审批弹窗？
- 窗格 C 五分钟前就做完了，但没有任何视觉反馈，你只能挨个切过去看。

tmux 只知道 PTY 里有没有活进程，不知道 Agent 在想什么。多 Agent 一开，人只能被动定时巡检。

Herdr 在终端复用器的基础上加了一层：Agent 状态推断引擎。服务端常驻守护进程既维护窗格拓扑，也实时分类每个窗格里的 Agent 处于五态中的哪一态。Socket API 把这些状态暴露给 CLI 和脚本。

---

## 演练：搭建与验证常驻作战室

### 1. 服务端状态

Herdr 是 Client/Server 架构。关掉终端窗口只是断开 Client，Server 一直在后台跑。

```text
$ herdr status
client:
  version: 0.9.0
  channel: stable
  protocol: 22
  endpoint_protocol_generation: 1

server:
  status: running
  version: 0.9.0
  endpoint_compatible: yes
  private_protocol: 22
  private_protocol_compatible: yes
  socket: /Users/yvan/.config/herdr/herdr.sock

update:
  restart_needed: no
  server_binary_stale: no
```

Session 列表：

```text
$ herdr session list
name                 status   directory                                        socket
default              running  /Users/yvan/.config/herdr                        /Users/yvan/.config/herdr/herdr.sock
```

所有通信走 `/Users/yvan/.config/herdr/herdr.sock` 这一个 UNIX 域套接字。

### 2. 终端作战室布局：工作区、标签页与窗格

初次启动 `herdr` 进入 TUI 界面，整个终端界面分为四个核心区块：

```text
┌─────────────────┬────────────────────────────────────────────────────────┐
│ 侧边栏 Sidebar  │ 标签栏 Tab Bar: [agents] [server] [logs] (+)           │
│                 ├────────────────────────────┬───────────────────────────┤
│ ▼ workspace-1   │ 窗格 Pane 1 (w1:p1)        │ 窗格 Pane 2 (w1:p2)       │
│   ● claude (w1) │                            │                           │
│   × codex  (w2) │ $ claude                   │ $ codex                   │
│                 │ ╭─── Claude Code ────────╮ │ ╭─── Codex ─────────────╮ │
│ ▶ workspace-2   │ │ ◐ working              │ │ │ × blocked (审批中)    │ │
│                 │ ╰────────────────────────╯ │ ╰───────────────────────╯ │
│                 ├────────────────────────────┴───────────────────────────┤
│                 │ 状态栏 / 模式栏 Mode Bar: [NORMAL] ctrl+b ? for help   │
└─────────────────┴────────────────────────────────────────────────────────┘
```

四层核心概念的层级关系：

1. **工作区（Workspace）**：最外层的顶层项目容器。建议**一个项目/仓库或一项独立任务分配一个 Workspace**。左侧侧边栏汇总显示该工作区内所有 Agent 的聚合状态徽章。
2. **标签页（Tab）**：工作区内的独立视口。类似浏览器的标签，可切分为 `agents`、`server`、`logs` 等不同视口，互不遮挡干扰。
3. **窗格（Pane）**：真正的终端 PTY 实例。可以在一个 Tab 内左右（垂直）或上下（水平）随意切分。每个窗格独立运行一个 Shell 或自主编码智能体（如 Claude Code、Codex）。
4. **侧边栏（Sidebar）**：全局注意力中枢。实时显示所有 Workspace 及其名下的 Agent 列表与实时状态符号（`◐` / `×` / `✓` / `○`），支持鼠标直接点击切窗，也可折叠。

### 3. 鼠标和快捷键

Herdr 默认鼠标全覆盖——点击切窗格、拖分割线、右键菜单、滚轮翻页。键盘快捷键是可选加速层。

分屏：`ctrl+b v`（左右），`ctrl+b -`（上下）。右键窗格边框也能切。脚本里用 `herdr pane split --direction right --cwd "$PWD"`。

导航：`ctrl+b h/j/k/l`（vim 风格）。缩放：`ctrl+b z` 把当前窗格全屏，再按一次回来。鼠标直接点也行。

先记住这五个就够日常用了（来自官方 keyboard 文档）：

| 动作 | 快捷键 |
| :--- | :--- |
| 新建标签页 | `prefix+c` |
| 垂直 / 水平切分 | `prefix+v` / `prefix+minus` |
| 窗格间导航 | `prefix+h/j/k/l` |
| 工作区导航 | `prefix+w` |
| 分离 | `prefix+q` |

当前分屏布局的 JSON 快照：

```text
$ herdr pane layout
{"id":"cli:pane:layout","result":{"layout":{"area":{"height":40,"width":120,"x":0,"y":0},"focused_pane_id":"w1:p3","panes":[{"focused":false,"pane_id":"w1:p1","rect":{"height":40,"width":60,"x":0,"y":0}},{"focused":true,"pane_id":"w1:p3","rect":{"height":40,"width":60,"x":60,"y":0}}],"splits":[{"direction":"right","id":"split_0_root","ratio":0.5,"rect":{"height":40,"width":120,"x":0,"y":0}}],"tab_id":"w1:t1","workspace_id":"w1","zoomed":false},"type":"pane_layout"}}
```

### 4. 五态模型与"已看"判定

下表的符号和配色直接来自 Herdr 源码 `shell.rs` 中的 `status_icon()` 和 `status_color()` 函数。配置 `status_indicators = "symbols"` 后侧边栏渲染的就是这些字形：

| 符号 | 配色 | 状态 | 含义 |
| :---: | :--- | :--- | :--- |
| `×` | red | **blocked** | 卡在审批/确认弹窗，等人 |
| `✓` | teal | **done** | 跑完了，你还没看过 |
| `◐` | yellow | **working** | 在跑 |
| `○` | green | **idle** | 看过了，空闲 |
| `·` | overlay | **unknown** | 有进程但分类不了 |

默认 `status_indicators = "dots"` 时，`working`/`blocked`/`done` 都显示实心圆 `●` 只靠颜色区分，`idle` 是空心圆 `○`，`unknown` 是中点 `·`。用 `symbols` 是因为色彩受限的终端下也能一眼区分。

**idle 和 done 为什么必须分开？** 两者对 Agent 来说都是"提示符就绪，可以输入"，但对人来说 `done` = 有新产物等你验收，`idle` = 你看过了它在闲着。区别在一个 Seen 标记：

- 用鼠标点击或快捷键切进该窗格，`done` → `idle`
- CLI 执行 `herdr pane focus` 或 `herdr agent focus`，同上
- `pane read` / `agent read` 读输出，**不消费** `done`
- 每个 TUI 客户端的 Seen 状态独立——客户端 A 看过不影响客户端 B 的 Done 徽章

问服务端"你是怎么判定这个窗格状态的"：

```text
$ herdr agent explain w1:p3
agent: claude
state: idle
manifest: remote:/Users/yvan/.local/state/herdr/agent-detection/remote/claude.toml 2026.09.04.1
rule: live_prompt_box (region=prompt_box_body priority=950)
evidence: "❯\n"
```

Herdr 抓到了 Claude Code 提示符的特征规则 `live_prompt_box`，判定为 `idle`。`agent explain` 用的是服务端活跃的检测清单缓存，反映当前真实的判定逻辑。

### 5. 配置（`config.toml`）

默认配置偏保守。多 Agent 场景下调两个关键项：`agent_panel_sort = "priority"` 让 blocked/done 置顶，`status_indicators = "symbols"` 让色彩受限终端也能分辨状态。

完整参考配置见 `ep0-basics/config.toml`：

```toml
# ep0-basics/config.toml
onboarding = false

[theme]
name = "catppuccin"

[terminal]
new_cwd = "follow"

[ui]
agent_panel_sort = "priority"
status_indicators = "symbols"
show_agent_labels_on_pane_borders = true
pane_gaps = true
mouse_scroll_lines = 3

[session]
resume_agents_on_restore = true

[keys]
prefix = "ctrl+b"
```

校验：

```text
$ HERDR_CONFIG_PATH=ep0-basics/config.toml herdr config check
config: ok
```

---

## 验收

### 1. 断言脚本

```text
$ ./ep0-basics/verify-session.sh
=== [EP0 验收] 1. 验证 Herdr CLI 版本与服务端状态 ===
[PASS] herdr binary detected: 0.9.0
[PASS] herdr server status: running

=== [EP0 验收] 2. 验证作战室配置文件 (config.toml) ===
config: ok
[PASS] config check: ok

=== [EP0 验收] 3. 验证常驻 Session 与 Socket 连通性 ===
[PASS] active sessions found: 1

=== [EP0 验收] 4. 验证活跃拓扑与 Agent 状态快照 ===
[PASS] detected live topology: 6 workspace(s), 5 pane(s)

=== [EP0 验收通过] 常驻 Session 守护就绪，断网重连与状态感知基座建立完成 ===
```

退出码 `0`，全过。

### 2. 手动分离再附着

1. `ctrl+b q` 分离（或直接关终端窗口）；
2. 新终端里跑 `herdr`；
3. 看三件事：分屏布局没变；Agent 进程没断（分离前 `working` 的回来可能已变 `done`，也可能还在跑）；侧边栏徽章瞬间亮起，没有重新检测过程。

### 3. 服务端重启后的恢复

机器重启或 `herdr server stop` 之后，原始进程死了，行为不同于分离：

| 恢复什么 | 来源 | 条件 |
| :--- | :--- | :--- |
| 窗格布局和拓扑 | `session.json` | 自动 |
| 终端屏幕内容 | `session-history.json` | 需开 `experimental.pane_history` |
| Agent 对话上下文 | Agent 自身后端 | 需安装集成 + `resume_agents_on_restore` |

重启后 Agent 通过保存的 Session ID 重新启动（如 `claude --resume <session-id>`），回到提示符等输入，不会自动继续上次的任务。没装集成的窗格恢复为普通 shell。

---

下一篇进钩子集成：用脚本故意构造审批弹窗，实测侧边栏标红。
