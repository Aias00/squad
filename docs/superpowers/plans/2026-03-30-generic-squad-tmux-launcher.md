# Generic Squad tmux Launcher Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace project-specific Claude + squad tmux bootstrap scripts with one reusable launcher that reads per-project config and per-run task briefs, generates a manager prompt, and starts a tmux squad session automatically.

**Architecture:** Keep the launcher as a Bash entrypoint for portability and direct tmux integration. Move project-specific inputs into a stable project config file and a per-run task brief, then synthesize manager prompt/output files from those inputs before starting panes and injecting `/squad` commands.

**Tech Stack:** Bash, tmux, squad CLI, Claude Code CLI, markdown/yaml text files

---

### Task 1: Add failing smoke test for generic launcher contract

**Files:**
- Create: `tests/squad_tmux_launcher_smoke.sh`
- Test: `tests/squad_tmux_launcher_smoke.sh`

- [ ] **Step 1: Write the failing test**

Create a shell smoke test that:
- creates a temp project
- writes `.squad/launcher.yaml`
- writes `.squad/run-task.md`
- invokes `scripts/squad-tmux-launch.sh --dry-run --no-setup --no-attach`
- asserts generated files exist and contain expected content

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/squad_tmux_launcher_smoke.sh`
Expected: FAIL because `scripts/squad-tmux-launch.sh` does not exist yet or lacks required behavior.

### Task 2: Implement generic launcher inputs and generation flow

**Files:**
- Create: `scripts/squad-tmux-launch.sh`
- Create: `templates/launcher.yaml.example`
- Create: `templates/run-task.md.example`
- Modify: `scripts/feishu-claude-manager-tmux.sh`
- Modify: `scripts/feishu-claude-manager-quickstart.sh`
- Modify: `scripts/claude-squad-camel-quickstart.sh`

- [ ] **Step 1: Implement CLI argument parsing and help output**

Support:
- `<project-dir>`
- `--task-file <path>`
- `--session-name <name>`
- `--workers <n>`
- `--no-setup`
- `--no-attach`
- `--dry-run`
- `--reuse-session`
- `-h`, `--help`

- [ ] **Step 2: Implement project/task input resolution**

Support:
- project config: `<project>/.squad/launcher.yaml`
- task brief priority: `--task-file` then `<project>/.squad/run-task.md`
- defaults when config file is missing

- [ ] **Step 3: Implement generated output files**

Generate:
- `.squad/quickstart/generated-manager.prompt.md`
- `.squad/quickstart/generated-run-summary.md`
- `.squad/quickstart/generated-terminal-map.md`

- [ ] **Step 4: Implement tmux creation and command injection**

Start:
- 1 manager
- N workers
- 1 inspector

Inject:
- `/squad manager`
- `/squad worker`
- `/squad worker worker-<n>`
- `/squad inspector`
- generated manager prompt

### Task 3: Make existing project-specific scripts delegate or deprecate cleanly

**Files:**
- Modify: `scripts/claude-squad-camel-quickstart.sh`
- Modify: `scripts/feishu-claude-manager-quickstart.sh`
- Modify: `scripts/feishu-claude-manager-tmux.sh`

- [ ] **Step 1: Decide compatibility behavior**

Either:
- keep them as wrappers around the generic launcher
- or leave them but document them as legacy examples

- [ ] **Step 2: Ensure they no longer diverge in behavior**

Reduce duplication so future changes happen in one place.

### Task 4: Verify green path and document usage

**Files:**
- Modify: `README.md`
- Test: `tests/squad_tmux_launcher_smoke.sh`

- [ ] **Step 1: Run smoke test to verify it passes**

Run: `bash tests/squad_tmx_launcher_smoke.sh`
Expected: PASS

- [ ] **Step 2: Run shell syntax checks**

Run:
- `bash -n scripts/squad-tmux-launch.sh`
- `bash -n tests/squad_tmux_launcher_smoke.sh`

Expected: both PASS

- [ ] **Step 3: Update README usage notes if needed**

Document:
- launcher inputs
- config/task file locations
- dry-run behavior
- tmux session reuse behavior
