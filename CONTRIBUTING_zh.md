# 为 claude-code-harness 做贡献

感谢你有意为 **claude-code-harness** 做贡献！本文档提供贡献指南。

## 如何贡献

### 报告问题

安全漏洞不是普通问题。请遵循 [SECURITY.md](SECURITY_zh.md)，
不要在公开的 GitHub issue 中包含漏洞利用细节、密钥、令牌或私有数据。

1. 检查该问题是否已存在于 [GitHub Issues](https://github.com/Chachamaru127/claude-code-harness/issues)
2. 如果不存在，创建一个新 issue，包含：
   - 清晰描述问题的标题
   - 复现步骤
   - 期望行为与实际行为
   - Claude Code 版本与操作系统

### 提交改动

1. Fork 仓库
2. 创建功能分支：`git checkout -b feature/your-feature-name`
3. 进行你的改动
4. 在本地测试你的改动
5. 用清晰的提交信息提交：`git commit -m "feat: add new feature"`
6. 推送到你的 fork：`git push origin feature/your-feature-name`
7. 开启一个 Pull Request

### 提交信息格式

我们遵循 [Conventional Commits](https://www.conventionalcommits.org/)：

- `feat:` - 新功能
- `fix:` - Bug 修复
- `docs:` - 文档改动
- `refactor:` - 代码重构
- `test:` - 添加或更新测试
- `chore:` - 维护类任务

### 代码风格

- 使用清晰、有描述性的名称
- 为复杂逻辑添加注释
- 让命令/agent/技能保持单一职责

## 插件结构


> **注意**：自 v2.17.0 起，命令已迁移到技能。新功能推荐使用技能。

### 添加新技能（推荐）

1. 创建 `skills/your-skill/SKILL.md`，带 YAML frontmatter：
2. 如有需要，把支撑文件加到 `skills/your-skill/references/`
3. 在 README.md 中补充新技能

### 添加新 Agent

1. 创建 `agents/your-agent.md`
2. 用 YAML frontmatter 定义该 agent
3. 更新 README.md（推荐）

> 注意：agents/ 会被 Claude Code 自动发现。通常你不需要在 `plugin.json` 中手工枚举它们。

## 版本管理

版本定义在两处，必须保持同步：
- `VERSION` - 事实来源
- `.claude-plugin/plugin.json` - 供插件系统使用

日常的功能/文档 PR 应保持这两个文件不变，并把面向用户的改动记录在
`CHANGELOG.md` 的 `[Unreleased]` 下。
只有在你有意做发布时才使用版本 bump。

### 版本脚本


### 仅发布场景的版本策略

- 日常 PR：不编辑 `VERSION` 或 `.claude-plugin/plugin.json`；在 `[Unreleased]` 下追加说明
- 发布工作：运行 `./scripts/sync-version.sh bump`，追加带版本号的 `CHANGELOG.md` 条目，然后创建 tag / GitHub Release
- 仓库的 pre-commit hook 只在你有意编辑发布元数据时把 `plugin.json` 同步到 `VERSION`；它不会自动 bump patch 版本

### 版本一致性检查

- **本地（推荐）**：提交前运行 `./scripts/sync-version.sh check`
- **CI（推荐）**：在 PR 上运行 `./tests/validate-plugin.sh` 和 `./scripts/ci/check-consistency.sh`

## CHANGELOG 记录规则（必读）

**遵循 [Keep a Changelog](https://keepachangelog.com/ja/1.0.0/) 格式**

每个版本条目使用以下小节：


**小节的区分使用**：

| 小节 | 什么时候用 |
|------------|----------|
| Added | 添加了完全新的功能时 |
| Changed | 改变了既有功能的行为或体验时 |
| Deprecated | 预告将来要删除的功能时 |
| Removed | 删除了功能或命令时 |
| Fixed | 修复了 bug 或缺陷时 |
| Security | 做了安全相关的修复时 |

**Before/After 表格**：仅在有重大体验变化（命令废止/合并、工作流变更、破坏性变更）时添加。轻微修正可以省略。

**版本比较链接**：在 CHANGELOG.md 末尾以 `[X.Y.Z]: https://github.com/.../compare/vPREV...vX.Y.Z` 格式添加

---

## 测试

提交前：

1. 校验插件结构与一致性：


2. （推荐）启用 pre-commit hook（保持发布元数据同步但不自动 bump）：


   **Windows 用户**：Git hook 需要 [Git for Windows](https://gitforwindows.org/)（包含 Git Bash）。无论你用哪种 shell（PowerShell、CMD 等），hook 都通过 Git Bash 自动运行。

3. 用 `--plugin-dir` 在另一个项目里做本地测试：


3. 确认命令按预期工作（`/help`），且核心循环能跑通：

   - `/harness-init`
   - `/plan-with-agent`
   - `/work`
   - `/harness-review`

## 有疑问？

- 为疑问开一个 issue
- 查看已有文档

感谢你的贡献！

```
claude-code-harness/
├── .claude-plugin/
│   ├── plugin.json      # Plugin manifest
│   └── marketplace.json # Marketplace config
├── skills/              # Skills (primary - v2.17.0+)
├── agents/              # Subagents
├── hooks/               # Lifecycle hooks
├── templates/           # Template files
├── README.md
├── LICENSE
└── CONTRIBUTING.md
```
```yaml
   ---
   name: your-skill
   description: "Description with trigger phrases. Use when... Do NOT load for..."
   allowed-tools: ["Read", "Write", "Edit", "Bash"]
   ---
```
```bash
# Check if versions are in sync
./scripts/sync-version.sh check

# Sync plugin.json to VERSION
./scripts/sync-version.sh sync

# Bump patch version for a release (e.g., 2.0.0 → 2.0.1)
./scripts/sync-version.sh bump
```
```markdown
## [X.Y.Z] - YYYY-MM-DD

### Added
- 新機能について

### Changed
- 既存機能の変更について

### Deprecated
- 間もなく削除される機能について

### Removed
- 削除された機能について

### Fixed
- バグ修正について

### Security
- 脆弱性に関する場合

#### Before/After（大きな変更時のみ）

| Before | After |
|--------|-------|
| 変更前の状態 | 変更後の状態 |
```
```bash
   ./tests/validate-plugin.sh
   ./scripts/ci/check-consistency.sh
```
```bash
   ./scripts/install-git-hooks.sh
```
```bash
   cd /path/to/your-project
   claude --plugin-dir /path/to/claude-code-harness
```