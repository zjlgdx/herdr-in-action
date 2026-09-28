# EP1 — 让 Herdr 替我盯着（Hooks & State Detection）

Herdr 的状态有两条通路：Agent 自己上报（`pane report-agent`），或服务端拿 TOML 清单匹配屏幕。Claude Code 与 Codex 走屏幕通路，集成钩子只报会话 ID。本课两条都跑一遍。

## 目录文件

- `mock-agent.sh`: 假 Agent，按自定义集成协议上报 working → blocked → working → idle，退出时交还权威。须在 Herdr 窗格里跑。
- `fake-claude.sh`: 假 Claude，不调模型，只往终端画屏幕；配合 `HERDR_AGENT=claude` 让 Herdr 按 Claude 清单去判。
- `verify-detection.sh`: 验收脚本。A 段跑 mock；B 段跑两个假 Claude（已知/陌生审批框）；C 段离线重放快照；D 段在临时 `XDG_CONFIG_HOME` 下验证本地覆盖清单。
- `evidence/`: 真实 Claude Code 屏幕快照与 `agent explain` 原始输出。
- `notes.md`: 本篇手记源文件。

## 怎么跑

1. 集成升到当前版本（升级 herdr 后必做）：
```bash
herdr integration status
herdr integration install claude
```

2. 运行验收（需 herdr server 在跑；会临时建一个不抢焦点的工作区，结束自动关闭）：
```bash
./ep1-hooks-detection/verify-detection.sh
```

3. 离线问服务端某个屏幕怎么判：
```bash
herdr agent explain --file ep1-hooks-detection/evidence/02-bash-permission.screen.txt --agent claude
```
