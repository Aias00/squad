#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
launcher="$script_dir/squad-tmux-launch.sh"
project_dir="/Users/aias/Work/github/agent-bot-gateway"

usage() {
  cat <<'EOF'
Usage:
  scripts/agent-bot-gateway-squad-quickstart.sh [launcher-options]

Description:
  Launch the generic squad tmux launcher for:
  /Users/aias/Work/github/agent-bot-gateway

Examples:
  scripts/agent-bot-gateway-squad-quickstart.sh
  scripts/agent-bot-gateway-squad-quickstart.sh --dry-run
  scripts/agent-bot-gateway-squad-quickstart.sh --no-attach
  scripts/agent-bot-gateway-squad-quickstart.sh --session-name agent-bot-gateway-squad-2
  scripts/agent-bot-gateway-squad-quickstart.sh --task-file /tmp/another-task.md

Notes:
  - Reads project config from:
    /Users/aias/Work/github/agent-bot-gateway/.squad/launcher.yaml
  - Reads task brief from:
    /Users/aias/Work/github/agent-bot-gateway/.squad/run-task.md
    unless overridden by --task-file
  - All options are passed through to scripts/squad-tmux-launch.sh
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

exec "$launcher" "$project_dir" "$@"
