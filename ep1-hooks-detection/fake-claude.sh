#!/usr/bin/env bash
# ep1-hooks-detection/fake-claude.sh
# 不调模型的"假 Claude"：只往终端画屏幕，让 Herdr 按 Claude 的检测清单去判。
#   HERDR_AGENT=claude bash fake-claude.sh <最终屏幕文件>
# HERDR_AGENT 让 Herdr 把这个前台进程当作 claude（agents.mdx「Status authority」）。
#
# 三段：
#   1. 停在一屏清单认不出的画面，等 Herdr 完成进程接管、第一次到达 idle。
#      接管阶段的第一次 idle 不算"完成"（src/terminal/state.rs 的 finish_agent_process_acquisition）。
#   2. 终端标题换成盲文 spinner，命中 claude.toml 的 osc_title_working -> working。
#   3. 清掉标题，画出最终屏幕，停住等按键。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FINAL_SCREEN="${1:?usage: HERDR_AGENT=claude bash fake-claude.sh <screen-file>}"
SETTLE_SCREEN="${SCRIPT_DIR}/evidence/03-unknown-prompt-shape.screen.txt"

clear; cat "$SETTLE_SCREEN"
sleep "${FAKE_SETTLE_SECONDS:-10}"

printf '\033]0;\342\240\213 Working\007'
sleep "${FAKE_WORK_SECONDS:-4}"

printf '\033]0;\007'; clear; cat "$FINAL_SCREEN"
read -r -n 1 _
