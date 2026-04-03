#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  claude-squad-camel-quickstart.sh <project-dir>

What it does:
  1. Verifies `squad` and `claude` are installed
  2. Runs `squad setup claude`
  3. Runs `squad init --refresh-roles` in the target project
  4. Generates:
     - .squad/quickstart/manager-camel-parallel-upgrade.prompt.md
     - .squad/quickstart/terminal-commands.md

After the script finishes:
  - Open 4 terminals in the target project
  - Start Claude Code in each terminal
  - Run `/squad manager`, `/squad worker`, `/squad worker worker-2`, `/squad inspector`
  - Paste the generated manager prompt into the manager session
EOF
}

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: required command not found: $cmd" >&2
    exit 1
  fi
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ $# -ne 1 ]]; then
  usage >&2
  exit 1
fi

require_cmd squad
require_cmd claude

project_input="$1"
mkdir -p "$project_input"
cd "$project_input"
project_dir="$(pwd)"

echo "[1/4] Refreshing Claude slash command"
squad setup claude

echo "[2/4] Initializing squad workspace in $project_dir"
squad init --refresh-roles

quickstart_dir="$project_dir/.squad/quickstart"
mkdir -p "$quickstart_dir"

prompt_file="$quickstart_dir/manager-camel-parallel-upgrade.prompt.md"
terminals_file="$quickstart_dir/terminal-commands.md"

echo "[3/4] Writing manager prompt"
cat >"$prompt_file" <<'EOF'
目标：在当前项目基础上，补齐基于 Apache Camel 的并行编排能力；采用兼容优先的最小改造策略，在尽量不动现有架构的前提下，做必要的执行引擎、状态流转和错误处理优化。

背景：
- 当前项目已经使用 Apache Camel 作为编排能力。
- 现有后端实现存在缺陷，导致无法稳定支持并行编排。
- 这次工作的核心不是推倒重写，而是在现有能力之上完善并行编排，并保证旧能力尽量不被破坏。

硬性约束：
1. 必须尽量兼容现有 DSL / 配置格式。
2. 必须尽量兼容现有 API / 调用方式。
3. 必须尽量兼容现有运行时行为和结果语义。
4. 如果并行能力与兼容性冲突，优先保证兼容；新增能力优先通过可选配置、兼容层、默认值或特性开关引入。
5. 不允许直接做大规模重写，不允许先入为主地替换整个编排模型。
6. manager 负责分析、拆解、协调、验收，不要自己承担主要实现。

执行原则：
1. 先审计现状，再拆任务，再推进改造；不要一开始就让多个 worker 盲改核心链路。
2. 优先使用 `squad task create / ack / complete` 管理任务；自由消息只用于补充沟通。
3. 所有任务都必须写清楚目标、范围、涉及文件、不可破坏的兼容边界、验收标准。
4. 每个阶段完成后都要让 inspector 审查，重点检查回归风险和兼容性破坏。
5. 如果发现范围过大或风险过高，要主动收缩改动，拆成更小的增量步骤推进。

请先完成以下工作：
1. 扫描仓库和现有 Camel 编排实现，梳理当前能力边界。
2. 明确“为什么现在无法支持并行编排”的根因，不要停留在表面现象。
3. 输出一份兼容性基线，至少包括：
   - 现有 DSL / 配置格式
   - 现有 API / 调用方式
   - 现有运行时关键语义
   - 当前已有的串行编排能力
   - 不能被破坏的外部行为
4. 明确并行编排要支持的最小目标能力，至少包括：
   - 明确可并行的分支能够并发执行
   - 并行分支完成后能够正确汇聚
   - 分支状态可追踪
   - 超时、失败、重试、取消、部分失败的语义明确
   - 不影响现有串行流程
5. 基于以上分析，再拆成 3 到 4 个增量任务，分配给在线 worker。

拆任务时，优先按下面的职责方向组织，但可以根据在线 agent 数量调整：
- 任务 A：现状审计与兼容基线
  目标：梳理当前 Camel 编排实现、执行路径、状态模型、错误处理链路，明确并行能力缺失的根因。
  验收：给出根因分析、兼容边界、风险点和建议改造范围。

- 任务 B：并行编排最小改造设计
  目标：在不破坏现有 DSL/API/语义的前提下，提出支持并行编排的最小实现路径。
  重点关注：Camel EIP 使用方式、Exchange/上下文隔离、分支汇聚、线程安全、状态同步。
  验收：给出最小改造方案、涉及模块、兼容策略、回退策略。

- 任务 C：执行引擎 / 状态流转 / 错误处理增量优化
  目标：只围绕并行编排所必需的部分进行内部重构。
  重点关注：任务状态机、分支生命周期、失败传播、超时处理、重试策略、幂等性、一致性。
  验收：代码改动范围可控，旧行为不被破坏，并能支撑并行能力落地。

- 任务 D：回归验证与兼容性验收
  目标：补齐测试和验证，证明旧能力仍可用，新并行能力可用。
  至少覆盖：
  - 旧串行编排回归
  - 新并行编排成功路径
  - 分支失败
  - 超时
  - 重试
  - 汇聚结果正确性
  - API/DSL/配置兼容性
  验收：输出验证结果、未覆盖风险、建议补充项。

Apache Camel 相关检查要求：
1. 不要先入为主地认定必须使用某一种 Camel 模式；要结合当前项目现状判断。
2. 重点核查：
   - 当前编排是如何映射到 Camel route / processor / EIP 的
   - 并行执行时上下文是否共享、是否会产生线程安全问题
   - 分支结果如何汇聚
   - 状态持久化或内存状态是否能表达 fork/join 过程
   - 错误传播、事务边界、补偿、重试是否会在并行场景下失真
3. 如需新增 DSL 或配置项，必须保证：
   - 默认值保持旧行为
   - 老配置无需修改即可继续运行
   - API 尽量不变
   - 运行结果语义尽量不变

协作要求：
1. manager 先运行 `squad agents`、`squad doctor`、必要的只读检查，再开始分配任务。
2. 每个 worker 完成后，manager 要先接收结果，再转给 inspector 审查。
3. inspector 如果给出 FAIL，manager 必须根据反馈发起返工，不要直接结束。
4. 避免多个 worker 同时改同一批核心文件；优先按模块边界拆分，降低冲突。

最终输出给我时，必须包含：
1. 当前问题根因总结。
2. 这次最小改造方案的核心思路。
3. 做了哪些改动，哪些地方刻意没有动。
4. 对 DSL / 配置 / API / 运行时语义的兼容性结论。
5. 验证命令、验证结果、是否存在回归风险。
6. 剩余限制、已知风险、后续建议。

请开始：先做现状扫描和兼容基线，不要一上来直接修改代码。
EOF

echo "[4/4] Writing terminal quickstart"
cat >"$terminals_file" <<EOF
# Claude Code + squad quickstart

Project:
$project_dir

Generated files:
- $prompt_file
- $terminals_file

## Terminal 1
\`\`\`bash
cd "$project_dir"
claude
\`\`\`

Then type:
\`\`\`text
/squad manager
\`\`\`

After the manager joins, paste the contents of:
\`\`\`text
$prompt_file
\`\`\`

## Terminal 2
\`\`\`bash
cd "$project_dir"
claude
\`\`\`

Then type:
\`\`\`text
/squad worker
\`\`\`

## Terminal 3
\`\`\`bash
cd "$project_dir"
claude
\`\`\`

Then type:
\`\`\`text
/squad worker worker-2
\`\`\`

## Terminal 4
\`\`\`bash
cd "$project_dir"
claude
\`\`\`

Then type:
\`\`\`text
/squad inspector
\`\`\`

## Optional observer terminal
\`\`\`bash
cd "$project_dir"
squad agents
squad doctor
squad task list
squad history
\`\`\`
EOF

echo
echo "Ready."
echo
echo "Project: $project_dir"
echo "Manager prompt: $prompt_file"
echo "Terminal guide: $terminals_file"
echo
echo "Next steps:"
echo "  1. Open 4 terminals in: $project_dir"
echo "  2. Start Claude Code in each terminal: claude"
echo "  3. Run /squad manager, /squad worker, /squad worker worker-2, /squad inspector"
echo "  4. Paste the generated manager prompt into the manager session"
