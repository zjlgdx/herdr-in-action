@AGENTS.md

## Claude Code

本项目使用 Herdr 终端复用器（不是 tmux），快捷键和命令与 tmux 完全不同。修改 `notes.md` 前必须核实 herdr 官方文档，不得凭 tmux 记忆推断。

### 验收命令

```bash
# EP0 验收
./ep0-basics/verify-session.sh

# 配置校验
HERDR_CONFIG_PATH=ep0-basics/config.toml herdr config check
```

### 写作规则

- `notes.md` 是源，改完从这里同步到博客，不要两边分头改。
- 润色时不得引入 emoji，状态符号只用 `×` `◐` `✓` `○` `·`。
- 每段技术断言标注出处（herdr help、源码文件名+函数名、或官方文档页面名）。
