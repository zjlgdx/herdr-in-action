# AGENTS.md

给在本仓库工作的 AI agent 的指令。本仓库是《Herdr 实战手记》系列。

## 项目本质

这是一个**学习项目**：产出物是"作者的理解"和"可复现的演练"，不是产品。每课一个目录，内含 `notes.md`（正文）+ 可执行验收脚本 + 一屏以内的 README。发布到 [灯下 Lamplight](https://blog.aixie.de/notes)。

## 技术栈

- Herdr 0.9.0（终端复用器，非 tmux）
- 纯 Bash 验收脚本（`set -euo pipefail`）
- config.toml（Herdr 配置格式）
- 无前端、无数据库、无 CI

## 权威参考来源

Herdr 文档随版本变动。写入或修改笔记内容前，按以下优先级核实事实：

1. 本机 `herdr --help` / `herdr <subcommand> --help` 实际输出
2. 克隆源码 `docs/next/website/src/content/docs/*.mdx`（keyboard.mdx、cli-reference.mdx、concepts.mdx、session-state.mdx）
3. 源码 `src/` 中的实现（如 `shell.rs` 里的 `status_icon()`、`status_color()`）
4. `config-reference.json`
5. 官方 herdr.dev 网站

不得凭记忆编写 Herdr 的快捷键、CLI 参数或配置项。错一个读者就会卡住。

## 红线

1. **围栏里的终端记录和 `herdr agent explain` 原话一个字不改。** 它们是证据；要改就重跑再贴。
2. **笔记里写的机制，验收脚本里必须真的能跑通。** 不允许"笔记超前于代码"。
3. **不写规格文档。** 不需要 SPEC.md、ROADMAP.md。计划只存在"下一课"。
4. **不用 emoji。** 状态指示用 Herdr 源码里的真实符号（`×` `◐` `✓` `○` `·`）。
5. **不为下一课预留设计。** 每课独立自包含，课与课之间允许复制粘贴。

## 目录结构

```
ep0-basics/     # EP0：Basics & Sessions
ep1-.../        # EP1-EP7 各课独立目录
docs/designs/   # 课程体系设计（仅供参考，不是需求文档）
```

每课目录下：
- `notes.md` — 正文（源文件，博客由脚本同步）
- `verify-*.sh` — 验收断言脚本
- `config.toml` — 参考配置（如有）
- `README.md` — 一屏以内，只写怎么跑

## 完成定义

一课完成 = 作者亲手跑通验收脚本 + `notes.md` 绘制水墨题图并发布部署到 blog.aixie.de/notes（遵循 Lamplight 发布流水线）。

## 文风

- 干、短、不绕弯子。写操作指令不写散文。
- 机制与现象分开。机制不随版本变，现象随版本漂移。
- 让模型润色前先列事实清单，润色后逐条比对。文风可以再润，事实退步读者看不出来。
