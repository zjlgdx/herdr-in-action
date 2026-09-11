# herdr-in-action

《Herdr 实战手记》— 从单窗格到常驻作战室，一个人调度多智能体军团的肌肉记忆与工程实践。

以 `herdr-in-action` 为实验源头，通过一组可复现的演练，让终端复用器进化为面向自主编码智能体的作战室基座。系列共 8 篇实战手记，同步发布至 [灯下 Lamplight](https://blog.aixie.de/notes)。

## 形式与自律约定

- **能力优先于机制**：每篇先回答“学完能多做什么”，再决定展开哪层技术细节。
- **演练必须可验收**：每篇配备可执行断言脚本（以 `set -euo pipefail` 开头），给出肉眼可见的验收标准。
- **两条工作流分层不混淆**：Herdr 是 L1/L2 基础设施（管环境怎么跑与状态怎么看），`one-shot-pairing` 是 L4 工程方法论（管质量怎么控与自动交付 PR）。
- **真实记录，拒绝造假**：正文记录真实实验参数与终端输出，围栏里的终端记录一个字不改。

## 篇目大纲

| 篇目 | 目录 | 核心矛盾 | 验收标准 | 状态 |
| :--- | :--- | :--- | :--- | :---: |
| **EP0** | [ep0-basics/](ep0-basics/) | tmux 只知窗格存活，不知 Agent 状态 | 终端关闭后 `attach` 恢复窗格与状态徽章 | **已完成** |
| **EP1** | `ep1-hooks-detection/` | 钩子缺席与状态判定，五态跃迁原理 | mock 触发 blocked 后 10 秒内标红，放行回 working | 待开始 |
| **EP2** | `ep2-socket-cli/` | Socket 注入后怎么知道对方何时算干完 | 脚本无人值守跑完三步任务，踩坑三报错闭环 | 待开始 |
| **EP3** | `ep3-worktree-topology/` | 多 Agent 同时修改同一代码仓库冲突 | 三 Agent 并行提交各自分支无冲突，收工一键清理 | 待开始 |
| **EP4** | `ep4-autonomous-pairing/` | 主控调度全局却不撑爆上下文 | 真实 issue 全程无人干预，异构面板双重盲审通过 | 待开始 |
| **EP5** | `ep5-cross-session/` | Cross-Session Messaging 与受阻会话无声挂起 | 跨会话扣留审批时 10 秒内标红，人工切入放行 | 待开始 |
| **EP6** | `ep6-remote-fleet/` | 算力主机长时间任务与本地随开随看 | 远端跑 10 分钟任务，中途断网 1 分钟重连不丢现场 | 待开始 |
| **EP7** | `ep7-retrospective/` | 终端复用器进化为 OS 后，工作流协议为何不淘汰 | 对照前七篇实验记录作答超级个体十问 | 待开始 |

## 快速上手

运行 EP0 验收检查：

```bash
./ep0-basics/verify-session.sh
```

校验参考配置文件：

```bash
HERDR_CONFIG_PATH=ep0-basics/config.toml herdr config check
```

## 设计方案

完整系列课程体系设计参见 [docs/designs/2026-09-10-herdr-curriculum-design.md](docs/designs/2026-09-10-herdr-curriculum-design.md)。
