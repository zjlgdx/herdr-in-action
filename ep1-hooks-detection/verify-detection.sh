#!/usr/bin/env bash
# ep1-hooks-detection/verify-detection.sh
# EP1 验收：两条状态通路各自成立。
#   A. 上报通路：mock-agent.sh 进入 blocked 后 10 秒内被服务端判定；人放行后回到 working；
#      后台完成显示 done，read 不消费，focus 消费。
#   B. 屏幕通路（在线）：fake-claude.sh 画出真实 Claude Code 审批框，10 秒内判 blocked；
#      画出抹掉特征行的审批框，后台标签页里显示 done（卡住的 Agent 亮 ✓）。
#   C. 屏幕通路（离线）：explain --file 重放同两份快照。
#   D. 本地覆盖清单：只写一条规则会整份替换远端清单；复制整份再追加规则才对。
#      覆盖文件放在临时 XDG_CONFIG_HOME 下，不碰 ~/.config/herdr。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EVIDENCE="${SCRIPT_DIR}/evidence"

pass() { echo "[PASS] $*"; }
fail() { echo "[FAIL] $*" >&2; exit 1; }
json() { python3 -c "import sys,json;d=json.load(sys.stdin);print($1)"; }
now_ms() { python3 -c 'import time;print(int(time.time()*1000))'; }

echo "=== [EP1 验收] 0. 前置条件 ==="
[[ "$(herdr status server)" == *"status: running"* ]] || fail "herdr server 未运行"
pass "herdr server running ($(herdr --version))"
CLAUDE_INT=$(herdr integration status | grep '^claude:')
[[ "$CLAUDE_INT" == "claude: current"* ]] || fail "claude 集成不是 current，先跑 herdr integration install claude"
pass "$CLAUDE_INT"

echo ""
echo "=== [EP1 验收] A. 上报通路：mock-agent ==="
PREV_WS=$(herdr workspace list | json '[w["workspace_id"] for w in d["result"]["workspaces"] if w["focused"]][0]')
WS=$(herdr workspace create --cwd "$SCRIPT_DIR" --label ep1-verify --no-focus | json 'd["result"]["workspace"]["workspace_id"]')
P=$(herdr pane list | json "[p['pane_id'] for p in d['result']['panes'] if p['workspace_id']=='$WS'][0]")
trap 'herdr workspace close "$WS" >/dev/null 2>&1 || true' EXIT
pass "临时工作区 $WS，窗格 $P（未抢焦点，当前活动工作区仍是 $PREV_WS）"

herdr pane run "$P" "bash ./mock-agent.sh" >/dev/null
# agent wait 要求目标已是 Agent；mock 第一次上报之前窗格只是 shell，会报 agent_not_found
for _ in $(seq 1 50); do herdr agent get "$P" >/dev/null 2>&1 && break; sleep 0.2; done
herdr agent wait "$P" --until working --timeout 10000 >/dev/null || fail "mock 未进入 working"
pass "mock -> working"

t0=$(now_ms)
herdr agent wait "$P" --until blocked --timeout 10000 >/dev/null || fail "10 秒内未判定 blocked"
pass "mock -> blocked，判定耗时 $(( $(now_ms) - t0 ))ms（上限 10000ms，从 working 起计，含 mock 剩余的工作时长）"

herdr pane send-text "$P" y >/dev/null
herdr agent wait "$P" --until working --timeout 10000 >/dev/null || fail "放行后未回到 working"
pass "人按 y 放行 -> working"

herdr agent wait "$P" --until done --timeout 10000 >/dev/null || fail "后台完成未显示 done"
pass "后台完成 -> done"

herdr agent read "$P" >/dev/null
S=$(herdr agent get "$P" | json 'd["result"]["agent"]["agent_status"]')
[[ "$S" == "done" ]] || fail "read 之后状态变成了 $S"
pass "agent read 之后仍是 done（read 不消费）"

herdr agent focus "$P" >/dev/null
S=$(herdr agent get "$P" | json 'd["result"]["agent"]["agent_status"]')
herdr workspace focus "$PREV_WS" >/dev/null
[[ "$S" == "idle" ]] || fail "focus 之后状态是 $S"
pass "agent focus 之后 -> idle（focus 消费），焦点已还给 $PREV_WS"

herdr pane send-text "$P" q >/dev/null
sleep 1
N=$(herdr agent list | json "len([a for a in d['result']['agents'] if a['pane_id']=='$P'])")
[[ "$N" == "0" ]] || fail "mock 退出后 Agent 仍在列表中"
pass "mock 退出 -> release-agent 交还权威，Agent 从列表消失"

echo ""
echo "=== [EP1 验收] B. 屏幕通路（在线）：fake-claude ==="
herdr pane run "$P" clear >/dev/null
P2=$(herdr pane split "$P" --direction right --cwd "$SCRIPT_DIR" --no-focus | json 'd["result"]["pane"]["pane_id"]')
herdr pane run "$P" "HERDR_AGENT=claude bash ./fake-claude.sh evidence/02-bash-permission.screen.txt" >/dev/null
herdr pane run "$P2" "HERDR_AGENT=claude bash ./fake-claude.sh evidence/03-unknown-prompt-shape.screen.txt" >/dev/null
for pane in "$P" "$P2"; do
  for _ in $(seq 1 50); do herdr agent get "$pane" >/dev/null 2>&1 && break; sleep 0.2; done
  herdr agent wait "$pane" --until working --timeout 30000 >/dev/null || fail "$pane 未进入 working"
done
pass "两个假 Claude 均 -> working（osc_title_working）"

t0=$(now_ms)
herdr agent wait "$P" --until blocked --timeout 10000 >/dev/null || fail "已知审批框 10 秒内未判定 blocked"
pass "已知审批框 -> blocked，判定耗时 $(( $(now_ms) - t0 ))ms（上限 10000ms，从 working 起计，含剩余的 working 时长）"

herdr agent wait "$P2" --until done --timeout 10000 >/dev/null || fail "陌生审批框未显示 done"
FB=$(herdr agent explain "$P2" --json | json 'd["fallback_reason"]')
[[ "$FB" == "default_known_agent_idle_fallback" ]] || fail "陌生审批框 fallback 为 $FB"
pass "陌生审批框 -> done（后台标签页亮 ✓），fallback: $FB"
herdr pane send-text "$P" q >/dev/null; herdr pane send-text "$P2" q >/dev/null

echo ""
echo "=== [EP1 验收] C. 屏幕通路（离线）：explain --file 重放 ==="
R=$(herdr agent explain --file "$EVIDENCE/02-bash-permission.screen.txt" --agent claude --json)
S=$(echo "$R" | json 'd["state"]'); RULE=$(echo "$R" | json '(d["matched_rule"] or {}).get("id")')
[[ "$S" == "blocked" ]] || fail "审批框快照判定为 $S"
pass "审批框快照 -> blocked（rule: $RULE）"

R=$(herdr agent explain --file "$EVIDENCE/03-unknown-prompt-shape.screen.txt" --agent claude --json)
S=$(echo "$R" | json 'd["state"]'); FB=$(echo "$R" | json 'd["fallback_reason"]')
[[ "$S" == "idle" && "$FB" == "default_known_agent_idle_fallback" ]] || fail "陌生审批框判定为 $S / $FB"
pass "抹掉特征行的审批框 -> idle（fallback: $FB）"

echo ""
echo "=== [EP1 验收] D. 本地覆盖清单（临时 XDG_CONFIG_HOME） ==="
XDG_TMP=$(mktemp -d)
trap 'herdr workspace close "$WS" >/dev/null 2>&1 || true; rm -rf "$XDG_TMP"' EXIT
OVR="$XDG_TMP/herdr/agent-detection/claude.toml"
mkdir -p "$(dirname "$OVR")"
RULE='
[[rules]]
id = "ep1_unknown_bash_prompt"
state = "blocked"
priority = 990
region = "whole_recent"
visible_blocker = true
contains = ["bash command", "4. no"]'
explain_ovr() { XDG_CONFIG_HOME="$XDG_TMP" herdr agent explain --file "$EVIDENCE/$1" --agent claude --json | json 'd["state"]+" "+str((d["matched_rule"] or {}).get("id"))'; }

S=$(herdr agent explain --file "$EVIDENCE/04-no-option-4.screen.txt" --agent claude --json | json 'd["state"]')
[[ "$S" == "blocked" ]] || fail "远端清单下 04 判定为 $S"
printf 'id = "claude"\nversion = "2026.09.28.1"\nmin_engine_version = 2\n%s\n' "$RULE" > "$OVR"
R=$(explain_ovr 04-no-option-4.screen.txt)
[[ "$R" == "idle None" ]] || fail "只含一条规则的覆盖文件下 04 判定为 $R"
pass "只写一条规则：04 从 blocked 变 $R（远端规则整份被替换）"

SRC=$(herdr agent explain --file "$EVIDENCE/02-bash-permission.screen.txt" --agent claude --json | json 'd["manifest_source"]')
SRC="${SRC#remote:}"
[[ -f "$SRC" ]] || fail "当前 claude 清单不是磁盘文件（$SRC），无法复制"
{ cat "$SRC"; echo "$RULE"; } > "$OVR"
R3=$(explain_ovr 03-unknown-prompt-shape.screen.txt); R4=$(explain_ovr 04-no-option-4.screen.txt)
[[ "$R3" == "blocked ep1_unknown_bash_prompt" && "$R4" == blocked* ]] || fail "整份覆盖下 03=$R3 04=$R4"
pass "复制整份再追加：03 -> $R3，04 -> $R4"

echo ""
echo "=== [EP1 验收通过] 上报通路、屏幕通路与本地覆盖均按文档行为工作 ==="
