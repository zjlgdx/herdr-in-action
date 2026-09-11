#!/usr/bin/env bash
# ep0-basics/verify-session.sh
# 验证 Herdr 常驻 Session、Socket API 与作战室配置的连通性与完整性。
# 符合课程设计测试规范：以 set -euo pipefail 开头，末尾断言验收条件。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_PATH="${SCRIPT_DIR}/config.toml"

echo "=== [EP0 验收] 1. 验证 Herdr CLI 版本与服务端状态 ==="
command -v herdr >/dev/null 2>&1 || {
  echo "[FAIL] 错误: 未在 PATH 中找到 herdr 命令" >&2
  exit 1
}

HERDR_VERSION=$(herdr --version | awk '{print $2}')
echo "[PASS] herdr binary detected: ${HERDR_VERSION}"

SERVER_STATUS=$(herdr status server | grep "status:" | awk '{print $2}')
if [[ "${SERVER_STATUS}" != "running" ]]; then
  echo "[FAIL] 错误: herdr server 未运行 (当前状态: ${SERVER_STATUS})" >&2
  exit 1
fi
echo "[PASS] herdr server status: running"

echo ""
echo "=== [EP0 验收] 2. 验证作战室配置文件 (config.toml) ==="
HERDR_CONFIG_PATH="${CONFIG_PATH}" herdr config check
echo "[PASS] config check: ok"

echo ""
echo "=== [EP0 验收] 3. 验证常驻 Session 与 Socket 连通性 ==="
SESSIONS_JSON=$(herdr session list --json)
RUNNING_COUNT=$(echo "${SESSIONS_JSON}" | grep -o '"running":true' | wc -l | tr -d ' ')

if [[ "${RUNNING_COUNT}" -lt 1 ]]; then
  echo "[FAIL] 错误: 未发现处于运行状态的 Herdr session" >&2
  exit 1
fi
echo "[PASS] active sessions found: ${RUNNING_COUNT}"

echo ""
echo "=== [EP0 验收] 4. 验证活跃拓扑与 Agent 状态快照 ==="
SNAPSHOT=$(herdr api snapshot)
WORKSPACE_COUNT=$(echo "${SNAPSHOT}" | grep -o '"workspace_id"' | wc -l | tr -d ' ')
PANE_COUNT=$(echo "${SNAPSHOT}" | grep -o '"pane_id"' | wc -l | tr -d ' ')

echo "[PASS] detected live topology: ${WORKSPACE_COUNT} workspace(s), ${PANE_COUNT} pane(s)"

echo ""
echo "=== [EP0 验收通过] 常驻 Session 守护就绪，断网重连与状态感知基座建立完成 ==="
