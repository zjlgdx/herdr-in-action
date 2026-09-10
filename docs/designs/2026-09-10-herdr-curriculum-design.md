# Herdr 实战演练与灯下手记系列课程设计

**Date:** 2026-09-10

## Context

全自主编码智能体（Claude Code、Codex、Antigravity 等）正在改变软件开发的形态：开发者的工作重心从亲手写代码，转向同时调度多个智能体并为它们把关。传统终端复用器（tmux、Zellij）看不见窗格里程序的状态，在多 Agent 并行时有两个痛点：一是智能体遇到高危操作或审批弹窗时静默挂起，开发者只能在多个窗口间来回巡检；二是缺少面向 Agent 的双向控制面，一个 Agent 无法可靠地拉起、驱动和等待另一个 Agent。

Herdr 0.9.0 已在本地跑起来，前期完成了《Herdr 全景实战与精通指南》速查版。本地还固化了工程级结对协议 `one-shot-pairing`（v0.4.2，含 `panel.sh` 异构评审面板），它把 `herdr` 窗格注入列为第一优先级通道。

本系列的目标不是解剖 Herdr 的源码，而是通过一组可复现的演练，让一个人真正精通 Herdr，并把多智能体调度用成肌肉记忆：同时开若干个 Agent 不打架，让它们互相指挥、互相评审，人只在需要审批和拍板时介入，最终做到一个人顶一支小团队的产出，即所谓 100X 超级个体。系列以 `herdr-in-action` 仓库为实验源头，产出 8 篇实战手记并发布至《灯下》个人博客（Lamplight）。技术细节只在支撑某个具体能力时才展开，展开的深度以“读者照着做能复现”为准。

## Discussion

在篇目组织上，对比过 5 篇合并方案与 7 篇递进方案。5 篇方案把状态感知与 Socket 控制、Worktree 与跨会话通信强行打包，单篇实验密度过高，读者做不完。初版 7 篇方案把 Claude Code Cross-Session Messaging 只当作 EP4 结尾的一段对比，没有独立实验，但它恰恰是“Agent 互相指挥”这条主线上最容易被忽略的一环。本版改为 8 篇：跨会话通信单独成篇，每篇只解决一个核心矛盾，并以一个可观察的验收结果收尾。

在课程定位上，明确了三条原则：
- **能力优先于机制**：每篇先回答“学完之后我能多做什么”，再决定要讲到哪一层。状态序列号、Socket 报文这类细节只在验证某个能力是否真的成立时才出现，不单独成节。
- **演练必须可验收**：每篇给出一个肉眼可见的验收标准，例如“Agent 卡在审批时侧边栏 10 秒内标红，人一键切入放行”。做不到就说明这篇没学会。
- **两条工作流分层不混淆**：Herdr 是 L1/L2 基础设施，管“环境怎么跑”和“状态怎么看”；`one-shot-pairing` 是 L4 工程方法论，管“质量怎么控”和“如何自动交付可合入的 PR”。前者没有后者，开发者只是在盲目开窗格；后者没有前者，就退化成看不见的子代理黑盒，遇到审批只能超时。

在跨会话协作上，Claude Code 2.1.224 起原生提供 Cross-Session Messaging（`ListAgents` / `SendMessage`），解决同构会话之间的文本直连。它的安全设计要求发给 bypass-permissions 会话的消息必须扣住等人批准（`crossSessionInbound`），所以受阻会话依然会无声挂起。Herdr 作为拓扑与状态基座，负责第一时间把 Blocked 标红并提供一键切入。两者是“L1/L2 拓扑与感知 + L3 语义总线”的上下层关系，而不是替代关系。

在状态模型上，纠正了早期文档“三态”的说法。Herdr 实际有五态：idle、working、blocked、done、unknown。idle 与 done 的区别不在 Agent 本身，而在“这个完成有没有被人看过”：focus 会把它标记为已看，read 不会，每个 TUI 客户端独立追踪。这个区别直接决定“一眼就知道该看哪个窗格”能不能成立，因此放进 EP1 作为核心演练。

## Approach

采用“演练驱动 + 协议融合 + 单向同步”落地：以 `~/Projects/herdr-in-action` 仓库为代码与实验源头，每篇一个 `epN-*/` 目录，配齐演练脚本、验收断言与笔记底稿 `notes.md`。博客侧复用 Lamplight 已有的 `scripts/sync-agent-notes.mjs`，把它从硬编码单系列改为按系列配置驱动（源仓库路径、ep 到手记 id 的映射、收官长文到 `content/posts/` 的映射），而不是复制第二份脚本。

全系列写作遵守 Lamplight 工程规范：不用模板套话，不堆形容词，正文记录真实实验参数、终端记录、报错重现与必要的源码引用；每篇配一幅文人水墨题图，大面积留白，唯一光源为暖琥珀纸灯。手记的开头不讲机制，先讲“今天演练完能做到什么”。

## Architecture

### 1. 八篇手记课程架构

每篇固定四段：能力跃迁（学完能多做什么）、核心矛盾、演练、验收。产物统一为 `epN-*/notes.md` 加一个可执行脚本。

- **EP0: 从单窗格到常驻作战室（Basics & Sessions）**
  - 能力跃迁：合上笔记本再打开，昨晚的所有 Agent 还在原位，一眼看清谁在干活、谁在等我。
  - 核心矛盾：tmux 只知道窗格活着，不知道里面的 Agent 是在思考、卡住还是做完了。
  - 演练：常驻 Session 守护、鼠标与快捷键双模操控、窗格切分、侧边栏五态图标含义、`config.toml` 常用项。
  - 验收：关闭终端再 `herdr session attach`，原有 Agent 窗格与状态徽章全部恢复。
  - 产物：`ep0-basics/config.toml`、`ep0-basics/notes.md`。

- **EP1: 让 Herdr 替我盯着（Hooks & State Detection）**
  - 能力跃迁：不再巡检窗口。Agent 停下来或卡在审批，侧边栏先于我知道。
  - 核心矛盾：Herdr 怎么知道模型停下了？钩子拿不到状态时靠什么兜底？
  - 演练：先执行 `herdr integration install claude` 把钩子升到当前版本（本地实测 v7 落后于 v9，逆向旧钩子会得出错误结论）；用 `mock-agent.sh` 模拟 idle → working → blocked → done 全流程，观察侧边栏变化；用 `herdr agent explain` 看钩子缺席时的缓冲区兜底判定；实测 idle 与 done 的“已看过”区别。
  - 验收：mock 进入 blocked 后 10 秒内侧边栏标红；切入窗格放行后自动回到 working。
  - 产物：`ep1-hooks-detection/mock-agent.sh`、`ep1-hooks-detection/notes.md`。

- **EP2: 让一个 Agent 指挥另一个（Socket API & Automation）**
  - 能力跃迁：写一段脚本就能拉起 Agent、注入任务、等它做完、读回结果，人不用碰键盘。
  - 核心矛盾：注入 prompt 之后，怎么知道对方真的开始干了、什么时候算干完？
  - 演练：用 `orchestrate.mjs` 走完 `agent start` → `agent prompt --wait` → `agent read` 的闭环；踩三个坑并记录：对方已 blocked 时注入被拒（`agent_blocked`）、注入后 5 秒无动静报 `agent_prompt_stalled`、对方已在 working 时 `--wait` 可能匹配到上一轮的完成。
  - 验收：脚本在无人操作下把一个三步任务跑完并把结果写入文件，三个坑各有一条可复现的报错记录。
  - 产物：`ep2-socket-cli/orchestrate.mjs`、`ep2-socket-cli/notes.md`。

- **EP3: 同时改一个仓库不打架（Worktrees & Workspaces）**
  - 能力跃迁：给三个 Agent 各发一个 issue，同一仓库并行推进，互不污染，收工后一键清理。
  - 核心矛盾：多 Agent 同时改同一目录导致文件冲突与上下文污染。
  - 演练：用 `herdr worktree create` 为每个 Agent 建独立分支与工作目录，与 workspace 绑定后侧边栏按拓扑分组；对比 `panel.sh` 使用的裸 `git worktree add --detach` 路径，明确两者何时该用哪个；演练 `herdr worktree remove` 与残留 prune。
  - 验收：三个 Agent 并行提交各自分支无冲突；全部移除后 `git worktree list` 只剩主目录。
  - 产物：`ep3-worktree-topology/setup-worktrees.sh`、`ep3-worktree-topology/notes.md`。

- **EP4: 结对作战室（One-Shot Pairing on Herdr）**
  - 能力跃迁：睡前丢一个 issue 进去，早上起来拿到一个已被独立评审过的 PR。
  - 核心矛盾：主控 Agent 如何拥有全局调度能力，又不把自己的上下文撑爆？
  - 演练：Navigator 在主窗格运行 `one-shot-pairing`，`detect-channel.sh` 识别为 `herdr`；通过 Socket API 拉起 Driver 窗格注入任务书；侧边栏监控 Driver 的 working 与 blocked，演示人工一键放行；用 `panel.sh` 起 Codex 与 Agy 异构评审面板（macOS 用 `nohup` 而非 `setsid`、Codex 任务书内联 diff、Agy 流式落盘超时仍可用），Fresh Reviewer 独立上下文盲审。
  - 验收：一个真实 issue 从任务书到评审通过全程无人干预，仅在审批弹窗时人工介入一次；面板产物目录内 `codex.md`、`agy.md`、`panel.done` 齐全。
  - 产物：`ep4-autonomous-pairing/pairing-harness.sh`、`ep4-autonomous-pairing/notes.md`。

- **EP5: 会话互通与代客审批的边界（Cross-Session Messaging）**
  - 能力跃迁：多个 Claude Code 会话之间直接对话协作，同时清楚地知道哪些事它们永远不会替我做。
  - 核心矛盾：会话之间能传消息，为什么受阻会话还是会无声挂起？
  - 演练：在两个 Herdr 窗格里各起一个 Claude Code，用 `ListAgents` 发现、`SendMessage` 互发任务；把其中一个以 bypass-permissions 启动，实测 `crossSessionInbound` 把入站消息扣住等审批的行为；对照 Herdr 侧边栏此时的 blocked 标红与一键放行；对比 EP4 中 Herdr 驱动异构面板（Codex / Agy）与同构总线的适用场景。
  - 验收：一条跨会话消息被扣住时，Herdr 在 10 秒内标红，人从侧边栏切入批准后消息送达。
  - 产物：`ep5-cross-session/relay-demo.sh`、`ep5-cross-session/notes.md`。

- **EP6: 跨机漫游（Remote Fleet & Persistence）**
  - 能力跃迁：轻薄本上一个侧边栏，同时看本机和远端主机上所有 Agent，断网重连不丢现场。
  - 核心矛盾：长时间任务应该跑在远端算力主机上，但人在本地要随时能看、能接管。
  - 演练：`herdr machine add` 建立 SSH 机器并在侧边栏出现；`herdr --remote` 附着，实测断网后重连恢复；对比 `--remote-keybindings local|server` 两种按键归属；说明远端与本地的 Agent id 各自独立、不可跨主机指挥。
  - 验收：远端 Agent 跑一个 10 分钟任务，中途本地断网 1 分钟，重连后状态与输出完整。
  - 产物：`ep6-remote-fleet/deploy-remote.sh`、`ep6-remote-fleet/notes.md`。

- **EP7: 收官复盘与超级个体十问（Retrospective & Ten Questions）**
  - 能力跃迁：形成自己的多智能体作战手册，知道什么任务该开几个 Agent、用哪种通道、人守在哪一环。
  - 核心矛盾：终端复用器向“智能体操作系统”演进后，上层工作流协议为什么不会被淘汰？
  - 演练：对照前七篇的实验记录回答十问：1) 什么任务值得开第二个 Agent；2) 什么时候用子代理、什么时候用 Herdr 窗格、什么时候用 Cross-Session；3) 五态里哪一态最该被人第一时间看到；4) 审批弹窗为什么不能让 Agent 代批；5) 一个人能同时盯多少个窗格；6) Worktree 隔离在什么规模下开始划算；7) 异构评审面板比同构评审多发现了什么；8) 无人值守一晚的失败模式有哪几种；9) 远端算力何时值得引入；10) Herdr 做成操作系统之后，`one-shot-pairing` 留下的是什么。
  - 验收：每一问都能引用前七篇的具体实验记录作答，不引用则删问。
  - 产物：`ep7-retrospective/notes.md`（并作为收官长文发布于 `Lamplight/content/posts/herdr-in-action.md`）。

### 2. 博客发布流水线与文件映射

- **代码与源文件仓库**：`~/Projects/herdr-in-action/`
  - 笔记源路径：`epN-*/notes.md`，第一行必须为 `# H1 标题`；终端记录围栏在源文件写 ```text，由同步脚本改为 ```term，与现有系列约定一致（AGENTS.md 二.4）。
- **博客目标仓库**：`~/Projects/Lamplight/`
  - 同步脚本：改造现有 `scripts/sync-agent-notes.mjs` 为按系列配置驱动，新增 herdr 系列的源仓库路径、ep 到手记 id 的映射，以及 EP7 到 `content/posts/herdr-in-action.md` 的映射。
  - 手记目标路径：`content/notes/n-YYYYMMDD-HHMM.md`。脚本只替换 frontmatter 中的 title 与正文，kind、date、time、tags、art、excerpt 需在首次发布时手工建立。
  - 题图路径：`public/art/<slug>.webp`，元数据登记在 `content/art/<slug>.md` 并递增 seq。
  - 同步命令：`npm run sync:notes` 与 `npm run sync:notes:check`。

## Assumptions & Open Questions

- Claude Code 版本 → 要求本地 v2.1.224 或更高，Cross-Session Messaging 与 `crossSessionInbound` 自该版本起提供；本地当前为 2.1.267。
- Herdr 集成钩子 → 每篇开始前执行 `herdr integration status`，claude 与 codex 钩子必须为 current，否则先 `herdr integration install`。
- `one-shot-pairing` 运行通道 → 默认以 Herdr 为第一优先级通道实测，保留子代理作为离线对比基准。
- 异构评审面板 → 默认探活本地 `codex` 与 `agy`，缺席者由 `panel.sh` 自动跳过并记入 `meta.txt`。
- EP6 远端主机 → 默认使用第二台可 SSH 的 macOS 或 Linux 主机；没有时用本地 Docker 起一个带 sshd 的容器作为降级方案，保证这一篇可复现。GPU 不是前提，Herdr 只关心 SSH。
- 题图生成 → 默认使用本地 `chatgpt-imagegen` CLI，遵循 Lamplight 单一琥珀光源文人水墨规范，生成后用 `cwebp` 压成 WebP。

## Testing

- **设计验证**：运行 `bash ~/developer/yy-skills/design-brainstorm/scripts/check-design-doc.sh docs/designs/2026-09-10-herdr-curriculum-design.md`，退出码为 0。
- **前置验证**：`herdr status` 显示 server running；`herdr integration status` 中 claude 与 codex 为 current；`claude --version` 不低于 2.1.224。
- **演练验收**：每个 `epN-*/` 目录的脚本均以 `set -euo pipefail` 开头，末尾断言本篇的验收条件（如 EP1 断言 `herdr agent wait --until blocked --timeout 10000` 成功返回），可在本地无报错复现。
- **结对通道验证**：在 Herdr 窗格内运行 `one-shot-pairing` 的 `detect-channel.sh`，输出为 `herdr` 而非 `subagent`。
- **面板清理验证**：向运行中的 `panel.sh` 发送 INT 或 TERM，断言 detached worktree 已被移除且 `panel.done` 写出。
- **同步一致性验证**：在 Lamplight 执行 `npm run sync:notes:check`，退出码为 0。
- **博客构建与回归**：发布前在 Lamplight 执行 `npm test` 和 `npm run build`，确保笔记预渲染、sitemap 与 RSS feed 均成功。
