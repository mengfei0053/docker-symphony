#!/usr/bin/env bash
set -euo pipefail

WORKFLOW_PATH="${SYMPHONY_WORKFLOW:-/config/WORKFLOW.md}"
LOGS_ROOT="${SYMPHONY_LOGS_ROOT:-/data/logs}"
PORT="${SYMPHONY_PORT:-4000}"

mkdir -p "$(dirname "$WORKFLOW_PATH")" "$LOGS_ROOT" "${SYMPHONY_WORKSPACE_ROOT:-/data/workspaces}"

if [[ ! -f "$WORKFLOW_PATH" ]]; then
	echo "No workflow file found at $WORKFLOW_PATH; copying example workflow." >&2
	cp /usr/local/share/symphony/WORKFLOW.example.md "$WORKFLOW_PATH"
fi

cd "${SYMPHONY_HOME:-/opt/symphony/elixir}"

if [[ "$#" -gt 0 ]]; then
	exec "$@"
fi

exec ./bin/symphony --logs-root "$LOGS_ROOT" --port "$PORT" "$WORKFLOW_PATH"
