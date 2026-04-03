#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
launcher="$repo_root/scripts/squad-tmux-launch.sh"

tmpdir="$(mktemp -d)"
cleanup() {
  rm -rf "$tmpdir"
}
trap cleanup EXIT

project_dir="$tmpdir/project"
mkdir -p "$project_dir/.squad/prompts"
git -C "$tmpdir" init -b main project >/dev/null
project_dir="$(cd "$project_dir" && pwd -P)"
git -C "$project_dir" config user.email "codex@example.com"
git -C "$project_dir" config user.name "Codex"
echo "demo" >"$project_dir/README.seed"
git -C "$project_dir" add README.seed
git -C "$project_dir" commit -m "seed" >/dev/null

cat >"$project_dir/.squad/launcher.yaml" <<'EOF'
project:
  name: demo-project
  session_name: demo-project-squad

runtime:
  claude_command: claude
  claude_args:
    - --dangerously-skip-permissions
  manager_role: manager
  worker_role: worker
  inspector_role: inspector
  workers: 2

workspace:
  init_args:
    - --refresh-roles
  worktree:
    enabled: true
    location: .worktrees
    branch: feat/feishu-claude-support
    path: feishu-claude-support
    base_ref: HEAD

focus:
  files:
    - src/app/main.ts
    - src/platforms/feishuPlatform.js
  docs:
    - README.md

constraints:
  - Keep Codex runtime behavior unchanged
  - Keep config backwards compatible
EOF

cat >"$project_dir/.squad/run-task.md" <<'EOF'
# Task
完善飞书渠道对 Claude Code 的支持。

## Goals
- 打通飞书下 Claude 的基础链路
- 补齐流式输出和状态反馈
- 完善 agent/runtime 选择和恢复

## Acceptance
- 生成 manager prompt
- 生成 terminal mapping
- dry-run 不启动 tmux
EOF

cat >"$project_dir/.squad/prompts/inspector.md" <<'EOF'
# Inspector Task
请重点审查 README、路径解析和 Claude 安装兼容性是否与实现一致。
EOF

bash "$launcher" "$project_dir" --dry-run --no-setup --no-attach

quickstart_dir="$project_dir/.squad/quickstart/feishu-claude-support"
prompt_file="$quickstart_dir/generated-manager.prompt.md"
inspector_prompt_file="$quickstart_dir/generated-inspector.prompt.md"
summary_file="$quickstart_dir/generated-run-summary.md"
map_file="$quickstart_dir/generated-terminal-map.md"

test -f "$prompt_file"
test -f "$inspector_prompt_file"
test -f "$summary_file"
test -f "$map_file"

grep -q "完善飞书渠道对 Claude Code 的支持" "$prompt_file"
grep -q "README、路径解析和 Claude 安装兼容性" "$inspector_prompt_file"
grep -q "src/platforms/feishuPlatform.js" "$prompt_file"
grep -q "Keep Codex runtime behavior unchanged" "$prompt_file"
grep -q "demo-project-squad" "$summary_file"
grep -q "claude --dangerously-skip-permissions" "$summary_file"
grep -q "generated-inspector.prompt.md" "$summary_file"
grep -q "feat/feishu-claude-support" "$summary_file"
grep -q ".worktrees/feishu-claude-support" "$summary_file"
grep -q "Workspace root" "$prompt_file"
grep -q "Worktree" "$prompt_file"
grep -q "manager" "$map_file"
grep -q "worker-2" "$map_file"
grep -q "inspector" "$map_file"

echo "PASS: generic launcher dry-run generated expected files"
