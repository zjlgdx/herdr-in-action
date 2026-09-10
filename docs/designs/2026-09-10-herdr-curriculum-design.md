# Herdr 实战演练与灯下手记系列课程设计

**Date:** 2026-09-10

## Context

全自主编码智能体（Claude Code、Codex、Antigravity 等）正在重构软件开发流程，开发者正从单兵编码转向多智能体并发调度。传统的终端复用器（tmux、Zellij）无法感知终端窗格内程序的语义与生命周期，在多 Agent 并行场景下产生两大痛点：一是智能体遇到高危操作或人工审批弹窗时陷入静默挂起（Blocked），开发者在多窗口间巡检成本极高；二是传统复用器缺乏面向 Agent 的标准双工控制面，无法形成机机协同闭环。

针对该痛点，前期已完成《Herdr 全景实战与精通指南》（Kindle Scribe 速查版），并在本地搭建了 Herdr 0.9.0 运行环境。同时，本地已固化工程级智能体结对协议 `one-shot-pairing`（v0.4.2），其核心规范将 `herdr` 窗格注入列为第一优先级通道。本设计的目的在于建立系统性实操仓库 `herdr-in-action`，打通深水区机制演练（状态钩子逆向、Socket 控制流、Git Worktree 拓扑隔离、Claude Code Cross-Session 跨会话通信，以及 `one-shot-pairing` 终极作战室形态落地），产出 7 篇硬核实战手记并发布至《灯下》个人博客（Lamplight）。

## Discussion

在篇目组织上，曾对比 5 篇精简合并方案与 7 篇深度递进方案。精简方案将状态钩子与 Socket 控制、Worktree 与跨会话消息强行打包，单篇实验密度过高，容易冲淡抓包与报错证据链。7 篇方案实现“一课一核心矛盾与独立实验验证”，在知识梯度与工程深度上完胜。

在架构分层上，深入辨析了 Herdr 基础设施与 `one-shot-pairing` 工作流的关系。两者绝非替代关系，而是分属不同层级：
- **L1/L2 基础设施（Herdr）**：提供操作系统级 PTY 窗格生命周期、后台常驻守护、三态感知机（Working/Blocked/Done）、Git Worktree 拓扑挂载与全功能按键/鼠标接管。Herdr 解决的是“环境怎么跑”与“状态怎么看”。
- **L4 工程方法论（`one-shot-pairing`）**：定义 Navigator（领航员不写代码、控小上下文）、Driver（司机深潜产出文件）、Fresh Reviewer（独立上下文盲审）与异构顾问面板（Codex/Agy 视角差）。它解决的是“质量怎么控”与“如何全自动交付可合入的 PR”。

若无 Herdr，`one-shot-pairing` 只能降级为不可见的 Subagent 管道黑盒，遇到审批弹窗只能无声超时，且父进程崩溃即全军覆没；而若无 `one-shot-pairing`，开发者在 Herdr 中也只是盲目开窗格，依然面临上下文爆炸与缺乏交叉复审的困境。两者融合，才能使 `one-shot-pairing` 从“降级摸黑跑”跃迁为“全透明、可随时接管、整晚常驻的自动化作战室”。

在跨会话协作上，分析了 Claude Code 原生 Cross-Session Messaging 与 Herdr 的关系。Cross-Session 通过每会话独立的 Unix Socket 解决同构会话间的文本消息直连，但其安全规范严禁“代客审批”，导致受阻会话无声挂起；Herdr 作为物理拓扑与状态感知基座，能第一时间在侧边栏标红 Blocked 状态并提供一键切入放行，两者形成“L1/L2 拓扑与感知 + L3 语义总线”的上下层互补关系。

## Approach

采用“实验驱动 + 协议融合 + 双轨同步”落地体系：以 `herdr-in-action` 仓库为代码与实验源头，各篇目配齐实验脚本、测试 Target 与笔记底稿（`notes.md`）；在 Lamplight 博客编写专用单向同步脚本 `sync-herdr-notes.mjs`，将笔记同步生成为博客手记（`content/notes/`）与收官长文（`content/posts/`）。

全系列写作严格遵守 Lamplight 工程规范：摒弃 AI 模板套话与形容词通胀，正文记录真实实验参数、控制台截屏日志（`term` 围栏）、报错重现与源码行号；每篇手记配有一幅文人水墨意象题图（大面积留白，唯一光源为暖琥珀纸灯）。

## Architecture

### 1. 七篇手记课程架构

- **EP0: 认知重塑与常驻基座（Basics & Sessions）**
  - 核心矛盾：传统终端复用器为何在 Agent 时代失效？
  - 实战演练：常驻 Session 守护、鼠标与快捷键双模操控、基础窗格切分与三态（Working/Blocked/Idle）视觉映射。
  - 实验产物：`ep0-basics/config.toml`、`ep0-basics/notes.md`。

- **EP1: 状态感知与钩子解密（Hooks & State Detection）**
  - 核心矛盾：Herdr 怎么知道模型停下了？
  - 实战演练：逆向剖析 `herdr integration`，抓取 `herdr-agent-state.sh` 与 Unix Socket 的握手报文，实测状态序列号（`state_change_seq`）与底层缓冲区快照（`detection` 回退源）。
  - 实验产物：`ep1-hooks-detection/mock-agent.sh`、`ep1-hooks-detection/notes.md`。

- **EP2: 无头驱动与控制原语（Socket API & Automation）**
  - 核心矛盾：如何摆脱手工按键，实现终端的全面可编程？
  - 实战演练：通过 Node.js/Bash 经由 `herdr.sock` 调用 `herdr agent prompt --wait`，实测 5 秒活跃门禁与 settled-state 判定，利用 bracketed-paste 保证输入原子性。
  - 实验产物：`ep2-socket-cli/orchestrate.mjs`、`ep2-socket-cli/notes.md`。

- **EP3: 拓扑工程与并发隔离（Worktrees & Workspaces）**
  - 核心矛盾：多 Agent 同时修改同一个代码仓库导致的文件写入锁与上下文污染。
  - 实战演练：利用 `herdr worktree` 与 `herdr workspace` 绑定，为不同 Agent 分配物理隔离的独立分支与工作目录；吸收 `one-shot-pairing` 经验，验证在 detached worktree 上运行异构评审面板秒级跳过 `node_modules` 扫描的加速收益。
  - 实验产物：`ep3-worktree-topology/setup-worktrees.sh`、`ep3-worktree-topology/notes.md`。

- **EP4: 智能体结对与自治编排（One-Shot Pairing on Herdr）**
  - 核心矛盾：如何让主控 Agent 拥有全局终端调度能力，实现无人值守端到端交付？
  - 实战演练：以 `one-shot-pairing` 的 `herdr` 通道为实战抓手，演示 Navigator 在主窗格运筹帷幄，通过 Herdr Socket API 拉起 Driver 窗格注入任务书；侧边栏实时监控 Driver 的 Working 与 Blocked 状态，演示人工一键切入放行；对比 Claude 原生 Cross-Session Messaging（同构总线）与 Herdr CLI 调派 Codex/Agy 顾问面板（异构视角）的协同流。
  - 实验产物：`ep4-autonomous-pairing/pairing-harness.sh`、`ep4-autonomous-pairing/notes.md`。

- **EP5: 跨机漫游与算力分流（Remote Fleet & Persistence）**
  - 核心矛盾：本地轻薄本如何调度远端 GPU 服务器上长时间运行的 Agent？
  - 实战演练：配置 `herdr machine` 建立 SSH 安全穿透隧道，测试断网漫游重连与本地/远端键盘映射仲裁机制。
  - 实验产物：`ep5-remote-fleet/deploy-remote.sh`、`ep5-remote-fleet/notes.md`。

- **EP6: 收官复盘与智能体基建十问（Retrospective & Ten Questions）**
  - 核心矛盾：终端复用器向操作系统演进的必然性，以及与上层工作流协议的共生关系。
  - 实战演练：对照源码、Socket 报文与真实工程场景，回答 10 个直击底层的心智与机制问题（重点复盘“为什么终端操作系统不会淘汰结对工作流协议”）。
  - 实验产物：`ep6-retrospective/notes.md`（并作为收官长文发布于 `Lamplight/content/posts/herdr-in-action.md`）。

### 2. 博客发布流水线与文件映射

- **代码与源文件仓库**：`/Users/yvan/projects/herdr-in-action/`
  - 笔记源路径：`epN/notes.md`（第一行必须为 `# H1 标题`，正文代码块为 ````term`）。
- **博客目标仓库**：`/Users/yvan/projects/Lamplight/`
  - 同步脚本：`Lamplight/scripts/sync-herdr-notes.mjs`。
  - 手记目标路径：`content/notes/n-YYYYMMDD-HHMM.md`。
  - 题图路径：`public/art/<slug>.webp` 与元数据 `content/art/<slug>.md`。
  - 同步命令：`npm run sync:herdr` 与 `npm run sync:herdr:check`。

## Assumptions & Open Questions

- Claude Code 版本要求 → 默认要求本地安装 v2.1.224 或更高版本：Cross-Session Messaging 在该版本后原生提供，保证实验可复现。
- `one-shot-pairing` 运行通道 → 默认以 Herdr 为第一优先级通道进行实测验证，保留 Subagent 作为离线对比基准。
- 异构 Agent 顾问面板 → 默认探活本地 `codex` 与 `agy`：若某 CLI 未就绪，自动降级为单模型评审，并在运行日志中记录。
- 题图生成执行方式 → 默认优先使用本地 `chatgpt-imagegen` CLI：严格遵循 Lamplight 单一琥珀光源文人水墨规范，生成后统一压缩为 WebP。

## Testing

- **设计验证**：运行 `bash /Users/yvan/developer/yy-skills/design-brainstorm/scripts/check-design-doc.sh docs/designs/2026-09-10-herdr-curriculum-design.md`，退出码为 0。
- **实验验证**：每个 `epN/` 目录下的自动化脚本均包含严格的前置状态检查（`set -euo pipefail`）与断言，可在本地终端无报错复现。
- **结对通道探测验证**：在 Herdr 环境中运行 `one-shot-pairing` 的 `detect-channel.sh`，确认输出识别为 `herdr` 而非降级的 `subagent`。
- **同步一致性验证**：在 Lamplight 仓库执行 `node scripts/sync-herdr-notes.mjs --check`，比对源笔记与发布手记的内容差异，无差异时退出码为 0。
- **博客构建与回归**：发布前在 Lamplight 执行 `npm test` 和 `npm run build`，确保所有笔记预渲染、sitemap 与 RSS feed 均构建成功。
