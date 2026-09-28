#!/usr/bin/env bash
# ep1-hooks-detection/mock-agent.sh
# 一个假 Agent：不调模型，只按"自定义集成"协议向 Herdr 上报生命周期状态。
# 走一遍 working -> blocked -> (人按 y) -> working -> idle，退出时交还状态权威。
#
# 必须在 Herdr 窗格里跑（依赖 HERDR_ENV / HERDR_PANE_ID / HERDR_BIN_PATH）。
# 协议出处：官方文档 integrations.mdx「Integrate your own agent」。

set -euo pipefail

WORK_SECONDS="${MOCK_WORK_SECONDS:-2}"
SOURCE="custom:ep1-mock"
AGENT="mock"

if [[ "${HERDR_ENV:-}" != "1" || -z "${HERDR_PANE_ID:-}" ]]; then
  echo "not inside a herdr pane; nothing to report" >&2
  exit 1
fi
HERDR="${HERDR_BIN_PATH:-herdr}"

# 同一 source 的 seq 必须严格递增，Herdr 丢弃旧 seq（integrations.mdx）
seq_no=0
report() {
  seq_no=$((seq_no + 1))
  "$HERDR" pane report-agent "$HERDR_PANE_ID" \
    --source "$SOURCE" --agent "$AGENT" --seq "$seq_no" --state "$@" >/dev/null
}
release() {
  seq_no=$((seq_no + 1))
  "$HERDR" pane release-agent "$HERDR_PANE_ID" \
    --source "$SOURCE" --agent "$AGENT" --seq "$seq_no" >/dev/null || true
}
trap release EXIT

echo "[mock] working..."
report working
sleep "$WORK_SECONDS"

echo "[mock] Approve: rm -rf build/ ? [y/N]"
report blocked --message "Approve rm -rf build/?"
read -r -n 1 answer
echo

if [[ "$answer" != "y" ]]; then
  echo "[mock] denied"
  report idle
  exit 0
fi

echo "[mock] approved, working..."
report working
sleep "$WORK_SECONDS"

echo "[mock] done"
report idle

# 停在"提示符就绪"状态，等 verify 脚本或人来收尾（按任意键退出 = 交还权威）
read -r -n 1 _
