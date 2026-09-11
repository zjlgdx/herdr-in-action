# EP0 — 从单窗格到常驻作战室（Basics & Sessions）

Herdr 实战系列第一篇。通过常驻 Session、双模控制与侧边栏五态感知，把终端从“被动跑命令的黑盒”改造成“合上电脑不丢现场、一眼看清谁在等我”的多 Agent 协同作战室。

## 目录文件

- `config.toml`: 生产级作战室配置参考，开启了优先级排序、字符状态徽章与 Agent 边框标识。
- `verify-session.sh`: 自动化验收断言脚本，校验服务端连通性、配置文件有效性与 Session 拓扑快照。
- `notes.md`: 本篇实战手记源文件（同步至 Lamplight 博客）。

## 怎么跑与验收

1. 校验作战室配置语法：
```bash
HERDR_CONFIG_PATH=ep0-basics/config.toml herdr config check
```

2. 运行自动化验收脚本：
```bash
./ep0-basics/verify-session.sh
```

3. 体验断网/关闭终端再恢复：
```bash
# 查看当前活跃 Session
herdr session list

# 在任意终端重新接入作战室
herdr session attach default
```
