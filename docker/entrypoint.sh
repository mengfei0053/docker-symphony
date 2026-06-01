#!/usr/bin/env bash
set -euo pipefail

WORKFLOW_PATH="${SYMPHONY_WORKFLOW:-/config/WORKFLOW.md}"
LOGS_ROOT="${SYMPHONY_LOGS_ROOT:-/data/logs}"
PORT="${SYMPHONY_PORT:-4000}"

mkdir -p "$(dirname "$WORKFLOW_PATH")" "$LOGS_ROOT" "${SYMPHONY_WORKSPACE_ROOT:-/data/workspaces}"

if [[ -d /host-ssh ]]; then
	mkdir -p /root/.ssh
	cp -R /host-ssh/. /root/.ssh/
	chmod 700 /root/.ssh
	find /root/.ssh -type f -name "*.pub" -exec chmod 644 {} +
	find /root/.ssh -type f ! -name "*.pub" -exec chmod 600 {} +
fi

if [[ ! -f "$WORKFLOW_PATH" ]]; then
	echo "No workflow file found at $WORKFLOW_PATH; copying example workflow." >&2
	cp /usr/local/share/symphony/WORKFLOW.example.md "$WORKFLOW_PATH"
fi

if [[ -z "${FIGMA_API_KEY:-}" ]]; then
	echo "Warning: FIGMA_API_KEY is not set; Codex Figma MCP will not authenticate." >&2
fi

cd "${SYMPHONY_HOME:-/opt/symphony/elixir}"

if [[ "$#" -gt 0 ]]; then
	exec "$@"
fi

exec ./bin/symphony \
	--i-understand-that-this-will-be-running-without-the-usual-guardrails \
	--logs-root "$LOGS_ROOT" \
	--port "$PORT" \
	"$WORKFLOW_PATH"
