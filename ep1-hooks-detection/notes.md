# 《Herdr 实战手记》EP1 让 Herdr 替我盯着：Hooks & State Detection

## 能力跃迁：学完能多做什么

不再巡检窗口。Agent 卡在审批框，侧边栏那一行变成红色的 `×`（EP0 的 `status_indicators = "symbols"` 配置）；做完了而你还没看，那一行是 `✓`。

还要知道这件事**什么时候不成立**：Agent 卡在 Herdr 不认识的审批框里，状态会回落成 idle。在后台标签页里它亮的是 `✓`，看上去像做完了在等你验收。学完这一篇，能用 `herdr agent explain` 查出 Herdr 为什么这么判，判错时写一份本地清单纠正过来。

---

## 核心矛盾：Herdr 凭什么知道模型停下了

我原以为靠的是钩子。Claude Code 有 hooks，Herdr 有 `herdr integration install claude`，装上以后应该由钩子上报状态。

实测不是这样。装好最新的 Claude 集成，钩子脚本只做一件事：

```text
$ grep -n "SessionStart\|method" ~/.claude/hooks/herdr-agent-state.sh
54:if hook_event_name != "SessionStart":
65:session_start_source = hook_input.get("source") if hook_event_name == "SessionStart" else None
82:        "method": "pane.report_agent_session",
```

它只在 `SessionStart` 触发，只发 `pane.report_agent_session`——上报会话 ID，供服务端重启后 `claude --resume`。**一个状态都不报。**

Herdr 早期确实这么做过。源码仓库的 CHANGELOG 里，0.3.0 为 pi、claude code、codex、opencode 加上了 "authoritative hook-driven state reporting"。

到 0.6.7，Claude Code、Codex 等集成改成 "now report session identity only"，状态交给屏幕检测。

官方 agents.mdx 的「Status authority」一节现在把这件事写成一张表，每种 Agent 只有一个状态权威：

| Agent | 状态权威 | 集成的作用 |
| :--- | :--- | :--- |
| Pi / Kimi / OpenCode / Kilo | 装了集成用钩子，否则屏幕清单 | 状态 + 会话 |
| OMP / MastraCode | 钩子 | 状态 + 会话 |
| Claude Code / Codex / Cursor / Antigravity / Grok / Copilot 等 | 屏幕清单（screen manifest） | 只管会话 |

同一节给了原因：这些 Agent 的钩子覆盖不全生命周期，会漏掉"审批通过""按 Esc 中断"这类转换；同一个窗格只认一个状态来源，避免出现两套互相矛盾的状态。

对 Claude Code 和 Codex，屏幕检测是唯一的状态来源，谈不上兜底。本篇两条通路都跑一遍：

- **上报通路**：Agent 自己调 `herdr pane report-agent` 说"我在 working/blocked/idle"。用 `mock-agent.sh` 演练。
- **屏幕通路**：服务端读窗格底部缓冲区，拿 TOML 清单里的规则去匹配。用真 Claude Code 的审批框，和一个只画屏幕的假 Claude 演练。

---

## 演练

### 0. 先把集成升到当前版本

本篇开工当天我把 herdr 从 0.9.0 升到 0.9.1，集成立刻落后：

```text
$ herdr integration status | grep -E 'claude|codex|pi:'
pi: outdated (v8 < v9) (/Users/yvan/.pi/agent/extensions/herdr-agent-state.ts)
claude: outdated (v9 < v10) (/Users/yvan/.claude/hooks/herdr-agent-state.sh)
codex: current (v8) (/Users/yvan/.codex/herdr-agent-state.sh)
```

升级前先把旧钩子复制到临时目录 `$S`，装完 diff：

```text
$ herdr integration install claude
installed claude integration hook to /Users/yvan/.claude/hooks/herdr-agent-state.sh
ensured claude settings at /Users/yvan/.claude/settings.json
$ herdr integration status | grep claude
claude: current (v10) (/Users/yvan/.claude/hooks/herdr-agent-state.sh)
$ diff $S/claude-hook-v9.sh ~/.claude/hooks/herdr-agent-state.sh
6c6
< # HERDR_INTEGRATION_VERSION=9
---
> # HERDR_INTEGRATION_VERSION=10
```

`settings.json` 里只变了一处：`SessionStart` 的 matcher 从 `*` 收窄成 `^(startup|resume|clear|compact|fork)$`。

integrations.mdx「Claude Code」给了原因：Grok CLI 会导入 Claude 的 hooks 配置，收窄以后 Grok 的 `new`/`load` 事件不再触发这个钩子。脚本主体没动，依然只报会话身份。

所以拿本机的钩子脚本去逆向状态机制，读到的只有会话上报；0.6.7 之前的旧钩子报过状态，读它会得出过时的结论。每次升级 herdr 后先跑 `herdr integration status`，落后就重装。

### 1. 上报通路：自己当一回 Agent

跑在 Herdr 窗格里的进程会继承 `HERDR_ENV`、`HERDR_PANE_ID`、`HERDR_BIN_PATH`、`HERDR_SOCKET_PATH` 四个变量（integrations.mdx「Integrate your own agent」）。有这四个变量，任何脚本都能向服务端报状态。

先在一个普通 shell 窗格上手动报一次 `working`：

```text
$ herdr pane report-agent w2:p1 --source mock:ep1 --agent mock --state working
$ herdr agent list
{"id":"cli:agent:list","result":{"agents":[{"agent":"mock","agent_status":"working","cwd":"/Users/yvan/Projects/herdr-in-action","focused":false,"foreground_cwd":"/Users/yvan/Projects/herdr-in-action","pane_id":"w2:p1","revision":0,"state_change_seq":1,"tab_id":"w2:t1","terminal_id":"term_65c8639a9e02c9","workspace_id":"w2"}],"type":"agent_list"}}
$ herdr agent explain w2:p1
{"error":{"code":"agent_explain_unavailable","message":"agent target w2:p1 does not have a detected agent label"},"id":"cli:agent:explain"}
```

`mock` 这个标签 Herdr 从没见过，照样成了 Agent，上报通路不要求 Herdr 认识上报方。`agent explain` 则返回错误：它只解释屏幕检测的结果，上报来的状态没有规则可讲。

接着在一个新窗格上把整个状态机走一遍。`status` 和第 3 节的 `st` 写法相同，取 `herdr agent get` 返回里的 `agent_status` 字段，目标换成 w6:p1：

```text
$ herdr pane report-agent w6:p1 --source mock:ep1 --agent mock --state working --seq 1
$ status
working
$ herdr agent wait w6:p1 --until blocked --timeout 10000 >/dev/null & sleep 1
$ herdr pane report-agent w6:p1 --source mock:ep1 --agent mock --state blocked --seq 2 --message 'Approve rm -rf build/?'
$ time wait

real	0m0.002s
user	0m0.000s
sys	0m0.000s
$ status
blocked
$ herdr pane report-agent w6:p1 --source mock:ep1 --agent mock --state working --seq 3
$ herdr pane report-agent w6:p1 --source mock:ep1 --agent mock --state idle --seq 4
$ status
done
$ herdr agent read w6:p1 >/dev/null
$ status
done
$ herdr agent focus w6:p1 >/dev/null
$ status
idle
```

同一个窗格上接着测 seq 乱序和交还权威：

```text
$ herdr pane report-agent w6:p1 --source mock:ep1 --agent mock --state working --seq 200
$ herdr pane report-agent w6:p1 --source mock:ep1 --agent mock --state blocked --seq 100; echo rc=$?
rc=0
$ status
working
$ herdr pane release-agent w6:p1 --source mock:ep1 --agent mock --seq 201
$ herdr agent list
{"id":"cli:agent:list","result":{"agents":[],"type":"agent_list"}}
```

上报命令返回时，后台的 `agent wait --until blocked` 已经退出，`time wait` 只有 2ms。验收脚本 A 段用退出码确认了它等到的是 blocked。

报的是 `idle`，服务端显示的却是 `done`。上报协议里没有 `done`，`herdr pane report-agent --help` 的 `--state` 只接受 idle / working / blocked / unknown，`done` 由服务端算出来。

seq 那一段：integrations.mdx 要求同一 source 的 seq 严格递增。seq 100 晚于 200 到达，被静默丢弃，退出码仍是 `0`，上报方拿不到任何拒绝信号。最后 `release-agent` 交还权威，Agent 从列表消失。

`mock-agent.sh` 把这些规则打包成一个会"卡审批"的假 Agent：报 working，睡 2 秒，报 blocked 并在终端里问 `[y/N]`，人按 `y` 后报 working，再睡 2 秒报 idle，退出时 `trap release EXIT`。

### 2. 屏幕通路：真 Claude Code 的审批框

先在实验工作区 w2 里开一个窗格 p2，cwd 设为一个新建的空目录（`herdr pane split w2:p1 --direction right --cwd <空目录> --no-focus`），再在它上面起 Claude。

用 `--permission-mode default` 起，保证 Bash 命令一定弹审批（本机 `settings.json` 里 `defaultMode` 是 `auto`，会自动放行）。

还没发 prompt，就先 blocked 了：

```text
$ herdr agent start ep1claude --kind claude --pane w2:p2 --timeout 60000 -- --permission-mode default
{"error":{"code":"agent_not_ready","message":"agent ep1claude is blocked during startup and is not ready for prompts"},"id":"cli:agent:start"}
```

```text
$ herdr agent explain ep1claude
agent: claude
state: blocked
manifest: remote:/Users/yvan/.local/state/herdr/agent-detection/remote/claude.toml 2026.09.11.1
rule: live_blocked_form (region=after_last_horizontal_rule priority=980)
evidence: " Accessing workspace:\n\n /private/tmp/claude-501/-Users-yvan-Projects-herdr-in-action/0a420e5c-d31f-4b08-b039-05ea0cb01341/scratchpad/lab\n\n Quick safety check: Is this a project you created or one you trust? (Like your own code, a well-known..."
```

新目录触发了 Claude 的"信任此文件夹"对话框。`herdr --skill` 打印的 Agent 使用说明里写明：启动阶段被卡住时，`agent start` 立即返回 `agent_not_ready`，不等超时。这个对话框光标默认停在 `No, exit`，人按 `Down` `Enter` 放行。

然后让它执行一条需要审批的命令：`Use the Bash tool to run exactly: touch ep1-probe.txt`。

```text
$ herdr agent explain ep1claude
agent: claude
state: blocked
manifest: remote:/Users/yvan/.local/state/herdr/agent-detection/remote/claude.toml 2026.09.11.1
rule: bash_permission_prompt (region=whole_recent priority=850)
evidence: "\n ▐▛███▛█   Claude Code v2.1.283\n▝▜██████▀  Opus 5.5 · Claude Max\n ▝▝   ▝▝   /…/-Users-yvan-Projects-herdr-in-action/0a420e5c-d31f-4b08-b039-05ea0cb01341/scratchpad/lab · /rc\n\n\n❯ Use the Bash tool to run exactly: touch ep1-probe.txt\n\n  Crea..."
```

屏幕底部当时长这样：

```text
$ herdr agent read ep1claude > evidence/02-bash-permission.screen.txt
$ grep -v '^\s*$' evidence/02-bash-permission.screen.txt | tail -16
❯ Use the Bash tool to run exactly: touch ep1-probe.txt
  Creating empty probe file
  ⎿  $ touch ep1-probe.txt
────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
 Bash command
 Tip: auto mode handles these prompts for you — choose "switch to auto mode" below
   touch ep1-probe.txt
   Create empty probe file
 Do you want to proceed?
 ❯ 1. Yes
   2. Yes, and always allow access to
      /private/tmp/claude-501/-Users-yvan-Projects-herdr-in-action/0a420e5c-d31f-4b08-b039-05ea0cb01341/scratchpad/lab
      from this project
   3. Yes, and switch to auto mode · auto mode handles these prompts for you
   4. No
 Esc to cancel · Tab to amend
```

命中的规则在清单文件 `claude.toml` 里（`herdr agent explain` 第三行给出了路径和版本）：

```toml
[[rules]]
id = "bash_permission_prompt"
state = "blocked"
priority = 850
region = "whole_recent"
visible_blocker = true
contains = ["do you want to proceed?"]
any = [
  { contains = ["bash command"] },
  { contains = ["bash("] },
  { contains = ["contains expansion"] },
  { contains = ["tab to amend"] },
  { contains = ["ctrl+e to explain"] },
]
```

这条规则的意思是：屏幕最近区域里有 `do you want to proceed?`，且出现任意一个 Bash 审批的特征词，就判 blocked。所有规则按 `priority` 从高到低试，第一条命中的说了算；`region` 决定看屏幕的哪一块（agents.mdx：看的是缓冲区底部的实时画面，不是你往上滚动看到的视口）。

### 3. done 与 idle：完成发生在哪里

EP0 说过：切进窗格消费 done，read 不消费。放行 Claude 的审批之后，我期待看到 done，结果是：

```text
$ st(){ herdr agent get ep1claude | python3 -c 'import sys,json;print(json.load(sys.stdin)["result"]["agent"]["agent_status"])'; }
$ herdr agent send-keys ep1claude Enter >/dev/null; sleep 1; echo -n "after approve: "; st
after approve: working
$ herdr agent wait ep1claude --timeout 60000 >/dev/null; echo -n "settled: "; st
settled: idle
$ herdr agent read ep1claude >/dev/null; echo -n "after read: "; st
after read: idle
$ herdr agent focus ep1claude >/dev/null; echo -n "after focus: "; st
after focus: idle
```

不带 `--until` 时，`agent wait` 等 idle、done、blocked 中任意一个（`herdr agent wait --help`）。

没有 done。而第 1 节的 mock 明明出了 done。区别在源码里。

`src/app/api_helpers.rs` 的 `pane_agent_status()`：

```rust
(crate::detect::AgentState::Idle, false) => crate::api::schema::AgentStatus::Done,
(crate::detect::AgentState::Idle, true) => crate::api::schema::AgentStatus::Idle,
```

done 就是"idle 且没被看过"。`seen` 在哪里设置，看 `src/app/actions.rs` 的 `apply_pane_state_change()`：

```rust
if change.state != AgentState::Idle {
    pane.seen = true;
} else if !suppress_completion && is_completion_transition(change) {
    pane.seen = suppress_active_tab_notifications;
}
```

`suppress_active_tab_notifications` 来自同文件的 `active_tab_suppresses_notifications()`：窗格在**当前活动标签页**里、且外层终端没失焦，就为真。也就是说，完成发生在你正在看的那个标签页里，服务端直接当你看过了，不会出 done。

Claude 那一轮，实验工作区 w2 是活动工作区，p2 就在活动标签页里；mock 那一轮，活动工作区是 w1。把活动工作区切回 w1 再跑一轮验证：

```text
$ herdr workspace focus w1 >/dev/null
$ herdr agent prompt ep1claude "Reply with the single word: ok" --wait --timeout 60000 >/dev/null; echo -n "settled (active=w1): "; st
settled (active=w1): done
$ herdr agent read ep1claude >/dev/null; echo -n "after read: "; st
after read: done
$ herdr agent focus ep1claude >/dev/null; echo -n "after focus: "; st
after focus: idle
```

补全 EP0 的规则：

- 完成发生在**后台**标签页 → `done`，等你切进去或 `agent focus` 才变 `idle`
- 完成发生在**当前活动**标签页 → 直接 `idle`
- `agent read` / `pane read` 任何时候都不消费

`agent focus` 会把服务端的活动工作区切过去。只要它还是活动标签页、外层终端也没失焦，那里的完成就不会亮 `✓`。

### 4. 离线重放：`explain --file`

以下命令在 `ep1-hooks-detection/evidence/` 下运行。把第 2 节的屏幕存成文件，不起 Claude、不花 token，就能反复问服务端怎么判：

```text
$ herdr agent explain --file 02-bash-permission.screen.txt --agent claude; echo "rc=$?"
agent: claude
state: blocked
manifest: remote:/Users/yvan/.local/state/herdr/agent-detection/remote/claude.toml 2026.09.11.1
rule: bash_permission_prompt (region=whole_recent priority=850)
evidence: "\n ▐▛███▛█   Claude Code v2.1.283\n▝▜██████▀  Opus 5.5 · Claude Max\n ▝▝   ▝▝   /…/-Users-yvan-Projects-herdr-in-action/0a420e5c-d31f-4b08-b039-05ea0cb01341/scratchpad/lab · /rc\n\n\n❯ Use the Bash tool to run exactly: touch ep1-probe.txt\n\n  Crea..."
rc=0
```

和在线判定一字不差。

现在模拟"Claude 某天改了审批框的文案"：逐步删掉特征行，看判定怎么变。`brief` 从 `explain --json` 里取 `state`、`matched_rule.id`、`fallback_reason` 三个字段：

```text
$ grep -v 'Do you want to proceed' 02-bash-permission.screen.txt > /tmp/ep1-a.txt
$ brief /tmp/ep1-a.txt
state: blocked | rule: legacy_no_prompt_blocker | fallback: None
$ grep -viE 'Do you want to proceed|Esc to cancel' 02-bash-permission.screen.txt > /tmp/ep1-b.txt
$ brief /tmp/ep1-b.txt
state: idle | rule: None | fallback: default_known_agent_idle_fallback
$ cmp /tmp/ep1-b.txt 03-unknown-prompt-shape.screen.txt && echo same-as-03
same-as-03
```

删掉 `Do you want to proceed?`，还是 blocked。兜住它的是一条优先级 300 的宽口径老规则 `legacy_no_prompt_blocker`，这里命中的是其中 `tab to amend` 这一组。

再删掉 `Esc to cancel · Tab to amend` 那一行，回落 idle。第二份快照就是仓库里的 `evidence/03-unknown-prompt-shape.screen.txt`。

这就是 agents.mdx「Blocked state」一节说的：blocked 判定是**故意严格**的，只有屏幕匹配已知的审批 UI 才标红；认得这个 Agent 但没有规则命中，回落到 idle，explain 里标 `default_known_agent_idle_fallback`。

### 5. 卡住的 Agent 亮 `✓`

离线重放只给出判定，不经过服务端的状态机。要看侧边栏实际显示什么，得在线跑一次。`fake-claude.sh` 不调模型，只往终端画屏幕，靠 `HERDR_AGENT=claude` 让 Herdr 按 Claude 的清单去判（agents.mdx「Status authority」里给 wrapper 用的提示变量）。

它分三段：先停在一屏清单认不出的画面，等 Herdr 完成进程接管；再把终端标题换成盲文 spinner，命中 `osc_title_working`；最后清掉标题，画出 03 号快照停住。

第一段要等，是因为接管阶段第一次到达 idle 时，服务端会压掉完成信号（`src/terminal/state.rs` 的 `finish_agent_process_acquisition()`）。

实验工作区用 `--no-focus` 建，是后台标签页。`st` 同第 3 节：

```text
$ herdr pane run w9:p1 'HERDR_AGENT=claude bash ./fake-claude.sh evidence/03-unknown-prompt-shape.screen.txt' >/dev/null
$ sleep 3; st
unknown
$ herdr agent wait w9:p1 --until working --timeout 30000 >/dev/null; st
working
$ herdr agent wait w9:p1 --until done --timeout 10000 >/dev/null; st
done
$ herdr agent explain w9:p1
agent: claude
state: idle
manifest: remote:/Users/yvan/.local/state/herdr/agent-detection/remote/claude.toml 2026.09.11.1
rule: none
fallback_reason: default_known_agent_idle_fallback
```

状态是 `done`，侧边栏上亮 `✓`。explain 说明它是回落出来的 idle：`rule: none`，`fallback_reason: default_known_agent_idle_fallback`。

落到侧边栏上，卡在陌生审批框里的 Agent 不会标红：在后台标签页里亮 `✓`，在当前标签页里是 `○`（第 3 节），`agent wait --until blocked` 也不会返回。文档说这种误判只影响显示和等待，Herdr 不会因此往窗格里发输入；同样也不会有任何提示。

我现在的做法是：给了任务、还没看到结果，它却显示 `✓` 或 `○`，就跑一次 `herdr agent explain`，看有没有 `fallback_reason: default_known_agent_idle_fallback`。

### 6. 用本地清单纠正误判

agents.mdx「Detection manifests」：本地覆盖文件 `~/.config/herdr/agent-detection/<agent>.toml` 永远优先于远端和内置清单。文档用的词是 replace，覆盖文件整份替换远端清单，不做合并。

覆盖目录来自源码 `src/detect/manifest.rs` 的 `override_path()`，它取 `config_dir()`，而 `config_dir()` 认 `XDG_CONFIG_HOME`。`explain --file` 在 CLI 本地求值，会读到这个目录。所以可以把覆盖文件放进临时目录演练，不碰真实配置。

先准备一条规则：屏幕里同时有 `bash command` 和 `4. no` 就判 blocked，专门兜住 03 号快照。04 号快照是 02 去掉 `4. No` 那一行，远端清单判它 blocked：

```text
$ cat /tmp/ep1-rule.toml

[[rules]]
id = "ep1_unknown_bash_prompt"
state = "blocked"
priority = 990
region = "whole_recent"
visible_blocker = true
contains = ["bash command", "4. no"]
$ export XDG_CONFIG_HOME=$(mktemp -d); mkdir -p $XDG_CONFIG_HOME/herdr/agent-detection
$ OVR=$XDG_CONFIG_HOME/herdr/agent-detection/claude.toml
$ brief 04-no-option-4.screen.txt
state: blocked | rule: bash_permission_prompt | fallback: None
$ printf 'id = "claude"\nversion = "2026.09.28.1"\nmin_engine_version = 2\n' > $OVR; cat /tmp/ep1-rule.toml >> $OVR
$ brief 04-no-option-4.screen.txt
state: idle | rule: None | fallback: default_known_agent_idle_fallback
$ cat ~/.local/state/herdr/agent-detection/remote/claude.toml /tmp/ep1-rule.toml > $OVR
$ brief 03-unknown-prompt-shape.screen.txt
state: blocked | rule: ep1_unknown_bash_prompt | fallback: None
$ brief 04-no-option-4.screen.txt
state: blocked | rule: bash_permission_prompt | fallback: None
```

只写一条规则时，04 丢掉了远端的 `bash_permission_prompt`，回落 idle，Claude 其余的规则也一起没了。把远端 `claude.toml` 整份复制过来再追加，新规则兜住了 03，远端规则照常判 04。

真要生效，就把 explain 第三行 `manifest:` 给出的远端文件复制到 `~/.config/herdr/agent-detection/claude.toml`，追加规则，再跑 `herdr server reload-agent-manifests`。

覆盖文件在的时候，这个 Agent 收不到远端清单的更新，explain 的 JSON 里 `local_override_shadowing_remote` 字段会标出来。等远端清单认得这个形状了，删掉覆盖文件再 reload 一次。

---

## 验收

`verify-detection.sh` 在一个不抢焦点的临时工作区里跑 mock 和两个假 Claude，再离线重放屏幕快照，最后在临时 `XDG_CONFIG_HOME` 下验证覆盖清单：

```text
$ ./ep1-hooks-detection/verify-detection.sh; echo "exit=$?"
=== [EP1 验收] 0. 前置条件 ===
[PASS] herdr server running (herdr 0.9.1)
[PASS] claude: current (v10) (/Users/yvan/.claude/hooks/herdr-agent-state.sh)

=== [EP1 验收] A. 上报通路：mock-agent ===
[PASS] 临时工作区 wB，窗格 wB:p1（未抢焦点，当前活动工作区仍是 w1）
[PASS] mock -> working
[PASS] mock -> blocked，判定耗时 1983ms（上限 10000ms，从 working 起计，含 mock 剩余的工作时长）
[PASS] 人按 y 放行 -> working
[PASS] 后台完成 -> done
[PASS] agent read 之后仍是 done（read 不消费）
[PASS] agent focus 之后 -> idle（focus 消费），焦点已还给 w1
[PASS] mock 退出 -> release-agent 交还权威，Agent 从列表消失

=== [EP1 验收] B. 屏幕通路（在线）：fake-claude ===
[PASS] 两个假 Claude 均 -> working（osc_title_working）
[PASS] 已知审批框 -> blocked，判定耗时 2951ms（上限 10000ms，从 working 起计，含剩余的 working 时长）
[PASS] 陌生审批框 -> done（后台标签页亮 ✓），fallback: default_known_agent_idle_fallback

=== [EP1 验收] C. 屏幕通路（离线）：explain --file 重放 ===
[PASS] 审批框快照 -> blocked（rule: bash_permission_prompt）
[PASS] 抹掉特征行的审批框 -> idle（fallback: default_known_agent_idle_fallback）

=== [EP1 验收] D. 本地覆盖清单（临时 XDG_CONFIG_HOME） ===
[PASS] 只写一条规则：04 从 blocked 变 idle None（远端规则整份被替换）
[PASS] 复制整份再追加：03 -> blocked ep1_unknown_bash_prompt，04 -> blocked bash_permission_prompt

=== [EP1 验收通过] 上报通路、屏幕通路与本地覆盖均按文档行为工作 ===
exit=0
```

写验收脚本时踩了两个坑：

1. `agent wait` 要求目标已经是 Agent。mock 第一次上报之前窗格只是 shell，`wait` 立即返回 `{"error":{"code":"agent_not_found","message":"agent target w3:p1 not found"}}`，不会等它出现。脚本里先轮询 `agent get` 直到成功。
2. `set -o pipefail` 下写 `herdr status server | grep -q ...`，服务端明明在跑也会判失败：`grep -q` 匹配到就退出，上游收到 SIGPIPE，管道整体非零。先把输出存进变量再匹配。

B、C、D 段断言的是判定结果，依赖远端清单当前的规则，而远端清单会自动更新。哪天 03 号快照被新规则判成 blocked，这几段就会失败。这时要重新截屏、重跑 explain，再更新笔记。

