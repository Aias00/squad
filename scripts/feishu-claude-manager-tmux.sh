#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  scripts/feishu-claude-manager-tmux.sh [project-dir] [session-name]

Default project-dir:
  /Users/aias/Work/github/agent-bot-gateway

Default session-name:
  agent-bot-gateway-squad

What it does:
  1. Verifies `squad`, `claude`, and `tmux`
  2. Runs `squad setup claude`
  3. Runs `squad init --refresh-roles` in the target project
  4. Generates quickstart files under .squad/quickstart
  5. Creates a tmux session with 4 panes
  6. Starts `claude` in each pane
  7. Auto-sends:
     - /squad manager
     - /squad worker
     - /squad worker worker-2
     - /squad inspector
  8. Pastes the generated manager prompt into the manager pane
  9. Attaches to the tmux session

Flags:
  --no-attach   Create and start the tmux session but do not attach
  --no-setup    Skip `squad setup claude`
  -h, --help    Show this help
EOF
}

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: missing required command: $cmd" >&2
    exit 1
  fi
}

wait_for_pane_command() {
  local target="$1"
  local expected="$2"
  local timeout_secs="${3:-20}"
  local start_ts
  start_ts="$(date +%s)"

  while true; do
    local current
    current="$(tmux display-message -p -t "$target" "#{pane_current_command}")"
    if [[ "$current" == "$expected" ]]; then
      return 0
    fi

    if (( "$(date +%s)" - start_ts >= timeout_secs )); then
      echo "Error: pane $target did not start '$expected' within ${timeout_secs}s (current: $current)" >&2
      return 1
    fi

    sleep 1
  done
}

send_tmux_text() {
  local target="$1"
  local text="$2"
  tmux load-buffer - <<<"$text"
  tmux paste-buffer -t "$target"
  tmux send-keys -t "$target" Enter
  tmux delete-buffer
}

no_attach=0
no_setup=0
positional=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-attach)
      no_attach=1
      shift
      ;;
    --no-setup)
      no_setup=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      positional+=("$1")
      shift
      ;;
  esac
done

project_dir="${positional[0]:-/Users/aias/Work/github/agent-bot-gateway}"
session_name="${positional[1]:-agent-bot-gateway-squad}"

require_cmd squad
require_cmd claude
require_cmd tmux

if [[ ! -d "$project_dir" ]]; then
  echo "Error: project directory does not exist: $project_dir" >&2
  exit 1
fi

cd "$project_dir"
project_dir="$(pwd)"

if (( no_setup == 0 )); then
  echo "[1/6] Refreshing Claude /squad command"
  squad setup claude
else
  echo "[1/6] Skipping squad setup claude (--no-setup)"
fi

echo "[2/6] Initializing squad workspace"
squad init --refresh-roles

quickstart_dir="$project_dir/.squad/quickstart"
mkdir -p "$quickstart_dir"

prompt_file="$quickstart_dir/manager-feishu-claude-support.prompt.md"
guide_file="$quickstart_dir/tmux-terminal-commands.md"

echo "[3/6] Writing manager prompt"
cat >"$prompt_file" <<'EOF'
目标：完善当前工程中飞书渠道对 Claude Code 的支持。在现有 Feishu runtime、agent/runtime 路由能力和 ClaudeClient 基础上，补齐飞书 + Claude 的完整可用链路，重点覆盖以下三类能力：

1. 基础链路可用
2. Claude 专属交互能力补齐
3. agent/runtime 选择、配置、切换、会话续接与恢复

背景判断：
- 当前仓库已经具备 Feishu 平台接入能力。
- 当前仓库已经具备 Claude runtime / ClaudeClient 基础能力。
- 本次工作不是从零接入 Claude，而是让飞书渠道下的 Claude 真正达到稳定可用、可切换、可恢复、可观测的状态。
- 必须避免破坏现有 Discord 渠道和现有 Codex 路径。

相关代码入口，分析和拆任务时优先关注这些位置：
- `src/feishu/runtime.js`
- `src/platforms/feishuPlatform.js`
- `src/claudeClient.js`
- `src/clients/agentClientRegistry.js`
- `src/agents/setupResolution.js`
- `src/codex/turnRunner.js`
- `src/commands/router.js`
- `README.md`
- `config/channels.example.json`

执行原则：
1. 先做现状分析和缺口识别，再拆任务，不要一开始直接修改代码。
2. 优先使用 `squad task create / ack / complete` 分配和跟踪任务。
3. manager 负责分析、拆解、协调、验收，不要自己承担大块实现。
4. 所有任务都必须写清楚：
   - 目标
   - 涉及文件
   - 不允许破坏的行为
   - 验收标准
5. 每个 worker 完成后，都必须交给 inspector 审查，重点关注兼容性、回归风险和异常路径。
6. 不允许为了支持 Claude 而破坏现有 Codex 运行时行为。
7. 不允许只验证 happy path，必须覆盖失败、降级和恢复场景。

请先完成以下分析：
1. 梳理飞书消息进入后的完整处理路径，明确从 inbound event 到 turn 执行再到消息回发的链路。
2. 梳理当前 `runtime=claude` 在系统中的进入点、配置解析方式和 thread/session 生命周期。
3. 明确飞书渠道下 Claude 支持目前缺失或不完整的点，至少覆盖：
   - 文本消息是否稳定进入 Claude turn
   - route -> agentId -> runtime 解析是否正确
   - thread/start 与 thread/resume 是否可用
   - Claude 流式输出是否能被 Feishu 正确呈现
   - Claude 的 tool/status/error 事件是否能被 Feishu 正确渲染
   - 审批请求在飞书下如何处理或降级
   - 图片/附件输入输出在 Claude agent 下是否兼容
   - 配置切换、agent 切换、会话恢复是否成立
4. 输出一份“当前能力基线 + 缺口列表 + 风险点”。

在分析完成后，把工作拆成 4 个任务，分配给在线 worker：

任务 A：飞书 + Claude 基础链路打通
目标：
- 确保飞书绑定 chat 在选择 Claude agent 或 `runtime=claude` 时，可以稳定完成一次完整 turn。
- 确保 route 绑定、thread/start、thread/resume、turn 执行、最终回复链路成立。

重点检查：
- `src/feishu/runtime.js`
- `src/codex/turnRunner.js`
- `src/clients/agentClientRegistry.js`
- `src/agents/setupResolution.js`

验收标准：
- 飞书消息可以稳定进入 Claude turn
- route 对应的 agent/runtime 解析正确
- thread/session 绑定和恢复链路可用
- 不破坏现有 Codex 路径

任务 B：飞书下 Claude 的交互能力补齐
目标：
- 补齐 Feishu 对 Claude 运行时输出的渲染与交互支持。

重点覆盖：
- 流式输出
- 状态消息
- tool progress / command execution / error 反馈
- 最终完成消息
- 审批请求在飞书下的降级或兼容处理
- 附件 / 图片输入输出兼容性提示与降级策略

重点检查：
- `src/feishu/runtime.js`
- `src/render/messageRenderer.js`
- `src/turns/notificationRuntime.js`
- `src/approvals/serverRequestRuntime.js`
- `src/claudeClient.js`

验收标准：
- Claude 的主要通知事件在飞书下能被清晰呈现
- 不支持的能力有明确降级策略和用户提示
- 不出现明显的消息丢失、错序、卡死或不可理解反馈

任务 C：agent/runtime 选择、配置切换与恢复完善
目标：
- 完善飞书侧对 agentId、defaultAgent、runtime=claude 的解析、切换、持久化和恢复行为。

重点覆盖：
- route 级 agent override
- defaultAgent fallback
- runtime 解析优先级
- `setagent` / `clearagent` 在飞书侧的支持边界
- 配置更新后行为一致性
- 恢复和重启后的绑定一致性

重点检查：
- `src/agents/setupResolution.js`
- `src/agents/agentRegistry.js`
- `src/config/loadConfig.js`
- `src/commands/router.js`
- `config/channels.example.json`
- `README.md`

验收标准：
- 飞书 route 下 agent/runtime 解析符合预期
- 配置优先级清晰且可验证
- 会话恢复和 route 绑定不会因 Claude 路径失真
- 文档和示例配置同步更新

任务 D：回归验证、诊断与文档收口
目标：
- 验证飞书 + Claude 可用，同时确保 Discord 和 Codex 路径不回退。

至少覆盖：
- Feishu + Claude 基础问答链路
- Feishu + Claude 流式/状态/错误反馈
- agent 切换与配置优先级
- thread/start 与 resume
- Codex 既有路径回归
- Discord 既有路径回归
- doctor/status/capabilities 输出是否仍然正确

验收标准：
- 补齐测试
- 补齐 README / 配置说明 / 运维说明
- 输出验证命令、通过结果、已知限制和剩余风险

兼容性要求：
1. 不破坏现有 Discord 平台行为。
2. 不破坏现有 Codex runtime 行为。
3. 不随意改变现有配置格式；如需新增字段，必须保持向后兼容。
4. 不把平台差异写死成大量分支判断，优先复用平台 capability 和 agent capability 机制。

最终汇报给我时，必须包含：
1. 当前问题和缺口总结
2. 你们采取的实现策略
3. 每个任务的完成情况
4. 哪些行为已经验证
5. 哪些能力仍然受限
6. 是否达到“飞书渠道可稳定使用 Claude Code”的标准
7. 剩余风险与下一步建议

请开始：
先运行必要的只读检查，给出能力基线和缺口列表，再拆任务并分配给 worker。
EOF

echo "[4/6] Writing tmux guide"
cat >"$guide_file" <<EOF
# tmux quickstart for Feishu + Claude support work

Project:
$project_dir

tmux session:
$session_name

Manager prompt:
$prompt_file

Attach later with:
\`\`\`bash
tmux attach -t "$session_name"
\`\`\`

Kill later with:
\`\`\`bash
tmux kill-session -t "$session_name"
\`\`\`
EOF

if tmux has-session -t "$session_name" 2>/dev/null; then
  echo "Error: tmux session already exists: $session_name" >&2
  echo "Use a different session name or run: tmux kill-session -t \"$session_name\"" >&2
  exit 1
fi

echo "[5/6] Creating tmux session"
tmux new-session -d -s "$session_name" -n squad "cd \"$project_dir\" && claude"
tmux split-window -h -t "$session_name":0 "cd \"$project_dir\" && claude"
tmux split-window -v -t "$session_name":0.0 "cd \"$project_dir\" && claude"
tmux split-window -v -t "$session_name":0.1 "cd \"$project_dir\" && claude"
tmux select-layout -t "$session_name":0 tiled

tmux select-pane -t "$session_name":0.0 -T manager
tmux select-pane -t "$session_name":0.1 -T worker
tmux select-pane -t "$session_name":0.2 -T worker-2
tmux select-pane -t "$session_name":0.3 -T inspector

wait_for_pane_command "$session_name":0.0 claude 30
wait_for_pane_command "$session_name":0.1 claude 30
wait_for_pane_command "$session_name":0.2 claude 30
wait_for_pane_command "$session_name":0.3 claude 30

echo "[6/6] Sending squad commands into tmux panes"
send_tmux_text "$session_name":0.0 "/squad manager"
send_tmux_text "$session_name":0.1 "/squad worker"
send_tmux_text "$session_name":0.2 "/squad worker worker-2"
send_tmux_text "$session_name":0.3 "/squad inspector"

sleep 3
send_tmux_text "$session_name":0.0 "$(cat "$prompt_file")"

echo
echo "Ready."
echo "Project: $project_dir"
echo "tmux session: $session_name"
echo "Manager prompt: $prompt_file"
echo "Guide: $guide_file"

if (( no_attach == 0 )); then
  echo "Attaching to tmux session..."
  if [[ -n "${TMUX:-}" ]]; then
    tmux switch-client -t "$session_name"
  else
    tmux attach -t "$session_name"
  fi
else
  echo "Session created without attaching (--no-attach)."
fi
