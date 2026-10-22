# 实现指南

本指南是面向 Claude Code Harness 贡献者的简明实现地图。
它是 `README.md`、`AGENTS.md` 和 `CLAUDE.md` 的补充。

## 当前架构

Claude Code Harness v4 以 Go 为主。

- 运行时入口：`bin/harness`
- Go 源码：`go/`
- Plugin manifest：`.claude-plugin/plugin.json`
- Hook 配置：`hooks/hooks.json` 和 `.claude-plugin/hooks.json`
- 主技能：`skills/`
- 公共镜像：`.agents/skills/`、`codex/.codex/skills/`、`opencode/skills/`
- 模板：`templates/`
- 测试与校验器：`tests/`、`scripts/ci/`

旧的 TypeScript `core/` 假设不属于当前必需的运行时界面。
校验器应改为检查 Go 运行时和随包分发的 plugin 界面。

## 实现流程

1. 阅读 `Plans.md`，确定精确的任务范围。
2. 保持改动收敛，只更新归属的文件。
3. 涉及技能改动时，先更新 `skills/`。
4. 技能改动后运行 `bash scripts/sync-skill-mirrors.sh`。
5. 为变更的行为添加或更新聚焦测试。
6. 交接前运行下面的验证命令。

## 技能与镜像规则

`skills/` 是共享技能的事实来源（SSOT）。

编辑技能后，用以下命令同步镜像：

```bash
bash scripts/sync-skill-mirrors.sh
bash scripts/sync-skill-mirrors.sh --check
```

当 Codex 工作流需要不同的指令界面时，Codex 专属行为放在 `skills-codex/`。
除非同样适用于 Claude Code，否则不要把 Codex 专属行为加进共享技能。

## Agent frontmatter 规则

Plugin subagent 不携带 Claude Code 仅运行时的设置，例如：

- `permissionMode`
- 顶层 `hooks`
- `mcpServers`

安全性通过 plugin hooks、Go guardrails、settings 和父会话的权限模型来保证。
参见 `docs/agent-frontmatter-policy.md`。

## 模板规则

所有 `templates/**/*.template` 文件必须在
`templates/template-registry.json` 中注册。

受版本管理的 Markdown 模板应包含 frontmatter：

```markdown
---
_harness_template: "path/from/templates"
_harness_version: "x.y.z"
---
```

当语言特定模板在 registry 中带有不同的 `locale` 值时，可以共用同一个输出路径。

## 验证命令

用以下命令做广泛的本地验证：

```bash
bash tests/validate-plugin.sh
bash tests/validate-skills.sh
bash scripts/ci/check-consistency.sh
bash scripts/ci/check-template-registry.sh
cd go && go build ./cmd/harness/ && go test ./... && go vet ./...
```

要完整跑一遍 shell 测试：

```bash
while IFS= read -r test_file; do
  bash "$test_file" < /dev/null
done < <(find tests -maxdepth 1 -type f \( -name 'test-*.sh' -o -name 'validate-*.sh' \) | sort)
```

## 发布边界

日常实现工作不应编辑 `VERSION` 或
`.claude-plugin/plugin.json` 的版本字段。

版本变更属于发布工作，应使用 `skills/harness-release/` 中记录的
发布脚本与发布验证流程。

