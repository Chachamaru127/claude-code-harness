# 安装、更新、卸载

在运行命令前先选择你当前使用的工具（今使っている tool）。
本页保留了以 Claude 为主的安装路径和现有的 Codex CLI 安装路径，
同时展示候选与不支持的宿主，但不升级它们的支持层级。

`not_observed != absent`：当缺少运行时证据时，记录为 `not observed`（未观察到），
而不是把不确定性变成支持或拒绝的声称。

## 通用成功契约

每个宿主章节都包含：

- 首个提示词，
- 首个命令，
- 验证命令，
- 成功外观。

对于候选或不支持的宿主，这些字段描述的是研究或边界检查，
它们不是安装指令。

### Claude Code（`supported`）

安装：

```bash
claude
```

然后在 Claude Code 内部：

```text
/plugin marketplace add Chachamaru127/claude-code-harness
/plugin install harness@claude-code-harness-marketplace
/harness-setup
```

更新：

```text
/plugin update harness
/harness-setup
```

卸载：

```text
/plugin uninstall harness
```

首个提示词：

```text
Plan a small change with acceptance criteria.
```

首个命令：

```text
/harness-plan
```

验证命令：

```text
/harness-sync
```

成功外观：会话能看到 Harness 工作流 skill，`Plans.md` 状态可读，
且下一个建议的动作是 plan、work、review 或 release，而不是原始的临时实现。

### Codex CLI（`supported`）

安装：

```bash
git clone https://github.com/Chachamaru127/claude-code-harness.git
cd claude-code-harness
./scripts/setup-codex.sh --user
```

通过隔离的 marketplace 冒烟测试，已验证 Codex CLI `0.132.0` 可直接安装插件：
该测试将 `.codex-plugin/plugin.json` 与 `codex/.codex/skills/` 打包进临时 marketplace。
仓库保留 `scripts/setup-codex.sh --user` 作为面向用户的回退路径，
直到直接插件路径具备相同的备份与遗留 skill 清理保障。

```bash
cd claude-code-harness
bash tests/test-codex-plugin-adapter.sh
```

如果 marketplace 安装不可用，或你需要现有的备份与遗留 skill 清理行为，
请使用回退脚本。

更新：

```bash
cd /path/to/claude-code-harness
git pull --ff-only
./scripts/setup-codex.sh --user
```

卸载：

```bash
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
mkdir -p "$CODEX_HOME/backups/manual-codex-uninstall"
for name in harness-plan harness-work harness-review harness-release harness-setup harness-sync breezing harness-loop; do
  [ -e "$CODEX_HOME/skills/$name" ] || continue
  mv "$CODEX_HOME/skills/$name" "$CODEX_HOME/backups/manual-codex-uninstall/"
done
```

此卸载路径仅移除已复制的 Harness skill 条目。
它不删除 Codex 设置、项目文件或 harness-mem 状态。

首个提示词：

```text
Use $harness-plan to create a plan for this change.
```

首个命令：

```text
$harness-plan
```

验证命令：

```bash
test -d "${CODEX_HOME:-$HOME/.codex}/skills/harness-plan"
test -f "${CODEX_HOME:-$HOME/.codex}/config.toml"
```

成功外观：Codex 能从 `CODEX_HOME` 列出或调用 Harness skill。
Live H4（2026-07-17）与 H7 release-preflight fail-closed 门禁将 CLI 路径锁定在 `supported` 层级。
3cli Bash PreToolUse 基线适用。
直接插件安装仅证明 marketplace 兼容性；单独的 app 候选门禁与 `scripts/setup-codex.sh --user` 回退路径仍被记录在案。

### Codex app（`candidate`）

不支持理由：Codex app 的行为未被 Codex CLI 安装、Codex CLI 帮助输出或 `scripts/setup-codex.sh --user` 证明。
Phase 73.1.3 没有面向最终用户的 app 安装、更新或卸载路径。

首个提示词：

```text
Use the Harness onboarding doc to identify the next safe planning step.
```

首个命令：

```text
No install command in Phase 73.1.3; candidate smoke only.
```

验证命令：

```bash
rg -n "Codex app.*candidate|app-specific smoke" docs/tool-capability-matrix.md docs/bootstrap-routing-contract.md docs/onboarding
```

成功外观：结果记录为 `candidate`、`manual` 或 `not observed`；
它不计入 Codex CLI 的对等性。

### OpenCode（`internal-compatible`）

安装：

```bash
git clone https://github.com/Chachamaru127/claude-code-harness.git
cd your-project
/path/to/claude-code-harness/scripts/setup-opencode.sh
```

更新：

```bash
cd /path/to/claude-code-harness
git pull --ff-only
cd your-project
/path/to/claude-code-harness/scripts/setup-opencode.sh
```

卸载：

```bash
mkdir -p .opencode/backups/manual-uninstall
[ -d .opencode/skills ] && mv .opencode/skills .opencode/backups/manual-uninstall/skills
[ -d .opencode/commands ] && mv .opencode/commands .opencode/backups/manual-uninstall/commands
[ -f opencode.json ] && mv opencode.json .opencode/backups/manual-uninstall/opencode.json
```

仅在你确定 `AGENTS.md` 完全由 Harness 创建时才移动它。
不要盲目删除项目指令。

首个提示词：

```text
Use the harness-plan skill to create a plan.
```

首个命令：

```text
harness-plan
```

验证命令：

```bash
test -f .opencode/skills/harness-plan/SKILL.md
test -f opencode.json
```

成功外观：OpenCode 能看到 Harness skill 文件与项目指引。
运行时 bootstrap 对等性仍未被证明，因此层级保持 `internal-compatible`。

### Cursor（`supported`）

安装：

```bash
git clone https://github.com/Chachamaru127/claude-code-harness.git
cd claude-code-harness
./scripts/setup-cursor.sh
```

然后重载 Cursor（Developer: Reload Window），使本地插件与 skill 注册生效。
不要通过 `~/.cursor/plugins/local` 下的符号链接注册仓库；
Cursor 会拒绝该目录以外的符号链接目标。

更新：

```bash
cd /path/to/claude-code-harness
git pull --ff-only
./scripts/setup-cursor.sh
```

卸载：

```bash
mkdir -p ~/.cursor/backups/manual-cursor-uninstall
[ -d ~/.cursor/plugins/local/harness ] \
  && mv ~/.cursor/plugins/local/harness ~/.cursor/backups/manual-cursor-uninstall/
```

此卸载路径仅移除已复制的 Harness 本地插件。
它不删除 Cursor 设置、项目文件或 harness-mem 状态。

首个提示词：

```text
Plan a small change with acceptance criteria.
```

首个命令：

```text
/harness-plan
```

验证命令：

```bash
bash scripts/setup-cursor.sh --check
test -f ~/.cursor/plugins/local/harness/skills/breezing/SKILL.md
```

成功外观：重载后 Cursor 列出 Harness skill（例如 `/breezing`、`/harness-plan`）。
Live H4 工作流冒烟（2026-07-17）与 H7 release-preflight fail-closed 门禁锁定 `supported`。
无传统 FS jail —— 容器隔离在 Harness 侧；见 [Containment disclosure](../docs/CURSOR_INTEGRATION.md#containment-disclosure)。
PM 交接文档与 adapter 安装声称保持分离。

容器限制（无传统 FS jail、allowlist 尽力而为）记录在
[known-limitations.md](../known-limitations.md) 与
[CURSOR_INTEGRATION.md](../docs/CURSOR_INTEGRATION.md#containment-disclosure) 中。

### Grok（`supported`）

安装：

```bash
git clone https://github.com/Chachamaru127/claude-code-harness.git
cd claude-code-harness
./scripts/setup-grok.sh
```

然后重启 Grok 或打开新会话，使用户插件与 skill 在任意项目中注册。
优先使用 CLI 安装路径（底层为 `grok plugin install`）。
若缺少 Grok CLI，安装脚本回退到在 `~/.grok/plugins/harness` 下的真实目录复制。

更新：

```bash
cd /path/to/claude-code-harness
git pull --ff-only
./scripts/setup-grok.sh
```

卸载：

```bash
# When installed via CLI:
grok plugin uninstall harness --confirm

# Fallback copy path:
mkdir -p ~/.grok/backups/manual-grok-uninstall
[ -d ~/.grok/plugins/harness ] \
  && mv ~/.grok/plugins/harness ~/.grok/backups/manual-grok-uninstall/
```

此卸载路径仅移除 Harness Grok 插件安装。
它不删除 Grok 设置、项目文件或 harness-mem 状态。

首个提示词：

```text
Plan a small change with acceptance criteria.
```

首个命令：

```text
/harness-plan
```

验证命令：

```bash
bash scripts/setup-grok.sh --check
test -f ~/.local/share/claude-code-harness/grok/skills/breezing/SKILL.md \
  || test -f ~/.grok/plugins/harness/skills/breezing/SKILL.md
```

成功外观：安装后 Grok 列出 Harness skill（例如 `/breezing`、`/harness-plan`），
包括从非 CCH 项目启动时。
Live H4 工作流冒烟（2026-07-17）与 H7 release-preflight fail-closed 门禁锁定 `supported`；
Claude 信封 PreToolUse 基线 —— 非完整的 Claude SessionStart / PreToolUse 对等性。
证据边界：`docs/research/grok-adapter-candidate.md`。

### Hermes Agent（`candidate`）

不支持理由：Hermes Agent 有本地操作员证据，证明手动 skill 符号链接暴露与动态斜杠命令发现，
但本仓库没有 Hermes 安装脚本、打包的宿主分发、路由模型、运行时基线对等性或 CI 门禁的工作流冒烟。

首个提示词：

```text
Use the Harness onboarding doc to identify the next safe planning step.
```

首个命令：

```text
No Harness install command in this phase; candidate symlink research only.
```

验证命令：

```bash
bash tests/test-hermes-agent-candidate.sh
```

成功外观：结果记录为 `candidate`、`manual` 或 `not observed`。
针对 `/harness-*` 与 `/breezing` 的本地动态斜杠发现，不计入公开支持、运行时基线对等性或 Claude hook 对等性。
证据边界：`docs/research/hermes-agent-candidate.md`。

### GitHub Copilot CLI（`candidate`）

不支持理由：GitHub Copilot CLI 可能成为手动指令档案或 adapter 候选，
但 Phase 73.1.3 没有针对它的已验证 Harness bootstrap、skill 路由、安装、更新或卸载路径。

首个提示词：

```text
Check whether a Harness manual profile is possible, then report missing bootstrap proof.
```

首个命令：

```text
No Harness command in Phase 73.1.3; candidate investigation only.
```

验证命令：

```bash
rg -n "GitHub Copilot CLI.*candidate|Copilot.*bootstrap" docs/tool-capability-matrix.md docs/bootstrap-routing-contract.md docs/onboarding
```

成功外观：证据保持为 `candidate`、`manual` 或 `not observed`；
仅凭 Superpowers 或官方 CLI 文档不作支持声称。

### Antigravity CLI（`future/unsupported`）

不支持理由：当前工件集中没有官方或本地已验证的 Harness adapter 路径。
因此 Phase 73.1.3 不对最终用户提供安装、更新或卸载路径。

首个提示词：

```text
No end-user prompt in Phase 73.1.3; record only whether an official route is observed.
```

首个命令：

```text
No command in Phase 73.1.3.
```

验证命令：

```bash
rg -n "Antigravity CLI.*future/unsupported|official or verified adapter route" docs/tool-capability-matrix.md docs/bootstrap-routing-contract.md docs/onboarding
```

成功外观：Antigravity 保持 `future/unsupported` 或 `not observed`；
公开的 onboarding 路径不将其呈现为可安装。

针对旧版 Claude 插件 ID，请遵循 [重命名指南](../docs/onboarding/plugin-rename.md)。
更新旧 ID 不会切换其名称。